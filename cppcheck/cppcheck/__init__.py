import os
import sys

DIR = os.path.join(os.path.dirname(__file__), "install")
EXE = ".exe" if os.name == "nt" else ""


def _run():
  binary = os.path.join(DIR, "cppcheck" + EXE)
  if os.name == "nt":  # no process replacement on Windows; run and forward the exit code
    import subprocess

    sys.exit(subprocess.call([binary] + sys.argv[1:]))
  os.execvp(binary, ["cppcheck"] + sys.argv[1:])


def smoketest():
  import subprocess
  binary = os.path.join(DIR, "cppcheck" + EXE)
  result = subprocess.run([binary, "--version"], capture_output=True, text=True, check=True)
  print(result.stdout.strip())
