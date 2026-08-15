Feature: Theme Grove

  Scenario: Use Cursor colors without source modifiers
    Given a Workspace containing entries
      | path         |
      | active.txt   |
      | modified.txt |
      | plain.txt    |
    And "active.txt" is Active
    And Git reports statuses
      | path         | status   |
      | modified.txt | modified |
    And a Grove theme assigns these sources
      | role                    | source              | foreground | background | modifiers     |
      | cursor                  | Style               | #010203    | #040506    | bold reversed |
      | git-modified-foreground | grove.test.modified |            |            |               |
    When Helix starts with Grove in that Workspace
    And Grove is focused
    Then Cursor uses the configured row colors without source modifiers
    And "modified.txt" uses the configured modified Git foreground
    And "plain.txt" uses the theme text foreground

  Scenario: Follow Helix theme changes for semantic sources
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
    And "anchor.txt" is Active
    And a Grove theme assigns these sources
      | role   | source            |
      | cursor | grove.test.cursor |
    When Helix starts with Grove in that Workspace
    And Grove is focused
    Then Cursor uses that scope from the active Helix theme
    When Helix changes to a theme with different colors for that scope
    And Grove is focused
    Then Cursor uses the new colors

  Scenario Outline: Resolve the Active file background from Helix theme scopes
    Given a Workspace containing entries
      | path       |
      | active.txt |
      | plain.txt  |
    And "active.txt" is Active
    And the Host theme uses Active buffer background "<bufferline>" and Statusline background "#334455"
    When Helix starts with Grove in that Workspace
    Then "active.txt" uses background "<expected>" and the foreground of "plain.txt" without modifiers

    Examples:
      | bufferline | expected |
      | #112233    | #112233  |
      | missing    | #334455  |

  Scenario: Override the Active file background
    Given a Workspace containing entries
      | path       |
      | active.txt |
      | plain.txt  |
    And "active.txt" is Active
    And a Grove theme assigns these sources
      | role                   | source | foreground | background | modifiers     |
      | active-file-background | Style  | #010203    | #040506    | bold reversed |
    When Helix starts with Grove in that Workspace
    Then "active.txt" uses background "#040506" and the foreground of "plain.txt" without modifiers

  Scenario Outline: Choose the icon palette from theme inputs
    Given a Workspace containing entries
      | path       |
      | plain.txt  |
    And "plain.txt" is Active
    And the Host theme uses background "<background>" and text "<text>"
    When Helix starts with Grove in that Workspace
    Then "plain.txt" uses the "<variant>" file icon variant

    Examples:
      | background | text    | variant |
      | default    | default | dark    |
      | #ffffff    | #ffffff | light   |
      | default    | #000000 | light   |

  Scenario: Inherit a missing Cursor foreground from Visible rows
    Given a Workspace containing entries
      | path       |
      | active.txt |
      | plain.txt  |
    And "active.txt" is Active
    And a Grove theme assigns these sources
      | role                        | source           | foreground | background |
      | pane-background             | Style            |            | #ddeeff    |
      | visible-row                 | Style            | #112233    | #ddeeff    |
      | cursor                      | Style            |            | #040506    |
      | active-file-mark-foreground | grove.test.empty |            |            |
    When Helix starts with Grove in that Workspace
    And Grove is focused
    Then "plain.txt" uses the configured Visible row colors
    And Cursor uses the configured background and Visible row foreground
    And the Active file mark uses the configured Visible row foreground

  Scenario: Override the Active file mark foreground
    Given a Workspace containing entries
      | path       |
      | active.txt |
    And "active.txt" is Active
    And a Grove theme assigns these sources
      | role                        | source | foreground | background | modifiers     |
      | active-file-mark-foreground | Style  | #010203    | #040506    | bold reversed |
    When Helix starts with Grove in that Workspace
    Then the Active file mark uses the configured foreground without source background or modifiers

  Scenario: Apply the Guides fallback with an empty source
    Given a Workspace containing entries
      | kind      | path             |
      | file      | anchor.txt       |
      | directory | outer            |
      | file      | outer/inside.txt |
    And "anchor.txt" is Active
    And a Grove theme assigns these sources
      | role              | source           |
      | guides-foreground | grove.test.empty |
    When Helix starts with Grove in that Workspace
    And the "outer" directory is expanded
    Then the Ancestor trace and Leaf mark on "outer/inside.txt" use the terminal gray foreground

  Scenario: Use visible whitespace color for Guides
    Given a Workspace containing entries
      | kind      | path             |
      | file      | anchor.txt       |
      | directory | outer            |
      | file      | outer/inside.txt |
    And "anchor.txt" is Active
    And the Host theme defines ui.virtual.whitespace but not ui.virtual.indent-guide
    When Helix starts with Grove in that Workspace
    And the "outer" directory is expanded
    Then the Ancestor trace and Leaf mark on "outer/inside.txt" use the theme Guides foreground

  Scenario: Apply status fallback colors with empty sources
    Given a Workspace containing entries
      | kind        | path                 | target  |
      | file        | active.txt           |         |
      | file        | conflict.txt         |         |
      | file        | deleted-dir/file.txt |         |
      | file        | modified.txt         |         |
      | file        | created.txt          |         |
      | broken link | broken-link          | missing |
    And "active.txt" is Active
    And Git reports statuses
      | path                 | status   |
      | conflict.txt         | conflict |
      | deleted-dir/file.txt | deleted  |
      | modified.txt         | modified |
      | created.txt          | created  |
    And a Grove theme assigns these sources
      | role                        | source           |
      | filesystem-error-foreground | grove.test.empty |
      | git-conflict-foreground      | grove.test.empty |
      | git-deleted-foreground       | grove.test.empty |
      | git-modified-foreground      | grove.test.empty |
      | git-created-foreground       | grove.test.empty |
      | unsaved-mark-foreground      | grove.test.empty |
    When Helix starts with Grove in that Workspace
    And the editor inserts "dirty-" without saving and returns to Normal mode
    Then these rows use terminal fallback colors
      | row            | marker           | ANSI color |
      | broken-link    | label            | 9          |
      | broken-link    | Broken link icon | 9          |
      | conflict.txt   | label            | 5          |
      | deleted-dir    | label            | 1          |
      | modified.txt   | label            | 3          |
      | created.txt    | label            | 2          |
      | active.txt     | Unsaved mark     | 6          |
      | Workspace root | Unsaved mark     | 6          |

  Scenario: Inherit the Pinned ancestor background
    Given a Workspace containing entries
      | kind | path                             | count |
      | file | alpha/beta/gamma/item-{:02d}.txt | 13    |
      | file | tail-{:02d}.txt                  | 6     |
    And "alpha/beta/gamma/item-00.txt" is Active
    And a Grove theme assigns these sources
      | role                | source           | foreground | background |
      | pane-background     | Style            |            | #ddeeff    |
      | visible-row         | Style            | #112233    | #ddeeff    |
      | pinned-ancestor-row | grove.test.empty |            |            |
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 6 rows
    And Grove is focused
    And Grove receives "Up"
    And the Wheel scrolls down over Grove
    And the Wheel scrolls down over Grove
    Then the Ancestor stack is "Workspace root > alpha > alpha/beta > alpha/beta/gamma" above File tree row "alpha/beta/gamma/item-02.txt"
    And "alpha/beta" uses the configured Visible row colors

  Scenario: Apply Rail terminal defaults with an empty source
    Given a Workspace containing entries
      | kind | path            | count |
      | file | anchor.txt      |       |
      | file | page-{:02d}.txt | 40    |
    And "anchor.txt" is Active
    And a Grove theme assigns these sources
      | role            | source           | foreground | background |
      | pane-background | Style            |            | #ddeeff    |
      | visible-row     | Style            | #112233    | #ddeeff    |
      | rail            | grove.test.empty |            |            |
    When Helix starts with Grove in that Workspace
    Then the Rail track and thumb use terminal default foregrounds

  Scenario Outline: Reject invalid Grove theme configuration
    Given Grove starts with theme configuration <configuration>
    Then Grove startup reports an invalid theme error

    Examples:
      | configuration              |
      | #t                         |
      | (grove-theme #:cursor "") |
      | (grove-theme #:cursor 42)  |
