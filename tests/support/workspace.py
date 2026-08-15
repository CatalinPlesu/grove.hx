from __future__ import annotations

import os
from collections.abc import Iterable
from dataclasses import dataclass, field
from pathlib import Path, PurePath


@dataclass(frozen=True)
class EntrySpec:
    path: PurePath
    kind: str = "file"
    target: PurePath | None = None
    lines: int = 1

    def __post_init__(self) -> None:
        object.__setattr__(self, "path", _safe_path(str(self.path), "path"))
        if self.target is not None:
            object.__setattr__(self, "target", _optional_path(str(self.target)))


@dataclass
class WorkspaceFixture:
    root: Path
    paths: set[PurePath] = field(default_factory=set)
    directories: set[PurePath] = field(default_factory=set)
    _permissions: dict[Path, int] = field(default_factory=dict, init=False, repr=False)

    @classmethod
    def create(
        cls,
        root: Path,
        entries: Iterable[EntrySpec],
    ) -> WorkspaceFixture:
        entries = tuple(entries)
        directories = {entry.path for entry in entries if entry.kind == "directory"} | {
            parent
            for entry in entries
            for parent in entry.path.parents
            if parent != PurePath(".")
        }
        root.mkdir()

        for entry in entries:
            path = root.joinpath(*entry.path.parts)
            if entry.kind == "directory":
                path.mkdir(parents=True, exist_ok=True)
            elif entry.kind == "file":
                path.parent.mkdir(parents=True, exist_ok=True)
                stem = Path(entry.path.name).stem
                path.write_text(
                    "".join(
                        f"{stem}-{line:03}\n" for line in range(1, entry.lines + 1)
                    ),
                    encoding="utf-8",
                )

        for entry in entries:
            path = root.joinpath(*entry.path.parts)
            if entry.kind in {"file link", "unfollowed directory link", "broken link"}:
                assert entry.target is not None
                path.parent.mkdir(parents=True, exist_ok=True)
                os.symlink(root.joinpath(*entry.target.parts), path)
            elif entry.kind == "fifo":
                path.parent.mkdir(parents=True, exist_ok=True)
                os.mkfifo(path)

        return cls(root, {entry.path for entry in entries} | directories, directories)

    def path(self, name: str) -> Path:
        path = _safe_path(name, "path")
        return self.root.joinpath(*path.parts)

    def document_path(self, name: str) -> Path:
        document = self.path(name)
        if not document.is_file():
            raise AssertionError(f'Workspace document is not a file: "{name}"')
        return document

    def create_file(self, name: str, content: str = "") -> None:
        path = _safe_path(name, "path")
        target = self.root.joinpath(*path.parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        self._remember_directories(path)
        self.paths.add(path)

    def create_link(self, name: str, target: str) -> None:
        path = _safe_path(name, "path")
        link_target = _optional_path(target)
        if link_target is None:
            raise ValueError(f'Workspace link "{name}" needs a target')
        visible = self.root.joinpath(*path.parts)
        visible.parent.mkdir(parents=True, exist_ok=True)
        os.symlink(self.root.joinpath(*link_target.parts), visible)
        self._remember_directories(path)
        self.paths.add(path)

    def numbered_line(self, name: str, line_number: int) -> str:
        return f"{PurePath(name).stem}-{line_number:03}"

    def delete(self, name: str) -> None:
        path = _safe_path(name, "path")
        self.root.joinpath(*path.parts).unlink()

    def rename(self, source: str, destination: str) -> None:
        source_path = _safe_path(source, "source")
        destination_path = _safe_path(destination, "destination")
        target = self.root.joinpath(*destination_path.parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        self.root.joinpath(*source_path.parts).rename(target)
        self.paths.remove(source_path)
        self._remember_directories(destination_path)
        self.paths.add(destination_path)

    def refresh(self) -> None:
        entries = tuple(self.root.rglob("*", recurse_symlinks=False))
        self.paths = {PurePath(entry.relative_to(self.root)) for entry in entries}
        self.directories = {
            PurePath(entry.relative_to(self.root))
            for entry in entries
            if entry.is_dir() and not entry.is_symlink()
        }

    def set_unreadable(self, name: str) -> None:
        path = self.path(name)
        if not path.exists():
            raise AssertionError(f'Workspace entry does not exist: "{name}"')
        self._permissions.setdefault(path, path.stat().st_mode)
        path.chmod(0)

    def set_readable(self, name: str) -> None:
        path = self.root / name
        path.chmod(0o700 if path.is_dir() else 0o600)

    def set_root_unreadable(self) -> None:
        self._permissions.setdefault(self.root, self.root.stat().st_mode)
        self.root.chmod(0o100)

    def close(self) -> None:
        for path, mode in self._permissions.items():
            if path.exists():
                path.chmod(mode)
        self._permissions.clear()

    def _remember_directories(self, path: PurePath) -> None:
        parents = {parent for parent in path.parents if parent != PurePath(".")}
        self.directories.update(parents)
        self.paths.update(parents)


def _optional_path(value: str) -> PurePath | None:
    if not value:
        return None
    path = PurePath(value.replace("\\n", "\n"))
    if path.is_absolute():
        raise ValueError(f"Unsafe Workspace target: {value!r}")
    return path


def _safe_path(value: str, field: str) -> PurePath:
    path = PurePath(value.replace("\\n", "\n"))
    if not value or path.is_absolute() or ".." in path.parts:
        raise ValueError(f"Unsafe Workspace {field}: {value!r}")
    return path
