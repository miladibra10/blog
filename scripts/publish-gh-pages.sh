#!/usr/bin/env bash
# Publish ./public onto the gh-pages branch.
#
#   scripts/publish-gh-pages.sh root  public
#   scripts/publish-gh-pages.sh dir   public pr-preview/pr-12
#   scripts/publish-gh-pages.sh remove pr-preview/pr-12
#
# Root publishes replace the site and keep pr-preview/. Directory publishes
# replace only that preview path. The custom-domain CNAME stays at the branch root.
set -euo pipefail

mode="${1:-}"
if [[ -z "${COMMIT_MESSAGE:-}" ]]; then
  echo "COMMIT_MESSAGE is required" >&2
  exit 1
fi

case "$mode" in
  root)
    source_dir="$(realpath "${2:-}")"
    dest_subdir=""
    ;;
  dir)
    source_dir="$(realpath "${2:-}")"
    dest_subdir="${3:-}"
    case "$dest_subdir" in
      pr-preview/pr-[0-9]*) ;;
      *)
        echo "refusing to publish outside a pull-request preview path: ${dest_subdir}" >&2
        exit 1
        ;;
    esac
    ;;
  remove)
    source_dir=""
    dest_subdir="${2:-}"
    case "$dest_subdir" in
      pr-preview/pr-[0-9]*) ;;
      *)
        echo "refusing to remove a path outside pull-request previews: ${dest_subdir}" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "usage: publish-gh-pages.sh root <public-dir>" >&2
    echo "       publish-gh-pages.sh dir <public-dir> pr-preview/pr-<number>" >&2
    echo "       publish-gh-pages.sh remove pr-preview/pr-<number>" >&2
    exit 1
    ;;
esac

repo_root="$(git rev-parse --show-toplevel)"
work="$(mktemp -d)"
cleanup() {
  cd "$repo_root"
  git worktree remove --force "$work" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-github-actions[bot]}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"

cd "$repo_root"

if git ls-remote --exit-code --heads origin gh-pages >/dev/null 2>&1; then
  git fetch origin gh-pages
  git worktree add --detach "$work" origin/gh-pages
else
  empty_tree="$(git hash-object -t tree /dev/null)"
  commit="$(git commit-tree "$empty_tree" -m "initial gh-pages")"
  git worktree add --detach "$work" "$commit"
fi

cd "$work"

if [[ "$mode" == "root" ]]; then
  find . -mindepth 1 -maxdepth 1 ! -name .git ! -name pr-preview -exec rm -rf {} +
  cp -a "${source_dir}/." .
elif [[ "$mode" == "dir" ]]; then
  rm -rf "$dest_subdir"
  mkdir -p "$dest_subdir"
  cp -a "${source_dir}/." "${dest_subdir}/"
else
  if [[ ! -d "$dest_subdir" ]]; then
    echo "No preview at ${dest_subdir}; nothing to remove."
    exit 0
  fi
  rm -rf "$dest_subdir"
fi

if [[ ! -f CNAME ]]; then
  printf '%s\n' 'blog.miladibra.com' > CNAME
fi
if [[ ! -e .nojekyll ]]; then
  : > .nojekyll
fi

git add -A
if git diff --cached --quiet; then
  echo "No changes to publish."
  exit 0
fi

git commit -m "$COMMIT_MESSAGE"

attempt=1
while [[ "$attempt" -le 5 ]]; do
  if git push origin "HEAD:refs/heads/gh-pages"; then
    echo "Published to gh-pages (${mode}${dest_subdir:+ ${dest_subdir}})."
    exit 0
  fi
  echo "Push attempt ${attempt} failed; rebasing onto origin/gh-pages." >&2
  git fetch origin gh-pages
  git rebase origin/gh-pages
  attempt=$((attempt + 1))
done

echo "Failed to push gh-pages after 5 attempts." >&2
exit 1
