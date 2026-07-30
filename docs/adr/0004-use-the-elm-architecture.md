# Use the Elm Architecture

Grove uses the Elm Architecture so one Model remains the authoritative semantic
state. Model receives only semantic Messages: Adapters decode raw keys, pointer
events, coordinates, and Host callback payloads before dispatch. `Model.update`
purely returns the next Model and Commands. Adapters install the next Model
before performing its Commands and keep runtime state outside Model. Values
derived only from Model are not stored separately, and View construction
remains pure.
