from pytest_bdd import parsers, then

from tests.support.host import Helix
from tests.support.screen import Screen
from tests.support.waiting import eventually


@then(parsers.parse('Grove is Docked on the "{side}" at width {width:d}'))
def grove_is_docked(helix: Helix, side: str, width: int) -> None:
    def mismatch(screen: Screen) -> str | None:
        actual = screen.pane_width(side, helix.width)
        if actual == width:
            return None
        return (
            f"Grove was not Docked on the {side} at width {width}; "
            f"observed width {actual}"
        )

    eventually(helix, mismatch)


@then(parsers.parse("Grove has width {width:d}"))
def grove_has_width(helix: Helix, width: int) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if screen.pane_width(screen.side or "", helix.width) == width
            else f"Grove did not retain width {width}"
        ),
    )


@then("Grove yields the whole terminal to Helix")
def grove_yields_to_helix(helix: Helix) -> None:
    eventually(
        helix,
        lambda screen: (
            None if screen.rail is None else "Grove did not yield the terminal"
        ),
    )


_FOREGROUNDS = {
    "conflict Git": (255, 0, 255),
    "deleted Git": (255, 0, 0),
    "modified Git": (255, 255, 0),
    "created Git": (0, 255, 0),
    "theme text": (216, 216, 216),
}
_SELECTION_BACKGROUNDS = {
    "Active": (48, 48, 48),
    "Cursor": (64, 64, 64),
}


@then(
    parsers.re(
        r'^"(?P<name>.+)" uses the '
        r"(?P<foreground>conflict Git|deleted Git|modified Git|created Git|theme text) "
        r"foreground$"
    )
)
def entry_uses_foreground(helix: Helix, name: str, foreground: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None
            and row.foreground_before(name) == _FOREGROUNDS[foreground]
            else f'"{name}" did not use the {foreground} foreground'
        ),
    )


@then(parsers.parse('"{name}" uses the unreadable-folder icon and error foreground'))
def unreadable_entry_uses_error_presentation(helix: Helix, name: str) -> None:
    def mismatch(screen: Screen) -> str | None:
        row = screen.row(name)
        if row is None:
            return f'Grove did not show unreadable row "{name}"'
        if row.foreground_before("󰷌") != (255, 0, 255):
            return f'"{name}" did not use the unreadable icon foreground'
        if row.foreground_before(name) != (255, 0, 255):
            return f'"{name}" did not use the error label foreground'
        return None

    eventually(helix, mismatch)


@then(parsers.parse('"{name}" uses the "{variant}" file icon variant'))
def file_icon_uses_variant(helix: Helix, name: str, variant: str) -> None:
    color = {"dark": (137, 224, 81), "light": (68, 112, 40)}[variant]
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None
            and row.foreground_before("󰈙") == color
            else f"Grove did not use the {variant} file-icon variant"
        ),
    )


@then(parsers.re(r"^these rows carry (?P<amount>one|no) Unsaved mark$"))
def rows_carry_unsaved_mark(
    helix: Helix,
    datatable: list[list[str]],
    amount: str,
) -> None:
    expected = "●" if amount == "one" else None
    names = [row[0] for row in datatable[1:]]

    def mismatch(screen: Screen) -> str | None:
        for name in names:
            row = (
                screen.workspace_root if name == "Workspace root" else screen.row(name)
            )
            if row is None:
                return f'Grove did not show "{name}"'
            if row.mark != expected:
                return (
                    f'"{name}" carried an Unsaved mark'
                    if expected is None
                    else f'"{name}" did not carry an Unsaved mark'
                )
        return None

    eventually(helix, mismatch)


@then("the Workspace root carries no Unsaved mark")
def workspace_root_carries_no_unsaved_mark(helix: Helix) -> None:
    def mismatch(screen: Screen) -> str | None:
        root = screen.workspace_root
        if root is None:
            return "Grove did not show the Workspace root"
        return (
            "Workspace root carried an Unsaved mark" if root.mark is not None else None
        )

    eventually(helix, mismatch)


@then(
    parsers.re(
        r'^"(?P<name>.+)" clips '
        r"(?P<mark>without an Unsaved mark|with its Unsaved mark visible)$"
    )
)
def long_filename_clips(helix: Helix, name: str, mark: str) -> None:
    suffix = {
        "without an Unsaved mark": "…",
        "with its Unsaved mark visible": "…●",
    }[mark]
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None and row.text.endswith(suffix)
            else f'"{name}" did not end with {suffix!r}'
        ),
    )


@then(parsers.parse('the failure foreground owns the "{name}" icon and label'))
def failure_foreground_owns_failed_entry(helix: Helix, name: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None
            and row.foreground_before("󰌺") == (255, 0, 255)
            and row.foreground_before(name) == (255, 0, 255)
            else f'"{name}" did not use the failure foreground'
        ),
    )


@then(parsers.parse('ignored status dims the "{name}" label only'))
def ignored_status_dims_label(helix: Helix, name: str) -> None:
    def mismatch(screen: Screen) -> str | None:
        ignored = screen.row(name)
        root = screen.workspace_root
        if ignored is None:
            return f'Grove did not show ignored row "{name}"'
        if root is None:
            return "Grove did not show the Workspace root"
        if not ignored.is_dimmed_before(name):
            return f'Ignored label "{name}" was not dimmed'
        if ignored.is_dimmed_before("") or root.is_dimmed_before(root.label):
            return "Ignored dimming leaked beyond the item label"
        return None

    eventually(helix, mismatch)


@then(
    parsers.parse(
        'the Workspace icon, "{name}" icon, and Unsaved marks keep their foregrounds'
    )
)
def icons_and_unsaved_marks_keep_foregrounds(helix: Helix, name: str) -> None:
    def mismatch(screen: Screen) -> str | None:
        root = screen.workspace_root
        row = screen.row(name)
        if root is None:
            return "Grove did not show the Workspace root"
        if row is None:
            return f'Grove did not show status row "{name}"'
        if root.foreground_before("󰙅") != (216, 216, 216):
            return "Git status recolored the Workspace icon"
        if row.foreground_before("󰈙") != (137, 224, 81):
            return f'Git status recolored the "{name}" icon'
        if root.foreground_before("●") != (0, 255, 255):
            return "Git status recolored the Workspace Unsaved mark"
        if row.foreground_before("●") != (0, 255, 255):
            return f'Git status recolored the "{name}" Unsaved mark'
        return None

    eventually(helix, mismatch)


@then(
    parsers.re(
        r'^the (?P<selection>Active|Cursor) "(?P<name>.+)" row background '
        r"spans its icon, label, and Unsaved mark$"
    )
)
def selected_background_spans_row(
    helix: Helix,
    name: str,
    selection: str,
) -> None:
    markers = ("󰈙", name, "●")
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None
            and all(
                row.background_before(marker) == _SELECTION_BACKGROUNDS[selection]
                for marker in markers
            )
            else f'{selection} background did not span the whole "{name}" row'
        ),
    )


@then(parsers.parse('the Cursor icon for "{name}" uses the Cursor foreground'))
def cursor_icon_uses_cursor_foreground(helix: Helix, name: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None
            and row.foreground_before("󰈙") == (0, 170, 255)
            else f'Cursor icon for "{name}" did not use the Cursor foreground'
        ),
    )


@then(
    parsers.re(
        r'^ignored dimming on "(?P<name>.+)" composes with the '
        r"(?P<selection>Active|Cursor) row background$"
    )
)
def ignored_dimming_composes_with_selected_background(
    helix: Helix,
    name: str,
    selection: str,
) -> None:
    def mismatch(screen: Screen) -> str | None:
        row = screen.row(name)
        if row is None:
            return f'Grove did not show ignored row "{name}"'
        if "󰈙" not in row.text:
            return f'Ignored row "{name}" did not show its file icon'
        if "●" not in row.text:
            return f'Ignored row "{name}" did not show its Unsaved mark'
        if not row.is_dimmed_before(name):
            return "Ignored item label was not dimmed"
        if row.is_dimmed_before("󰈙") or row.is_dimmed_before("●"):
            return "Ignored dimming leaked to the icon or Unsaved mark"
        if any(
            row.background_before(marker) != _SELECTION_BACKGROUNDS[selection]
            for marker in ("󰈙", name, "●")
        ):
            return "Selected background did not span the ignored row"
        return None

    eventually(helix, mismatch)


@then(parsers.parse('the Pinned "{name}" row keeps ordinary status layers'))
def pinned_row_keeps_ordinary_status_layers(helix: Helix, name: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None
            and "▾" in row.text
            and "" in row.text
            and "●" in row.text
            and row.foreground_before(name) == (255, 255, 0)
            and row.foreground_before("●") == (0, 255, 255)
            and all(
                row.background_before(marker) == (64, 64, 64)
                for marker in ("", name, "●")
            )
            else f'Pinned row "{name}" lost ordinary status layers'
        ),
    )


@then(parsers.parse('the Pinned "{name}" row background composes with ignored dimming'))
def pinned_background_composes_with_ignored_dimming(
    helix: Helix,
    name: str,
) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if (row := screen.row(name)) is not None
            and "▾" in row.text
            and "" in row.text
            and row.is_dimmed_before(name)
            and not row.is_dimmed_before("")
            and not row.is_dimmed_before("▾")
            and all(
                row.background_before(marker) == (32, 32, 32)
                for marker in ("▾", "", name)
            )
            else f'Pinned row "{name}" lost its background or ignored dimming'
        ),
    )
