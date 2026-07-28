from pathlib import Path

import pytest

from tests.support.host import Helix
from tests.support.screen import IncompleteScreen
from tests.support.waiting import capture
from tests.support.workspace import Workspace


@pytest.fixture
def workspaces() -> dict[str, Workspace]:
    return {}


@pytest.fixture
def active_file() -> Path | None:
    return None


def pytest_bdd_step_error(
    request,
    feature,
    scenario,
    step,
    step_func_args: dict[str, object],
    exception,
) -> None:
    helix = step_func_args.get("helix")
    if not isinstance(helix, Helix):
        return
    try:
        screen = capture(helix)
        frame = "\n".join(screen.lines)
    except IncompleteScreen as capture_error:
        frame = "\n".join(capture_error.lines)
    except Exception as capture_error:
        frame = f"<terminal capture failed: {capture_error!r}>"
    request.node.add_report_section(
        "call",
        "pytest-bdd terminal frame",
        f"{feature.name} / {scenario.name}\n{step.name}\n{exception!r}\n\n{frame}",
    )
