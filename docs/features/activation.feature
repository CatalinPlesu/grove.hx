Feature: Activate files

  Scenario: Reveal a nested Active file only when Grove is focused
    Given a Workspace containing entries
      | path                   |
      | outer/inner/active.txt |
    And "outer/inner/active.txt" is Active
    When Helix starts with Grove in that Workspace
    Then the File tree does not show "outer/inner/active.txt"
    When Grove is focused
    Then the File tree shows "outer/inner/active.txt"
    And "outer/inner/active.txt" has Cursor

  Scenario: Reveal an off-screen Active file when Grove is focused
    Given a Workspace containing entries
      | kind | path                            | count |
      | file | outer/inner/item-{:02d}.txt     | 20    |
    And "outer/inner/item-05.txt" is Active
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 8 rows
    And "outer" is activated
    And "outer/inner" is activated
    And the Wheel scrolls down over Grove
    And the Wheel scrolls down over Grove
    And the Wheel scrolls down over Grove
    And the Wheel scrolls down over Grove
    Then the File tree does not show "outer/inner/item-05.txt"
    When Grove is focused
    Then Pane row 4 is "outer/inner/item-05.txt"
    And the Ancestor stack is "Workspace root > outer > outer/inner" above File tree row "outer/inner/item-05.txt"
    When "outer/inner/item-05a.txt" is created
    Then the File tree shows "outer/inner/item-05a.txt"
    And Pane row 4 is "outer/inner/item-05.txt"
    And "outer/inner/item-05.txt" has Cursor

  Scenario: Reveal a top-level Active file after Wheel scrolling to the bottom
    Given a Workspace containing entries
      | kind | path           | count |
      | file | item-{:02d}.txt | 40    |
    And "item-00.txt" is Active
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 8 rows
    And the Wheel scrolls down 20 times over Grove
    Then the File tree ends with "item-39.txt"
    And the File tree does not show "item-00.txt"
    When Grove is focused
    Then Pane row 2 is "item-00.txt"
    When "item-00a.txt" is created
    Then the File tree shows "item-00a.txt"
    And Pane row 2 is "item-00.txt"
    And "item-00.txt" has Cursor

  Scenario: Reveal a nested Active file after Wheel scrolling to the bottom
    Given a Workspace containing entries
      | kind | path                        | count |
      | file | outer/inner/item-{:02d}.txt | 15    |
      | file | tail-{:02d}.txt             | 30    |
    And "outer/inner/item-00.txt" is Active
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 8 rows
    And Grove is focused
    And Grove receives "Escape"
    And the Wheel scrolls down 20 times over Grove
    Then the File tree ends with "tail-29.txt"
    And the File tree does not show "outer/inner/item-00.txt"
    When Grove is focused
    Then Pane row 4 is "outer/inner/item-00.txt"
    And the Ancestor stack is "Workspace root > outer > outer/inner" above File tree row "outer/inner/item-00.txt"
    When the Wheel scrolls down over Grove
    Then Pane row 4 is "outer/inner/item-03.txt"

  Scenario: Reveal a nested file activated by Helix
    Given a Workspace containing entries
      | kind      | path              |
      | file      | anchor.txt        |
      | directory | folder            |
      | file      | folder/inside.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And Grove receives Helix's file-picker chord and searches for "inside"
    Then Helix shows the "folder/inside.txt" document
    And the File tree does not show "folder/inside.txt"
    When Grove is focused
    Then the File tree shows "folder/inside.txt"

  Scenario: Open another file in the current split
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
      | target.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And Grove receives "Down"
    And Grove receives "Enter"
    And the editor inserts "opened-" and saves
    Then the content of "target.txt" starts with "opened-"
    And Helix Editor view count is 1

  Scenario Outline: Open the Active file in a new split
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
      | target.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And Grove receives "<key>"
    Then Helix Editor view count is 2
    And Helix shows the "anchor.txt" document

    Examples:
      | key    |
      | Ctrl-s |
      | Ctrl-v |

  Scenario Outline: Open another file in a new split
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
      | target.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And Grove receives "Down"
    And Grove receives "<key>"
    Then Helix Editor view count is 2
    And Helix shows the "target.txt" document

    Examples:
      | key    |
      | Ctrl-s |
      | Ctrl-v |

  Scenario: Follow the Active file after closing a split
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
      | target.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And Grove receives "Down"
    And Grove receives "Ctrl-v"
    Then Helix Editor view count is 2
    When Helix closes the active Editor view
    Then Helix Editor view count is 1
    And Helix shows the "anchor.txt" document
    And "anchor.txt" uses the Active file mark

  Scenario: Keep Grove focused after activating a directory
    Given a Workspace containing entries
      | kind      | path              |
      | file      | anchor.txt        |
      | directory | folder            |
      | file      | folder/inside.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And Grove receives "Up"
    And Grove receives "Enter"
    Then "folder" has Cursor
    When Grove receives "Down"
    And Grove receives "Enter"
    Then Helix shows the "folder/inside.txt" document

  Scenario: Preserve the editor view when activating an open file
    Given a Workspace containing entries
      | kind | path       | lines |
      | file | active.txt | 100   |
      | file | other.txt  | 100   |
    And "active.txt" is Active
    When Helix starts with Grove in that Workspace
    And the editor cursor moves to line 60 in "active.txt" with line 55 first
    And "active.txt" is activated
    And "other.txt" is activated
    Then Helix shows the "other.txt" document
    When "active.txt" is activated
    Then the editor view for "active.txt" is restored at line 60 with line 55 first

  Scenario: Preserve the editor view when activating the Active file
    Given a Workspace containing entries
      | kind | path       | lines |
      | file | active.txt | 100   |
      | file | other.txt  | 100   |
    And "active.txt" is Active
    When Helix starts with Grove in that Workspace
    And the editor cursor moves to line 60 in "active.txt" with line 55 first
    And Grove is focused
    And Grove receives "Enter"
    Then the editor view for "active.txt" is restored at line 60 with line 55 first

  Scenario: Preserve the exact path of a sanitized filename
    Given a Workspace containing entries
      | kind | path          |
      | file | anchor.txt    |
      | file | odd\nname.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    Then the File tree shows "odd\nname.txt"
    When "odd\nname.txt" is activated
    And the editor inserts "opened-" and saves
    Then the content of "odd\nname.txt" starts with "opened-"

  Scenario: Leave an open failure to Helix
    Given a Workspace containing entries
      | kind | path       |
      | file | anchor.txt |
      | file | locked.txt |
    And "anchor.txt" is Active
    And "locked.txt" is unreadable
    When Helix starts with Grove in that Workspace
    And "locked.txt" is activated
    Then Helix shows the "anchor.txt" document
    And Grove does not replace the error with a generic notice

  Rule: With representative links

    Background:
      Given a Workspace containing entries
        | kind        | path        | target    |
        | file        | file2.txt   |           |
        | file link   | file-link   | file2.txt |
        | broken link | broken-link | missing   |
      And "file2.txt" is Active

    Scenario: Ignore activation of a Broken link
      When Helix starts with Grove in that Workspace
      And "broken-link" is activated
      Then Helix shows the "file2.txt" document
      When the editor receives "i" while Grove is unfocused
      Then the active Editor view is in Insert mode

    Scenario: Open a File link
      When Helix starts with Grove in that Workspace
      And "file-link" is activated
      Then Helix shows the "file-link" document
