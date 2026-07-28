Feature: Activate files

  Scenario: Reveal the Active file on startup
    Given a Workspace containing entries
      | path                   |
      | outer/inner/active.txt |
    And "outer/inner/active.txt" is Active
    When Helix starts with Grove in that Workspace
    Then the File tree shows "active.txt"

  Scenario: Reveal a nested file activated by Helix
    Given a Workspace containing entries
      | kind      | path              | target | lines |
      | file      | anchor.txt        |        |       |
      | directory | folder            |        |       |
      | file      | folder/inside.txt |        |       |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And Grove receives Helix's file-picker chord for "inside.txt"
    Then Helix shows the "folder/inside.txt" document
    And the File tree shows "inside.txt"

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
    And Helix has 1 editor view

  Scenario Outline: Open the Active file in a new split
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
      | target.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And Grove receives "<key>"
    Then Helix has 2 editor views
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
    Then Helix has 2 editor views
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
    Then Helix has 2 editor views
    When Helix closes the active Editor view
    Then Helix has 1 editor view
    And Helix shows the "anchor.txt" document
    And "anchor.txt" is the Active file

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

  Scenario: Ignore activation of a Broken link
    Given a Workspace containing entries
      | kind                      | path            | target    |
      | file                      | file2.txt       |           |
      | file                      | file10.txt      |           |
      | file                      | .env            |           |
      | directory                 | adir            |           |
      | directory                 | .git            |           |
      | file                      | .git/hidden.txt |           |
      | file link                 | file-link       | file2.txt |
      | unfollowed directory link | directory-link  | adir      |
      | broken link               | broken-link     | missing   |
      | fifo                      | named-pipe      |           |
    And "file2.txt" is Active
    When Helix starts with Grove in that Workspace
    And "broken-link" is activated
    Then Helix shows the "file2.txt" document
    And the editor remains active

  Scenario: Open a File link
    Given a Workspace containing entries
      | kind                      | path            | target    |
      | file                      | file2.txt       |           |
      | file                      | file10.txt      |           |
      | file                      | .env            |           |
      | directory                 | adir            |           |
      | directory                 | .git            |           |
      | file                      | .git/hidden.txt |           |
      | file link                 | file-link       | file2.txt |
      | unfollowed directory link | directory-link  | adir      |
      | broken link               | broken-link     | missing   |
      | fifo                      | named-pipe      |           |
    And "file2.txt" is Active
    When Helix starts with Grove in that Workspace
    And "file-link" is activated
    Then Helix shows the "file-link" document

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
