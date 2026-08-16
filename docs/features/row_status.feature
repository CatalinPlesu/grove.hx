Feature: Present File tree status layers

  Scenario: Propagate one Unsaved mark through collapsed ancestors
    Given a Workspace containing entries
      | kind | path                   |
      | file | outer/inner/active.txt |
    And "outer/inner/active.txt" is Active
    When Helix starts with Grove in that Workspace
    And Grove is focused
    And the editor inserts "changed-" without saving and returns to Normal mode
    Then these rows carry one Unsaved mark
      | row            |
      | Workspace root |
      | outer                  |
      | outer/inner            |
      | outer/inner/active.txt |
    When the "outer" directory is collapsed
    Then these rows carry one Unsaved mark
      | row            |
      | Workspace root |
      | outer          |
    And the File tree does not show "outer/inner"
    And the File tree does not show "outer/inner/active.txt"

  Scenario: Keep the Unsaved mark visible after a filename clips
    Given a Workspace containing entries
      | kind | path                    |
      | file | very-long-file-name.scm |
    And "very-long-file-name.scm" is Active
    And Grove settings
      | setting | value |
      | side    | left  |
      | width   | 16    |
    When Helix starts with Grove in that Workspace
    Then "very-long-file-name.scm" clips without an Unsaved mark
    When the editor inserts "dirty-" without saving and returns to Normal mode
    Then "very-long-file-name.scm" clips with its Unsaved mark visible

  Scenario: Color equivalent modified Git statuses alike
    Given a Workspace containing entries
      | path              |
      | modified.txt      |
      | rename-before.txt |
      | copy-source.txt   |
      | type-change.txt   |
    And Git reports statuses
      | path            | status       | source            |
      | modified.txt    | modified     |                   |
      | renamed.txt     | renamed      | rename-before.txt |
      | copied.txt      | copied       | copy-source.txt   |
      | type-change.txt | type changed | modified.txt      |
    And Grove settings
      | setting | value    |
      | icons   | disabled |
    When Helix starts with Grove in that Workspace
    Then "modified.txt" uses the modified Git foreground
    And "renamed.txt" uses the modified Git foreground
    And "copied.txt" uses the modified Git foreground
    And "type-change.txt" uses the modified Git foreground

  Scenario: Keep Workspace row status scoped to Workspace files
    Given a Workspace containing entries
      | kind | path                   |
      | file | outer/inner/active.txt |
    And "outer/inner/active.txt" is Active
    When Helix starts with Grove in that Workspace
    And a file outside the Workspace is opened
    And the editor inserts "outside-" without saving and returns to Normal mode
    Then these rows carry no Unsaved mark
      | row            |
      | Workspace root |

  Scenario: Treat a nested Git repository as a single Workspace entry
    Given a Workspace containing entries
      | path            |
      | anchor.txt      |
      | nested/file.txt |
    And Git tracks "anchor.txt"
    And "nested" is a Git repository
    And Grove settings
      | setting | value    |
      | icons   | disabled |
    When Helix starts with Grove in that Workspace
    And the "nested" directory is expanded
    Then "nested" uses the created Git foreground
    And "nested/file.txt" uses the theme text foreground

  Scenario: Map status from a Git repository above the Workspace
    Given a Workspace containing entries
      | path        |
      | tracked.txt |
    And "tracked.txt" is Active
    And a parent Git repository tracks "tracked.txt" as modified inside the Workspace
    When Helix starts with Grove in that Workspace
    Then "tracked.txt" uses the modified Git foreground

  Scenario: Compose ordinary status layers on a Pinned row
    Given a Workspace containing entries
      | kind | path                                  | count |
      | file | alpha/beta/gamma/item-{:02d}.txt      | 13    |
      | file | tail-{:02d}.txt                       | 6     |
    And Git reports statuses
      | path                            | status   |
      | alpha/beta/gamma/item-00.txt    | modified |
    And "alpha/beta/gamma/item-00.txt" is Active
    When Helix starts with Grove in that Workspace
    And the editor inserts "dirty-" without saving and returns to Normal mode
    And the terminal height becomes 6 rows
    And Grove is focused
    And Grove receives "Up"
    And the Wheel scrolls down over Grove
    And the Wheel scrolls down over Grove
    Then the Ancestor stack is "Workspace root > alpha > alpha/beta > alpha/beta/gamma" above File tree row "alpha/beta/gamma/item-02.txt"
    And the Pinned "alpha/beta/gamma" row keeps ordinary status layers

  Scenario: Dim an ignored label on a Pinned row
    Given a Workspace containing entries
      | kind | path                                  | count |
      | file | alpha/beta/gamma/item-{:02d}.txt      | 13    |
      | file | tail-{:02d}.txt                       | 6     |
    And Git reports statuses
      | path  | status  |
      | alpha | ignored |
    And "alpha/beta/gamma/item-00.txt" is Active
    When Helix starts with Grove in that Workspace
    And the terminal height becomes 6 rows
    And Grove is focused
    And Grove receives "Up"
    And the Wheel scrolls down over Grove
    And the Wheel scrolls down over Grove
    Then the Ancestor stack is "Workspace root > alpha > alpha/beta > alpha/beta/gamma" above File tree row "alpha/beta/gamma/item-02.txt"
    And the Pinned "alpha" row keeps its background while its label is dimmed

  Rule: With representative Git statuses

    Background:
      Given a Workspace containing entries
        | kind        | path                     | target         |
        | file        | clean.txt                |                |
        | file        | modified.txt             |                |
        | file        | modified-dir/file.txt    |                |
        | file        | modified-dir/created.txt |                |
        | file        | deleted-dir/modified.txt |                |
        | file        | deleted-dir/file.txt     |                |
        | file        | conflict-dir/file.txt    |                |
        | file        | created.txt              |                |
        | file        | created-dir/file.txt     |                |
        | file        | ignored-dir/file.txt     |                |
        | file        | ignored.txt              |                |
        | broken link | broken-link              | missing-before |
      And Git reports statuses
        | path                     | status   |
        | conflict-dir/file.txt    | conflict |
        | deleted-dir/file.txt     | deleted  |
        | modified.txt             | modified |
        | modified-dir/file.txt    | modified |
        | deleted-dir/modified.txt | modified |
        | broken-link              | modified |
        | modified-dir/created.txt | created  |
        | created.txt              | created  |
        | created-dir/file.txt     | created  |
        | ignored-dir              | ignored  |
        | ignored.txt              | ignored  |
      And "clean.txt" is Active

    Scenario: Layer Git, failure, Unsaved, and Cursor presentation
      When Helix starts with Grove in that Workspace
      Then "Workspace root" uses the conflict Git foreground
      And "conflict-dir" uses the conflict Git foreground
      And "deleted-dir" uses the deleted Git foreground
      And "modified-dir" uses the modified Git foreground
      And "modified.txt" uses the modified Git foreground
      And "created-dir" uses the created Git foreground
      And "created.txt" uses the created Git foreground
      And "broken-link" uses the broken-link icon and error foreground
      And ignored status dims the "ignored-dir" label only
      When "modified.txt" is activated
      And the editor inserts "dirty-" without saving and returns to Normal mode
      Then the Workspace icon, "modified.txt" file icon, and their Unsaved marks keep their foregrounds
      When Grove is focused
      Then the Cursor "modified.txt" row background spans its icon, label, and Unsaved mark
      And "modified.txt" uses the "dark" file icon variant
      And "modified.txt" uses the modified Git foreground
      When "ignored.txt" is activated
      And the editor inserts "ignored-" without saving and returns to Normal mode
      Then ignored status dims the "ignored.txt" label only
      When Grove is focused
      Then the ignored "ignored.txt" label stays dimmed on the Cursor row background

    Scenario: Refresh Git status after every save
      Given Grove settings
        | setting | value    |
        | icons   | disabled |
      When Helix starts with Grove in that Workspace
      And the editor inserts "saved-" and saves
      Then "clean.txt" uses the modified Git foreground
      And these rows carry no Unsaved mark
        | row            |
        | Workspace root |
        | clean.txt      |

    Scenario: Clear Git coloring when Git becomes unavailable
      When Helix starts with Grove in that Workspace
      Then "Workspace root" uses the conflict Git foreground
      And "conflict-dir" uses the conflict Git foreground
      And "deleted-dir" uses the deleted Git foreground
      And "modified-dir" uses the modified Git foreground
      And "modified.txt" uses the modified Git foreground
      And "created-dir" uses the created Git foreground
      And "created.txt" uses the created Git foreground
      When the editor inserts "dirty-" without saving and returns to Normal mode
      And Git metadata becomes unavailable
      Then "modified.txt" uses the theme text foreground
      And these rows carry one Unsaved mark
        | row            |
        | Workspace root |
        | clean.txt      |
      And the File tree shows "modified.txt"
