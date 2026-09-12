#!/usr/bin/env python3
"""Fetch curated RSS feeds and cache the top headlines as JSON for the
omarchy newsfeed bar widget. Stdlib only -- no external dependencies."""

import html
import json
import os
import re
import sys
import urllib.request
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from xml.etree import ElementTree

FEEDS = {
    "sports": [
        ("ESPN", "https://www.espn.com/espn/rss/news"),
        ("BBC Sport", "https://feeds.bbci.co.uk/sport/rss.xml"),
    ],
    "world": [
        ("BBC World", "https://feeds.bbci.co.uk/news/world/rss.xml"),
        ("NPR World", "https://feeds.npr.org/1004/rss.xml"),
    ],
    "us": [
        ("NPR News", "https://feeds.npr.org/1001/rss.xml"),
        ("BBC US & Canada", "https://feeds.bbci.co.uk/news/world/us_and_canada/rss.xml"),
    ],
    "cyber": [
        ("The Hacker News", "https://feeds.feedburner.com/TheHackersNews"),
        ("BleepingComputer", "https://www.bleepingcomputer.com/feed/"),
    ],
    "tech": [
        ("Ars Technica", "https://feeds.arstechnica.com/arstechnica/index"),
        ("The Verge", "https://www.theverge.com/rss/index.xml"),
    ],
}

CATEGORY_LABELS = {
    "sports": "Sports",
    "world": "World",
    "us": "U.S.",
    "cyber": "Cybersecurity",
    "tech": "Tech",
}

CACHE_DIR = os.path.expanduser("~/.cache/omarchy-newsfeed")
CACHE_FILE = os.path.join(CACHE_DIR, "headlines.json")
TIMEOUT = 8
MAX_TOTAL = 10
PER_CATEGORY_CAP = 15
UA = "Mozilla/5.0 (X11; Linux x86_64) omarchy-newsfeed/1.0"

TAG_RE = re.compile(r"<[^>]+>")
WS_RE = re.compile(r"\s+")


def clean_text(raw):
    if not raw:
        return ""
    text = TAG_RE.sub(" ", raw)
    text = html.unescape(text)
    text = WS_RE.sub(" ", text).strip()
    return text


def parse_date(value):
    if not value:
        return None
    try:
        dt = parsedate_to_datetime(value)
    except (TypeError, ValueError):
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read()


NS = {"atom": "http://www.w3.org/2005/Atom", "content": "http://purl.org/rss/1.0/modules/content/"}


def parse_feed(raw, source, category):
    items = []
    try:
        root = ElementTree.fromstring(raw)
    except ElementTree.ParseError:
        return items

    # RSS 2.0
    for item in root.findall(".//item"):
        title = clean_text((item.findtext("title") or ""))
        link = (item.findtext("link") or "").strip()
        pub = parse_date(item.findtext("pubDate"))
        desc = clean_text(
            item.findtext("description")
            or item.findtext("content:encoded", namespaces=NS)
            or ""
        )
        if not title or not link:
            continue
        items.append({
            "title": title,
            "link": link,
            "source": source,
            "category": category,
            "summary": desc[:600],
            "published": pub.isoformat() if pub else None,
            "_sort": pub or datetime.min.replace(tzinfo=timezone.utc),
        })

    # Atom
    if not items:
        for entry in root.findall("atom:entry", NS):
            title = clean_text(entry.findtext("atom:title", default="", namespaces=NS))
            link_el = entry.find("atom:link", NS)
            link = link_el.get("href") if link_el is not None else ""
            pub = parse_date(entry.findtext("atom:updated", default="", namespaces=NS)
                              or entry.findtext("atom:published", default="", namespaces=NS))
            desc = clean_text(entry.findtext("atom:summary", default="", namespaces=NS)
                               or entry.findtext("atom:content", default="", namespaces=NS))
            if not title or not link:
                continue
            items.append({
                "title": title,
                "link": link,
                "source": source,
                "category": category,
                "summary": desc[:600],
                "published": pub.isoformat() if pub else None,
                "_sort": pub or datetime.min.replace(tzinfo=timezone.utc),
            })

    return items


def collect():
    by_category = {cat: [] for cat in FEEDS}

    for category, sources in FEEDS.items():
        for source, url in sources:
            try:
                raw = fetch(url)
                by_category[category].extend(parse_feed(raw, source, category))
            except Exception as exc:  # noqa: BLE001 -- one dead feed shouldn't kill the run
                print(f"warning: {source} ({url}) failed: {exc}", file=sys.stderr)

    for cat in by_category:
        by_category[cat].sort(key=lambda x: x["_sort"], reverse=True)

    # Curated selection: an even split across categories (10 slots / 5
    # categories = 2 each, most recent first) so a fast-publishing category
    # like tech or cyber can't crowd out sports or world news. Any shortfall
    # (a category with fewer than its share) is backfilled by global recency.
    per_category = MAX_TOTAL // len(FEEDS)
    picked = []
    seen_links = set()

    for items in by_category.values():
        for item in items[:per_category]:
            picked.append(item)
            seen_links.add(item["link"])

    remaining = sorted(
        (item for items in by_category.values() for item in items if item["link"] not in seen_links),
        key=lambda x: x["_sort"],
        reverse=True,
    )

    for item in remaining:
        if len(picked) >= MAX_TOTAL:
            break
        if item["link"] in seen_links:
            continue
        picked.append(item)
        seen_links.add(item["link"])

    picked.sort(key=lambda x: x["_sort"], reverse=True)
    picked = picked[:MAX_TOTAL]

    for item in picked:
        item.pop("_sort", None)
        item["categoryLabel"] = CATEGORY_LABELS.get(item["category"], item["category"])

    by_category_out = {}
    for cat, items in by_category.items():
        capped = items[:PER_CATEGORY_CAP]
        for item in capped:
            item.pop("_sort", None)
            item["categoryLabel"] = CATEGORY_LABELS.get(item["category"], item["category"])
        by_category_out[cat] = capped

    return picked, by_category_out


def main():
    os.makedirs(CACHE_DIR, exist_ok=True)
    headlines, by_category = collect()
    payload = {
        "fetchedAt": datetime.now(timezone.utc).isoformat(),
        "headlines": headlines,
        "byCategory": by_category,
    }
    tmp_path = CACHE_FILE + ".tmp"
    with open(tmp_path, "w") as fh:
        json.dump(payload, fh, indent=2)
    os.replace(tmp_path, CACHE_FILE)
    total_cat = sum(len(v) for v in by_category.values())
    print(f"wrote {len(headlines)} curated + {total_cat} by-category headlines to {CACHE_FILE}")


if __name__ == "__main__":
    main()
