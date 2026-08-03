from __future__ import annotations

import time
from collections.abc import Callable

from tests.support.host import Helix
from tests.support.screen import IncompleteScreen, Screen

Check = Callable[[Screen], str | None]


def capture(host: Helix) -> Screen:
    return Screen.parse(
        host.pane.capture_pane(escape_sequences=True),
        paths=host.workspace.paths,
        directories=host.workspace.directories,
        workspace_name=host.workspace.root.name,
    )


def eventually(host: Helix, check: Check) -> Screen:
    deadline = time.monotonic() + 10
    last_mismatch = "no complete frame captured"
    last_lines: tuple[str, ...] | None = None
    while time.monotonic() < deadline:
        if host.is_dead():
            raise AssertionError("Helix exited before the expected state")
        try:
            screen = capture(host)
        except IncompleteScreen as error:
            last_lines = error.lines
            time.sleep(0.05)
            continue
        last_lines = screen.lines
        if (last_mismatch := check(screen)) is None:
            return screen
        time.sleep(0.05)
    frame = "\n".join(last_lines) if last_lines is not None else "<no frame>"
    raise AssertionError(f"{last_mismatch}\n\nLast frame:\n{frame}")


def eventually_bottom_line_contains(host: Helix, text: str) -> None:
    deadline = time.monotonic() + 10
    last_lines: tuple[str, ...] | None = None
    while time.monotonic() < deadline:
        if host.is_dead():
            raise AssertionError("Helix exited before the expected state")
        last_lines = tuple(host.pane.capture_pane())
        if last_lines and text in last_lines[-1]:
            return
        time.sleep(0.05)
    frame = "\n".join(last_lines) if last_lines is not None else "<no frame>"
    raise AssertionError(f'Helix did not show "{text}"\n\nLast frame:\n{frame}')


def focus_grove(host: Helix) -> None:
    eventually(
        host,
        lambda screen: None if screen.rail is not None else "Grove did not render",
    )
    host.focus_grove()
    eventually(
        host,
        lambda screen: (
            None if screen.grove_cursor is not None else "Grove did not render focus"
        ),
    )


def consistently(
    host: Helix,
    check: Check,
    *,
    duration: float = 0.25,
) -> None:
    deadline = time.monotonic() + duration
    observed_complete_frame = False
    last_incomplete: IncompleteScreen | None = None
    while time.monotonic() < deadline:
        if host.is_dead():
            raise AssertionError("Helix exited during a stability check")
        try:
            screen = capture(host)
        except IncompleteScreen as error:
            last_incomplete = error
            time.sleep(0.05)
            continue
        observed_complete_frame = True
        if (mismatch := check(screen)) is not None:
            raise AssertionError(f"{mismatch}\n\nFrame:\n" + "\n".join(screen.lines))
        time.sleep(0.05)
    if not observed_complete_frame:
        frame = (
            "\n".join(last_incomplete.lines)
            if last_incomplete is not None
            else "<no frame>"
        )
        raise AssertionError(
            "No complete frame captured during the stability check"
            f"\n\nLast frame:\n{frame}"
        )
