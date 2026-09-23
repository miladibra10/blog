# blog

Hugo blog for [blog.miladibra.com](https://blog.miladibra.com/), using the [Archie](https://github.com/athul/archie) theme. Posts are the canonical versions. [dev.to](https://dev.to/) imports them from the RSS feed.

## Local preview

Hugo **0.166.0** extended is pinned in `.hugo-version`.

```bash
git submodule update --init --recursive
./scripts/install-hugo.sh
hugo server -D --baseURL http://localhost:1313/ --disableFastRender
```

The draft server is at <http://localhost:1313/>. `./scripts/build.sh` builds the production site and checks that the RSS feed contains full post HTML.

## Write a post

```bash
hugo new posts/my-new-post.md
```

Front matter:

```yaml
---
title: "Post title"
description: "One sentence summary."
date: 2026-09-23T21:00:00Z
draft: true
tags: ["example"]
toc: false
# tldr: "Optional short summary shown above the post."
---
```

`draft: true` keeps the post off the production site. Pull-request previews still build drafts, so you can read the post before it is published. Set `draft` to `false` when it should go live.

Tags are copied into the RSS feed as categories. dev.to accepts lowercase tags, so prefer those.

Open a pull request for the post. The **Preview site** workflow comments with a preview URL and also prints that URL in the Actions job summary:

`https://blog.miladibra.com/pr-preview/pr-<number>/`

Previews are published for pull requests opened from this repository. Closing the pull request removes that preview. Merging to `main` publishes the production site and leaves other open previews in place.

## RSS and dev.to

Production feed:

`https://blog.miladibra.com/index.xml`

The feed contains the full HTML of every published post, with absolute URLs, tags, and permalinks. dev.to uses the permalink as the canonical URL when you turn that option on.

In dev.to, open **Settings → Extensions → Publishing to DEV Community from RSS** (or **Dashboard → RSS Import Feeds**) and submit:

- Feed URL: `https://blog.miladibra.com/index.xml`
- Mark the RSS source as the canonical URL

Only posts under `content/posts` are included. About, search, and drafts are left out of the production feed.

## GitHub Pages

Production deploys from `main` onto the `gh-pages` branch. One-time setup in the repository:

1. **Settings → Pages → Build and deployment → Source:** Deploy from a branch.
2. **Branch:** `gh-pages`, folder `/ (root)`.
3. **Settings → Actions → General → Workflow permissions:** Read and write permissions. The deploy and preview workflows push to `gh-pages` and the preview workflow comments on pull requests.

DNS for the subdomain, at the registrar for `miladibra.com`:

```text
blog  CNAME  miladibra10.github.io
```

GitHub also shows the expected records under **Settings → Pages** after the `CNAME` file is published. The first production deploy writes `blog.miladibra.com` to `gh-pages`.

## Theme

The theme is the git submodule `themes/archie`, pinned to a commit. Update it with:

```bash
git submodule update --remote themes/archie
```
