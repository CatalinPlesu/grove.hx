# Isolate Steel home in acceptance tests

Helix 25.07.1 rewrites generated modules under `STEEL_HOME/cogs/helix` and
`STEEL_HOME/lsp` during startup, so parallel processes can corrupt the shared
copies before `init.scm` runs. Each acceptance test therefore uses its own
writable `STEEL_HOME`, including a test-owned copy of `devicons`; do not
serialize the suite or add retries to hide the race. Keep this isolation until
Grove uses a Helix release containing
[mattwparas/helix#140](https://github.com/mattwparas/helix/pull/140) and repeated
parallel runs pass with one shared `STEEL_HOME`.
