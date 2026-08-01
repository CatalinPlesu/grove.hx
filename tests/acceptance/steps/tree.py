from pytest_bdd import parsers, then, when

from tests.support.host import Helix
from tests.support.screen import Screen
from tests.support.waiting import consistently, eventually
from tests.support.workspace import Workspace


@when(parsers.parse('the File tree shows "{name}"'))
@then(parsers.parse('the File tree shows "{name}"'))
def file_tree_shows(helix: Helix, name: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None if screen.row(name) is not None else f'Grove did not show "{name}"'
        ),
    )


@then(parsers.parse('the content of "{name}" starts with "{text}"'))
def file_content_starts_with(
    helix: Helix,
    workspace: Workspace,
    name: str,
    text: str,
) -> None:
    document = workspace.document_path(name)

    def mismatch(_screen: Screen) -> str | None:
        try:
            content = document.read_text(encoding="utf-8")
        except FileNotFoundError:
            return f'"{name}" disappeared while Helix saved it'
        if not content.startswith(text):
            return f'The content of "{name}" did not start with {text!r}'
        return None

    eventually(helix, mismatch)


@then(parsers.parse('the content of "{name}" contains "{text}"'))
def file_content_contains(
    helix: Helix,
    workspace: Workspace,
    name: str,
    text: str,
) -> None:
    document = workspace.document_path(name)

    def mismatch(_screen: Screen) -> str | None:
        try:
            content = document.read_text(encoding="utf-8")
        except FileNotFoundError:
            return f'"{name}" disappeared while Helix saved it'
        if text not in content:
            return f'The content of "{name}" did not contain {text!r}'
        return None

    eventually(helix, mismatch)


@then(parsers.parse('the File tree does not show "{name}"'))
def file_tree_does_not_show(helix: Helix, name: str) -> None:
    def absent(screen: Screen) -> str | None:
        return None if screen.row(name) is None else f'Grove kept showing "{name}"'

    eventually(helix, absent)
    consistently(helix, absent)


@then("File tree rows appear in order")
def file_tree_rows_appear_in_order(
    helix: Helix,
    datatable: list[list[str]],
) -> None:
    names = [row[0] for row in datatable[1:]]

    def mismatch(screen: Screen) -> str | None:
        rows = [screen.row(name) for name in names]
        missing = [name for name, row in zip(names, rows, strict=True) if row is None]
        if missing:
            return f"Grove did not show File tree rows {missing!r}"
        positions = [row.number for row in rows if row is not None]
        if positions == sorted(positions):
            return None
        actual = [
            name
            for _position, name in sorted(
                zip(positions, names, strict=True),
            )
        ]
        return f"File tree row order was {actual!r}, not {names!r}"

    eventually(helix, mismatch)


_ICONS = {
    "Broken link": "󰌺",
    "File link": "",
    "directory": "",
    "file": "󰈙",
}


@then(
    parsers.re(
        r'^"(?P<name>.+)" uses the '
        r"(?P<kind>Broken link|File link|directory|file) icon$"
    )
)
def entry_uses_icon(helix: Helix, name: str, kind: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None and row.has_icon(_ICONS[kind])
            else f'"{name}" did not use the {kind} icon'
        ),
    )


@then("the Workspace root uses one File tree icon")
def workspace_root_uses_one_icon(helix: Helix) -> None:
    screen = _screen_with_rows(helix)
    row = screen.workspace_root
    assert row is not None
    assert row.text.count("󰙅") == 1
    assert not row.is_expandable and "" not in row.text


@then("the Workspace root has neither an Ancestor trace nor a Leaf mark")
def workspace_root_has_no_ancestor_trace_or_leaf_mark(helix: Helix) -> None:
    row = _screen_with_rows(helix).workspace_root
    assert row is not None
    assert "│" not in row.text[: row.label_column()]
    assert "·" not in row.text[: row.label_column()]


@then(parsers.parse('"{name}" uses {count:d} Ancestor trace'))
@then(parsers.parse('"{name}" uses {count:d} Ancestor traces'))
def entry_uses_ancestor_traces(helix: Helix, name: str, count: int) -> None:
    row = _screen_with_rows(helix, name).row(name)
    assert row is not None
    assert row.text[: row.label_column()].count("│") == count


@then(parsers.parse('"{name}" has no Ancestor trace'))
def entry_has_no_ancestor_trace(helix: Helix, name: str) -> None:
    row = _screen_with_rows(helix, name).row(name)
    assert row is not None
    assert "│" not in row.text[: row.label_column()]


@then(parsers.parse('"{name}" uses one Leaf mark'))
def entry_uses_one_leaf_mark(helix: Helix, name: str) -> None:
    row = _screen_with_rows(helix, name).row(name)
    assert row is not None
    assert row.text[: row.label_column()].count("·") == 1


@then(parsers.parse('"{name}" has no Leaf mark'))
def entry_has_no_leaf_mark(helix: Helix, name: str) -> None:
    row = _screen_with_rows(helix, name).row(name)
    assert row is not None
    assert "·" not in row.text[: row.label_column()]


@then(
    parsers.parse(
        'the Ancestor traces and Leaf mark on "{name}" '
        "use the indent-guide theme foreground"
    )
)
def ancestor_traces_and_leaf_mark_use_indent_guide_foreground(
    helix: Helix,
    name: str,
) -> None:
    row = _screen_with_rows(helix, name).row(name)
    assert row is not None
    assert row.foreground_before("│") == (136, 136, 136)
    assert row.foreground_before("·") == (136, 136, 136)
    assert not row.is_dimmed_before("│")
    assert not row.is_dimmed_before("·")


@then(
    parsers.parse(
        'the Ancestor trace and Leaf mark on "{name}" '
        "use the dimmed theme text foreground"
    )
)
def ancestor_trace_and_leaf_mark_use_dimmed_text_foreground(
    helix: Helix,
    name: str,
) -> None:
    row = _screen_with_rows(helix, name).row(name)
    assert row is not None
    text_foreground = row.foreground_before(row.label)
    assert text_foreground is not None
    assert row.foreground_before("│") == text_foreground
    assert row.foreground_before("·") == text_foreground
    assert row.is_dimmed_before("│")
    assert row.is_dimmed_before("·")


@then(parsers.parse('"{file}" aligns with "{directory}" in icon mode'))
def icon_mode_entries_align(helix: Helix, file: str, directory: str) -> None:
    screen = _screen_with_rows(helix, file, directory)
    file_row = screen.row(file)
    directory_row = screen.row(directory)
    assert file_row is not None and directory_row is not None
    assert file_row.label_column() == directory_row.label_column()


@then(
    parsers.parse(
        'the Workspace label starts in column 4 and "{directory}" and "{file}" '
        "labels start in column 6"
    )
)
def icon_label_columns(helix: Helix, directory: str, file: str) -> None:
    screen = _screen_with_rows(helix, directory, file)
    root = screen.workspace_root
    directory_row = screen.row(directory)
    file_row = screen.row(file)
    assert root is not None and root.label_column() == 3
    assert directory_row is not None and directory_row.label_column() == 5
    assert file_row is not None and file_row.label_column() == 5


@then(parsers.parse('"{name}" can expand'))
def entry_can_expand(helix: Helix, name: str) -> None:
    _entry_has_disclosure(helix, name, "▸")


@then(parsers.parse('"{name}" cannot expand'))
def entry_cannot_expand(helix: Helix, name: str) -> None:
    _entry_has_disclosure(helix, name, None)


def _entry_has_disclosure(
    helix: Helix,
    name: str,
    expected: str | None,
) -> None:
    state = "expandable" if expected is not None else "inert"
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None and row.disclosure == expected
            else f'"{name}" did not become {state}'
        ),
    )


@then(parsers.parse('"{child}" is indented two columns from "{parent}"'))
def child_is_indented(helix: Helix, child: str, parent: str) -> None:
    screen = _screen_with_rows(helix, child, parent)
    child_row = screen.row(child)
    parent_row = screen.row(parent)
    assert child_row is not None and parent_row is not None
    assert child_row.label_column() == parent_row.label_column() + 2


@then(
    parsers.parse(
        'Workspace, "{directory}", and "{file}" labels occupy reclaimed icon columns'
    )
)
def labels_reclaim_icon_columns(
    helix: Helix,
    workspace: Workspace,
    directory: str,
    file: str,
) -> None:
    screen = _screen_with_rows(helix, directory, file)
    root = screen.workspace_root
    directory_row = screen.row(directory)
    file_row = screen.row(file)
    assert root is not None and root.label == workspace.root.name
    assert root.label_column() == 1
    assert directory_row is not None and directory_row.label_column() == 3
    assert file_row is not None and file_row.label_column() == 3


def _screen_with_rows(helix: Helix, *names: str) -> Screen:
    def mismatch(screen: Screen) -> str | None:
        if screen.workspace_root is None:
            return "Grove did not show the Workspace root"
        missing = [name for name in names if screen.row(name) is None]
        return f"Grove did not show rows {missing!r}" if missing else None

    return eventually(helix, mismatch)


@when(parsers.parse('the "{name}" directory is expanded'))
def expand_directory(helix: Helix, name: str) -> None:
    _toggle_directory(helix, name, "▾")
    helix.focus_grove()


@when(parsers.parse('the "{name}" directory is collapsed'))
def collapse_directory(helix: Helix, name: str) -> None:
    _toggle_directory(helix, name, "▸")


@then(parsers.parse('"{name}" remains expanded'))
def directory_remains_expanded(helix: Helix, name: str) -> None:
    _wait_for_disclosure(helix, name, "▾")


@then(parsers.parse('"{name}" remains collapsed'))
def directory_remains_collapsed(helix: Helix, name: str) -> None:
    _wait_for_disclosure(helix, name, "▸")


def _toggle_directory(helix: Helix, name: str, disclosure: str) -> None:
    row = _screen_with_rows(helix, name).row(name)
    assert row is not None
    helix.click(row=row.number)
    _wait_for_disclosure(helix, name, disclosure)


def _wait_for_disclosure(helix: Helix, name: str, disclosure: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None and row.disclosure == disclosure
            else f'Grove did not show "{name}" with disclosure {disclosure}'
        ),
    )


@when(parsers.parse('the File tree root is "{name}"'))
@then(parsers.parse('the File tree root is "{name}"'))
def file_tree_root_is(helix: Helix, name: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (root := screen.workspace_root) is not None and root.label == name
            else f'Grove did not show Workspace root "{name}"'
        ),
    )


@then(parsers.parse('Pane row {number:d} is "{name}"'))
def pane_row_is(helix: Helix, number: int, name: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None and row.number == number
            else f'Pane row {number} was not "{name}"'
        ),
    )


@then(parsers.parse('Pane row {number:d} is not "{name}"'))
def pane_row_is_not(helix: Helix, number: int, name: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if screen.workspace_root is not None
            and ((row := screen.row(name)) is None or row.number != number)
            else f'Pane row {number} remained "{name}"'
        ),
    )


@then(parsers.parse('the File tree ends with "{name}"'))
def file_tree_ends_with(helix: Helix, name: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None and row.number == helix.height
            else f'Grove did not clamp the File tree at "{name}"'
        ),
    )


@then(
    parsers.parse(
        'the Ancestor stack is "{names}" above File tree row "{first_visible}"'
    )
)
def ancestor_stack_is_above_file_tree_row(
    helix: Helix,
    names: str,
    first_visible: str,
) -> None:
    expected = (*names.split(" > "), first_visible)
    eventually(
        helix,
        lambda screen: (
            None
            if all(
                (row := screen.row(name)) is not None and row.number == number
                for number, name in enumerate(expected, start=1)
            )
            else (
                f'Grove did not show Ancestor stack "{names}" above "{first_visible}"'
            )
        ),
    )


@then(parsers.parse('the Ancestor stack is "{names}" above File tree content'))
def ancestor_stack_is_above_file_tree_content(
    helix: Helix,
    names: str,
) -> None:
    expected = names.split(" > ")
    eventually(
        helix,
        lambda screen: (
            None
            if all(
                (row := screen.row(name)) is not None and row.number == number
                for number, name in enumerate(expected, start=1)
            )
            and bool(screen.grove_row_text(len(expected) + 1).strip())
            else f'Grove did not show Ancestor stack "{names}" above File tree content'
        ),
    )
