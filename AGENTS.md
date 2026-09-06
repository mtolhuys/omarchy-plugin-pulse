# Omarchy Plugin Pulse — agent notes

Plugin Pulse is a local-first Omarchy **service + bar-widget** that charts marketplace views/copies/hearts plus GitHub stars for an accumulating multi-author plugin pool.

## Layout

* `manifest.json` — `keepLoaded: true`, kinds `service` + `bar-widget`, default bar section `right`
* `bin/pulse` — Python 3 stdlib collector / SQLite store / JSON snapshot CLI
* `src/Service.qml` — hourly collect + snapshot state for the widget
* `src/BarWidget.qml` — KeyboardPanel UI with resolution chips, Canvas chart, toggles, totals
* `src/LineChart.qml` — multi-series line chart
* `src/Model.js` — parse/format helpers

## Invariants

1. Authors are multi-select (`tracked_authors` + `enabled_authors`); enabling pulls matching catalog plugins into a shared pool. Match against author / id / repo text. No baked-in default author.
2. HTTPS only to allowlisted origins: raw.githubusercontent.com (catalog), api.omarchyplugins.com (stats), and api.github.com (stars).
3. Estimated history is **per metric**: on first write of views/copies/hearts/stars, seed a smooth monotonic curve from `listedAt` → first observed value (not real historic data). If a metric already has observes but zero seeds (late-added stars), backfill seeds before the earliest observe without rewriting observes or alerting. UI must say **Estimated history**.
4. State under XDG state dir; retention + ~8 MiB hard cap; archive/clear available.
5. Theme-native `Color` / `Style` / `Border` like Disk Lens.
6. Do not marketplace-submit unless explicitly requested.

## Commands

```bash
./bin/pulse collect
./bin/pulse snapshot --resolution daily
./bin/pulse enable-author <key>
./bin/pulse disable-author <key>
./bin/pulse authors
./bin/pulse status
make test
make validate
```
