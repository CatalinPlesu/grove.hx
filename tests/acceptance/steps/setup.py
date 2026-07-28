import json
import os
import subprocess
from pathlib import Path, PurePath

from libtmux.server import Server
from pytest import FixtureRequest
from pytest_bdd import given, parsers, when

from tests.support.host import DEFAULT_STARTUP, TEST_THEME, Helix, start
from tests.support.waiting import eventually
from tests.support.workspace import Workspace


@when(
    "Helix starts with Grove in that Workspace",
    target_fixture="helix",
)
def start_helix(
    tmp_path: Path,
    server: Server,
    request: FixtureRequest,
    workspace: Workspace,
    active_file: Path | None,
) -> Helix:
    return _launch(tmp_path, server, request, workspace, active_file)


@when(
    "Helix starts with Grove with icons disabled",
    target_fixture="helix",
)
def start_helix_with_icons_disabled(
    tmp_path: Path,
    server: Server,
    request: FixtureRequest,
    workspace: Workspace,
    active_file: Path | None,
) -> Helix:
    return _launch(
        tmp_path,
        server,
        request,
        workspace,
        active_file,
        startup="(grove-start! #:icons #f)",
    )


@when(
    parsers.parse(
        'Helix starts with Grove under background "{background}" and text "{text}"'
    ),
    target_fixture="helix",
)
def start_helix_with_theme_inputs(
    tmp_path: Path,
    server: Server,
    request: FixtureRequest,
    workspace: Workspace,
    active_file: Path | None,
    background: str,
    text: str,
) -> Helix:
    return _launch(
        tmp_path,
        server,
        request,
        workspace,
        active_file,
        theme=TEST_THEME
        + f'"ui.background" = {{ bg = "{background}" }}\n'
        + f'"ui.text" = {{ fg = "{text}" }}\n',
    )


@when(
    parsers.parse('Helix starts with Grove on the "{side}" at width {width:d}'),
    target_fixture="helix",
)
def start_configured_helix(
    tmp_path: Path,
    server: Server,
    request: FixtureRequest,
    workspace: Workspace,
    active_file: Path | None,
    side: str,
    width: int,
) -> Helix:
    return _launch(
        tmp_path,
        server,
        request,
        workspace,
        active_file,
        startup=f"(grove-start! #:side '{side} #:width {width})",
    )


@when(
    parsers.parse(
        'Helix starts with Grove on the "{side}" at width {width:d} with icons disabled'
    ),
    target_fixture="helix",
)
def start_configured_helix_with_icons_disabled(
    tmp_path: Path,
    server: Server,
    request: FixtureRequest,
    workspace: Workspace,
    active_file: Path | None,
    side: str,
    width: int,
) -> Helix:
    return _launch(
        tmp_path,
        server,
        request,
        workspace,
        active_file,
        startup=f"(grove-start! #:side '{side} #:width {width} #:icons #f)",
    )


@when(
    parsers.parse('Helix starts with Grove in Workspace "{workspace_name}"'),
    target_fixture="helix",
)
def start_helix_in_named_workspace(
    tmp_path: Path,
    server: Server,
    request: FixtureRequest,
    workspaces: dict[str, Workspace],
    active_file: Path | None,
    workspace_name: str,
) -> Helix:
    return _launch(
        tmp_path,
        server,
        request,
        workspaces[workspace_name],
        active_file,
    )


@when(
    parsers.parse(
        'Helix starts with Grove ready for an Active file change to "{name}"'
    ),
    target_fixture="helix",
)
def start_helix_ready_for_active_file_change(
    tmp_path: Path,
    server: Server,
    request: FixtureRequest,
    workspace: Workspace,
    active_file: Path | None,
    name: str,
) -> Helix:
    target = json.dumps(str(workspace.document_path(name)))
    signal = json.dumps(str(tmp_path / "host-file-change"))
    startup = (
        '(require "helix/misc.scm")\n'
        '(require (prefix-in helix. "helix/commands.scm"))\n'
        "(define (host-file-change-ready?)\n"
        f"  (with-handler (lambda (_) #f) (file-metadata {signal})))\n"
        "(define (await-host-file-change)\n"
        "  (if (host-file-change-ready?)\n"
        f"      (helix.open {target})\n"
        "      (enqueue-thread-local-callback-with-delay\n"
        "       20 await-host-file-change)))\n"
        f"{DEFAULT_STARTUP}\n"
        "(enqueue-thread-local-callback-with-delay\n"
        " 20 await-host-file-change)"
    )
    return _launch(
        tmp_path,
        server,
        request,
        workspace,
        active_file,
        startup=startup,
    )


def _launch(
    tmp_path: Path,
    server: Server,
    request: FixtureRequest,
    workspace: Workspace,
    active_file: Path | None,
    *,
    startup: str = DEFAULT_STARTUP,
    theme: str = TEST_THEME,
) -> Helix:
    helix = start(
        tmp_path / "host",
        server,
        workspace,
        active_file=active_file,
        startup=startup,
        theme=theme,
    )
    request.addfinalizer(helix.close)
    eventually(
        helix,
        lambda screen: (
            None
            if screen.editor_mode == "Normal" and screen.rail is not None
            else "Helix and Grove did not finish startup"
        ),
    )
    return helix


@given(
    "a Workspace containing entries",
    target_fixture="workspace",
)
def workspace_with_entries(tmp_path: Path, datatable: list[list[str]]) -> Workspace:
    return Workspace.create(tmp_path / "workspace", datatable)


@given(parsers.parse('"{name}" is Active'), target_fixture="active_file")
def select_active_file(workspace: Workspace, name: str) -> Path:
    return workspace.document_path(name)


@given("an Active file outside the Workspace", target_fixture="active_file")
def select_active_file_outside_workspace(workspace: Workspace) -> Path:
    outside = workspace.root.parent / "outside.txt"
    outside.write_text("outside\n", encoding="utf-8")
    return outside


@given(parsers.parse('a Workspace named "{name}" containing entries'))
def named_workspace_with_entries(
    tmp_path: Path,
    workspaces: dict[str, Workspace],
    name: str,
    datatable: list[list[str]],
) -> None:
    workspaces[name] = Workspace.create(tmp_path / name, datatable)


@given(
    parsers.parse('"{name}" is Active in Workspace "{workspace_name}"'),
    target_fixture="active_file",
)
def select_named_active_file(
    workspaces: dict[str, Workspace],
    workspace_name: str,
    name: str,
) -> Path:
    return workspaces[workspace_name].document_path(name)


@given(parsers.parse('Git tracks "{name}" as {status} in Workspace "{workspace_name}"'))
def named_workspace_git_status(
    workspaces: dict[str, Workspace],
    workspace_name: str,
    name: str,
    status: str,
) -> None:
    workspace = workspaces[workspace_name]
    if status not in {"clean", "modified"}:
        raise ValueError(f"Unsupported Git test status: {status!r}")
    _report_git_statuses(workspace, [(name, status, "")])


@given(parsers.parse('"{name}" is unreadable'))
@when(parsers.parse('"{name}" becomes unreadable'))
def make_entry_unreadable(
    workspace: Workspace,
    request: FixtureRequest,
    name: str,
) -> None:
    workspace.set_unreadable(name)
    request.addfinalizer(lambda: workspace.set_readable(name))


@when(parsers.parse('"{name}" is created'))
def create_workspace_file(workspace: Workspace, name: str) -> None:
    workspace.create_file(name)


@when(parsers.parse('"{name}" is deleted'))
def delete_workspace_file(workspace: Workspace, name: str) -> None:
    workspace.delete(name)


@when("the external link target appears")
def create_external_link_target(workspace: Workspace) -> None:
    workspace.create_external_target()


@when(parsers.parse('"{name}" becomes readable'))
def entry_becomes_readable(workspace: Workspace, name: str) -> None:
    workspace.set_readable(name)


@given("Git reports statuses")
def git_reports_statuses(
    workspace: Workspace,
    datatable: list[list[str]],
) -> None:
    _report_git_statuses(workspace, _git_status_records(datatable))


def _report_git_statuses(
    workspace: Workspace,
    records: list[tuple[str, str, str]],
) -> None:
    for name, status, _source in records:
        if status == "created":
            workspace.delete(name)

    ignored = [
        f"{name}/" if PurePath(name) in workspace.directories else name
        for name, status, _source in records
        if status == "ignored"
    ]
    if ignored:
        workspace.create_file(".gitignore", "".join(f"{name}\n" for name in ignored))

    configuration = (
        ("status.renames", "copies")
        if any(status == "copied" for _name, status, _source in records)
        else None
    )
    _initialize_git(workspace.root, configuration=configuration)

    conflicts = [name for name, status, _source in records if status == "conflict"]
    if conflicts:
        _create_git_conflicts(workspace, conflicts)

    for name, status, source in records:
        _apply_git_status(workspace, name, status, source)


def _git_status_records(
    table: list[list[str]],
) -> list[tuple[str, str, str]]:
    if not table or table[0] not in (
        ["path", "status"],
        ["path", "status", "source"],
    ):
        raise ValueError("Git status table needs path and status columns")
    if any(len(row) != len(table[0]) for row in table[1:]):
        raise ValueError("Git status table rows must match the header")
    if len(table) < 2:
        raise ValueError("Git status table needs at least one path")

    records = [(row[0], row[1], row[2] if len(row) == 3 else "") for row in table[1:]]
    allowed = {
        "clean",
        "modified",
        "deleted",
        "created",
        "ignored",
        "conflict",
        "renamed",
        "copied",
        "type changed",
    }
    sourced = {"renamed", "copied", "type changed"}
    for name, status, source in records:
        if status not in allowed:
            raise ValueError(f"Unsupported Git test status: {status!r}")
        if (status in sourced) != bool(source):
            raise ValueError(
                f'Git status "{status}" has an invalid source for "{name}"'
            )
    return records


def _create_git_conflicts(workspace: Workspace, paths: list[str]) -> None:
    _git(workspace.root, "checkout", "-qb", "other")
    for path in paths:
        workspace.create_file(path, "other\n")
    _git(workspace.root, "commit", "-qam", "other")
    _git(workspace.root, "checkout", "-q", "main")
    for path in paths:
        workspace.create_file(path, "main\n")
    _git(workspace.root, "commit", "-qam", "main")
    _git(workspace.root, "merge", "other", check=False)


def _apply_git_status(
    workspace: Workspace,
    name: str,
    status: str,
    source: str,
) -> None:
    if status in {"clean", "ignored", "conflict"}:
        return
    if status == "modified":
        path = workspace.root.joinpath(*PurePath(name).parts)
        if path.is_symlink():
            target = os.readlink(path)
            path.unlink()
            os.symlink(f"{target}.modified", path)
        else:
            with path.open("a", encoding="utf-8") as file:
                file.write("modified\n")
    elif status == "deleted":
        workspace.delete(name)
    elif status == "created":
        workspace.create_file(name, "created\n")
    elif status == "renamed":
        workspace.rename(source, name)
        _git(workspace.root, "add", source, name)
    elif status == "copied":
        content = (workspace.root / source).read_text(encoding="utf-8")
        workspace.create_file(name, content)
        workspace.create_file(source, "changed source\n")
        _git(workspace.root, "add", name, source)
    elif status == "type changed":
        workspace.delete(name)
        workspace.create_link(name, source)


@given(parsers.parse('Git tracks "{name}"'))
def git_tracks_path(workspace: Workspace, name: str) -> None:
    _initialize_git(workspace.root, name)


@given(parsers.parse('"{name}" is a Git repository'))
def directory_is_git_repository(workspace: Workspace, name: str) -> None:
    root = workspace.root / name
    if not root.is_dir():
        raise ValueError(f'Git repository directory does not exist: "{name}"')
    _initialize_git(root)


@when("the Workspace root becomes unreadable")
def workspace_root_becomes_unreadable(
    workspace: Workspace,
    request: FixtureRequest,
) -> None:
    workspace.set_root_unreadable()
    request.addfinalizer(workspace.set_root_readable)


@when("Git metadata becomes unavailable")
def git_metadata_becomes_unavailable(workspace: Workspace) -> None:
    (workspace.root / ".git").rename(workspace.root.parent / "git-metadata")


def _initialize_git(
    root: Path,
    *paths: str,
    configuration: tuple[str, str] | None = None,
) -> None:
    _git(root, "init", "-q", "-b", "main")
    _git(root, "config", "user.name", "Grove Test")
    _git(root, "config", "user.email", "grove@example.invalid")
    if configuration is not None:
        _git(root, "config", *configuration)
    _git(root, "add", *(paths or (".",)))
    _git(root, "commit", "-qm", "base")


def _git(
    root: Path,
    *arguments: str,
    check: bool = True,
) -> None:
    subprocess.run(
        ["git", "-C", str(root), *arguments],
        check=check,
        capture_output=True,
        text=True,
    )
