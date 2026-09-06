import os
import sys

BIN_DIR = os.path.join(os.path.dirname(__file__), "bin")
EXE = ".exe" if os.name == "nt" else ""


def _run():
  binary = os.path.join(BIN_DIR, "git-lfs" + EXE)
  if os.name == "nt":  # no process replacement on Windows; run and forward the exit code
    import subprocess

    sys.exit(subprocess.call([binary] + sys.argv[1:]))
  os.execvp(binary, [binary] + sys.argv[1:])


def smoketest():
  import subprocess
  binary = os.path.join(BIN_DIR, "git-lfs" + EXE)
  subprocess.run([binary, "--version"], check=True)
