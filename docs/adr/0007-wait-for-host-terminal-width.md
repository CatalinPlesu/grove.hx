# Wait for a host terminal-width API

Steel's `string-length` counts Unicode code points, not terminal cells, and
Helix does not expose its cell-width or grapheme-safe truncation rules to Steel,
so wide and combined filenames can break Grove's presentation layout.
Keep the existing `string-length` measurement and accept this limitation. Do
not embed Unicode tables, replace non-ASCII names, or add a native Steel
package; replace the measurement only when Steel or Helix exposes pure native
functions that use the same width and grapheme rules as Helix rendering.
