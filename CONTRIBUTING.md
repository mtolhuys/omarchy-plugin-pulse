# Contributing

Thanks for helping make marketplace growth easier to see on Omarchy.

## Before starting

Read [`AGENTS.md`](AGENTS.md) and the notes under [`docs/`](docs/). Behavior changes should update docs and tests in the same change.

## Principles

* Keep the author filter configurable — never hard-lock the product to one publisher.
* Keep network access allowlisted, bounded, and anonymous.
* Prefer clear estimated-vs-observed labeling over silent invention.
* Keep the helper on Python 3 stdlib unless there is a strong reason not to.
* Theme colors and spacing come from Omarchy `Color` / `Style` / `Border` contracts.

## Testing

Run `make test` and `make validate`. Prefer the disposable Omarchy Plugin Lab for visual checks. Do not treat a daily host as the primary test bed.

## Pull requests

* Keep commits focused and explain the user-visible effect.
* Do not marketplace-submit from contributor workflows unless the maintainer asks.
* Keep docs and fixtures free of private machine data.
