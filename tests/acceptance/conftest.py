from __future__ import annotations

from contextlib import ExitStack
from pathlib import Path

import pytest
from libtmux.server import Server

from tests.support.grove import GroveDriver
from tests.support.helix import HelixDriver, HelixSandbox
from tests.support.tui import TuiError
from tests.support.workspace import WorkspaceFixture


@pytest.fixture
def workspaces() -> dict[str, WorkspaceFixture]:
    return {}


@pytest.fixture
def active_file() -> Path | None:
    return None


@pytest.fixture
def helix_sandbox(tmp_path: Path) -> HelixSandbox:
    return HelixSandbox(tmp_path / "host")


@pytest.fixture
def resources(server: Server, tmp_path: Path):
    with ExitStack() as stack:
        yield stack


def pytest_bdd_step_error(
    request,
    feature,
    scenario,
    step,
    step_func_args: dict[str, object],
    exception,
) -> None:
    driver = step_func_args.get("grove") or step_func_args.get("helix")
    try:
        if isinstance(driver, GroveDriver):
            terminal = driver.helix.terminal.capture()
        elif isinstance(driver, HelixDriver):
            terminal = driver.terminal.capture()
        else:
            return
        rendered = "\n".join(terminal.lines)
    except TuiError as capture_error:
        rendered = (
            "\n".join(capture_error.frame.lines)
            if capture_error.frame is not None
            else f"<terminal capture failed: {capture_error!r}>"
        )
    except Exception as capture_error:
        rendered = f"<terminal capture failed: {capture_error!r}>"
    request.node.add_report_section(
        "call",
        "pytest-bdd terminal frame",
        f"{feature.name} / {scenario.name}\n{step.name}\n{exception!r}\n\n{rendered}",
    )
