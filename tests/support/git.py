from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path, PurePath

from .workspace import WorkspaceFixture


@dataclass(frozen=True)
class GitStatusSpec:
    path: str
    status: str
    source: str | None = None


@dataclass(frozen=True)
class GitFixture:
    workspace: WorkspaceFixture

    def report(self, records: list[GitStatusSpec]) -> None:
        for record in records:
            if record.status == "created":
                self.workspace.delete(record.path)
        ignored = [
            f"{record.path}/"
            if PurePath(record.path) in self.workspace.directories
            else record.path
            for record in records
            if record.status == "ignored"
        ]
        if ignored:
            self.workspace.create_file(
                ".gitignore", "".join(f"{name}\n" for name in ignored)
            )
        configuration = (
            ("status.renames", "copies")
            if any(record.status == "copied" for record in records)
            else None
        )
        self.initialize(configuration=configuration)
        conflicts = [record.path for record in records if record.status == "conflict"]
        if conflicts:
            self._create_conflicts(conflicts)
        for record in records:
            self._apply(record)

    def initialize(
        self,
        *paths: str,
        configuration: tuple[str, str] | None = None,
        root: Path | None = None,
    ) -> None:
        root = root or self.workspace.root
        self._git(root, "init", "-q", "-b", "main")
        self._git(root, "config", "user.name", "Grove Test")
        self._git(root, "config", "user.email", "grove@example.invalid")
        if configuration is not None:
            self._git(root, "config", *configuration)
        self._git(root, "add", *(paths or (".",)))
        self._git(root, "commit", "-qm", "base")

    def hide_metadata(self) -> None:
        (self.workspace.root / ".git").rename(
            self.workspace.root.parent / "git-metadata"
        )

    def _create_conflicts(self, paths: list[str]) -> None:
        root = self.workspace.root
        self._git(root, "checkout", "-qb", "other")
        for path in paths:
            self.workspace.create_file(path, "other\n")
        self._git(root, "commit", "-qam", "other")
        self._git(root, "checkout", "-q", "main")
        for path in paths:
            self.workspace.create_file(path, "main\n")
        self._git(root, "commit", "-qam", "main")
        self._git(root, "merge", "other", check=False)

    def _apply(self, record: GitStatusSpec) -> None:
        name, status, source = record.path, record.status, record.source or ""
        if status in {"clean", "ignored", "conflict"}:
            return
        if status == "modified":
            path = self.workspace.path(name)
            if path.is_symlink():
                target = os.readlink(path)
                path.unlink()
                os.symlink(f"{target}.modified", path)
            else:
                with path.open("a", encoding="utf-8") as file:
                    file.write("modified\n")
        elif status == "deleted":
            self.workspace.delete(name)
        elif status == "created":
            self.workspace.create_file(name, "created\n")
        elif status == "renamed":
            self.workspace.rename(source, name)
            self._git(self.workspace.root, "add", source, name)
        elif status == "copied":
            content = self.workspace.path(source).read_text(encoding="utf-8")
            self.workspace.create_file(name, content)
            self.workspace.create_file(source, "changed source\n")
            self._git(self.workspace.root, "add", name, source)
        elif status == "type changed":
            self.workspace.delete(name)
            self.workspace.create_link(name, source)
        else:
            raise ValueError(f"Unsupported Git test status: {status!r}")

    @staticmethod
    def _git(root: Path, *arguments: str, check: bool = True) -> None:
        subprocess.run(
            ["git", "-C", str(root), *arguments],
            check=check,
            capture_output=True,
            text=True,
        )
