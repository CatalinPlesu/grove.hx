from pathlib import PurePath


def scenario_path(name: str) -> PurePath:
    if name == "Workspace root":
        return PurePath()
    return PurePath(name.replace("\\n", "\n"))
