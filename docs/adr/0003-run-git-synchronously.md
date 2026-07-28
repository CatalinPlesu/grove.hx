# Run Git synchronously because Steel cannot poll child status

Pinned Steel can redirect stdout and wait for a child, but it cannot check
whether the child has exited without blocking; an output file does not prove
exit, and discarding the handle can leave the process unreaped. Grove therefore
runs one Git observation at a time, reads stdout directly, closes the pipe, and
always attempts to reap a successfully spawned child before returning to Helix,
even if reading or closing stdout fails. Accept that a stuck Git process blocks
Helix until Steel exposes a non-blocking child-status check that makes the
background design safe.
