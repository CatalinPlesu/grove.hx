import subprocess
from pathlib import Path


def test_domain() -> None:
    source = Path(__file__).with_name("domain.scm")
    subprocess.run(["steel", str(source)], check=True)
