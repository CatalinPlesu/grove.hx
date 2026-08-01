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

  Scenario: Show Guides
    Given a Workspace containing entries
      | kind      | path                        | target | lines |
      | file      | anchor.txt                  |        |       |
      | directory | outer                       |        |       |
      | directory | outer/inner                 |        |       |
      | file      | outer/inner/inside.txt      |        |       |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    Then the Workspace root has neither an Ancestor trace nor a Leaf mark
    And "anchor.txt" has no Ancestor trace
    And "anchor.txt" uses one Leaf mark
    And "anchor.txt" uses the file icon
    When the "outer" directory is expanded
    And the "outer/inner" directory is expanded
    Then "inner" uses 1 Ancestor trace
    And "inside.txt" uses 2 Ancestor traces
    And "inside.txt" uses one Leaf mark
    And the Ancestor traces and Leaf mark on "inside.txt" use the indent-guide theme foreground

  Scenario: Disable guides
    Given a Workspace containing entries
      | kind      | path                        | target | lines |
      | file      | anchor.txt                  |        |       |
      | directory | outer                       |        |       |
      | file      | outer/inside.txt            |        |       |
    And "anchor.txt" is Active
    And Grove settings
      | setting | value    |
      | side    | left     |
      | width   | 24       |
      | icons   | disabled |
      | guides  | disabled |
    When Helix starts with Grove in that Workspace
    Then "anchor.txt" has no Leaf mark
    When the "outer" directory is expanded
    Then "inside.txt" has no Ancestor trace
    And "inside.txt" has no Leaf mark

  Scenario: Dim guides when the theme leaves their foreground unspecified
    Given a Workspace containing entries
      | kind      | path             | target | lines |
      | file      | anchor.txt       |        |       |
      | directory | outer            |        |       |
      | file      | outer/inside.txt |        |       |
    And "anchor.txt" is Active
    And Grove settings
      | setting | value    |
      | icons   | disabled |
    And the Host theme has no indent-guide foreground
    When Helix starts with Grove in that Workspace
    And the "outer" directory is expanded
    Then the Ancestor trace and Leaf mark on "inside.txt" use the dimmed theme text foreground

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
    And "file-link" uses one Leaf mark
    And "directory-link" uses one Leaf mark
    And "broken-link" uses one Leaf mark

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
    And Grove settings
      | setting | value    |
      | side    | left     |
      | width   | 24       |
      | icons   | disabled |
    When Helix starts with Grove in that Workspace
    Then "folder" can expand
    And Workspace, "folder", and "anchor.txt" labels occupy reclaimed icon columns
    And "anchor.txt" uses one Leaf mark
