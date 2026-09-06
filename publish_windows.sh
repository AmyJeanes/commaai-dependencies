#!/usr/bin/env bash
# Windows only. comma publishes the Linux and macOS wheels to PyPI on every master push (release.sh); the
# win_amd64 wheels are built from a fork and go to a GitHub release on it instead. The release also carries an
# index.html that uv accepts as a flat index (pip's --find-links), with sha256 fragments so uv.lock pins the hashes.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
cd "$ROOT_DIR"

if [[ $# -gt 0 ]]; then
  echo "usage: ./build.sh && ./publish_windows.sh" >&2
  exit 2
fi
case "$(uname -s)" in
  MINGW*|MSYS*) ;;
  *) echo "error: the Windows wheels are built and published from an MSYS2 shell" >&2; exit 1 ;;
esac
command -v gh >/dev/null || { echo "error: the GitHub CLI (gh) is required" >&2; exit 1; }

# the release tag names the commit that built the wheels: tracked files must be clean and pushed, and match dist/
# (build output such as dist/ and the uv cache is untracked and does not count)
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "error: uncommitted changes; commit and push what built the wheels first:" >&2
  git status --porcelain --untracked-files=no >&2
  exit 1
fi
git fetch --quiet origin
if ! git branch --remotes --contains HEAD | grep -q .; then
  echo "error: HEAD is not pushed to origin" >&2
  exit 1
fi
POST_N="$(git rev-list --count HEAD)"
TAG="windows-post$POST_N"

shopt -s nullglob
wheels=(dist/*.whl)
shopt -u nullglob
if [[ ${#wheels[@]} -eq 0 ]]; then
  echo "error: no wheels in dist/; run ./build.sh first" >&2
  exit 1
fi
for whl in "${wheels[@]}"; do
  case "$(basename "$whl")" in
    comma_deps_*.post"$POST_N"-*) ;;
    comma_deps_*) echo "error: $whl was not built from HEAD (expected .post$POST_N); run ./build.sh" >&2; exit 1 ;;
  esac
done

REPO="$(git remote get-url origin | sed -E 's#^.*github[.]com[:/]##; s#[.]git$##')"
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "error: release $TAG already exists on $REPO" >&2
  exit 1
fi

DOWNLOAD_URL="https://github.com/$REPO/releases/download/$TAG"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

{
  echo '<!DOCTYPE html>'
  echo "<html><head><meta charset='utf-8'><title>$TAG</title></head><body>"
  for whl in "${wheels[@]}"; do
    name="$(basename "$whl")"
    sha="$(sha256sum "$whl" | cut -d' ' -f1)"
    echo "<a href='$DOWNLOAD_URL/$name#sha256=$sha'>$name</a><br>"
  done
  echo '</body></html>'
} > "$WORK/index.html"

CLANG_VERSION="$(clang --version 2>/dev/null | head -1 || true)"
{
  echo "win_amd64 wheels built from $(git rev-parse HEAD) by ./build.sh in an MSYS2 CLANG64 shell${CLANG_VERSION:+ ($CLANG_VERSION)}."
  echo
  echo 'Use them as a uv flat index:'
  echo
  echo '```toml'
  echo '[[tool.uv.index]]'
  echo 'name = "comma-deps-windows"'
  echo "url = \"$DOWNLOAD_URL/index.html\""
  echo 'format = "flat"'
  echo 'explicit = true'
  echo '```'
  echo
  echo '| wheel | size |'
  echo '|---|---|'
  for whl in "${wheels[@]}"; do
    echo "| $(basename "$whl") | $(du -h "$whl" | cut -f1) |"
  done
} > "$WORK/notes.md"

echo "Publishing ${#wheels[@]} wheel(s) as release $TAG on $REPO"
gh release create "$TAG" --repo "$REPO" --target "$(git rev-parse HEAD)" --title "Windows wheels $TAG" \
  --notes-file "$WORK/notes.md" "${wheels[@]}" "$WORK/index.html"
git fetch --quiet --tags origin
echo "flat index: $DOWNLOAD_URL/index.html"
