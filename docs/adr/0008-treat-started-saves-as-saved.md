# Treat started saves as saved

## Decision

Helix's `document-saved` Steel hook fires when saving starts and exposes no
completion or failure event. Grove therefore removes that document from
Unsaved state immediately. A later document change restores the mark. Revisit
this decision when Helix exposes the completed save result to Steel.
