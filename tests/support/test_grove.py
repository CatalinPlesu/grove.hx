from pathlib import PurePath
from unittest.mock import Mock

import pytest

from tests.support.grove import GroveFrame
from tests.support.helix import HelixFrame
from tests.support.tui import TerminalFrame
from tests.support.workspace import WorkspaceFixture


def _frame(lines: list[str], workspace: WorkspaceFixture) -> GroveFrame:
    terminal = TerminalFrame.decode(100, len(lines), lines)
    return GroveFrame.decode(HelixFrame.decode(terminal), workspace)


def test_grove_frame_uses_exact_workspace_paths_for_duplicate_labels(tmp_path) -> None:
    workspace = WorkspaceFixture(
        tmp_path / "workspace",
        paths={
            PurePath("alpha"),
            PurePath("alpha/same.txt"),
            PurePath("beta"),
            PurePath("beta/same.txt"),
        },
        directories={PurePath("alpha"), PurePath("beta")},
    )
    frame = _frame(
        [
            f"{'  workspace':24}▕{'':75}",
            f"{'  ▾ alpha':24}▕{'':75}",
            f"{'      same.txt':24}▕{'':75}",
            f"{'  ▾ beta':24}▕{'':75}",
            f"{'      same.txt':24}▕{'same.txt ¦ GNR ¦ 1:1':75}",
        ],
        workspace,
    )

    assert frame.row(PurePath("alpha/same.txt")).number == 3
    assert frame.row(PurePath("beta/same.txt")).number == 5


def test_grove_frame_rejects_a_partially_rendered_rail(tmp_path) -> None:
    workspace = WorkspaceFixture(tmp_path / "workspace")
    terminal = TerminalFrame.decode(
        100,
        3,
        [
            f"{'workspace':24}▕{'':75}",
            "partially rendered",
            f"{'':24}▕{'anchor.txt ¦ GNR ¦ 1:1':75}",
        ],
    )

    with pytest.raises(AssertionError, match="Incomplete Grove frame"):
        GroveFrame.decode(HelixFrame.decode(terminal), workspace)


def test_grove_frame_allows_a_short_prompt_below_the_rail(tmp_path) -> None:
    workspace = WorkspaceFixture(tmp_path / "workspace")

    frame = _frame(
        [
            f"{'workspace':24}▕{'':75}",
            f"{'':24}▕{'anchor.txt ¦ GNR ¦ 1:1':75}",
            ":",
        ],
        workspace,
    )

    assert frame.pane is not None
    assert frame.pane.rail.track_rows == (1, 2)


def test_grove_driver_hold_requires_a_complete_frame(tmp_path) -> None:
    from tests.support.grove import GroveDriver

    workspace = WorkspaceFixture(tmp_path / "workspace")
    partial = HelixFrame.decode(
        TerminalFrame.decode(
            100,
            3,
            [
                f"{'workspace':24}▕{'':75}",
                "partially rendered",
                f"{'':24}▕{'anchor.txt ¦ GNR ¦ 1:1':75}",
            ],
        )
    )
    helix = Mock()
    helix.hold.side_effect = lambda check, duration: check(partial)
    driver = GroveDriver(helix, workspace)

    with pytest.raises(AssertionError, match="No complete Grove frame observed"):
        driver.hold(lambda _frame: None, duration=0.01)


def test_grove_frame_rejects_multiple_cursors(tmp_path) -> None:
    workspace = WorkspaceFixture(
        tmp_path / "workspace",
        paths={PurePath("one.txt"), PurePath("two.txt")},
    )

    with pytest.raises(AssertionError, match="multiple Cursor marks"):
        _frame(
            [
                f"{'>· one.txt':24}▕{'':75}",
                f"{'>· two.txt':24}▕{'two.txt ¦ GNR ¦ 1:1':75}",
            ],
            workspace,
        )


def test_grove_frame_decodes_cursor_on_workspace_root(tmp_path) -> None:
    workspace = WorkspaceFixture(tmp_path / "workspace")
    frame = _frame(
        [f"{'>workspace':24}▕{'anchor.txt ¦ GNR ¦ 1:1':75}"],
        workspace,
    )

    assert frame.pane is not None
    assert frame.pane.cursor == frame.pane.workspace_root


def test_grove_frame_decodes_unique_descendant_without_visible_parents(
    tmp_path,
) -> None:
    workspace = WorkspaceFixture(
        tmp_path / "workspace",
        paths={
            PurePath("outer"),
            PurePath("outer/inner"),
            PurePath("outer/inner/active.txt"),
        },
        directories={PurePath("outer"), PurePath("outer/inner")},
    )
    frame = _frame(
        [
            f"{'  workspace':24}▕{'':75}",
            f"{'      active.txt':24}▕{'active.txt ¦ GNR ¦ 1:1':75}",
        ],
        workspace,
    )

    assert frame.row(PurePath("outer/inner/active.txt")).number == 2


def test_grove_frame_rejects_a_row_under_the_wrong_visible_parent(tmp_path) -> None:
    workspace = WorkspaceFixture(
        tmp_path / "workspace",
        paths={PurePath("alpha"), PurePath("beta/child.txt")},
        directories={PurePath("alpha")},
    )

    with pytest.raises(AssertionError, match="ambiguous filesystem identity"):
        _frame(
            [
                f"{'  ▾ alpha':24}▕{'':75}",
                f"{'      child.txt':24}▕{'child.txt ¦ GNR ¦ 1:1':75}",
            ],
            workspace,
        )


def test_grove_frame_preserves_mark_like_and_controlled_filenames(tmp_path) -> None:
    workspace = WorkspaceFixture(
        tmp_path / "workspace",
        paths={PurePath("literal +"), PurePath("odd\nname.txt")},
    )
    frame = _frame(
        [
            f"{'  workspace':24}▕{'':75}",
            f"{'  literal + +':24}▕{'':75}",
            f"{'  odd?name.txt':24}▕{'odd?name.txt ¦ GNR ¦ 1:1':75}",
        ],
        workspace,
    )

    assert frame.row(PurePath("literal +")).number == 2
    assert frame.row(PurePath("odd\nname.txt")).path == PurePath("odd\nname.txt")


def test_grove_frame_rejects_ambiguous_unsaved_mark_filename(tmp_path) -> None:
    workspace = WorkspaceFixture(
        tmp_path / "workspace",
        paths={PurePath("foo"), PurePath("foo +")},
    )

    with pytest.raises(AssertionError, match="ambiguous identity"):
        _frame(
            [f"{'  foo +':24}▕{'foo ¦ GNR ¦ 1:1':75}"],
            workspace,
        )


def test_grove_frame_decodes_a_right_pane_and_clipped_label(tmp_path) -> None:
    path = PurePath("a-very-long-filename.txt")
    workspace = WorkspaceFixture(tmp_path / "workspace", paths={path})

    frame = _frame(
        [
            f"{'':75}▏{'  workspace':24}",
            f"{'a-very-long-filename.txt ¦ GNR ¦ 1:1':75}▏{'  a-very-long…':24}",
        ],
        workspace,
    )

    assert frame.pane is not None
    assert frame.pane.side == "right"
    assert frame.row(path).number == 2


def test_grove_frame_decodes_an_absent_pane(tmp_path) -> None:
    workspace = WorkspaceFixture(tmp_path / "workspace")

    frame = _frame(["document.txt ¦ GNR ¦ 1:1"], workspace)

    assert frame.pane is None
