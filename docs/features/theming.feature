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
      | role                    | source           |
      | cursor                  | native row Style |
      | git-modified-foreground | semantic scope   |
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
      | role   | source                |
      | cursor | cursor semantic scope |
    When Helix starts with Grove in that Workspace
    And Grove is focused
    Then Cursor uses that scope from the active Helix theme
    When Helix changes to a theme with different colors for that scope
    And Grove is focused
    Then Cursor uses the new colors

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
      | role                        | source                        |
      | pane-background             | fixed Pane Style              |
      | visible-row                 | fixed Visible row Style       |
      | cursor                      | fixed Cursor background Style |
      | active-file-mark-foreground | empty scope                   |
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
      | role                        | source                        |
      | active-file-mark-foreground | native row Style              |
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
      | role              | source      |
      | guides-foreground | empty scope |
    When Helix starts with Grove in that Workspace
    And the "outer" directory is expanded
    Then the Ancestor trace and Leaf mark on "inside.txt" use the terminal gray foreground

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
      | role                        | source      |
      | filesystem-error-foreground | empty scope |
      | git-conflict-foreground      | empty scope |
      | git-deleted-foreground       | empty scope |
      | git-modified-foreground      | empty scope |
      | git-created-foreground       | empty scope |
      | unsaved-mark-foreground      | empty scope |
    When Helix starts with Grove in that Workspace
    And the editor inserts "dirty-" without saving
    Then Grove uses terminal fallback colors for status presentation

  Scenario: Inherit the Pinned ancestor background
    Given a Workspace containing entries
      | kind | path                             | count |
      | file | alpha/beta/gamma/item-{:02d}.txt | 13    |
      | file | tail-{:02d}.txt                  | 6     |
    And "alpha/beta/gamma/item-00.txt" is Active
    And a Grove theme assigns these sources
      | role                | source                  |
      | pane-background     | fixed Pane Style        |
      | visible-row         | fixed Visible row Style |
      | pinned-ancestor-row | empty scope             |
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 6 rows
    And Grove is focused
    And Grove receives "Up"
    And the Wheel scrolls down over Grove
    And the Wheel scrolls down over Grove
    Then the Ancestor stack is "workspace > alpha > beta > gamma" above File tree row "item-02.txt"
    And "beta" uses the configured Visible row colors

  Scenario: Apply Rail terminal defaults with an empty source
    Given a Workspace containing entries
      | kind | path            | count |
      | file | anchor.txt      |       |
      | file | page-{:02d}.txt | 40    |
    And "anchor.txt" is Active
    And a Grove theme assigns these sources
      | role            | source                  |
      | pane-background | fixed Pane Style        |
      | visible-row     | fixed Visible row Style |
      | rail            | empty scope             |
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
