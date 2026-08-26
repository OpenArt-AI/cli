#!/bin/sh
# OpenArt CLI installer for macOS and Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/OpenArt-AI/cli/main/install.sh | sh
#
# Options (pass after `-s --`):
#   --version 0.1.0     install this exact version instead of the latest
#   --prefix ~/.local   install to <prefix>/bin instead of the default
#   --no-verify         skip the SHA-256 checksum check (not recommended)
#   --help
#
#   curl -fsSL https://raw.githubusercontent.com/OpenArt-AI/cli/main/install.sh | sh -s -- --prefix "$HOME/.local"
#
# On Windows, use install.ps1 instead.

set -eu

REPO="OpenArt-AI/cli"
BINARY="openart"

VERSION=""
PREFIX=""
VERIFY="yes"

say() { printf '%s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || err "'$1' is required but was not found on PATH"; }

# Spelled out rather than scraped from the comment header above: when this
# script arrives through `curl | sh` there is no $0 to read it back out of.
usage() {
  cat <<'USAGE'
OpenArt CLI installer for macOS and Linux.

  curl -fsSL https://raw.githubusercontent.com/OpenArt-AI/cli/main/install.sh | sh

Options (pass them after `-s --`):
  --version <x.y.z>   install this exact version instead of the latest
  --prefix <dir>      install to <dir>/bin instead of the default
  --no-verify         skip the SHA-256 checksum check (not recommended)
  -h, --help          show this message

  curl -fsSL .../install.sh | sh -s -- --prefix "$HOME/.local"
  curl -fsSL .../install.sh | sh -s -- --version 0.1.0

On Windows, use install.ps1 instead.
USAGE
  exit 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) [ "$#" -ge 2 ] || err "--version needs a value"; VERSION="$2"; shift 2 ;;
    --version=*) VERSION="${1#*=}"; shift ;;
    --prefix) [ "$#" -ge 2 ] || err "--prefix needs a value"; PREFIX="$2"; shift 2 ;;
    --prefix=*) PREFIX="${1#*=}"; shift ;;
    --no-verify) VERIFY="no"; shift ;;
    -h|--help) usage ;;
    *) err "unknown option '$1' (try --help)" ;;
  esac
done

need curl
need tar

# --- Which build do we want? ------------------------------------------------

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$os" in
  darwin|linux) ;;
  mingw*|msys*|cygwin*) err "this script is for macOS and Linux — on Windows run install.ps1 (see https://github.com/${REPO}#windows)" ;;
  *) err "unsupported operating system '$os'" ;;
esac

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *) err "unsupported architecture '$arch' — only amd64 and arm64 are built" ;;
esac

# No --version given: ask GitHub which release is current. This reads the
# "Latest" release, which prereleases and backports never claim.
if [ -z "$VERSION" ]; then
  VERSION="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)"
  [ -n "$VERSION" ] ||
    err "could not determine the latest version — GitHub may be rate-limiting you; retry, or pass --version"
fi
VERSION="${VERSION#v}" # tags carry a v, archive names do not

ARCHIVE="${BINARY}_${VERSION}_${os}_${arch}.tar.gz"
BASE_URL="https://github.com/${REPO}/releases/download/v${VERSION}"

# --- Where does it go? ------------------------------------------------------

# Prefer a system-wide install, but never surprise anyone with a sudo prompt
# they did not ask for: if /usr/local/bin is not already writable, fall back to
# the user's own ~/.local/bin instead of escalating.
# Walk up to the closest directory that actually exists. Asking whether
# ~/.local/bin is writable when neither it nor ~/.local exists yet answers "no"
# for the wrong reason, and the caller would escalate to sudo over it.
existing_ancestor() {
  dir="$1"
  while [ ! -e "$dir" ]; do
    parent="$(dirname "$dir")"
    [ "$parent" = "$dir" ] && break
    dir="$parent"
  done
  printf '%s\n' "$dir"
}

if [ -z "$PREFIX" ]; then
  if [ -w "$(existing_ancestor /usr/local/bin)" ]; then
    PREFIX="/usr/local"
  else
    PREFIX="${HOME}/.local"
  fi
fi
BIN_DIR="${PREFIX}/bin"

# --- Download ---------------------------------------------------------------

tmp="$(mktemp -d)"
# shellcheck disable=SC2064 # $tmp is fixed here; expand it now, not on exit
trap "rm -rf '$tmp'" EXIT INT TERM

say "Downloading ${BINARY} ${VERSION} (${os}/${arch})..."
curl -fsSL --proto '=https' --tlsv1.2 -o "${tmp}/${ARCHIVE}" "${BASE_URL}/${ARCHIVE}" ||
  err "could not download ${BASE_URL}/${ARCHIVE} — is ${VERSION} a released version?"

if [ "$VERIFY" = "yes" ]; then
  if command -v sha256sum >/dev/null 2>&1; then
    sha256() { sha256sum "$1" | cut -d' ' -f1; }
  elif command -v shasum >/dev/null 2>&1; then
    sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
  else
    sha256() { return 1; }
  fi

  if actual="$(sha256 "${tmp}/${ARCHIVE}")"; then
    curl -fsSL --proto '=https' --tlsv1.2 -o "${tmp}/checksums.txt" "${BASE_URL}/checksums.txt" ||
      err "could not download the checksum file — re-run with --no-verify to skip this check"
    expected="$(awk -v want="$ARCHIVE" '$2 == want { print $1 }' "${tmp}/checksums.txt")"
    [ -n "$expected" ] || err "${ARCHIVE} is not listed in checksums.txt"
    [ "$actual" = "$expected" ] ||
      err "checksum mismatch for ${ARCHIVE}: got ${actual}, expected ${expected}. Do not use this download."
    say "Checksum verified."
  else
    say "warning: no sha256sum or shasum found — skipping checksum verification."
  fi
fi

tar -xzf "${tmp}/${ARCHIVE}" -C "$tmp"
[ -f "${tmp}/${BINARY}" ] || err "the archive did not contain a '${BINARY}' binary"

# --- Install ----------------------------------------------------------------

# One place that decides whether a command needs sudo, so the rules cannot drift
# between creating the directory and writing into it.
as_owner() {
  if [ -w "$(existing_ancestor "$BIN_DIR")" ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    err "${BIN_DIR} is not writable and sudo is unavailable — re-run with --prefix \"\$HOME/.local\""
  fi
}

[ -d "$BIN_DIR" ] || as_owner mkdir -p "$BIN_DIR"
as_owner install -m 0755 "${tmp}/${BINARY}" "${BIN_DIR}/${BINARY}"

# Gatekeeper flags anything downloaded by curl; without this the first run dies
# with "cannot be opened because the developer cannot be verified".
if [ "$os" = "darwin" ]; then
  xattr -d com.apple.quarantine "${BIN_DIR}/${BINARY}" 2>/dev/null || true
fi

say ""
say "Installed $("${BIN_DIR}/${BINARY}" version | head -n 1) to ${BIN_DIR}/${BINARY}"

case ":${PATH}:" in
  *":${BIN_DIR}:"*)
    say ""
    say "Get started with:  ${BINARY} login"
    ;;
  *)
    say ""
    say "${BIN_DIR} is not on your PATH. Add it:"
    say ""
    say "  echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ~/.zshrc   # or ~/.bashrc"
    say "  export PATH=\"${BIN_DIR}:\$PATH\""
    say ""
    say "Then get started with:  ${BINARY} login"
    ;;
esac
