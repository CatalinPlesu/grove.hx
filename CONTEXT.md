# Grove

## Language

**Workspace**:
Grove's current filesystem knowledge of the Workspace selected from Helix's
current working directory: its root identity and current File tree. It owns
filesystem truth only. Git state and Grove interaction are owned separately.
_Avoid_: Project, Tree model, provider state, project pane

**Model**:
Grove's one authoritative semantic state at an instant. It stores Workspace,
Git status, unsaved-buffer observation, and Grove interaction state. It exposes
semantic Visible rows ready for presentation as a pure projection of those
facts. Presentation geometry and adapter state are not part of it.
_Avoid_: Application state, pane model, presentation model

**Active file**:
The Workspace file in Helix's active editor split. Only Host Context observation
changes it; an open command never predicts it. Grove reveals and highlights it.
A present Unsaved mark preserves that emphasis.
Normal activation of this row only returns control to Helix, preserving its
cursor and scroll. Split activation still opens the requested split.
_Avoid_: Cursor, selected row

**Editor view**:
One Helix editor split. Its rendered document, cursor, and viewport are Host
Context that Grove may observe but does not own.
_Avoid_: Pane, Active file, Grove view

**Cursor**:
The Grove tree row targeted by keyboard navigation and row actions. It exists
only while Grove is focused, begins on the Active file when possible, and
otherwise begins on the Workspace root. It disappears after file activation,
Escape, an outside click, or the first key Grove does not bind. An unbound key
is passed to Helix after Cursor disappears. A present Unsaved mark preserves
Cursor emphasis. A refreshed File tree keeps the Cursor on the same row when it
survives and resets it to the Workspace root when it does not.
_Avoid_: Active file, current file

**Workspace session**:
The expansion, optional Cursor, and viewport intent retained for the current
Workspace. Changing Helix's current directory replaces the session when it
changes the Workspace root. Grove width is retained independently across roots.
_Avoid_: Interaction state, persisted settings

**Viewport intent**:
Whether the viewport follows the Cursor or stays anchored after direct
scrolling. Direct scrolling never moves the Cursor. Active file observation may
reveal a row without creating or moving the Cursor.
_Avoid_: Numeric viewport offset, Cursor

**Pane**:
Grove's visible docked region: File tree rows plus the permanent Rail. It is
presentation geometry, not a state owner or a separate Helix pane.
_Avoid_: Runtime pane, pane model, interaction state

**Rail**:
The permanent editor-facing column of Grove. Its track separates Grove from the
editor, its optional thumb represents the viewport, and horizontal dragging
resizes Grove.
_Avoid_: Separator, scrollbar column

**File tree**:
One immutable ordered filesystem hierarchy containing the entries currently
known to Grove. Its Workspace root is separate identity; collapsed directories
remain present without their contents.
_Avoid_: Tree state, session

**Unreadable directory**:
A directory present in the File tree whose contents Grove could not read. It
remains expandable and has a distinct error presentation. An Unreadable
Workspace root has the same failure presentation but cannot expand.
_Avoid_: Failed entry, unavailable subtree, inert directory

**Unfollowed directory link**:
A symbolic link whose target is a directory. Grove deliberately does not
traverse it. It remains visible but cannot expand.
_Avoid_: Symlink folder, inert directory, broken directory

**File link**:
A symbolic link whose target is a regular file. Grove opens it like a regular
file.
_Avoid_: Symlink file, linked entry

**Broken link**:
A symbolic link whose target is missing, unreadable, or unsupported. Grove
keeps it visible but inert, with a distinct error presentation.
_Avoid_: Inert symlink, unknown entry

**Git status**:
Grove's latest optional Git state for paths in the current Workspace. File names
use the status foreground directly. Directory names use the strongest status
beneath their path, including collapsed descendants, in this order: conflict,
deleted, modified, created. Ignored status dims only the exact entry label. Git
status never controls the File tree or recolors entry icons and Unsaved marks.
Cursor and Active file styling keep the Git foreground while applying their own
background and modifiers. Git status is scoped to the Workspace.
_Avoid_: Git overlay, Git snapshot, Git truth, Git mark

**Unsaved status**:
The distinction between a file with unsaved edits (`unsaved`) and a directory
or Workspace root containing such a file (`unsaved-ancestor`). Files outside
the current Workspace give neither status.
_Avoid_: Dirty flag, Buffer status

**Unsaved mark**:
The single trailing `●` presenting either Unsaved status. It appears on
collapsed directories and the Workspace root, and never becomes a count.
_Avoid_: Buffer overlay, Buffer mark, dirty count

**Visible row**:
One semantic filesystem entry in the current File tree. Its stable identity
drives navigation, while ordinary non-root rows also expose a path for pointer
actions.
_Avoid_: Rendered line, row index

**Pinned ancestor row**:
The presentation of an expanded ancestor directory held above scrolling Visible
rows to keep the current hierarchy legible.
_Avoid_: Sticky row, pinned folder, folder header

**Ancestor stack**:
The outermost ordered prefix of Pinned ancestor rows shown above scrolling File
tree content.
_Avoid_: Folder stacking, sticky headers, breadcrumb
