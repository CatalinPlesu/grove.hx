# Settle tmux mouse presses before dragging

## Decision

Acceptance-test drag gestures wait 200 milliseconds after the mouse press
before sending movement. tmux can otherwise deliver the movement before Helix
has established the drag, which makes the same gesture behave like a click.
Ordinary clicks send press and release without this delay.

Keep the delay inside the mouse actor, not in scenarios or assertions. Revisit
it when the test harness can observe that Helix has accepted a drag, or when a
Helix or tmux upgrade makes repeated parallel runs pass without the delay.
