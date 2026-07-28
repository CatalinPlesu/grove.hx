Feature: Adapt File tree icons to the theme

  Scenario Outline: Choose the icon palette from theme inputs
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove under background "<background>" and text "<text>"
    Then "anchor.txt" uses the "<variant>" file icon variant

    Examples:
      | background | text    | variant |
      | default    | default | dark    |
      | #ffffff    | #ffffff | light   |
      | default    | #000000 | light   |
