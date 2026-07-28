import json
from pathlib import Path

from pytest_bdd import parsers, then, when

from tests.support.host import Helix
from tests.support.waiting import consistently, eventually
from tests.support.workspace import Workspace


@when(parsers.parse('the editor receives "{key}" while Grove is unfocused'))
def editor_receives(helix: Helix, key: str) -> None:
    helix.type(key)


@when(parsers.parse('Grove receives Helix\'s file-picker chord for "{name}"'))
def grove_receives_file_picker_chord(helix: Helix, name: str) -> None:
    helix.key("Space")
    helix.type("f")
    helix.type(name.removesuffix(".txt"), enter=True)
    eventually(
        helix,
        lambda screen: (
            None
            if screen.document is not None and Path(screen.document).name == name
            else f'Helix did not show document "{name}"'
        ),
    )


@when(parsers.parse('Helix changes the Active file to "{name}"'))
def helix_changes_active_file(
    tmp_path: Path,
    workspace: Workspace,
    name: str,
) -> None:
    workspace.document_path(name)
    (tmp_path / "host-file-change").touch()


@when(
    parsers.parse(
        'the editor cursor moves to line {line_number:d} in "{name}" '
        "with line {first_visible_line_number:d} first"
    )
)
def editor_moves_and_aligns_line(
    helix: Helix,
    workspace: Workspace,
    line_number: int,
    name: str,
    first_visible_line_number: int,
) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if screen.editor_view(name) is not None
            else f'Helix did not show "{name}" before navigation'
        ),
    )
    helix.type(f"{line_number}Gzt")
    eventually(
        helix,
        lambda screen: (
            None
            if (view := screen.editor_view(name)) is not None
            and view.first_visible_line is not None
            and workspace.numbered_line(name, first_visible_line_number)
            in view.first_visible_line
            else (
                f'Helix did not show line {first_visible_line_number} first in "{name}"'
            )
        ),
    )


@when(parsers.parse('the editor inserts "{text}" without saving'))
def editor_inserts_without_saving(helix: Helix, text: str) -> None:
    _insert(helix, text)


@when(parsers.parse('the editor inserts "{text}" and saves'))
def editor_inserts_and_saves(helix: Helix, text: str) -> None:
    _insert(helix, text)
    helix.command(":write")


def _insert(helix: Helix, text: str) -> None:
    helix.type("i")
    helix.type(text)
    eventually(
        helix,
        lambda screen: (
            None
            if screen.editor_mode == "Insert"
            else "Helix did not enter Insert mode"
        ),
    )
    helix.key("Escape")
    eventually(
        helix,
        lambda screen: (
            None
            if screen.editor_mode == "Normal"
            else "Helix did not leave Insert mode"
        ),
    )


@when(parsers.parse("the terminal width becomes {width:d} columns"))
def terminal_width_becomes(helix: Helix, width: int) -> None:
    helix.resize(width=width)
    eventually(
        helix,
        lambda _screen: (
            None
            if helix.width == width
            else f"Terminal did not resize to {width} columns"
        ),
    )


@when(parsers.parse("the terminal height becomes {height:d} rows"))
def terminal_height_becomes(helix: Helix, height: int) -> None:
    helix.resize(height=height)
    eventually(
        helix,
        lambda screen: (
            None
            if helix.height == height and len(screen.lines) == height
            else f"Terminal did not resize to {height} rows"
        ),
    )


@when("Grove is focused")
def focus_grove(helix: Helix) -> None:
    eventually(
        helix,
        lambda screen: None if screen.rail is not None else "Grove did not render",
    )
    helix.focus_grove()
    eventually(
        helix,
        lambda screen: (
            None if screen.cursor is not None else "Grove did not receive focus"
        ),
    )


@when(parsers.parse('Grove receives "{key}"'))
def grove_receives_key(helix: Helix, key: str) -> None:
    helix.key(key)


@when(parsers.parse('Helix runs "{command}" for Workspace "{workspace_name}"'))
def change_workspace(
    helix: Helix,
    workspaces: dict[str, Workspace],
    command: str,
    workspace_name: str,
) -> None:
    workspace = workspaces[workspace_name]
    _return_to_editor(helix)
    if command == "cd":
        helix.change_workspace(workspace)
    elif command == "push-directory":
        helix.push_workspace(workspace)
    else:
        raise ValueError(f"Unknown Workspace command: {command!r}")


@when('Helix runs "pop-directory"')
def return_to_previous_workspace(helix: Helix) -> None:
    _return_to_editor(helix)
    helix.pop_workspace()


def _return_to_editor(helix: Helix) -> None:
    helix.key("Escape")
    eventually(
        helix,
        lambda screen: (
            None if screen.cursor is None else "Grove did not return focus to Helix"
        ),
    )


@when("a file outside the Workspace is opened and edited without saving")
def edit_file_outside_workspace(helix: Helix, workspace: Workspace) -> None:
    outside = workspace.root.parent / "outside.txt"
    outside.write_text("outside\n", encoding="utf-8")
    helix.command(f":open {json.dumps(str(outside))}")
    eventually(
        helix,
        lambda screen: (
            None
            if screen.editor_contains("outside")
            else "Helix did not open the file outside the Workspace"
        ),
    )
    _insert(helix, "outside-")


@then(parsers.parse("the active Editor view is in {mode} mode"))
def editor_has_mode(helix: Helix, mode: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None if screen.editor_mode == mode else f"Editor did not enter {mode} mode"
        ),
    )


@then(parsers.parse('Helix shows the "{name}" document'))
def helix_shows_document(helix: Helix, name: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None if screen.document == name else f'Helix did not show document "{name}"'
        ),
    )


@then("the editor still shows the outside file")
def editor_still_shows_outside_file(helix: Helix) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if screen.editor_contains("outside")
            else "Helix stopped showing the file outside the Workspace"
        ),
    )


@then(
    parsers.parse(
        'the editor view for "{name}" is restored at line {line_number:d} '
        "with line {first_visible_line_number:d} first"
    )
)
def editor_view_is_restored(
    helix: Helix,
    workspace: Workspace,
    name: str,
    line_number: int,
    first_visible_line_number: int,
) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (view := screen.editor_view(name)) is not None
            and view.cursor == (line_number, 1)
            and view.first_visible_line is not None
            and workspace.numbered_line(name, first_visible_line_number)
            in view.first_visible_line
            else f'Helix did not restore "{name}" at line {line_number}'
        ),
    )


@then(parsers.parse("the editor cursor is on line {line_number:d}"))
def editor_cursor_is_on_line(helix: Helix, line_number: int) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (view := screen.active_editor_view) is not None
            and view.cursor is not None
            and view.cursor[0] == line_number
            else f"Helix did not move the editor cursor to line {line_number}"
        ),
    )


@then(parsers.parse("Helix has {count:d} editor view"))
@then(parsers.parse("Helix has {count:d} editor views"))
def helix_has_editor_views(helix: Helix, count: int) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if screen.editor_view_count == count
            else f"Helix did not show {count} editor views"
        ),
    )


@then(parsers.parse('"{name}" is the Active file'))
def entry_is_active_file(helix: Helix, name: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None
            and row.background_before(name) == (48, 48, 48)
            else f'Grove did not present "{name}" as the Active file'
        ),
    )


@then(parsers.parse('"{name}" has Cursor'))
def entry_has_cursor(helix: Helix, name: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None
            and row.background_before(name) == (64, 64, 64)
            else f'Grove did not place Cursor on "{name}"'
        ),
    )


@when("Helix closes the active Editor view")
def helix_closes_active_editor_view(helix: Helix) -> None:
    helix.command(":quit!")


@when("Helix exits")
def exit_helix(helix: Helix) -> None:
    helix.exit()


@then("Helix exits normally")
def helix_exits_normally(helix: Helix) -> None:
    helix.wait_for_exit()


@then("the editor remains active")
def editor_remains_active(helix: Helix) -> None:
    helix.type("i")
    helix.type("editor-active")
    eventually(
        helix,
        lambda screen: (
            None
            if screen.editor_mode == "Insert"
            and screen.editor_contains("editor-active")
            else "Grove took focus from the active editor"
        ),
    )


@then("Grove does not replace the error with a generic notice")
def grove_does_not_replace_open_error(helix: Helix) -> None:
    consistently(
        helix,
        lambda screen: (
            "Grove replaced Helix's open error with a generic notice"
            if screen.editor_contains("Grove: cannot open file")
            else None
        ),
    )
