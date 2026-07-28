# Use the Elm Architecture

Grove uses the Elm Architecture so one Model remains the authoritative semantic
state: Messages describe input, and `Model.update` purely returns the next Model
and Commands. Adapters turn external input into Messages, install the next Model
before performing its Commands, and keep runtime state outside the Model.
Values derived only from the Model are not stored separately, and View
construction remains pure.
