# Omarchy News Feed

A curated news headlines widget for [Omarchy](https://omarchy.org/). Adds a
📰 icon to the bar; click it for a dropdown of recent headlines across five
categories, with per-category filter tabs and a summary view for each story.

- **Categories:** Sports, World, U.S., Cybersecurity, Tech (with an "All"
  tab showing a balanced curated mix of the 10 most recent across all five)
- **Per story:** title, source, relative time, and a short summary pulled
  from the article's own feed description, with a link to open the full
  article in your browser
- **Self-contained:** headlines are fetched by a bundled Python script
  (stdlib only, no extra dependencies) on a timer inside the widget itself
  — no separate systemd unit or cron job to set up

## Install

```
omarchy plugin add https://github.com/benjamin-romaine/Omarchy_RSS_Newsfeed.git --enable
```

Or clone manually into `~/.config/omarchy/plugins/` and run
`omarchy-shell shell rescanPlugins`, then add the widget to your bar with:

```
omarchy bar put io.github.benjamin-romaine.omarchy-newsfeed --section right
```

## Requirements

- Python 3 (stdlib only — no pip packages needed)
- `xdg-open` (used to open articles in your default browser)

## Customizing feed sources

Edit the `FEEDS` dict at the top of `fetch-news.py` — each category maps to
a list of `(source name, RSS/Atom URL)` pairs. The widget refreshes on its
own timer (`refreshIntervalMs` in `NewsFeedPanel.qml`, default 20 minutes),
or you can trigger a manual refresh from the "⟳ Refresh" link in the
dropdown.

## License

MIT — see [LICENSE](LICENSE).
