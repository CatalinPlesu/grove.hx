Feature: Keep hierarchy visible while the File tree scrolls

  Scenario: Pin the hierarchy after scrolling into a nested subtree
    Given a Workspace containing entries
      | kind | path                             | count |
      | file | alpha/beta/gamma/item-{:02d}.txt | 13    |
      | file | tail-{:02d}.txt                  | 6     |
    And "alpha/beta/gamma/item-00.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And the terminal height becomes 6 rows
    And the Wheel scrolls down over Grove
    Then the Ancestor stack is "workspace > alpha > beta" above File tree row "gamma"

  Scenario: Peel at one-level and multi-level sibling boundaries
    Given a Workspace containing entries
      | kind      | path                          | count |
      | file      | alpha/beta/gamma/g-{:02d}.txt | 2     |
      | directory | alpha/beta/sibling            |       |
      | directory | omega                         |       |
      | file      | tail-{:02d}.txt               | 8     |
    And "alpha/beta/gamma/g-00.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And the terminal height becomes 6 rows
    And the Wheel scrolls down over Grove
    And the Wheel scrolls down over Grove
    Then the Ancestor stack is "workspace > alpha > beta" above File tree row "sibling"
    When the Wheel scrolls down over Grove
    Then the Ancestor stack is "workspace" above File tree row "tail-01.txt"

  Scenario: Disable the Ancestor stack when the complete chain does not fit
    Given a Workspace containing entries
      | kind | path                   | target | lines |
      | file | outer/inner/active.txt |        |       |
    And "outer/inner/active.txt" is Active
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 2 rows
    And Grove is focused
    Then Pane row 1 is "inner"
    And Pane row 2 is "active.txt"

  Scenario: Keep a Pinned row inert while Wheel still scrolls
    Given a Workspace containing entries
      | kind | path                             | count |
      | file | alpha/beta/gamma/item-{:02d}.txt | 13    |
      | file | tail-{:02d}.txt                  | 6     |
    And "alpha/beta/gamma/item-00.txt" is Active
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 6 rows
    And Grove is focused
    And Grove receives "Up"
    And the Wheel scrolls down over Grove
    And the Wheel scrolls down over Grove
    And "gamma" is activated
    Then the Ancestor stack is "workspace > alpha > beta > gamma" above File tree row "item-02.txt"
    And "gamma" has Cursor
    When the Wheel scrolls down over the Pinned row "gamma"
    Then Pane row 5 is "item-05.txt"
    When Grove receives "Left"
    Then Pane row 4 is "gamma"
    And the File tree does not show "item-00.txt"

  Scenario: Reveal Cursor from direct scrolling by ordinary capacity
    Given a Workspace containing entries
      | kind | path                             | count |
      | file | alpha/beta/gamma/item-{:02d}.txt | 13    |
      | file | tail-{:02d}.txt                  | 6     |
    And "alpha/beta/gamma/item-03.txt" is Active
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 6 rows
    And Grove is focused
    And Grove receives "Down"
    Then Pane row 6 is "item-04.txt"
    When the Wheel scrolls down over Grove
    And Grove receives "PageDown"
    Then Pane row 5 is "item-06.txt"
    And "item-06.txt" has Cursor

  Scenario Outline: Keep direct scrolling for non-item keys
    Given a Workspace containing entries
      | kind | path                             | count |
      | file | alpha/beta/gamma/item-{:02d}.txt | 13    |
      | file | tail-{:02d}.txt                  | 6     |
    And "alpha/beta/gamma/item-00.txt" is Active
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 6 rows
    And Grove is focused
    And Grove receives "Up"
    And the Wheel scrolls down over Grove
    And the Wheel scrolls down over Grove
    And Grove receives "<key>"
    Then the Ancestor stack is "workspace > alpha > beta > gamma" above File tree content

    Examples:
      | key    |
      | +      |
      | -      |
      | Escape |
      | z      |

  Scenario Outline: Snap back and act on a Pinned Cursor directory
    Given a Workspace containing entries
      | kind | path                             | count |
      | file | alpha/beta/gamma/item-{:02d}.txt | 13    |
      | file | tail-{:02d}.txt                  | 6     |
    And "alpha/beta/gamma/item-00.txt" is Active
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 6 rows
    And Grove is focused
    And Grove receives "Up"
    And the Wheel scrolls down over Grove
    And the Wheel scrolls down over Grove
    Then the Ancestor stack is "workspace > alpha > beta > gamma" above File tree row "item-02.txt"
    And "gamma" has Cursor
    When Grove receives "<key>"
    Then Pane row 4 is "<expected>"
    And the File tree does not show "item-00.txt"

    Examples:
      | key    | expected |
      | Left   | gamma    |
      | Enter  | gamma    |
      | Ctrl-s | gamma    |
      | Ctrl-v | gamma    |
