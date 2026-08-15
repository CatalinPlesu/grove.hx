Feature: Navigate and resize with the Rail

  Rule: Without scrollable content

    Scenario: Ignore vertical Rail input when there is no thumb
      Given a Workspace containing entries
        | path       |
        | anchor.txt |
        | target.txt |
      And "anchor.txt" is Active
      When Helix starts with Grove in that Workspace
      And the Rail track is clicked
      And the Rail track is dragged vertically
      Then Helix shows the "anchor.txt" document
      And Pane row 2 is "anchor.txt"

  Rule: With scrollable content

    Background:
      Given a Workspace containing entries
        | kind | path            | count |
        | file | anchor.txt      |       |
        | file | page-{:02d}.txt | 40    |
      And "anchor.txt" is Active
      When Helix starts with Grove in that Workspace

    Scenario: Page by one visible height from the Rail track
      When the terminal height becomes 10 rows
      And the Rail track below the thumb is clicked
      Then Pane row 2 is "page-08.txt"
      When the Rail track above the thumb is clicked
      Then Pane row 2 is "anchor.txt"

    Scenario: Keep the chosen Rail axis until release
      When the Rail drag moves horizontally toward width 30 and then vertically
      Then Grove has width 30
      And Pane row 2 is "anchor.txt"

    Scenario: Keep the vertical Rail axis until release
      When the Rail drag moves vertically and then horizontally
      Then Pane row 2 is not "page-00.txt"
      And Grove has width 32

    Scenario: Clamp vertical thumb dragging at the File tree end
      When the Rail thumb is pressed
      And the Rail thumb is dragged to the bottom
      Then the File tree ends with "page-39.txt"
      When the Rail thumb is pressed
      And the Rail thumb is dragged to the top
      Then Pane row 2 is "anchor.txt"

    Scenario: Continue thumb dragging after the File tree and terminal change
      When the Rail thumb is pressed
      And "aardvark.txt" is created
      And "extra-1.txt" is created
      And "extra-2.txt" is created
      Then the File tree shows "extra-2.txt"
      When "page-05.txt" is deleted
      Then the File tree does not show "page-05.txt"
      When the terminal height becomes 25 rows
      And the Rail thumb is dragged down
      Then Pane row 2 is not "page-00.txt"

    Scenario: Let a key cancel a Rail drag
      When the Rail thumb is pressed
      And Grove receives Helix's file-picker chord and searches for "page-10"
      And the pointer moves horizontally
      Then Helix shows the "page-10.txt" document
      And Grove has width 32

    Scenario: Let Wheel scrolling cancel a Rail drag
      When the Rail thumb is pressed
      And the Wheel scrolls down over Grove
      And the pointer moves horizontally
      Then Pane row 2 is "page-01.txt"
      And Grove has width 32

    Scenario: Let a new press cancel a Rail drag
      When the Rail thumb is pressed
      And "page-10.txt" is pressed
      And the pointer moves horizontally
      Then Helix shows the "page-10.txt" document
      And Grove has width 32

  Rule: Across Ancestor stack changes

    Scenario: Keep the Rail thumb height while the Ancestor stack peels
      Given a Workspace containing entries
        | kind      | path                          | count |
        | file      | alpha/beta/sibling/inside.txt |       |
        | directory | omega                         |       |
        | file      | tail-{:02d}.txt                | 10    |
      And "alpha/beta/sibling/inside.txt" is Active
      When Helix starts with Grove in that Workspace
      And Grove is focused
      And the terminal height becomes 6 rows
      And the Wheel scrolls down over Grove
      Then the Ancestor stack is "Workspace root > alpha > alpha/beta" above File tree row "alpha/beta/sibling"
      When the Rail thumb height is noted
      And the Rail thumb is pressed
      And the Rail thumb is dragged to the bottom
      Then the Ancestor stack is "Workspace root" above File tree row "tail-05.txt"
      And Pane row 6 is "tail-09.txt"
      And the Rail thumb keeps its height

  Rule: Across Workspace changes

    Scenario: Cancel a Rail drag when the Workspace changes
      Given a Workspace named "first" containing entries
        | kind | path            | count |
        | file | page-{:02d}.txt | 40    |
      And "page-00.txt" is Active in Workspace "first"
      And a Workspace named "second" containing entries
        | path       |
        | anchor.txt |
      When Helix starts with Grove in Workspace "first"
      And the Rail thumb is pressed
      And Helix runs "cd" for Workspace "second"
      Then the File tree root is "second"
      When the pointer moves horizontally
      Then the File tree root is "second"
      And Grove has width 32
