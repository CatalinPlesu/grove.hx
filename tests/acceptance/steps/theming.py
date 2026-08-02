import time
from pathlib import Path

from libtmux.server import Server
from pytest import FixtureRequest
from pytest_bdd import given, parsers, then, when
from rich.text import Text

from tests.support.host import TEST_THEME, Helix, start
from tests.support.screen import ANSI_CONSOLE, Row, Screen
from tests.support.waiting import eventually
from tests.support.workspace import Workspace


@given("a Grove theme assigns these sources", target_fixture="grove_start_options")
def configured_grove_theme(datatable: list[list[str]]) -> tuple[str, ...]:
    sources = {
        "native row Style": (
            "(style-bg "
            "(style-fg "
            "(style-with-reversed (style-with-bold (style))) "
            "(Color/rgb 1 2 3)) "
            "(Color/rgb 4 5 6))"
        ),
        "semantic scope": '"grove.test.modified"',
        "cursor semantic scope": '"grove.test.cursor"',
        "empty scope": '"grove.test.empty"',
        "fixed Pane Style": "(style-bg (style) (Color/rgb 221 238 255))",
        "fixed Visible row Style": (
            "(style-bg (style-fg (style) (Color/rgb 17 34 51)) (Color/rgb 221 238 255))"
        ),
        "fixed Cursor background Style": ("(style-bg (style) (Color/rgb 4 5 6))"),
    }
    fields = " ".join(f"#:{role} {sources[source]}" for role, source in datatable[1:])
    return (f"#:theme (grove-theme {fields})",)


@when("Helix changes to a theme with different colors for that scope")
def change_to_alternate_theme(helix: Helix) -> None:
    helix.command(":theme grove_test_alt")


@given(
    parsers.re(r"^Grove starts with theme configuration (?P<configuration>.+)$"),
    target_fixture="helix",
)
def start_with_invalid_theme(
    tmp_path: Path,
    server: Server,
    request: FixtureRequest,
    configuration: str,
) -> Helix:
    workspace = Workspace.create(
        tmp_path / "workspace",
        [["path"], ["anchor.txt"]],
    )
    helix = start(
        tmp_path / "host",
        server,
        workspace,
        active_file=None,
        startup=f"(grove-start! #:theme {configuration})",
        theme=TEST_THEME,
    )
    request.addfinalizer(helix.close)
    return helix


@then("Grove startup reports an invalid theme error")
def startup_reports_invalid_theme(helix: Helix) -> None:
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        output = "\n".join(helix.pane.capture_pane())
        if "invalid Grove theme" in output:
            return
        time.sleep(0.05)
    raise AssertionError("Grove did not report invalid theme configuration")


@then("Cursor uses the configured row colors without source modifiers")
def cursor_uses_configured_colors_only(helix: Helix) -> None:
    def mismatch(screen: Screen) -> str | None:
        active = screen.row("active.txt")
        if active is None:
            return 'Grove did not show "active.txt"'
        if active.foreground_before("active.txt") != (1, 2, 3):
            return "Cursor did not use the configured foreground"
        for marker in ("*", "active.txt"):
            actual = active.style_before(marker)
            if active.background_before(marker) != (4, 5, 6):
                return "Cursor did not use the configured background"
            if bool(actual.bold) or bool(actual.reverse):
                return "Cursor kept source modifiers"
        return None

    eventually(helix, mismatch)


@then("Cursor uses that scope from the active Helix theme")
def cursor_uses_semantic_scope(helix: Helix) -> None:
    _cursor_uses_background(helix, (17, 34, 51))


@then("Cursor uses the new colors")
def cursor_uses_changed_semantic_scope(helix: Helix) -> None:
    _cursor_uses_background(helix, (51, 68, 85))


def _cursor_uses_background(
    helix: Helix,
    expected: tuple[int, int, int],
) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row("anchor.txt")) is not None
            and row.background_before("anchor.txt") == expected
            else "Cursor did not follow the active Helix theme"
        ),
    )


@then(parsers.parse('"{name}" uses the configured Visible row colors'))
def entry_uses_configured_visible_row_colors(
    helix: Helix,
    name: str,
) -> None:
    def mismatch(screen: Screen) -> str | None:
        row = screen.row(name)
        if row is None:
            return f'Grove did not show "{name}"'
        style = row.style_before(name)
        if (
            row.foreground_before(name) == (17, 34, 51)
            and row.background_before(name) == (221, 238, 255)
            and not any((style.reverse, style.bold, style.dim))
        ):
            return None
        return f'"{name}" did not use the Visible row colors: {style!r}'

    eventually(helix, mismatch)


@then("Cursor uses the configured background and Visible row foreground")
def cursor_inherits_visible_row_foreground(helix: Helix) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row("active.txt")) is not None
            and row.foreground_before("active.txt") == (17, 34, 51)
            and row.background_before("active.txt") == (4, 5, 6)
            else "Cursor did not inherit the Visible row foreground"
        ),
    )


@then("the Active file mark uses the configured Visible row foreground")
def active_file_mark_inherits_row_foreground(helix: Helix) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row("active.txt")) is not None
            and row.foreground_before("*") == (17, 34, 51)
            else "Active file mark did not inherit the row foreground"
        ),
    )


@then(
    "the Active file mark uses the configured foreground without source "
    "background or modifiers"
)
def active_file_mark_uses_configured_foreground_only(helix: Helix) -> None:
    def mismatch(screen: Screen) -> str | None:
        row = screen.row("active.txt")
        if row is None:
            return 'Grove did not show "active.txt"'
        mark = row.style_before("*")
        if row.foreground_before("*") != (1, 2, 3):
            return "Active file mark did not use the configured foreground"
        if row.background_before("*") != row.background_before("active.txt"):
            return "Active file mark replaced the row background"
        if bool(mark.bold) or bool(mark.reverse):
            return "Active file mark kept source modifiers"
        return None

    eventually(helix, mismatch)


def _color_number(row: Row, marker: str) -> int | None:
    color = row.style_before(marker).color
    return color.number if color is not None else None


@then("Grove uses terminal fallback colors for status presentation")
def grove_uses_status_fallback_colors(helix: Helix) -> None:
    expected = {
        "broken-link": 9,
        "conflict.txt": 5,
        "deleted-dir": 1,
        "modified.txt": 3,
        "created.txt": 2,
    }

    def mismatch(screen: Screen) -> str | None:
        for name, color in expected.items():
            row = screen.row(name)
            if row is None:
                return f'Grove did not show "{name}"'
            actual = _color_number(row, name)
            if actual != color:
                return f'"{name}" used ANSI color {actual!r}, not {color}'
        broken = screen.row("broken-link")
        if broken is None or _color_number(broken, "󰌺") != expected["broken-link"]:
            return '"broken-link" did not apply its fallback to the icon'
        active = screen.row("active.txt")
        root = screen.workspace_root
        if active is None or _color_number(active, "+") != 6:
            return '"active.txt" did not use terminal cyan for its Unsaved mark'
        if root is None or _color_number(root, "+") != 6:
            return "Workspace did not use terminal cyan for its Unsaved mark"
        return None

    eventually(helix, mismatch)


@then("the Rail track and thumb use terminal default foregrounds")
def rail_uses_terminal_default_foregrounds(helix: Helix) -> None:
    def mismatch(screen: Screen) -> str | None:
        thumb = screen.rail_thumb
        track = screen.rail_track("below") or screen.rail_track("above")
        if track is None or thumb is None:
            return "Grove did not show both Rail parts"

        for part, position in (("track", track), ("thumb", thumb)):
            column, row = position
            style = Text.from_ansi(screen.styled_lines[row - 1]).get_style_at_offset(
                ANSI_CONSOLE,
                column - 1,
            )
            if style.color is not None and not style.color.is_default:
                return (
                    f"Rail {part} used {style.color!r}, "
                    "not the terminal default foreground"
                )
        return None

    eventually(helix, mismatch)
