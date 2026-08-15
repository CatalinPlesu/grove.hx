# Use the Elm Architecture

Grove uses the Elm Architecture so one Model remains the authoritative semantic
state. Adapters decode raw keys, pointer events, coordinates, and Host callback
payloads, then call named Model transitions. Each transition purely returns the
next Model and an optional Command. Adapters install the next Model before
performing its Command and keep runtime state outside Model. Values derived only
from Model are not stored as independent state. The adapter retains only the
Workspace root and Layout used by the latest rendered frame, so pointer input
maps to what the user saw.
