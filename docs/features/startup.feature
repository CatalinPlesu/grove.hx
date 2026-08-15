Feature: Start Grove

  Scenario: Start without an Active file
    Given a Workspace containing entries
      | kind | path       |
      | file | anchor.txt |
    When Helix starts with Grove in that Workspace
    Then the File tree shows "anchor.txt"
    When the editor receives "i" while Grove is unfocused
    Then the active Editor view is in Insert mode

  Scenario: Start Docked without taking editor focus
    Given a Workspace containing entries
      | kind      | path              |
      | file      | anchor.txt        |
      | directory | folder            |
      | file      | folder/inside.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    Then the File tree shows "anchor.txt"
    When the editor receives "i" while Grove is unfocused
    Then the active Editor view is in Insert mode

  Scenario: Exit with Grove running
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
    When Helix starts with Grove in that Workspace
    And Helix exits
    Then Helix exits normally
