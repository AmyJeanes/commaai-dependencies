import os
import sys

TOOLCHAIN_DIR = os.path.join(os.path.dirname(__file__), "toolchain")
BIN_DIR = os.path.join(TOOLCHAIN_DIR, "bin")
EXE = ".exe" if os.name == "nt" else ""


def _run(name):
  binary = os.path.join(BIN_DIR, name + EXE)
  if os.name == "nt":  # no process replacement on Windows; run and forward the exit code
    import subprocess

    sys.exit(subprocess.call([binary] + sys.argv[1:]))
  os.execvp(binary, [binary] + sys.argv[1:])


def _run_gcc():
  _run("arm-none-eabi-gcc")


def _run_objcopy():
  _run("arm-none-eabi-objcopy")


def _run_size():
  _run("arm-none-eabi-size")


def smoketest():
  import subprocess
  gcc = os.path.join(BIN_DIR, "arm-none-eabi-gcc" + EXE)
  subprocess.run([gcc, "--version"], check=True)
