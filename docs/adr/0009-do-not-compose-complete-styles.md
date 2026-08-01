---
status: superseded by ADR-0010
---

# Do not compose complete Styles

Steel does not expose Helix's native Style patching API, so Grove selects one
complete row Style and applies only the property-specific changes that Steel
exposes. A native row source remains complete; Grove only fills its missing
colors from the Visible row. Default and semantic row sources without colors
receive the fallback modifiers that keep an empty theme readable. Steel cannot
expose their modifiers, so a modifier-only semantic source also receives the
fallback. Revisit this decision when Steel exposes native Style patching or
modifier inspection.
