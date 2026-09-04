# Security notes

* Network: GET-only HTTPS to two fixed origins. Redirects that leave the allowlist fail closed.
* Responses are size-bounded (12 MiB) and time-bounded.
* User-Agent identifies this plugin; no cookies or auth headers.
* Storage: SQLite under the user XDG state directory only.
* The helper never executes downloaded content; catalog/stats are JSON aggregates.
* Paths and author strings are treated as data and passed as argv, not interpolated into a shell.
