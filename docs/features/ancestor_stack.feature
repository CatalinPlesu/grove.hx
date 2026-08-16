Feature: Keep hierarchy visible while the File tree scrolls

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
    Then the Ancestor stack is "Workspace root > alpha > alpha/beta" above File tree row "alpha/beta/sibling"
    When the Wheel scrolls down over Grove
    Then the Ancestor stack is "Workspace root" above File tree row "tail-01.txt"

  Scenario: Disable the Ancestor stack when the complete chain does not fit
    Given a Workspace containing entries
      | kind | path                   |
      | file | outer/inner/active.txt |
    And "outer/inner/active.txt" is Active
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 2 rows
    And Grove is focused
    Then Pane row 1 is "outer/inner"
    And Pane row 2 is "outer/inner/active.txt"

  Scenario: Keep the hierarchy at the File tree end
    Given a Workspace containing entries
      | kind      | path                          | count |
      | file      | alpha/beta/sibling/inside.txt |       |
      | directory | omega                         |       |
      | file      | tail-{:02d}.txt                | 3     |
    And "alpha/beta/sibling/inside.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And the terminal height becomes 6 rows
    And the Wheel scrolls down 20 times over Grove
    Then the Ancestor stack is "Workspace root" above File tree row "omega"
    And Pane row 5 is "tail-02.txt"
    And Pane row 6 is unused

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
    And "alpha/beta/gamma" is activated
    Then the Ancestor stack is "Workspace root > alpha > alpha/beta > alpha/beta/gamma" above File tree row "alpha/beta/gamma/item-02.txt"
    And "alpha/beta/gamma" has Cursor
    When the Wheel scrolls down over the Pinned row "alpha/beta/gamma"
    Then Pane row 5 is "alpha/beta/gamma/item-05.txt"
    When Grove receives "Left"
    Then Pane row 4 is "alpha/beta/gamma"
    And the File tree does not show "alpha/beta/gamma/item-00.txt"

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
    Then Pane row 6 is "alpha/beta/gamma/item-04.txt"
    When the Wheel scrolls down over Grove
    And Grove receives "PageDown"
    Then Pane row 5 is "alpha/beta/gamma/item-06.txt"
    And "alpha/beta/gamma/item-06.txt" has Cursor

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
    Then the Ancestor stack is "Workspace root > alpha > alpha/beta > alpha/beta/gamma" above File tree content

    Examples:
      | key    |
      | +      |
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
    Then the Ancestor stack is "Workspace root > alpha > alpha/beta > alpha/beta/gamma" above File tree row "alpha/beta/gamma/item-02.txt"
    And "alpha/beta/gamma" has Cursor
    When Grove receives "<key>"
    Then Pane row 4 is "<expected>"
    And the File tree does not show "alpha/beta/gamma/item-00.txt"

    Examples:
      | key    | expected |
      | Left   | alpha/beta/gamma |
      | Enter  | alpha/beta/gamma |
