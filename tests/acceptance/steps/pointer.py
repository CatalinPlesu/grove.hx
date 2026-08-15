from pytest_bdd import parsers, then, when

from tests.support.grove import GroveDriver, GroveFrame, VisibleRow
from tests.support.tui import PointerContact

from .rows import scenario_path


@when(
    parsers.parse('"{name}" is pressed'),
    target_fixture="mouse_contact",
)
def row_is_pressed(grove: GroveDriver, name: str) -> PointerContact:
    return grove.press_row(_row(grove, name).path)


@when(parsers.parse('the pointer releases over "{name}"'))
def pointer_releases(
    grove: GroveDriver,
    mouse_contact: PointerContact,
    name: str,
) -> None:
    mouse_contact.move_to(row=_row(grove, name).number, column=5)
    mouse_contact.release()


@when(parsers.parse('"{name}" is activated'))
def row_is_activated(grove: GroveDriver, name: str) -> None:
    grove.press_row(_row(grove, name).path).release()


@when("the editor is pressed")
def editor_is_pressed(grove: GroveDriver) -> None:
    grove.click_editor()


@when("blank Grove space is pressed")
def blank_grove_space_is_pressed(grove: GroveDriver) -> None:
    grove.click_blank_pane()


@when(parsers.re(r"^the Wheel scrolls (?P<direction>up|down) over Grove$"))
def wheel_scrolls_over_grove(grove: GroveDriver, direction: str) -> None:
    grove.wheel(direction)


@when(parsers.parse("the Wheel scrolls down {count:d} times over Grove"))
def wheel_scrolls_repeatedly(grove: GroveDriver, count: int) -> None:
    for _ in range(count):
        grove.wheel("down")


@when(parsers.parse('the Wheel scrolls down over the Pinned row "{name}"'))
def wheel_scrolls_over_pinned_row(grove: GroveDriver, name: str) -> None:
    grove.wheel("down", over=scenario_path(name))


@when(parsers.re(r"^the Rail track (?P<direction>above|below) the thumb is clicked$"))
def rail_track_page_is_clicked(grove: GroveDriver, direction: str) -> None:
    grove.click_rail_track(direction)


@when("the Rail track is clicked")
def rail_track_without_thumb_is_clicked(grove: GroveDriver) -> None:
    frame = _rail_screen(grove)
    assert frame.pane is not None
    grove.helix.terminal.click(2, frame.pane.rail.column)


@when("the Rail track is dragged vertically")
def rail_track_is_dragged_vertically(grove: GroveDriver) -> None:
    frame = _rail_screen(grove)
    assert frame.pane is not None
    column = frame.pane.rail.column
    grove.helix.terminal.press(2, column).drag_to(
        row=min(grove.helix.terminal.capture().height, 8),
        column=column,
    )


@when(
    parsers.parse(
        "the Rail drag moves horizontally toward width {width:d} and then vertically"
    )
)
def rail_drag_moves_horizontally_then_vertically(
    grove: GroveDriver,
    width: int,
) -> None:
    frame, contact = _press_rail_thumb(grove)
    assert frame.pane is not None
    direction = 1 if frame.pane.side == "left" else -1
    destination = frame.pane.rail.column + direction * (width - frame.pane.width)
    contact.move_to(row=contact.row, column=destination)
    grove.wait(
        lambda current: (
            None
            if current.pane is not None and current.pane.width == width
            else f"Grove did not choose horizontal resizing toward width {width}"
        ),
    )
    contact.move_to(
        row=min(contact.row + 8, grove.helix.terminal.capture().height),
        column=destination,
    )
    contact.release()


@when("the Rail drag moves vertically and then horizontally")
def rail_drag_moves_vertically_then_horizontally(grove: GroveDriver) -> None:
    frame, contact = _press_rail_thumb(grove)
    assert frame.pane is not None
    before = frame.pane.rail.thumb
    assert before is not None
    destination = min(contact.row + 5, grove.helix.terminal.capture().height)
    contact.move_to(row=destination, column=contact.column)
    grove.wait(
        lambda current: (
            None
            if current.pane is not None
            and current.pane.rail.thumb is not None
            and current.pane.rail.thumb[1] != before[1]
            else "The Rail did not choose vertical scrolling"
        ),
    )
    contact.move_to(row=contact.row, column=contact.column + 8)
    contact.release()


@when(
    "the Rail thumb is pressed",
    target_fixture="rail_contact",
)
def rail_thumb_is_pressed(grove: GroveDriver) -> PointerContact:
    return _press_rail_thumb(grove)[1]


@when(
    "the Rail thumb height is noted",
    target_fixture="noted_rail_thumb_height",
)
def rail_thumb_height_is_noted(grove: GroveDriver) -> int:
    frame = _rail_screen(grove)
    assert frame.pane is not None
    return len(frame.pane.rail.thumb_rows)


@then("the Rail thumb keeps its height")
def rail_thumb_keeps_its_height(
    grove: GroveDriver,
    noted_rail_thumb_height: int,
) -> None:
    grove.wait(
        lambda frame: (
            None
            if frame.pane is not None
            and len(frame.pane.rail.thumb_rows) == noted_rail_thumb_height
            else "The Rail thumb height changed with the Ancestor stack"
        ),
    )


@when(parsers.re(r"^the Rail thumb is dragged to the (?P<edge>top|bottom)$"))
def rail_thumb_is_dragged_to_edge(
    grove: GroveDriver,
    rail_contact: PointerContact,
    edge: str,
) -> None:
    frame = _rail_screen(grove)
    assert frame.pane is not None
    rail_contact.drag_to(
        row={"top": 1, "bottom": grove.helix.terminal.capture().height}[edge],
        column=frame.pane.rail.column,
    )


@when("the Rail thumb is dragged down")
def rail_thumb_is_dragged_down(
    grove: GroveDriver,
    rail_contact: PointerContact,
) -> None:
    frame = grove.wait(
        lambda current: (
            None
            if current.pane is not None and current.pane.rail.thumb is not None
            else "Grove did not show a Rail thumb"
        ),
    )
    assert frame.pane is not None and frame.pane.rail.thumb is not None
    column, row = frame.pane.rail.thumb
    rail_contact.drag_to(
        row=min(row + 8, grove.helix.terminal.capture().height),
        column=column,
    )


@when("the pointer moves horizontally")
def pointer_moves_horizontally(rail_contact: PointerContact) -> None:
    rail_contact.move_to(
        row=rail_contact.row,
        column=rail_contact.column + 8,
    )
    rail_contact.release()


@when(parsers.parse('the "{side}" Rail is dragged toward width {requested:d}'))
def rail_is_dragged(
    grove: GroveDriver,
    side: str,
    requested: int,
) -> None:
    frame = grove.capture()
    if frame.pane is None or frame.pane.side != side:
        raise AssertionError(f"Grove did not render on the {side}")
    grove.drag_rail_to_width(requested)


def _press_rail_thumb(grove: GroveDriver) -> tuple[GroveFrame, PointerContact]:
    frame = grove.wait(
        lambda current: (
            None
            if current.pane is not None and current.pane.rail.thumb is not None
            else "Grove did not show a Rail thumb"
        ),
    )
    assert frame.pane is not None and frame.pane.rail.thumb is not None
    column, row = frame.pane.rail.thumb
    return frame, grove.helix.terminal.press(row, column)


def _row(grove: GroveDriver, name: str) -> VisibleRow:
    return grove.wait_for_row(scenario_path(name))


def _rail_screen(grove: GroveDriver) -> GroveFrame:
    return grove.wait(
        lambda frame: None if frame.pane is not None else "Grove did not show its Rail",
    )
