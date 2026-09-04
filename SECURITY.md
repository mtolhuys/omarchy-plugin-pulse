# Security policy

## Reporting a vulnerability

Please report security issues privately to the repository owner through GitHub’s private vulnerability reporting when available. Do not open a public issue that includes private paths, live credentials, or a working exploit.

Include the affected version, expected and observed behavior, and whether the issue can leave the allowlisted network boundary or corrupt the local history store.

## Supported versions

| Version | Supported |
| --- | --- |
| `0.1.0` | Yes |

## Security boundary

Plugin Pulse is a same-user, local-first viewer. It only contacts two public HTTPS origins (marketplace catalog + stats), stores anonymous aggregate counters locally, and never needs credentials, root, or write access outside its XDG state directory. Engineering details live in [`docs/SECURITY.md`](docs/SECURITY.md).
