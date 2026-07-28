from pytest_bdd import scenarios

pytest_plugins = (
    "tests.acceptance.steps.setup",
    "tests.acceptance.steps.editor",
    "tests.acceptance.steps.tree",
    "tests.acceptance.steps.pointer",
    "tests.acceptance.steps.presentation",
)

scenarios("../../docs/features")
