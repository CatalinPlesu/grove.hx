from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from functools import cached_property
from pathlib import PurePath

from rich.console import Console
from rich.style import Style
from rich.text import Text

Rgb = tuple[int, int, int]
RAIL_GLYPHS = frozenset("▕▐▏▌")
LEFT_RAIL_GLYPHS = frozenset("▕▐")
RIGHT_RAIL_GLYPHS = frozenset("▏▌")
ANSI_CONSOLE = Console(color_system="truecolor")
MODES = {"GNR": "Normal", "GIN": "Insert", "GSE": "Select"}


class IncompleteScreen(Exception):
    def __init__(self, lines: tuple[str, ...]):
        self.lines = lines
        super().__init__("Incomplete terminal frame:\n" + "\n".join(lines))


@dataclass(frozen=True)
class EditorView:
    status: str
    lines: tuple[str, ...]

    @property
    def document(self) -> str:
        document, separator, _rest = self.status.partition("¦")
        if not separator or not document.strip():
            raise AssertionError(f"Malformed test statusline: {self.status!r}")
        return document.strip()

    @property
    def mode(self) -> str | None:
        modes = [
            name for token, name in MODES.items() if _status_token(self.status, token)
        ]
        if len(modes) > 1:
            raise AssertionError(f"Ambiguous Helix mode: {self.status!r}")
        return modes[0] if modes else None

    @property
    def cursor(self) -> tuple[int, int] | None:
        match = re.search(r"(\d+):(\d+)\s*$", self.status)
        return (int(match.group(1)), int(match.group(2))) if match else None

    @property
    def first_visible_line(self) -> str | None:
        return self.lines[0] if self.lines else None


@dataclass(frozen=True)
class _StatusSegment:
    row: int
    start: int
    end: int
    text: str


@dataclass(frozen=True)
class Row:
    number: int
    text: str
    path: PurePath
    label: str
    ansi: Text

    def has_icon(self, icon: str) -> bool:
        return icon in self.text[: self.label_column()]

    def label_column(self) -> int:
        column = _label_start(self.text, self.label)
        if column is None:
            raise AssertionError(f'Row has no label "{self.label}": {self.text!r}')
        return column

    def foreground_before(self, marker: str) -> Rgb | None:
        if marker != self.label and marker not in self.text:
            return None
        return _rgb(self.style_before(marker).color)

    def background_before(self, marker: str) -> Rgb | None:
        if marker != self.label and marker not in self.text:
            return None
        return _rgb(self.style_before(marker).bgcolor)

    def is_dimmed_before(self, marker: str) -> bool:
        return self.style_before(marker).dim

    def style_before(self, marker: str) -> Style:
        offset = self.label_column() if marker == self.label else self.text.find(marker)
        if offset < 0:
            raise AssertionError(f'Row has no marker "{marker}": {self.text!r}')
        return self.ansi.get_style_at_offset(ANSI_CONSOLE, offset)

    @property
    def disclosure(self) -> str | None:
        return next((glyph for glyph in "▸▾" if glyph in self.text), None)

    @property
    def mark(self) -> str | None:
        return "●" if self.text.endswith((" ●", "…●")) else None

    @property
    def is_expandable(self) -> bool:
        return self.disclosure is not None


@dataclass(frozen=True)
class Screen:
    lines: tuple[str, ...]
    styled_lines: tuple[str, ...]
    rail: int | None
    grove_before_rail: bool
    paths: frozenset[PurePath]
    directories: frozenset[PurePath]
    workspace_name: str | None

    @classmethod
    def parse(
        cls,
        styled_lines: list[str] | tuple[str, ...],
        *,
        paths: set[PurePath] | frozenset[PurePath] = frozenset(),
        directories: set[PurePath] | frozenset[PurePath] = frozenset(),
        workspace_name: str | None = None,
    ) -> Screen:
        styled = tuple(styled_lines)
        lines = tuple(Text.from_ansi(line).plain for line in styled)
        rail, grove_before = _layout(lines)
        return cls(
            lines,
            styled,
            rail,
            grove_before,
            frozenset(paths),
            frozenset(directories),
            workspace_name,
        )

    def row(self, identity: str) -> Row | None:
        path = PurePath(identity.replace("\\n", "\n"))
        if identity == self.workspace_name:
            if path in self.paths:
                raise AssertionError(
                    f'Screen has ambiguous identity "{identity}" for the '
                    "Workspace root and a filesystem path"
                )
            return self.workspace_root
        if path in self.paths:
            matches = [row for row in self._rows if row.path == path]
        else:
            matches = [row for row in self._rows if row.label == identity]
        if len(matches) > 1:
            raise AssertionError(f'Grove has multiple rows named "{identity}"')
        return matches[0] if matches else None

    @property
    def workspace_root(self) -> Row | None:
        lines = self._grove_lines()
        if self.workspace_name is None or not lines:
            return None
        text = lines[0].rstrip()
        if _label_start(text, self.workspace_name) is None:
            return None
        return Row(
            1, text, PurePath("."), self.workspace_name, self._styled_grove_line(1)
        )

    @property
    def grove_row_styles(self) -> tuple[tuple[PurePath, Style], ...]:
        root = (root,) if (root := self.workspace_root) else ()
        return tuple(
            (row.path, row.style_before(row.label)) for row in root + self._rows
        )

    @property
    def side(self) -> str | None:
        if self.rail is None:
            return None
        return "left" if self.grove_before_rail else "right"

    def pane_width(self, side: str, terminal_width: int) -> int | None:
        if self.rail is None or side != self.side:
            return None
        return self.rail + 1 if side == "left" else terminal_width - self.rail

    @property
    def rail_thumb(self) -> tuple[int, int] | None:
        if self.rail is None:
            return None
        return next(
            (
                (self.rail + 1, row)
                for row, line in enumerate(self.lines, start=1)
                if line[self.rail] in "▐▌"
            ),
            None,
        )

    def rail_track(self, direction: str) -> tuple[int, int] | None:
        if self.rail is None:
            return None
        thumb_rows = [
            row
            for row, line in enumerate(self.lines, start=1)
            if line[self.rail] in "▐▌"
        ]
        if not thumb_rows:
            return None
        rows = (
            range(min(thumb_rows) - 1, 0, -1)
            if direction == "above"
            else range(max(thumb_rows) + 1, len(self.lines) + 1)
        )
        return next(
            (
                (self.rail + 1, row)
                for row in rows
                if self.lines[row - 1][self.rail] in "▕▏"
            ),
            None,
        )

    @property
    def blank_grove_row(self) -> int | None:
        return next(
            (
                number
                for number, line in enumerate(self._grove_lines(), start=1)
                if not line.strip()
            ),
            None,
        )

    def grove_row_text(self, number: int) -> str:
        return self._grove_lines()[number - 1].rstrip()

    @cached_property
    def editor_views(self) -> tuple[EditorView, ...]:
        return _decode_editor_views(self._editor_lines())

    @property
    def active_editor_view(self) -> EditorView | None:
        active = tuple(view for view in self.editor_views if view.mode is not None)
        if len(active) > 1:
            raise AssertionError("Helix rendered multiple active Editor views")
        return active[0] if active else None

    @property
    def editor_view_count(self) -> int:
        return len(self.editor_views)

    def editor_view(self, document: str) -> EditorView | None:
        matches = tuple(view for view in self.editor_views if view.document == document)
        if len(matches) > 1:
            raise AssertionError(
                f'Helix rendered multiple views for document "{document}"'
            )
        return matches[0] if matches else None

    @property
    def editor_mode(self) -> str | None:
        view = self.active_editor_view
        return view.mode if view else None

    @property
    def document(self) -> str | None:
        view = self.active_editor_view
        return view.document if view else None

    def editor_contains(self, text: str) -> bool:
        return any(text in line for line in self._editor_lines())

    def _grove_lines(self) -> tuple[str, ...]:
        if self.rail is None:
            return ()
        if self.grove_before_rail:
            return tuple(line[: self.rail] for line in self.lines)
        return tuple(line[self.rail + 1 :] for line in self.lines)

    @cached_property
    def _rows(self) -> tuple[Row, ...]:
        labels = {_display_label(path.name) for path in self.paths}
        rows = []
        parents: list[tuple[int, PurePath]] = []
        for number, text in enumerate(self._grove_lines(), start=1):
            match = _matched_label(text.rstrip(), labels)
            if match is None:
                continue
            label, column = match
            while parents and parents[-1][0] >= column:
                parents.pop()
            parent = parents[-1][1] if parents else PurePath(".")
            candidates = [
                path
                for path in self.paths
                if path.parent == parent and _display_label(path.name) == label
            ]
            if not candidates:
                candidates = [
                    path for path in self.paths if _display_label(path.name) == label
                ]
            if len(candidates) > 1:
                raise AssertionError(
                    f"Screen row has ambiguous filesystem identity: {text!r}"
                )
            if not candidates:
                continue
            path = candidates[0]
            rows.append(
                Row(
                    number,
                    text.rstrip(),
                    path,
                    label,
                    self._styled_grove_line(number),
                )
            )
            if path in self.directories:
                parents.append((column, path))
        return tuple(rows)

    def _styled_grove_line(self, number: int) -> Text:
        styled = Text.from_ansi(self.styled_lines[number - 1])
        if self.rail is None:
            return styled
        if self.grove_before_rail:
            return styled[: self.rail]
        return styled[self.rail + 1 :]

    def _editor_lines(self) -> tuple[str, ...]:
        if self.rail is None:
            return self.lines
        if self.grove_before_rail:
            return tuple(line[self.rail + 1 :] for line in self.lines)
        return tuple(line[: self.rail] for line in self.lines)


def _layout(lines: tuple[str, ...]) -> tuple[int | None, bool]:
    positions = [
        {index for index, character in enumerate(line) if character in RAIL_GLYPHS}
        for line in lines
    ]
    if not positions or all(not row for row in positions):
        return None, True
    if any(not row for row in positions):
        counts = {
            column: sum(column in row for row in positions)
            for column in set().union(*positions)
        }
        if counts and max(counts.values()) >= max(2, len(lines) - 1):
            raise IncompleteScreen(lines)
        return None, True
    layouts = []
    for column in set.intersection(*positions):
        glyphs = {line[column] for line in lines}
        if glyphs <= LEFT_RAIL_GLYPHS:
            layouts.append((column, True))
        elif glyphs <= RIGHT_RAIL_GLYPHS:
            layouts.append((column, False))
    if len(layouts) != 1:
        raise AssertionError("Screen has no unique Grove Rail")
    return layouts[0]


def _matched_label(row: str, names: set[str]) -> tuple[str, int] | None:
    matches = []
    for name in names:
        column = _label_start(row, name)
        if column is not None:
            matches.append((name, column))
    if not matches:
        return None
    if len(matches) > 1:
        raise AssertionError(f"Screen row has ambiguous identity: {row!r}")
    return matches[0]


def _label_start(row: str, label: str) -> int | None:
    literal = row.rstrip()
    texts = [
        literal,
        literal.removesuffix(" ●").rstrip(),
        literal.removesuffix("●").rstrip(),
    ]
    exact = next(
        (len(text) - len(label) for text in texts if _has_label(text, label)),
        None,
    )
    if exact is not None:
        return exact
    return _clipped_label_start(texts, label)


def _clipped_label_start(texts: list[str], label: str) -> int | None:
    for length in range(len(label) - 1, 0, -1):
        clipped = f"{label[:length]}…"
        match = next(
            (len(text) - len(clipped) for text in texts if _has_label(text, clipped)),
            None,
        )
        if match is not None:
            return match
    return None


def _has_label(text: str, label: str) -> bool:
    if not text.endswith(label):
        return False
    start = len(text) - len(label)
    if start and not text[start - 1].isspace():
        return False
    prefix = text[:start]
    return all(
        character.isspace()
        or character in "▸▾│·"
        or unicodedata.category(character) in {"Co", "So"}
        for character in prefix
    )


def _display_label(label: str) -> str:
    return "".join(
        "?" if unicodedata.category(character) == "Cc" else character
        for character in label
    )


def _decode_editor_views(lines: tuple[str, ...]) -> tuple[EditorView, ...]:
    segments = tuple(_status_segments(lines))
    return tuple(
        EditorView(
            segment.text,
            tuple(
                line[segment.start : segment.end].rstrip()
                for line in lines[_content_start(segment, segments) : segment.row]
            ),
        )
        for segment in segments
    )


def _status_token(text: str, token: str) -> bool:
    return re.search(rf"(?:^|\s|¦){token}(?=\s|¦|$)", text) is not None


def _is_status(line: str) -> bool:
    document, separator, rest = line.partition("¦")
    if not separator:
        return False
    has_selection = re.match(r"\d+\s+sel(?:\s|$)", rest.strip()) is not None
    has_coordinates = re.search(r"\d+:\d+\s*$", line) is not None
    has_mode = any(_status_token(line, mode) for mode in MODES)
    return bool(document.strip()) and has_coordinates and (has_selection or has_mode)


def _status_segments(lines: tuple[str, ...]):
    for row, line in enumerate(lines):
        for match in re.finditer(r"[^│]+", line):
            status = match.group().strip()
            if _is_status(status):
                start, end = match.span()
                yield _StatusSegment(row, start, end, status)


def _content_start(
    segment: _StatusSegment,
    segments: tuple[_StatusSegment, ...],
) -> int:
    previous_rows = [
        candidate.row
        for candidate in segments
        if candidate.row < segment.row and candidate.start == segment.start
    ]
    return max(previous_rows, default=-1) + 1


def _rgb(color) -> Rgb | None:
    if color is None:
        return None
    triplet = color.get_truecolor()
    return triplet.red, triplet.green, triplet.blue
