Feature: Use the pointer in Grove

  Scenario: Activate a visible row on left press
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
      | target.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And "target.txt" is pressed
    Then Helix shows the "target.txt" document
    When the pointer releases over "anchor.txt"
    Then Helix shows the "target.txt" document

  Scenario: Toggle a directory on left press
    Given a Workspace containing entries
      | kind      | path              |
      | file      | anchor.txt        |
      | directory | folder            |
      | file      | folder/inside.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And "folder" is pressed
    Then the File tree shows "folder/inside.txt"
    When the editor receives "i" while Grove is unfocused
    Then the active Editor view is in Insert mode

  Scenario: Keep the Pinned Workspace root inert on press
    Given a Workspace containing entries
      | kind      | path              |
      | file      | anchor.txt        |
      | directory | folder            |
      | file      | folder/inside.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And "Workspace root" is pressed
    Then the File tree shows "folder"
    When the editor receives "i" while Grove is unfocused
    Then the active Editor view is in Insert mode

  Scenario: Keep an unreadable Workspace root inert on press
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And the Workspace root becomes unreadable
    Then "Workspace root" uses the unreadable-directory icon and error foreground
    And "Workspace root" cannot expand
    When "Workspace root" is pressed
    And the editor receives "i" while Grove is unfocused
    Then the active Editor view is in Insert mode

  Scenario: Keep the existing Cursor when a directory is pressed
    Given a Workspace containing entries
      | kind      | path              |
      | file      | anchor.txt        |
      | directory | folder            |
      | file      | folder/inside.txt |
      | file      | target.txt        |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And Grove receives "Down"
    And "folder" is pressed
    And Grove receives "Enter"
    Then Helix shows the "target.txt" document

  Scenario: Return an outside press to Helix
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And the editor is pressed
    And the editor inserts "outside-" and saves
    Then the content of "anchor.txt" contains "outside-"

  Scenario: Keep Grove unchanged for an outside Wheel event
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And the Wheel scrolls down over the editor
    Then Pane row 2 is "anchor.txt"
    And "anchor.txt" has Cursor

  Rule: Scroll the File tree

    Background:
      Given a Workspace containing entries
        | kind | path            | count |
        | file | anchor.txt      |       |
        | file | page-{:02d}.txt | 40    |
      And "anchor.txt" is Active
      When Helix starts with Grove in that Workspace

    Scenario: Scroll three rows without moving Cursor
      When Grove is focused
      And Grove receives "Down"
      And the Wheel scrolls down over Grove
      And "Workspace root" is pressed
      Then Pane row 2 is "page-01.txt"
      When Grove receives "Enter"
      Then Helix shows the "page-00.txt" document

    Scenario: Keep a scrolled viewport stable when a file is pressed
      Then the File tree shows "page-04.txt"
      When the Wheel scrolls down over Grove
      And "page-04.txt" is pressed
      Then Helix shows the "page-04.txt" document
      And Pane row 2 is "page-01.txt"

    Scenario: Scroll three rows up without moving Cursor
      When Grove is focused
      And Grove receives "Down"
      And the Wheel scrolls down over Grove
      And the Wheel scrolls up over Grove
      Then Pane row 2 is "anchor.txt"
      When Grove receives "Enter"
      Then Helix shows the "page-00.txt" document

  Rule: Other pointer input

    Scenario: Keep Cursor when blank Grove space is pressed
      Given a Workspace containing entries
        | path       |
        | anchor.txt |
      And "anchor.txt" is Active
      When Helix starts with Grove in that Workspace
      And Grove is focused
      And blank Grove space is pressed
      Then "anchor.txt" has Cursor

    Scenario: Ignore inert rows and blank Grove space
      Given a Workspace containing entries
        | kind                      | path           | target |
        | file                      | file2.txt      |        |
        | directory                 | adir           |        |
        | unfollowed directory link | directory-link | adir   |
      And "file2.txt" is Active
      When Helix starts with Grove in that Workspace
      And "directory-link" is pressed
      And blank Grove space is pressed
      Then Helix shows the "file2.txt" document
      When the editor receives "i" while Grove is unfocused
      Then the active Editor view is in Insert mode
