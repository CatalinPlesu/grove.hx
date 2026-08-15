from pathlib import Path, PurePath

import pytest

from tests.support.workspace import EntrySpec, WorkspaceFixture


def test_unsafe_workspace_path_is_rejected_before_io(tmp_path: Path) -> None:
    root = tmp_path / "workspace"

    with pytest.raises(ValueError):
        WorkspaceFixture.create(root, [EntrySpec(path=PurePath("../outside.txt"))])

    assert not root.exists()


def test_created_file_records_its_path_and_implicit_directories(
    tmp_path: Path,
) -> None:
    workspace = WorkspaceFixture.create(
        tmp_path / "workspace",
        [EntrySpec(PurePath("anchor.txt"))],
    )

    workspace.create_file("outer/inner/created.txt")

    assert workspace.paths == {
        PurePath("anchor.txt"),
        PurePath("outer"),
        PurePath("outer/inner"),
        PurePath("outer/inner/created.txt"),
    }
    assert workspace.directories == {
        PurePath("outer"),
        PurePath("outer/inner"),
    }


def test_deleted_path_remains_known(tmp_path: Path) -> None:
    workspace = WorkspaceFixture.create(
        tmp_path / "workspace",
        [EntrySpec(PurePath("target.txt"))],
    )

    workspace.delete("target.txt")

    assert PurePath("target.txt") in workspace.paths
    assert not (workspace.root / "target.txt").exists()


def test_created_link_records_its_visible_path(tmp_path: Path) -> None:
    workspace = WorkspaceFixture.create(
        tmp_path / "workspace",
        [EntrySpec(PurePath("target.txt"))],
    )

    workspace.create_link("links/visible.txt", "target.txt")

    visible = workspace.root / "links/visible.txt"
    assert visible.is_symlink()
    assert visible.read_text() == "target-001\n"
    assert workspace.paths == {
        PurePath("target.txt"),
        PurePath("links"),
        PurePath("links/visible.txt"),
    }
    assert workspace.directories == {PurePath("links")}


def test_renamed_file_updates_its_known_path(tmp_path: Path) -> None:
    workspace = WorkspaceFixture.create(
        tmp_path / "workspace",
        [EntrySpec(PurePath("source.txt"))],
    )

    workspace.rename("source.txt", "nested/destination.txt")

    assert not (workspace.root / "source.txt").exists()
    assert (workspace.root / "nested/destination.txt").read_text() == "source-001\n"
    assert workspace.paths == {
        PurePath("nested"),
        PurePath("nested/destination.txt"),
    }
    assert workspace.directories == {PurePath("nested")}


def test_refresh_rebuilds_paths_without_following_directory_links(
    tmp_path: Path,
) -> None:
    workspace = WorkspaceFixture.create(
        tmp_path / "workspace",
        [
            EntrySpec(PurePath("target"), kind="directory"),
            EntrySpec(PurePath("target/inside.txt")),
            EntrySpec(
                PurePath("visible"),
                kind="unfollowed directory link",
                target=PurePath("target"),
            ),
        ],
    )
    workspace.paths.clear()
    workspace.directories.clear()

    workspace.refresh()

    assert workspace.paths == {
        PurePath("target"),
        PurePath("target/inside.txt"),
        PurePath("visible"),
    }
    assert workspace.directories == {PurePath("target")}
