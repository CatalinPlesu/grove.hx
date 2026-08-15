import os
from pathlib import PurePath

from pytest_bdd import parsers, then, when

from tests.support.grove import GroveDriver
from tests.support.helix import HelixSandbox
from tests.support.workspace import WorkspaceFixture


@then(parsers.parse('the native prompt is "{label}"'))
def native_prompt_is(grove: GroveDriver, label: str) -> None:
    grove.helix.wait(
        lambda frame: (
            None
            if frame.bottom_line.rstrip() == label
            else f"Helix prompt was {frame.bottom_line!r}, not {label!r}"
        )
    )


@when(parsers.parse('the prompt receives "{text}"'))
def prompt_receives(grove: GroveDriver, text: str) -> None:
    grove.helix.terminal.write(text)
    grove.helix.terminal.key("Enter")


@when(parsers.parse('Helix opens "{name}"'))
def open_document(
    grove: GroveDriver,
    workspace: WorkspaceFixture,
    name: str,
) -> None:
    grove.helix.command(f'open "{workspace.root / name}"')
    grove.wait(
        lambda frame: (
            None if frame.helix.document == name else f'Helix did not open "{name}"'
        ),
    )


@then(parsers.parse('the old "{name}" buffer is closed'))
def old_buffer_is_closed(
    grove: GroveDriver,
    helix_sandbox: HelixSandbox,
    workspace: WorkspaceFixture,
    name: str,
) -> None:
    expected = str(workspace.root / name)
    grove.wait(
        lambda _frame: (
            None
            if expected in helix_sandbox.closed_documents
            else f'Helix did not close the old "{name}" buffer'
        ),
    )


@then(parsers.parse('Helix closed "{first}" before "{second}"'))
def documents_closed_in_order(
    helix_sandbox: HelixSandbox,
    workspace: WorkspaceFixture,
    first: str,
    second: str,
) -> None:
    expected_first = str(workspace.root / first)
    expected_second = str(workspace.root / second)
    closed = helix_sandbox.closed_documents
    assert expected_first in closed
    assert expected_second in closed
    assert closed.index(expected_first) < closed.index(expected_second)


@then(parsers.parse('"{name}" exists as an empty file'))
def empty_file_exists(
    grove: GroveDriver, workspace: WorkspaceFixture, name: str
) -> None:
    path = workspace.root.joinpath(*PurePath(name).parts)
    grove.wait(
        lambda _frame: None if path.is_file() else f'Grove did not create "{name}"',
    )
    assert path.read_bytes() == b""
    workspace.refresh()


@then(parsers.parse('"{name}" exists as a directory'))
def directory_exists(
    grove: GroveDriver, workspace: WorkspaceFixture, name: str
) -> None:
    absolute = workspace.root.joinpath(*PurePath(name).parts)
    grove.wait(
        lambda _frame: None if absolute.is_dir() else f'Grove did not create "{name}"',
    )
    workspace.refresh()


@then(parsers.parse('"{source}" no longer exists and "{destination}" exists'))
def path_was_moved(
    grove: GroveDriver,
    workspace: WorkspaceFixture,
    source: str,
    destination: str,
) -> None:
    source_absolute = workspace.root.joinpath(*PurePath(source).parts)
    destination_absolute = workspace.root.joinpath(*PurePath(destination).parts)
    grove.wait(
        lambda _frame: (
            None
            if not source_absolute.exists() and destination_absolute.exists()
            else f'Grove did not move "{source}" to "{destination}"'
        ),
    )

    workspace.refresh()


@then(parsers.parse('Helix shows the message "{message}"'))
def helix_shows_message(grove: GroveDriver, message: str) -> None:
    _wait_for_bottom_line(grove, message)


@then(parsers.parse('Helix shows the message "{message}" at terminal column 0'))
def helix_shows_message_at_terminal_start(grove: GroveDriver, message: str) -> None:
    _wait_for_bottom_line(grove, message)
    bottom_line = grove.helix.capture().bottom_line
    assert bottom_line.startswith(message), (
        f'Helix did not show "{message}" at terminal column 0: {bottom_line!r}'
    )


@then(parsers.parse('Helix keeps the message "{message}" while idle'))
def helix_keeps_message_while_idle(grove: GroveDriver, message: str) -> None:
    grove.helix.hold(
        lambda frame: (
            None
            if message in frame.bottom_line
            else f'Helix did not keep "{message}" while idle'
        ),
        duration=0.75,
    )


def _wait_for_bottom_line(grove: GroveDriver, text: str) -> None:
    grove.helix.wait(
        lambda frame: (
            None if text in frame.bottom_line else f'Helix did not show "{text}"'
        )
    )


@then(parsers.parse('"{name}" does not exist'))
@then(parsers.parse('"{name}" no longer exists'))
def path_no_longer_exists(
    grove: GroveDriver, workspace: WorkspaceFixture, name: str
) -> None:
    path = PurePath(name)
    absolute = workspace.root.joinpath(*path.parts)
    grove.wait(
        lambda _frame: (
            None if not os.path.lexists(absolute) else f'Grove did not delete "{name}"'
        ),
    )
    workspace.refresh()


@then(parsers.parse('"{name}" still exists'))
def path_still_exists(workspace: WorkspaceFixture, name: str) -> None:
    path = workspace.root.joinpath(*PurePath(name).parts)
    assert os.path.lexists(path)


@then(parsers.parse('the editor contains "{text}"'))
def editor_contains(grove: GroveDriver, text: str) -> None:
    grove.wait(
        lambda frame: (
            None
            if frame.helix.contains(text)
            else f'Helix did not show editor text "{text}"'
        ),
    )
