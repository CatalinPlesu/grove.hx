from __future__ import annotations

import contextlib
import json
import os
import shlex
import shutil
import time
from dataclasses import dataclass, field
from pathlib import Path

from libtmux import exc as libtmux_exc
from libtmux.pane import Pane
from libtmux.server import Server
from libtmux.session import Session

from tests.support.workspace import Workspace

REPOSITORY = Path(__file__).parents[2]
DEFAULT_STARTUP = "(grove-start!)"
_NAMED_KEYS = {
    "Ctrl-d": "C-d",
    "Ctrl-j": "C-j",
    "Ctrl-n": "C-n",
    "Ctrl-r": "C-r",
    "Ctrl-s": "C-s",
    "Ctrl-v": "C-v",
    "Ctrl-y": "C-y",
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
TEST_THEME = """\
inherits = "base16_default_dark"
"ui.text.focus" = { bg = "#303030" }
"ui.virtual.indent-guide" = { fg = "#888888" }
"ui.virtual.ruler" = { bg = "#202020" }
"error" = { fg = "#ff00ff" }
"diff.minus" = { fg = "#ff0000" }
"diff.delta" = { fg = "#ffff00" }
"diff.plus" = { fg = "#00ff00" }
"info" = { fg = "#00ffff" }
"grove.test.cursor" = { bg = "#112233" }
"grove.test.modified" = { fg = "#456789" }
"grove.test.empty" = {}
"""
ALT_TEST_THEME = TEST_THEME.replace(
    '"grove.test.cursor" = { bg = "#112233" }',
    '"grove.test.cursor" = { bg = "#334455" }',
)


@dataclass
class Helix:
    pane: Pane
    session: Session
    workspace: Workspace
    _closed_documents_log: Path = field(repr=False)
    _workspace_history: list[Workspace] = field(
        default_factory=list,
        init=False,
        repr=False,
    )

    def change_workspace(self, workspace: Workspace) -> None:
        self.command(f":cd {json.dumps(str(workspace.root))}")
        self.workspace = workspace

    def push_workspace(self, workspace: Workspace) -> None:
        previous = self.workspace
        self.command(f":pushd {json.dumps(str(workspace.root))}")
        self._workspace_history.append(previous)
        self.workspace = workspace

    def pop_workspace(self) -> None:
        if not self._workspace_history:
            raise AssertionError("Helix has no previous Workspace")
        workspace = self._workspace_history[-1]
        self.command(":popd")
        self._workspace_history.pop()
        self.workspace = workspace

    def close(self) -> None:
        with contextlib.suppress(libtmux_exc.LibTmuxException):
            self.session.kill()

    def key(self, key: str) -> None:
        if len(key) == 1:
            self.type(key)
            return
        try:
            rendered = _NAMED_KEYS[key]
        except KeyError as error:
            raise ValueError(f"Unknown Helix test key: {key!r}") from error
        self.pane.send_keys(rendered, enter=False, literal=False)

    def type(self, text: str, *, enter: bool = False) -> None:
        self.pane.send_keys(text, enter=enter, literal=True)

    def paste(self, text: str) -> None:
        self.pane.server.set_buffer(text)
        self.pane.paste_buffer(delete_after=True, bracket=True)

    def command(self, command: str) -> None:
        if not command.startswith(":"):
            raise ValueError(f"Helix command must start with ':': {command!r}")
        self.type(":")
        self.paste(command[1:])
        self.pane.enter()

    @property
    def closed_documents(self) -> tuple[str, ...]:
        if not self._closed_documents_log.exists():
            return ()
        return tuple(
            self._closed_documents_log.read_text(encoding="utf-8").splitlines()
        )

    def press(self, *, row: int, column: int = 5) -> MouseContact:
        self._send_raw(f"\x1b[<0;{column};{row}M")
        return MouseContact(self, column=column, row=row)

    def click(self, *, row: int, column: int = 5) -> None:
        self.press(row=row, column=column).release()

    def wheel(self, direction: str, *, row: int, column: int = 5) -> None:
        code = {"up": 64, "down": 65}[direction]
        self._send_raw(f"\x1b[<{code};{column};{row}M")

    def _send_raw(self, sequence: str) -> None:
        self.pane.send_keys(sequence, enter=False, literal=True)

    def focus_grove(self) -> None:
        self.key("Space")
        self.type("e")

    def exit(self) -> None:
        self.pane.window.set_option("remain-on-exit", "on")
        self.command(":quit!")

    def wait_for_exit(self) -> None:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            self.pane.refresh()
            if self.pane.pane_dead == "1":
                if self.pane.pane_dead_status == "0":
                    return
                output = "\n".join(self.pane.capture_pane())
                raise AssertionError(
                    f"Helix exited with status {self.pane.pane_dead_status}:\n{output}"
                )
            time.sleep(0.05)
        raise AssertionError("Helix did not exit")

    def is_dead(self) -> bool:
        self.pane.refresh()
        return self.pane.pane_dead == "1"

    @property
    def width(self) -> int:
        self.pane.refresh()
        return int(self.pane.pane_width)

    @property
    def height(self) -> int:
        self.pane.refresh()
        return int(self.pane.pane_height)

    def resize(
        self,
        *,
        width: int | None = None,
        height: int | None = None,
    ) -> None:
        self.pane.window.set_option("window-size", "manual")
        self.pane.window.resize(width=width, height=height)


@dataclass
class MouseContact:
    helix: Helix
    column: int
    row: int
    settled: bool = False

    def release(self) -> None:
        self.helix._send_raw(f"\x1b[<0;{self.column};{self.row}m")

    def drag_to(self, *, row: int, column: int) -> None:
        self.move_to(row=row, column=column)
        self.release()

    def move_to(self, *, row: int, column: int) -> None:
        if not self.settled:
            time.sleep(0.2)
            self.settled = True
        self.column = column
        self.row = row
        self.helix._send_raw(f"\x1b[<32;{column};{row}M")


def start(
    root: Path,
    server: Server,
    workspace: Workspace,
    *,
    active_file: Path | None,
    startup: str,
    theme: str,
) -> Helix:
    closed_documents_log = root / "closed-documents"
    startup = _document_close_hook(closed_documents_log) + "\n" + startup
    config_home, steel_home = _prepare_homes(root, startup, theme)
    command = _command(
        config_home,
        steel_home,
        workspace,
        active_file,
    )
    session = server.new_session(
        session_name="helix",
        start_directory=workspace.root,
        window_command=command,
        x=100,
        y=30,
    )
    return Helix(
        session.active_pane,
        session,
        workspace,
        closed_documents_log,
    )


def _document_close_hook(destination: Path) -> str:
    path = json.dumps(str(destination))
    return (
        '(require "helix/editor.scm")\n'
        "(register-hook\n"
        " 'document-closed\n"
        " (lambda (event)\n"
        f"  (call-with-output-file {path}\n"
        "   (lambda (port)\n"
        "    (display (doc-closed-path event) port)\n"
        "    (newline port))\n"
        "   #:exists 'append)))"
    )


def _prepare_homes(
    root: Path,
    startup: str,
    theme: str,
) -> tuple[Path, Path]:
    config_home = root / "xdg"
    helix_config = config_home / "helix"
    steel_home = root / "steel"
    (helix_config / "themes").mkdir(parents=True)
    shutil.copytree(
        _installed_steel_home() / "cogs" / "devicons",
        steel_home / "cogs" / "devicons",
    )
    (helix_config / "themes" / "grove_test.toml").write_text(theme, encoding="utf-8")
    (helix_config / "themes" / "grove_test_alt.toml").write_text(
        ALT_TEST_THEME,
        encoding="utf-8",
    )
    (helix_config / "config.toml").write_text(
        'theme = "grove_test"\n'
        "[editor]\n"
        "mouse = true\n"
        "[editor.statusline]\n"
        'left = ["file-name", "separator", "selections"]\n'
        "center = []\n"
        'right = ["mode", "separator", "position"]\n'
        'separator = "¦"\n'
        'mode.normal = "GNR"\n'
        'mode.insert = "GIN"\n'
        'mode.select = "GSE"\n',
        encoding="utf-8",
    )
    (helix_config / "init.scm").write_text(
        f'(require "{REPOSITORY / "grove.scm"}")\n'
        '(require "helix/components.scm")\n'
        '(require "helix/keymaps.scm")\n'
        '(require "helix/misc.scm")\n'
        "(define (grove-test-key-received)\n"
        ' (set-status! "Grove test key reached Helix"))\n'
        f"{startup}\n"
        "(keymap (global)\n"
        ' (normal (space (e ":grove-focus!"))\n'
        "  (C-n grove-test-key-received) (C-r grove-test-key-received)\n"
        "  (C-d grove-test-key-received) (C-j grove-test-key-received)\n"
        "  (C-y grove-test-key-received)))\n",
        encoding="utf-8",
    )
    return config_home, steel_home


def _command(
    config_home: Path,
    steel_home: Path,
    workspace: Workspace,
    active_file: Path | None,
) -> str:
    return shlex.join(
        [
            "env",
            f"XDG_CONFIG_HOME={config_home}",
            f"STEEL_HOME={steel_home}",
            "hx",
            "--working-dir",
            str(workspace.root),
            *([str(active_file)] if active_file is not None else []),
        ]
    )


def _installed_steel_home() -> Path:
    if configured := os.environ.get("STEEL_HOME"):
        return Path(configured).expanduser()
    data_home = os.environ.get("XDG_DATA_HOME")
    return (
        Path(data_home).expanduser() if data_home else Path.home() / ".local/share"
    ) / "steel"
