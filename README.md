# Omarchy Plugin Pulse

<p align="center">
  <img src="assets/banner.png" alt="Plugin Pulse — track marketplace Views, Copies, and Hearts with authors, charts, and desktop growth alerts" width="100%" />
</p>

<p align="center"><b>Local-first Omarchy bar widget</b> for marketplace growth.<br/>
Track <b>Views · Copies · Hearts</b>, pool authors, and get alerts when you ship heat.</p>

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

* Multi-series line charts for views / copies / hearts / stars
* Hourly · Daily · Weekly · Monthly resolutions
* Per-plugin toggles and a totals table
* Configurable author filter (matches author name, plugin id, or repo URL)
* Local SQLite size, archive, and clear controls

## Data sources

| Source | URL | Purpose |
| --- | --- | --- |
| Catalog | `https://raw.githubusercontent.com/omacom/omarchy-plugin-marketplace/main/site/catalog.json` | Plugin metadata + `listedAt` |
| Stats | `https://api.omarchyplugins.com/v1/stats` | Current views / copies / hearts |
| GitHub | `https://api.github.com/repos/{owner}/{repo}` | Current star count (per plugin repo) |

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

## Keybinding

Optional Hyprland shortcut (add to `~/.config/hypr/bindings.lua`):

```lua
o.bind("SUPER + ALT + P", "Omarchy Plugin Pulse", "omarchy-shell shell toggle io.github.mtolhuys.plugin-pulse")
```

Then `hyprctl reload`. Toggle opens the Pulse popout if closed, and hides it if open.
