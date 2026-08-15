from __future__ import annotations

import shlex
import time
import uuid
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path

from libtmux import exc as libtmux_exc
from libtmux.pane import Pane
from libtmux.server import Server
from libtmux.session import Session
from rich.text import Text

_Check = Callable[["TerminalFrame"], str | None]

_KEYS = {
    "Down": "Down",
    "Enter": "Enter",
    "Escape": "Escape",
    "Left": "Left",
    "PageDown": "NPage",
    "PageUp": "PPage",
    "Right": "Right",
    "Space": "Space",
    "Up": "Up",
}


@dataclass(frozen=True)
class TerminalFrame:
    width: int
    height: int
    lines: tuple[str, ...]
    styled_lines: tuple[str, ...]

    @classmethod
    def decode(
        cls,
        width: int,
        height: int,
        styled_lines: Sequence[str],
    ) -> TerminalFrame:
        styled = tuple(styled_lines)
        return cls(
            width,
            height,
            tuple(Text.from_ansi(line).plain for line in styled),
            styled,
        )


class TuiError(AssertionError):
    def __init__(
        self,
        message: str,
        *,
        frame: TerminalFrame | None = None,
    ) -> None:
        self.frame = frame
        super().__init__(message)


@dataclass
class TuiDriver:
    _pane: Pane
    _session: Session

    @classmethod
    def start(
        cls,
        server: Server,
        argv: Sequence[str],
        *,
        cwd: Path,
        env: Mapping[str, str] | None = None,
        width: int = 100,
        height: int = 30,
    ) -> TuiDriver:
        if not argv:
            raise ValueError("TUI argv must not be empty")
        if width < 1 or height < 1:
            raise ValueError("Terminal dimensions must be positive")
        command = [
            "env",
            *(f"{key}={value}" for key, value in (env or {}).items()),
            *argv,
        ]
        try:
            session = server.new_session(
                session_name=f"tui-{uuid.uuid4().hex}",
                start_directory=cwd,
                window_command=shlex.join(command),
                x=width,
                y=height,
            )
            pane = session.active_pane
            pane.window.set_option("remain-on-exit", "on")
            return cls(pane, session)
        except libtmux_exc.LibTmuxException as error:
            raise TuiError(f"Could not start TUI: {error}") from error

    def close(self) -> None:
        try:
            self._session.kill()
        except libtmux_exc.LibTmuxException as error:
            if "can't find session" in str(error) or "no server running" in str(error):
                return
            raise TuiError(f"Could not close TUI: {error}") from error

    def wait_for_exit(self, timeout: float = 10) -> int:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            status = self._exit_status()
            if status is not None:
                return status
            time.sleep(0.05)
        frame = self.capture()
        raise TuiError("TUI did not exit", frame=frame)

    def key(self, name: str) -> None:
        if len(name) == 1:
            self.write(name)
            return
        token = _ctrl_key(name) or _KEYS.get(name)
        if token is None:
            raise ValueError(f"Unknown terminal key: {name!r}")
        self._pane.send_keys(token, enter=False, literal=False)

    def write(self, text: str) -> None:
        self._pane.send_keys(text, enter=False, literal=True)

    def paste(self, text: str) -> None:
        self._pane.server.set_buffer(text)
        self._pane.paste_buffer(delete_after=True, bracket=True)

    def press(self, row: int, column: int) -> PointerContact:
        self._validate_position(row, column)
        self._send_raw(f"\x1b[<0;{column};{row}M")
        return PointerContact(self, row, column)

    def click(self, row: int, column: int) -> None:
        self.press(row, column).release()

    def wheel(self, direction: str, row: int, column: int) -> None:
        self._validate_position(row, column)
        try:
            code = {"up": 64, "down": 65}[direction]
        except KeyError as error:
            raise ValueError(f"Unknown wheel direction: {direction!r}") from error
        self._send_raw(f"\x1b[<{code};{column};{row}M")

    def resize(
        self,
        *,
        width: int | None = None,
        height: int | None = None,
    ) -> None:
        if width is None and height is None:
            raise ValueError("Resize needs width or height")
        if width is not None and width < 1 or height is not None and height < 1:
            raise ValueError("Terminal dimensions must be positive")
        self._pane.window.set_option("window-size", "manual")
        self._pane.window.resize(width=width, height=height)

    def capture(self) -> TerminalFrame:
        try:
            self._pane.refresh()
            return TerminalFrame.decode(
                int(self._pane.pane_width),
                int(self._pane.pane_height),
                self._pane.capture_pane(escape_sequences=True),
            )
        except libtmux_exc.LibTmuxException as error:
            raise TuiError(f"Terminal capture failed: {error}") from error

    def wait(self, check: _Check, *, timeout: float = 10) -> TerminalFrame:
        deadline = time.monotonic() + timeout
        mismatch = "condition was not met"
        frame: TerminalFrame | None = None
        while time.monotonic() < deadline:
            status = self._exit_status()
            if status is not None:
                frame = self.capture()
                raise TuiError(
                    f"TUI exited before the expected state with status {status}",
                    frame=frame,
                )
            frame = self.capture()
            if (mismatch := check(frame)) is None:
                return frame
            time.sleep(0.05)
        rendered = "\n".join(frame.lines) if frame is not None else "<no frame>"
        raise TuiError(f"{mismatch}\n\nLast frame:\n{rendered}", frame=frame)

    def hold(
        self,
        check: _Check,
        *,
        duration: float = 0.25,
    ) -> TerminalFrame:
        deadline = time.monotonic() + duration
        frame = self.capture()
        while time.monotonic() < deadline:
            status = self._exit_status()
            if status is not None:
                raise TuiError(
                    f"TUI exited during a stability check with status {status}",
                    frame=frame,
                )
            frame = self.capture()
            if (mismatch := check(frame)) is not None:
                raise TuiError(
                    f"{mismatch}\n\nFrame:\n" + "\n".join(frame.lines),
                    frame=frame,
                )
            time.sleep(0.05)
        return frame

    def _exit_status(self) -> int | None:
        try:
            self._pane.refresh()
        except libtmux_exc.LibTmuxException:
            return None
        return int(self._pane.pane_dead_status) if self._pane.pane_dead == "1" else None

    def _validate_position(self, row: int, column: int) -> None:
        frame = self.capture()
        if not 1 <= row <= frame.height or not 1 <= column <= frame.width:
            raise ValueError(
                f"Terminal position ({row}, {column}) is outside "
                f"{frame.height}x{frame.width}"
            )

    def _send_raw(self, sequence: str) -> None:
        self._pane.send_keys(sequence, enter=False, literal=True)


@dataclass
class PointerContact:
    _driver: TuiDriver
    row: int
    column: int
    _released: bool = False
    _settled: bool = False

    def move_to(self, *, row: int, column: int) -> None:
        if self._released:
            raise ValueError("Pointer contact is already released")
        self._driver._validate_position(row, column)
        if not self._settled:
            time.sleep(0.2)
            self._settled = True
        self.row = row
        self.column = column
        self._driver._send_raw(f"\x1b[<32;{column};{row}M")

    def release(self) -> None:
        if self._released:
            raise ValueError("Pointer contact is already released")
        self._driver._send_raw(f"\x1b[<0;{self.column};{self.row}m")
        self._released = True

    def drag_to(self, *, row: int, column: int) -> None:
        self.move_to(row=row, column=column)
        self.release()


def _ctrl_key(name: str) -> str | None:
    prefix = "Ctrl-"
    if not name.startswith(prefix) or len(name) != len(prefix) + 1:
        return None
    return f"C-{name[-1]}"
