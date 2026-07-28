from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path, PurePath


@dataclass(frozen=True)
class Entry:
    kind: str
    path: PurePath
    target: PurePath | None
    lines: int


@dataclass
class Workspace:
    root: Path
    paths: set[PurePath] = field(default_factory=set)
    directories: set[PurePath] = field(default_factory=set)

    @classmethod
    def create(cls, root: Path, table: list[list[str]]) -> Workspace:
        entries = _entries(table)
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

    def document_path(self, name: str) -> Path:
        path = _safe_path(name, "path")
        document = self.root.joinpath(*path.parts)
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

    def set_unreadable(self, name: str) -> None:
        path = self.root / name
        if not path.exists():
            raise AssertionError(f'Workspace entry does not exist: "{name}"')
        path.chmod(0)

    def set_readable(self, name: str) -> None:
        path = self.root / name
        path.chmod(0o700 if path.is_dir() else 0o600)

    def create_external_target(self) -> None:
        target = self.root.parent / "outside" / "target.txt"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("target\n", encoding="utf-8")

    def set_root_unreadable(self) -> None:
        self.root.chmod(0o100)

    def set_root_readable(self) -> None:
        self.root.chmod(0o700)

    def _remember_directories(self, path: PurePath) -> None:
        parents = {parent for parent in path.parents if parent != PurePath(".")}
        self.directories.update(parents)
        self.paths.update(parents)


def _entries(table: list[list[str]]) -> tuple[Entry, ...]:
    if len(table) < 2:
        raise ValueError("Workspace table needs a header and at least one entry")
    header = table[0]
    if len(header) != len(set(header)):
        raise ValueError("Workspace table has duplicate columns")
    if any(len(row) != len(header) for row in table[1:]):
        raise ValueError("Workspace table rows must match the header")
    if header == ["path"]:
        records = [{"path": row[0], "kind": "file"} for row in table[1:]]
    else:
        expected = {"kind", "path"}
        if not expected <= set(header):
            raise ValueError("Workspace table needs kind and path columns")
        allowed = expected | {"target", "lines", "count"}
        if not set(header) <= allowed:
            raise ValueError("Workspace table has unknown columns")
        records = [dict(zip(header, row, strict=True)) for row in table[1:]]

    result: list[Entry] = []
    for record in records:
        count = _positive(record.get("count") or "1", "count")
        template = record["path"]
        if count > 1 and "{" not in template:
            raise ValueError("Counted paths need a format field")
        for index in range(count):
            path = template.format(index) if count > 1 else template
            result.append(
                Entry(
                    kind=_kind(record["kind"]),
                    path=_safe_path(path, "path"),
                    target=_optional_path(record.get("target") or ""),
                    lines=_positive(record.get("lines") or "1", "lines"),
                )
            )

    paths = [entry.path for entry in result]
    if len(paths) != len(set(paths)):
        raise ValueError("Workspace table has duplicate paths")
    _validate_links(result)
    _validate_hierarchy(result)
    return tuple(result)


def _kind(value: str) -> str:
    allowed = {
        "file",
        "directory",
        "file link",
        "unfollowed directory link",
        "broken link",
        "fifo",
    }
    if value not in allowed:
        raise ValueError(f"Unknown Workspace entry kind: {value!r}")
    return value


def _validate_links(entries: list[Entry]) -> None:
    links = {"file link", "unfollowed directory link", "broken link"}
    for entry in entries:
        if entry.kind in links and entry.target is None:
            raise ValueError(f'Workspace link "{entry.path}" needs a target')
        if entry.kind not in links and entry.target is not None:
            raise ValueError(f'Workspace entry "{entry.path}" cannot have a target')


def _validate_hierarchy(entries: list[Entry]) -> None:
    kinds = {entry.path: entry.kind for entry in entries}
    for entry in entries:
        for parent in entry.path.parents:
            if parent == PurePath("."):
                continue
            if (kind := kinds.get(parent)) is not None and kind != "directory":
                raise ValueError(
                    f'Workspace entry "{parent}" cannot contain "{entry.path}"'
                )


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


def _positive(value: str, field: str) -> int:
    try:
        number = int(value)
    except ValueError as error:
        raise ValueError(f"Workspace {field} must be an integer") from error
    if number < 1:
        raise ValueError(f"Workspace {field} must be positive")
    return number
