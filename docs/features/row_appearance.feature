Feature: Present File tree rows

  Scenario: Choose icons and indentation from entry kind
    Given a Workspace containing entries
      | kind      | path              | target | lines |
      | file      | anchor.txt        |        |       |
      | directory | folder            |        |       |
      | file      | folder/inside.txt |        |       |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    Then the Workspace root uses one File tree icon
    And "folder" uses the directory icon
    And "anchor.txt" uses the file icon
    And "anchor.txt" aligns with "folder" in icon mode
    And the Workspace label starts in column 4 and "folder" and "anchor.txt" labels start in column 6
    And "folder" can expand
    When the "folder" directory is expanded
    Then "inside.txt" is indented two columns from "folder"

  Scenario: Present links by target state
    Given a Workspace containing entries
      | kind                      | path            | target    | lines |
      | file                      | file2.txt       |           |       |
      | file                      | file10.txt      |           |       |
      | file                      | .env            |           |       |
      | directory                 | adir            |           |       |
      | directory                 | .git            |           |       |
      | file                      | .git/hidden.txt |           |       |
      | file link                 | file-link       | file2.txt |       |
      | unfollowed directory link | directory-link  | adir      |       |
      | broken link               | broken-link     | missing   |       |
      | fifo                      | named-pipe      |           |       |
    And "file2.txt" is Active
    When Helix starts with Grove in that Workspace
    Then "file-link" uses the File link icon
    And "directory-link" uses the directory icon
    And "broken-link" uses the Broken link icon

  Scenario: Present an unreadable directory as failed
    Given a Workspace containing entries
      | kind      | path              |
      | file      | anchor.txt        |
      | directory | locked            |
      | file      | locked/inside.txt |
    And "anchor.txt" is Active
    And Git reports statuses
      | path              | status   |
      | anchor.txt        | modified |
      | locked/inside.txt | modified |
    When Helix starts with Grove in that Workspace
    Then "locked" uses the modified Git foreground
    And "anchor.txt" uses the modified Git foreground
    When the "locked" directory is expanded
    And the File tree shows "inside.txt"
    And "locked" becomes unreadable
    And Grove receives "Up"
    And Grove receives "Enter"
    And Grove receives "Enter"
    Then "locked" uses the unreadable-folder icon and error foreground

  Scenario: Present an unreadable Workspace root as failed
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    And the Workspace root becomes unreadable
    Then "workspace" uses the unreadable-folder icon and error foreground
    And "workspace" cannot expand

  Scenario: Align rows with icons disabled
    Given a Workspace containing entries
      | kind      | path              | target | lines |
      | file      | anchor.txt        |        |       |
      | directory | folder            |        |       |
      | file      | folder/inside.txt |        |       |
    And "anchor.txt" is Active
    When Helix starts with Grove on the "left" at width 24 with icons disabled
    Then "folder" can expand
    And Workspace, "folder", and "anchor.txt" labels occupy reclaimed icon columns
