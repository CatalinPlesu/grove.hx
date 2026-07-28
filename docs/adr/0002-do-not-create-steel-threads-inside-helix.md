# Do not create Steel threads inside Helix

An allocation-heavy Steel native worker can make Helix unresponsive because
the Steel safepoint helper retains `GLOBAL_ENGINE` while component rendering
needs the same mutex, as tracked in
[mattwparas/helix#138](https://github.com/mattwparas/helix/issues/138). Grove
therefore creates no Steel native threads inside Helix and runs filesystem
traversal and File tree construction through Helix callbacks. Revisit this
decision once upstream provides a safe asynchronous Steel integration.
