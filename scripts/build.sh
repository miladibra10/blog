#!/usr/bin/env bash
# Build the site. Pass a base URL to override hugo.toml (used for previews).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

base_url="${1:-https://blog.miladibra.com/}"
case "$base_url" in
  */) ;;
  *) base_url="${base_url}/" ;;
esac

args=(--minify --baseURL "$base_url")
if [[ "${HUGO_BUILDDRAFTS:-}" == "true" ]]; then
  args+=(--buildDrafts --buildFuture)
fi

hugo "${args[@]}"

if [[ "${HUGO_ENV:-}" == "preview" ]]; then
  printf 'User-agent: *\nDisallow: /\n' > public/robots.txt
fi

python3 scripts/check_feed.py "$base_url"

test -s public/index.html
test -s public/CNAME
grep -q 'blog.miladibra.com' public/CNAME
test -f public/.nojekyll
test -s public/about/index.html
test -s public/posts/index.html
test -s public/search/index.html
test -s public/search/index.json
test -s public/404.html
