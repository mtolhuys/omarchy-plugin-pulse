# Changelog

## 0.1.1 — 2026-09-06

* GitHub stars as a fourth metric (fetch, charts/totals, growth alerts).
* Per-metric estimated history seeding, including backfill when a late-added metric already has observes without seeds.
* Documented Estimated history clearly in the README and agent notes.

## 0.1.0 — 2026-09-04

* Initial release: service + bar widget for marketplace growth charts.
* Python 3 stdlib helper with allowlisted HTTPS fetches and SQLite history.
* First-collect estimated history from `listedAt` → now (labeled in the UI).
* Hourly / daily / weekly / monthly resolutions, plugin toggles, author setting.
* Local archive / clear controls and DB size display.
