import json

import pytest
from pytest_bdd import given, parsers, then, when
from rich.console import Console
from rich.text import Text

from tests.support.grove import GroveDriver, GroveFrame, VisibleRow

from .rows import scenario_path

ANSI_CONSOLE = Console(color_system="truecolor")

_INVALID_THEMES = {
    "a boolean": "#t",
    "an empty Cursor source": '(grove-theme #:cursor "")',
    "a numeric Cursor source": "(grove-theme #:cursor 42)",
}


@pytest.fixture
def grove_theme_sources() -> dict[str, dict[str, str]]:
    return {}


@given(
    parsers.parse('an invalid Grove theme configuration: "{configuration}"'),
    target_fixture="grove_settings",
)
def invalid_grove_theme(configuration: str) -> dict[str, str]:
    return {"theme": _INVALID_THEMES[configuration]}


@given("a Grove theme assigns these sources", target_fixture="grove_settings")
def configured_grove_theme(
    datatable: list[list[str]],
    grove_theme_sources: dict[str, dict[str, str]],
) -> dict[str, str]:
    header, *rows = datatable
    grove_theme_sources.update(
        (record["role"], record) for record in (dict(zip(header, row)) for row in rows)
    )
    fields = " ".join(
        f"#:{role} {_theme_source(record)}"
        for role, record in grove_theme_sources.items()
    )
    return {"theme": f"(grove-theme {fields})"}


def _theme_source(record: dict[str, str]) -> str:
    if record["source"] != "Style":
        return json.dumps(record["source"])
    style = "(style)"
    for modifier in record.get("modifiers", "").split():
        style = f"(style-with-{modifier} {style})"
    for field, operation in (("foreground", "style-fg"), ("background", "style-bg")):
        if color := record.get(field):
            red, green, blue = bytes.fromhex(color.removeprefix("#"))
            style = f"({operation} {style} (Color/rgb {red} {green} {blue}))"
    return style


def _configured_color(
    sources: dict[str, dict[str, str]],
    role: str,
    field: str,
) -> tuple[int, int, int]:
    return tuple(bytes.fromhex(sources[role][field].removeprefix("#")))


def _active_file_row(frame: GroveFrame) -> VisibleRow | None:
    if frame.pane is None:
        return None
    return next(
        (row for row in frame.pane.rows if "*" in row.text[: row.label_column]),
        None,
    )


@when("Helix changes to a theme with different colors for that scope")
def change_to_alternate_theme(grove: GroveDriver) -> None:
    grove.helix.command("theme grove_test_alt")


@then("Cursor uses the configured row colors without source modifiers")
def cursor_uses_configured_colors_only(
    grove: GroveDriver,
    grove_theme_sources: dict[str, dict[str, str]],
) -> None:
    foreground = _configured_color(grove_theme_sources, "cursor", "foreground")
    background = _configured_color(grove_theme_sources, "cursor", "background")

    def mismatch(frame: GroveFrame) -> str | None:
        active = frame.pane.cursor if frame.pane else None
        if active is None:
            return "Grove did not show Cursor"
        if active.foreground_at(active.label) != foreground:
            return "Cursor did not use the configured foreground"
        for marker in ("*", active.label):
            actual = active.style_at(marker)
            if active.background_at(marker) != background:
                return "Cursor did not use the configured background"
            if bool(actual.bold) or bool(actual.reverse):
                return "Cursor kept source modifiers"
        return None

    grove.wait(mismatch)


@then("Cursor uses that scope from the active Helix theme")
def cursor_uses_semantic_scope(grove: GroveDriver) -> None:
    _cursor_uses_background(grove, (17, 34, 51))


@then("Cursor uses the new colors")
def cursor_uses_changed_semantic_scope(grove: GroveDriver) -> None:
    _cursor_uses_background(grove, (51, 68, 85))


def _cursor_uses_background(
    grove: GroveDriver,
    expected: tuple[int, int, int],
) -> None:
    grove.wait(
        lambda frame: (
            None
            if frame.pane is not None
            and (row := frame.pane.cursor) is not None
            and row.background_at(row.label) == expected
            else "Cursor did not follow the active Helix theme"
        ),
    )


@then(
    parsers.parse(
        '"{name}" uses background "{expected}" and the foreground of "{reference}" without modifiers'
    )
)
def entry_uses_background_only(
    grove: GroveDriver,
    name: str,
    expected: str,
    reference: str,
) -> None:
    expected_rgb = tuple(bytes.fromhex(expected.removeprefix("#")))

    def mismatch(frame: GroveFrame) -> str | None:
        row = frame.row(scenario_path(name))
        plain = frame.row(scenario_path(reference))
        if row is None or plain is None:
            return "Grove did not show both rows"
        style = row.style_at(row.label)
        if row.background_at(row.label) != expected_rgb:
            return f'"{name}" did not use background {expected}'
        if row.foreground_at(row.label) != plain.foreground_at(plain.label):
            return f'"{name}" kept the source foreground'
        if bool(style.bold) or bool(style.reverse):
            return f'"{name}" kept source modifiers'
        return None

    grove.wait(mismatch)


@then(parsers.parse('"{name}" uses the configured Visible row colors'))
def entry_uses_configured_visible_row_colors(
    grove: GroveDriver,
    name: str,
    grove_theme_sources: dict[str, dict[str, str]],
) -> None:
    foreground = _configured_color(
        grove_theme_sources,
        "visible-row",
        "foreground",
    )
    background = _configured_color(
        grove_theme_sources,
        "visible-row",
        "background",
    )

    def mismatch(frame: GroveFrame) -> str | None:
        row = frame.row(scenario_path(name))
        if row is None:
            return f'Grove did not show "{name}"'
        style = row.style_at(row.label)
        if (
            row.foreground_at(row.label) == foreground
            and row.background_at(row.label) == background
            and not any((style.reverse, style.bold, style.dim))
        ):
            return None
        return f'"{name}" did not use the Visible row colors: {style!r}'

    grove.wait(mismatch)


@then("Cursor uses the configured background and Visible row foreground")
def cursor_inherits_visible_row_foreground(
    grove: GroveDriver,
    grove_theme_sources: dict[str, dict[str, str]],
) -> None:
    foreground = _configured_color(
        grove_theme_sources,
        "visible-row",
        "foreground",
    )
    background = _configured_color(grove_theme_sources, "cursor", "background")
    grove.wait(
        lambda frame: (
            None
            if frame.pane is not None
            and (row := frame.pane.cursor) is not None
            and row.foreground_at(row.label) == foreground
            and row.background_at(row.label) == background
            else "Cursor did not inherit the Visible row foreground"
        ),
    )


@then("the Active file mark uses the configured Visible row foreground")
def active_file_mark_inherits_row_foreground(
    grove: GroveDriver,
    grove_theme_sources: dict[str, dict[str, str]],
) -> None:
    foreground = _configured_color(
        grove_theme_sources,
        "visible-row",
        "foreground",
    )
    grove.wait(
        lambda frame: (
            None
            if (row := _active_file_row(frame)) is not None
            and row.foreground_at("*") == foreground
            else "Active file mark did not inherit the row foreground"
        ),
    )


@then(
    "the Active file mark uses the configured foreground without source "
    "background or modifiers"
)
def active_file_mark_uses_configured_foreground_only(
    grove: GroveDriver,
    grove_theme_sources: dict[str, dict[str, str]],
) -> None:
    foreground = _configured_color(
        grove_theme_sources,
        "active-file-mark-foreground",
        "foreground",
    )

    def mismatch(frame: GroveFrame) -> str | None:
        row = _active_file_row(frame)
        if row is None:
            return "Grove did not show the Active file mark"
        mark = row.style_at("*")
        if row.foreground_at("*") != foreground:
            return "Active file mark did not use the configured foreground"
        if row.background_at("*") != row.background_at(row.label):
            return "Active file mark replaced the row background"
        if bool(mark.bold) or bool(mark.reverse):
            return "Active file mark kept source modifiers"
        return None

    grove.wait(mismatch)


@then("these rows use terminal fallback colors")
def rows_use_terminal_fallback_colors(
    grove: GroveDriver,
    datatable: list[list[str]],
) -> None:
    _, *expected = datatable

    def mismatch(frame: GroveFrame) -> str | None:
        for name, marker_name, color_text in expected:
            row = frame.row(scenario_path(name))
            if row is None:
                return f'Grove did not show "{name}"'
            marker = {
                "label": row.label,
                "Broken link icon": "󰌺",
                "Unsaved mark": "+",
            }[marker_name]
            color = int(color_text)
            style_color = row.style_at(marker).color
            actual = style_color.number if style_color is not None else None
            if actual != color:
                return f'"{name}" {marker_name} used ANSI color {actual!r}, not {color}'
        return None

    grove.wait(mismatch)


@then("the Rail track and thumb use terminal default foregrounds")
def rail_uses_terminal_default_foregrounds(grove: GroveDriver) -> None:
    def mismatch(frame: GroveFrame) -> str | None:
        thumb = frame.pane.rail.thumb if frame.pane else None
        track = (
            frame.pane.rail.track("below") or frame.pane.rail.track("above")
            if frame.pane
            else None
        )
        if track is None or thumb is None:
            return "Grove did not show both Rail parts"

        for part, position in (("track", track), ("thumb", thumb)):
            column, row = position
            style = Text.from_ansi(
                frame.helix.terminal.styled_lines[row - 1]
            ).get_style_at_offset(
                ANSI_CONSOLE,
                column - 1,
            )
            if style.color is not None and not style.color.is_default:
                return (
                    f"Rail {part} used {style.color!r}, "
                    "not the terminal default foreground"
                )
        return None

    grove.wait(mismatch)
