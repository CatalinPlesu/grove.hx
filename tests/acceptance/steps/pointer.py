from pytest_bdd import parsers, then, when

from tests.support.host import Helix, MouseContact
from tests.support.screen import Row, Screen
from tests.support.waiting import eventually


@when(
    parsers.parse('"{name}" is pressed'),
    target_fixture="mouse_contact",
)
def row_is_pressed(helix: Helix, name: str) -> MouseContact:
    return helix.press(row=_row(helix, name).number)


@when(parsers.parse('the pointer releases over "{name}"'))
def pointer_releases(
    helix: Helix,
    mouse_contact: MouseContact,
    name: str,
) -> None:
    mouse_contact.move_to(row=_row(helix, name).number, column=5)
    mouse_contact.release()


@when(parsers.parse('"{name}" is activated'))
def row_is_activated(helix: Helix, name: str) -> None:
    helix.press(row=_row(helix, name).number).release()


@when("the editor is pressed")
def editor_is_pressed(helix: Helix) -> None:
    helix.click(row=1, column=min(50, helix.width - 2))


@when("blank Grove space is pressed")
def blank_grove_space_is_pressed(helix: Helix) -> None:
    screen = eventually(
        helix,
        lambda current: (
            None
            if current.blank_grove_row is not None
            else "Grove did not show blank Pane space"
        ),
    )
    assert screen.blank_grove_row is not None
    column = 5 if screen.side == "left" else helix.width - 5
    helix.click(row=screen.blank_grove_row, column=column)


@when(parsers.re(r"^the Wheel scrolls (?P<direction>up|down) over Grove$"))
def wheel_scrolls_over_grove(helix: Helix, direction: str) -> None:
    helix.wheel(direction, row=min(5, helix.height))


@when(parsers.parse('the Wheel scrolls to "{name}" at the File tree bottom'))
def wheel_scrolls_to_file_tree_bottom(
    helix: Helix,
    name: str,
) -> None:
    for _ in range(20):
        helix.wheel("down", row=min(5, helix.height))
    eventually(
        helix,
        lambda screen: (
            None
            if screen.row(name) is not None
            else f'Wheel scrolling did not reach "{name}"'
        ),
    )


@when(parsers.parse('the Wheel scrolls down over the Pinned row "{name}"'))
def wheel_scrolls_over_pinned_row(helix: Helix, name: str) -> None:
    screen = eventually(
        helix,
        lambda current: (
            None
            if current.rail is not None and current.row(name) is not None
            else f'Grove did not show the Pinned row "{name}"'
        ),
    )
    row = screen.row(name)
    assert row is not None
    column = 5 if screen.side == "left" else helix.width - 5
    helix.wheel("down", row=row.number, column=column)


@when(parsers.re(r"^the Rail track (?P<direction>above|below) the thumb is clicked$"))
def rail_track_page_is_clicked(helix: Helix, direction: str) -> None:
    screen = eventually(
        helix,
        lambda current: (
            None
            if current.rail_track(direction) is not None
            else f"Rail did not show track {direction} the thumb"
        ),
    )
    track = screen.rail_track(direction)
    before = screen.rail_thumb
    assert track is not None and before is not None
    column, row = track
    helix.click(row=row, column=column)
    eventually(
        helix,
        lambda current: (
            None
            if current.rail_thumb is not None
            and (
                current.rail_thumb[1] < before[1]
                if direction == "above"
                else current.rail_thumb[1] > before[1]
            )
            else f"Rail did not page {direction} from its track"
        ),
    )


@when("the Rail track is clicked")
def rail_track_without_thumb_is_clicked(helix: Helix) -> None:
    screen = _rail_screen(helix)
    assert screen.rail is not None
    helix.click(row=2, column=screen.rail + 1)


@when("the Rail track is dragged vertically")
def rail_track_is_dragged_vertically(helix: Helix) -> None:
    screen = _rail_screen(helix)
    assert screen.rail is not None
    column = screen.rail + 1
    helix.press(row=2, column=column).drag_to(
        row=min(helix.height, 8),
        column=column,
    )


@when(
    parsers.parse(
        "the Rail drag moves horizontally toward width {width:d} and then vertically"
    )
)
def rail_drag_moves_horizontally_then_vertically(
    helix: Helix,
    width: int,
) -> None:
    screen, contact = _press_rail_thumb(helix)
    assert screen.side is not None and screen.rail is not None
    current_width = screen.pane_width(screen.side, helix.width)
    assert current_width is not None
    direction = 1 if screen.side == "left" else -1
    destination = screen.rail + 1 + direction * (width - current_width)
    contact.move_to(row=contact.row, column=destination)
    eventually(
        helix,
        lambda current: (
            None
            if current.pane_width(screen.side, helix.width) == width
            else f"Grove did not choose horizontal resizing toward width {width}"
        ),
    )
    contact.move_to(
        row=min(contact.row + 8, helix.height),
        column=destination,
    )
    contact.release()


@when("the Rail drag moves vertically and then horizontally")
def rail_drag_moves_vertically_then_horizontally(helix: Helix) -> None:
    screen, contact = _press_rail_thumb(helix)
    before = screen.rail_thumb
    assert before is not None
    destination = min(contact.row + 5, helix.height)
    contact.move_to(row=destination, column=contact.column)
    eventually(
        helix,
        lambda current: (
            None
            if current.rail_thumb is not None and current.rail_thumb[1] != before[1]
            else "The Rail did not choose vertical scrolling"
        ),
    )
    contact.move_to(row=contact.row, column=contact.column + 8)
    contact.release()


@when(
    "the Rail thumb is pressed",
    target_fixture="rail_contact",
)
def rail_thumb_is_pressed(helix: Helix) -> MouseContact:
    return _press_rail_thumb(helix)[1]


@when(
    "the Rail thumb height is noted",
    target_fixture="noted_rail_thumb_height",
)
def rail_thumb_height_is_noted(helix: Helix) -> int:
    return _rail_screen(helix).rail_thumb_height


@then("the Rail thumb keeps its height")
def rail_thumb_keeps_its_height(
    helix: Helix,
    noted_rail_thumb_height: int,
) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if screen.rail_thumb_height == noted_rail_thumb_height
            else "The Rail thumb height changed with the Ancestor stack"
        ),
    )


@when(parsers.re(r"^the Rail thumb is dragged to the (?P<edge>top|bottom)$"))
def rail_thumb_is_dragged_to_edge(
    helix: Helix,
    rail_contact: MouseContact,
    edge: str,
) -> None:
    screen = _rail_screen(helix)
    assert screen.rail is not None
    rail_contact.drag_to(
        row={"top": 1, "bottom": helix.height}[edge],
        column=screen.rail + 1,
    )


@when("the Rail thumb is dragged down")
def rail_thumb_is_dragged_down(
    helix: Helix,
    rail_contact: MouseContact,
) -> None:
    screen = eventually(
        helix,
        lambda current: (
            None
            if current.rail_thumb is not None
            else "Grove did not show a Rail thumb"
        ),
    )
    assert screen.rail_thumb is not None
    column, row = screen.rail_thumb
    rail_contact.drag_to(
        row=min(row + 8, helix.height),
        column=column,
    )


@when("the pointer moves horizontally")
def pointer_moves_horizontally(rail_contact: MouseContact) -> None:
    rail_contact.move_to(
        row=rail_contact.row,
        column=rail_contact.column + 8,
    )
    rail_contact.release()


@when(parsers.parse('the "{side}" Rail is dragged toward width {requested:d}'))
def rail_is_dragged(
    helix: Helix,
    side: str,
    requested: int,
) -> None:
    screen = eventually(
        helix,
        lambda current: (
            None if current.side == side else f"Grove did not render on the {side}"
        ),
    )
    assert screen.rail is not None
    current = screen.pane_width(side, helix.width)
    assert current is not None
    direction = 1 if side == "left" else -1
    destination = screen.rail + 1 + direction * (requested - current)
    destination = max(2, min(helix.width - 1, destination))
    helix.press(row=2, column=screen.rail + 1).drag_to(
        row=2,
        column=destination,
    )


def _press_rail_thumb(helix: Helix) -> tuple[Screen, MouseContact]:
    screen = eventually(
        helix,
        lambda current: (
            None
            if current.rail_thumb is not None
            else "Grove did not show a Rail thumb"
        ),
    )
    assert screen.rail_thumb is not None
    column, row = screen.rail_thumb
    return screen, helix.press(row=row, column=column)


def _row(helix: Helix, name: str) -> Row:
    screen = eventually(
        helix,
        lambda current: (
            None if current.row(name) is not None else f'Grove did not show "{name}"'
        ),
    )
    row = screen.row(name)
    assert row is not None
    return row


def _rail_screen(helix: Helix) -> Screen:
    return eventually(
        helix,
        lambda screen: (
            None if screen.rail is not None else "Grove did not show its Rail"
        ),
    )
