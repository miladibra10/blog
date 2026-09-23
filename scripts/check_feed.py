#!/usr/bin/env python3
"""Fail the build unless the RSS feed is something dev.to can import."""

import html
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlparse

CONTENT_NS = "http://purl.org/rss/1.0/modules/content/"
ATOM_NS = "http://www.w3.org/2005/Atom"


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: check_feed.py <base-url>")
    base = sys.argv[1]
    if not base.endswith("/"):
        base += "/"

    feed_path = Path("public/index.xml")
    if not feed_path.is_file():
        raise SystemExit("public/index.xml was not generated")

    root = ET.parse(feed_path).getroot()
    if root.tag != "rss":
        raise SystemExit(f"expected an rss root, found {root.tag}")

    channel = root.find("channel")
    if channel is None:
        raise SystemExit("RSS feed has no channel")

    self_link = channel.find(f"{{{ATOM_NS}}}link")
    if self_link is None or not (self_link.get("href") or "").startswith(base):
        raise SystemExit("RSS atom:link does not use the site base URL")

    items = channel.findall("item")
    if not items:
        raise SystemExit("RSS feed has no posts for dev.to to import")

    for item in items:
        title = (item.findtext("title") or "").strip()
        link = (item.findtext("link") or "").strip()
        encoded = item.find(f"{{{CONTENT_NS}}}encoded")
        body = encoded.text if encoded is not None and encoded.text else ""
        if not title:
            raise SystemExit("RSS item is missing a title")
        if not link.startswith(base):
            raise SystemExit(f"RSS item link is not absolute: {link}")
        if "<p>" not in body and "<a " not in body:
            raise SystemExit(f"RSS item {title!r} does not contain HTML content")
        text = html.unescape(body)
        if 'href="/' in text or 'src="/' in text:
            raise SystemExit(
                f"RSS item {title!r} still has a root-relative URL in its HTML"
            )
        host = urlparse(base).netloc
        for url in re.findall(r'(?:href|src)="([^"]+)"', text):
            parsed = urlparse(url)
            if parsed.netloc == host and not url.startswith(base):
                raise SystemExit(
                    f"RSS item {title!r} links to {url}, outside {base}"
                )

    home = Path("public/index.html").read_text()
    if f'href={base}' not in home and f'href="{base}"' not in home:
        raise SystemExit(f"home page logo does not point at {base}")

    search_index = Path("public/search/index.json").read_text()
    if '"permalink":' not in search_index:
        raise SystemExit("search index is missing permalinks")
    for permalink in re.findall(r'"permalink":"([^"]+)"', search_index):
        if not permalink.startswith(base):
            raise SystemExit(f"search permalink is not under the base URL: {permalink}")

    print(f"RSS feed ok: {len(items)} post(s), full content, absolute URLs")


if __name__ == "__main__":
    main()
