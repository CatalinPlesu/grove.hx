# Theme Grove

Grove follows the active Helix theme by default. Use `grove-theme` to change
only the parts that need different colors.

## Quick start

Pass Helix theme keys to individual Theme roles:

```scheme
(grove-start!
  #:theme
  (grove-theme
    #:cursor "ui.cursor.primary"
    #:guides-foreground "ui.virtual.whitespace"
    #:git-modified-foreground "warning"))
```

Every role is optional. Omit a role, or set it to `#f`, to use its default.

## Color sources

A string such as `"warning"` names a key from the active Helix theme. The
override changes when you switch themes. Use this form for most overrides.

Pass a Style when you need fixed colors:

```scheme
(require "helix/components.scm")
(require "helix/themes.scm")

(grove-start!
  #:theme
  (grove-theme
    #:cursor
    (style-bg
      (style)
      (string->color "#303446"))

    #:git-modified-foreground
    (style-fg
      (style)
      (string->color "#e5c07b"))))
```

Grove reads only the properties listed in the role table. It ignores modifiers,
underline, and every unlisted property. For example, a background in a Git
foreground role has no effect.

Grove keeps every supplied color. If two roles use the same color, they can look
the same. Choose different theme keys or fixed colors when you need a stronger
distinction.

## Roles

| Role | What it colors | Style properties used | Default | When a property is missing |
| --- | --- | --- | --- | --- |
| `pane-background` | Pane | background | `ui.background` | terminal background |
| `visible-row` | ordinary File tree rows | foreground and background | `ui.text` | terminal foreground; Pane background |
| `pinned-ancestor-row` | Pinned ancestor rows | foreground and background | `ui.virtual.ruler` | matching Visible color |
| `cursor` | Cursor row | foreground and background | `ui.text.focus` | matching Visible color |
| `active-file-background` | Active file row | background | `ui.bufferline.active`, then `ui.statusline.active` | Visible row background |
| `guides-foreground` | Ancestor traces and Leaf marks | foreground | `ui.virtual.indent-guide` | terminal gray |
| `active-file-mark-foreground` | Active file marks | foreground | `info` | matching row foreground |
| `rail` | Rail thumb and track | foreground for thumb, background for track | `ui.menu.scroll` | matching terminal default |
| `filesystem-error-foreground` | Unreadable directory and Broken link icons and labels | foreground | `error` | terminal bright red |
| `git-conflict-foreground` | labels with a conflicting Git status | foreground | `error` | terminal magenta |
| `git-deleted-foreground` | labels with a deleted Git status | foreground | `diff.minus` | terminal red |
| `git-modified-foreground` | labels with a modified Git status | foreground | `diff.delta` | terminal yellow |
| `git-created-foreground` | labels with a created Git status | foreground | `diff.plus` | terminal green |
| `unsaved-mark-foreground` | Unsaved marks | foreground | `info` | terminal cyan |

Helix theme-key lookup can fall back to a broader key. For example,
`ui.menu.scroll` can receive colors from `ui.menu`. Grove uses the colors that
Helix returns.

When `active-file-background` is omitted, Grove takes the first available
background from its two default keys. This means `ui.bufferline.active` can use
`ui.bufferline`, and `ui.statusline.active` can use `ui.statusline`. If none of
them supplies a background, the Active file keeps the Visible row background.
A configured override replaces this default chain.

## Overlap

Row roles apply in this order:

1. Cursor
2. Pinned ancestor row
3. Active file
4. Visible row

Filesystem errors override Git status for the affected label. Git status
overrides the row foreground. Guides and Unsaved marks use their own
foregrounds. Ignored Git status dims only the exact label.

Cursor marks use their row colors. Active file marks use their Theme role
foreground and the row background. Git status does not recolor either mark.

File icons keep their selected palette colors on Visible, Pinned, and Cursor
rows. Git status does not recolor them. A filesystem error can replace the
affected error icon foreground.

## Invalid values

`#:theme` must receive a `grove-theme`. Each role must contain `#f`, a non-empty
theme key, or a Style. Grove reports invalid values during startup.
