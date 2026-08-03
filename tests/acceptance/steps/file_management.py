import os
import time
from pathlib import PurePath

from pytest_bdd import parsers, then, when

from tests.support.host import Helix
from tests.support.waiting import (
    eventually,
    eventually_bottom_line_contains,
)
from tests.support.workspace import Workspace


def _open_document(helix: Helix, workspace: Workspace, name: str) -> None:
    helix.command(f':open "{workspace.root / name}"')
    eventually(
        helix,
        lambda screen: (
            None if screen.document == name else f'Helix did not open "{name}"'
        ),
    )


@then(parsers.parse('the native prompt is "{label}"'))
def native_prompt_is(helix: Helix, label: str) -> None:
    eventually_bottom_line_contains(helix, label)


@when(parsers.parse('the prompt receives "{text}"'))
def prompt_receives(helix: Helix, text: str) -> None:
    helix.type(text, enter=True)


@when(parsers.parse('Helix prepares "{protection}" for file mutation'))
def prepare_file_protection(
    helix: Helix,
    workspace: Workspace,
    protection: str,
) -> None:
    if protection == "dirty source":
        _open_document(helix, workspace, "source.txt")
        helix.type("idirty-")
        helix.key("Escape")
    elif protection == "open destination":
        _open_document(helix, workspace, "destination.txt")
    else:
        raise ValueError(f"Unknown file protection: {protection!r}")
    _open_document(helix, workspace, "anchor.txt")


@when(
    parsers.parse(
        'Helix opens "{background}" as a clean background buffer behind "{active}"'
    )
)
def open_clean_background_buffer(
    helix: Helix,
    workspace: Workspace,
    background: str,
    active: str,
) -> None:
    _open_document(helix, workspace, background)
    _open_document(helix, workspace, active)


@then(parsers.parse('the old "{name}" buffer is closed'))
def old_buffer_is_closed(
    helix: Helix,
    workspace: Workspace,
    name: str,
) -> None:
    expected = str(workspace.root / name)
    eventually(
        helix,
        lambda _screen: (
            None
            if expected in helix.closed_documents
            else f'Helix did not close the old "{name}" buffer'
        ),
    )


@then(parsers.parse('Helix closed "{first}" before "{second}"'))
def documents_closed_in_order(
    helix: Helix,
    workspace: Workspace,
    first: str,
    second: str,
) -> None:
    expected_first = str(workspace.root / first)
    expected_second = str(workspace.root / second)
    closed = helix.closed_documents
    assert expected_first in closed
    assert expected_second in closed
    assert closed.index(expected_first) < closed.index(expected_second)


@then(parsers.parse('"{name}" exists as an empty file'))
def empty_file_exists(helix: Helix, workspace: Workspace, name: str) -> None:
    path = workspace.root.joinpath(*PurePath(name).parts)
    eventually(
        helix,
        lambda _screen: None if path.is_file() else f'Grove did not create "{name}"',
    )
    assert path.read_bytes() == b""
    workspace.refresh()


@then(parsers.parse('"{name}" exists as a directory'))
def directory_exists(helix: Helix, workspace: Workspace, name: str) -> None:
    absolute = workspace.root.joinpath(*PurePath(name).parts)
    eventually(
        helix,
        lambda _screen: None if absolute.is_dir() else f'Grove did not create "{name}"',
    )
    workspace.refresh()


@then(parsers.parse('"{source}" no longer exists and "{destination}" exists'))
def path_was_moved(
    helix: Helix,
    workspace: Workspace,
    source: str,
    destination: str,
) -> None:
    source_absolute = workspace.root.joinpath(*PurePath(source).parts)
    destination_absolute = workspace.root.joinpath(*PurePath(destination).parts)
    eventually(
        helix,
        lambda _screen: (
            None
            if not source_absolute.exists() and destination_absolute.exists()
            else f'Grove did not move "{source}" to "{destination}"'
        ),
    )

    workspace.refresh()


@then(parsers.parse('Helix shows the message "{message}"'))
def helix_shows_message(helix: Helix, message: str) -> None:
    eventually_bottom_line_contains(helix, message)


@then(parsers.parse('Helix shows the message "{message}" at terminal column 0'))
def helix_shows_message_at_terminal_start(helix: Helix, message: str) -> None:
    eventually_bottom_line_contains(helix, message)
    bottom_line = tuple(helix.pane.capture_pane())[-1]
    assert bottom_line.startswith(message), (
        f'Helix did not show "{message}" at terminal column 0: {bottom_line!r}'
    )


@then(parsers.parse('Helix keeps the message "{message}" while idle'))
def helix_keeps_message_while_idle(helix: Helix, message: str) -> None:
    deadline = time.monotonic() + 0.75
    while time.monotonic() < deadline:
        lines = tuple(helix.pane.capture_pane())
        assert lines and message in lines[-1], (
            f'Helix did not keep "{message}" while idle'
        )
        time.sleep(0.05)


@then(parsers.parse('"{name}" does not exist'))
@then(parsers.parse('"{name}" no longer exists'))
def path_no_longer_exists(helix: Helix, workspace: Workspace, name: str) -> None:
    path = PurePath(name)
    absolute = workspace.root.joinpath(*path.parts)
    eventually(
        helix,
        lambda _screen: (
            None if not os.path.lexists(absolute) else f'Grove did not delete "{name}"'
        ),
    )
    workspace.refresh()


@then(parsers.parse('"{name}" still exists'))
def path_still_exists(workspace: Workspace, name: str) -> None:
    path = workspace.root.joinpath(*PurePath(name).parts)
    assert os.path.lexists(path)


@then(parsers.parse('the editor contains "{text}"'))
def editor_contains(helix: Helix, text: str) -> None:
    eventually(
        helix,
        lambda screen: (
            None
            if screen.editor_contains(text)
            else f'Helix did not show editor text "{text}"'
        ),
    )
