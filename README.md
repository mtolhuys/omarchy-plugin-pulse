# Omarchy Plugin Pulse

Local-first bar widget that charts marketplace growth for plugins by a configurable author (default `mtolhuys`).

Plugin Pulse keeps an on-disk history of **views**, **copies**, and **hearts** from the public Omarchy marketplace stats API, joined with listing metadata from the marketplace catalog. The first collect seeds a smooth estimated curve from each plugin’s `listedAt` time to now so the chart is useful immediately; the UI labels that as **Estimated history**.

## Install

```bash
omarchy plugin add https://github.com/mtolhuys/omarchy-plugin-pulse.git --enable
```

Update:

```bash
omarchy plugin update io.github.mtolhuys.plugin-pulse
```

Remove:

```bash
omarchy plugin remove io.github.mtolhuys.plugin-pulse
```

### Enable the bar widget

1. Install and enable the plugin (command above).
2. Open **Omarchy → Bar / Widgets** (or your bar layout settings).
3. Add **Plugin Pulse** to a bar section (defaults to the **right** section).
4. Click the pulse icon in the bar to open the panel. Middle-click refreshes.

Requires Omarchy Quattro with third-party `schemaVersion: 1` **service** + **bar-widget** support and Python 3 (stdlib only: `sqlite3`, `urllib`).

## What it shows

* Multi-series line charts for views / copies / hearts
* Hourly · Daily · Weekly · Monthly resolutions
* Per-plugin toggles and a totals table
* Configurable author filter (matches author name, plugin id, or repo URL)
* Local SQLite size, archive, and clear controls

## Data sources

| Source | URL | Purpose |
| --- | --- | --- |
| Catalog | `https://raw.githubusercontent.com/omacom/omarchy-plugin-marketplace/main/site/catalog.json` | Plugin metadata + `listedAt` |
| Stats | `https://api.omarchyplugins.com/v1/stats` | Current views / copies / hearts |

Requests are HTTPS-only, origin-allowlisted, size-bounded, and sent with a clear `User-Agent`. Nothing is uploaded.

## Storage

State lives under `$XDG_STATE_HOME/omarchy-plugin-pulse/` (usually `~/.local/state/omarchy-plugin-pulse/`).

Retention aims for hourly detail (~72h), daily (~90d), weekly (~2y), and a tiny monthly tail, with a hard size cap near **8 MiB**. **Archive** copies the DB aside and drops seed points; **Clear** deletes samples.

## Development

```bash
make test
make validate
```

Helper CLI:

```bash
./bin/pulse collect
./bin/pulse snapshot --resolution daily
./bin/pulse status
```

## License

MIT — see [LICENSE](LICENSE).
