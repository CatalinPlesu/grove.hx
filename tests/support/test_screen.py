from pathlib import Path, PurePath
from unittest.mock import Mock

import pytest

from tests.support.host import Helix
from tests.support.screen import IncompleteScreen, Screen
from tests.support.waiting import consistently
from tests.support.workspace import Workspace


def test_parse_decodes_plain_styled_lines_and_reuses_rows() -> None:
    screen = Screen.parse(
        [
            f"{'  󰙅 workspace':24}▕{'target-001':75}",
            f"{'  󰈙 target.txt':24}▕{'':75}",
            f"{'':24}▕{'folder/target.txt ¦ 1 sel GIN ¦ 1:1':75}",
        ],
        paths={PurePath("target.txt")},
        workspace_name="workspace",
    )

    first_target_row = screen.row("target.txt")

    assert screen.row("workspace") == screen.workspace_root
    assert first_target_row is not None
    assert screen.row("target.txt") is first_target_row
    assert screen.row("txt") is None
    assert screen.document == "folder/target.txt"
    assert screen.editor_mode == "Insert"
    assert screen.editor_view_count == 1


def test_parse_decodes_vertical_editor_views() -> None:
    screen = Screen.parse(
        [
            f"{'':24}▕{'left-001':36}│{'right-001':38}",
            f"{'':24}▕{'left.txt ¦ 1 sel ¦ 1:1':36}│{'right.txt ¦ 1 sel GNR ¦ 2:1':38}",
        ]
    )

    left = screen.editor_view("left.txt")
    right = screen.editor_view("right.txt")

    assert screen.editor_view_count == 2
    assert screen.document == "right.txt"
    assert left is not None
    assert right is not None
    assert right.cursor == (2, 1)


def test_parse_ignores_a_partially_rendered_status_line() -> None:
    screen = Screen.parse(["anchor.txt ¦ 1 sel"])

    assert screen.editor_mode is None
    assert screen.editor_view_count == 0


def test_row_decodes_a_unique_descendant_without_visible_ancestors() -> None:
    screen = Screen.parse(
        [
            f"{'  󰙅 workspace':24}▕{'':75}",
            f"{'      󰈙 active.txt':24}▕{'active.txt ¦ 1 sel GNR ¦ 1:1':75}",
        ],
        paths={
            PurePath("outer"),
            PurePath("outer/inner"),
            PurePath("outer/inner/active.txt"),
        },
        directories={PurePath("outer"), PurePath("outer/inner")},
    )

    active = screen.row("outer/inner/active.txt")
    assert active is not None
    assert active.number == 2


def test_parse_rejects_a_partially_rendered_rail() -> None:
    styled_lines = [
        f"{'workspace':24}▕{'':75}",
        "partially rendered",
        f"{'':24}▕{'anchor.txt ¦ GNR ¦ 1:1':75}",
    ]
    with pytest.raises(IncompleteScreen) as caught:
        Screen.parse(styled_lines)

    assert caught.value.lines == tuple(styled_lines)


def test_consistently_fails_without_a_complete_frame() -> None:
    styled_lines = [
        f"{'workspace':24}▕{'':75}",
        "partially rendered",
        f"{'':24}▕{'anchor.txt ¦ GNR ¦ 1:1':75}",
    ]
    pane = Mock()
    pane.pane_dead = "0"
    pane.capture_pane.return_value = styled_lines
    host = Helix(pane, Mock(), Workspace(Path("workspace")))
    with pytest.raises(
        AssertionError,
        match="(?s)No complete frame.*partially rendered",
    ):
        consistently(host, lambda _screen: None, duration=0.01)


def test_rows_use_workspace_paths_and_preserve_mark_like_filenames() -> None:
    styled_lines = [
        f"{'  󰙅 workspace':24}▕{'':75}",
        f"{'  ▾  alpha':24}▕{'':75}",
        f"{'      󰈙 same.txt':24}▕{'':75}",
        f"{'  ▾  beta':24}▕{'':75}",
        f"{'      󰈙 same.txt':24}▕{'':75}",
        f"{'  󰈙 literal ● ●':24}▕{'literal ● ¦ GNR ¦ 1:1':75}",
        f"{'  󰈙 odd?name.txt':24}▕{'':75}",
    ]
    paths = {
        PurePath("alpha"),
        PurePath("alpha/same.txt"),
        PurePath("beta"),
        PurePath("beta/same.txt"),
        PurePath("literal ●"),
        PurePath("odd\nname.txt"),
    }

    screen = Screen.parse(
        styled_lines,
        paths=paths,
        directories={PurePath("alpha"), PurePath("beta")},
    )

    alpha = screen.row("alpha/same.txt")
    beta = screen.row("beta/same.txt")
    marked = screen.row("literal ●")
    controlled = screen.row("odd\\nname.txt")
    assert alpha is not None and alpha.number == 3
    assert beta is not None and beta.number == 5
    assert marked is not None and marked.number == 6
    assert controlled is not None and controlled.path == PurePath("odd\nname.txt")
    with pytest.raises(AssertionError, match="multiple"):
        screen.row("same.txt")


def test_rejects_an_ambiguous_unsaved_mark_filename() -> None:
    screen = Screen.parse(
        [f"{'  󰈙 foo ●':24}▕{'foo ¦ GNR ¦ 1:1':75}"],
        paths={PurePath("foo"), PurePath("foo ●")},
    )

    with pytest.raises(AssertionError, match="ambiguous identity"):
        screen.row("foo")
