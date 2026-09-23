#!/usr/bin/env bash
# Install the Hugo extended binary pinned in .hugo-version.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(tr -d '[:space:]' < "${root}/.hugo-version")"

if command -v hugo >/dev/null 2>&1 && hugo version | grep -q "v${version}"; then
  hugo version
  exit 0
fi

asset="hugo_extended_${version}_linux-amd64.tar.gz"
url="https://github.com/gohugoio/hugo/releases/download/v${version}/${asset}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "${tmp}/hugo.tar.gz" "$url"

if [[ -w /usr/local/bin ]]; then
  tar -xzf "${tmp}/hugo.tar.gz" -C /usr/local/bin hugo
elif command -v sudo >/dev/null 2>&1; then
  sudo tar -xzf "${tmp}/hugo.tar.gz" -C /usr/local/bin hugo
else
  mkdir -p "${HOME}/.local/bin"
  tar -xzf "${tmp}/hugo.tar.gz" -C "${HOME}/.local/bin" hugo
  export PATH="${HOME}/.local/bin:${PATH}"
fi

hugo version
