from pathlib import Path

import pytest
from libtmux.server import Server

from tests.support.tui import TuiDriver, TuiError


def test_tui_driver_runs_and_observes_a_terminal(
    server: Server,
    tmp_path: Path,
) -> None:
    tui = TuiDriver.start(
        server,
        ["/bin/sh", "-c", 'printf "ready\\n"; exec cat'],
        cwd=tmp_path,
        width=40,
        height=8,
    )
    try:
        tui.wait(lambda frame: None if "ready" in frame.lines else "not ready")
        tui.write("hello")
        tui.key("Enter")
        frame = tui.wait(
            lambda current: None if "hello" in current.lines else "no echo"
        )
        assert frame.width == 40
        assert frame.height == 8
        tui.paste("pasted")
        tui.key("Enter")
        tui.wait(lambda current: None if "pasted" in current.lines else "no paste")
        tui.resize(width=44, height=9)
        tui.wait(
            lambda current: (
                None if (current.width, current.height) == (44, 9) else "not resized"
            )
        )
        tui.hold(lambda _frame: None)
        with pytest.raises(TuiError, match="missing"):
            tui.wait(lambda _frame: "missing", timeout=0.01)
        tui.key("Ctrl-d")
        assert tui.wait_for_exit() == 0
    finally:
        tui.close()
        tui.close()


def test_tui_driver_sends_pointer_input(
    server: Server,
    tmp_path: Path,
) -> None:
    tui = TuiDriver.start(
        server,
        [
            "/bin/sh",
            "-c",
            'printf "ready\\n"; stty raw -echo; od -An -t u1 -N 18',
        ],
        cwd=tmp_path,
        width=100,
        height=8,
    )
    try:
        tui.wait(lambda frame: None if "ready" in frame.lines else "not ready")
        tui.click(2, 3)
        assert tui.wait_for_exit() == 0
        output = " ".join(" ".join(tui.capture().lines).split())
        assert "27 91 60 48 59 51 59 50 77 27 91 60 48 59 51 59 50 109" in output
    finally:
        tui.close()
