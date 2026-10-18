# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 1.0.x | ✅ |
| < 1.0 | ❌ (upgrade) |

## Reporting a vulnerability

Please use GitHub's **private security advisory**
([Security → Advisories → New draft advisory](https://github.com/ashish-jha-73/IkshvakuPEM/security/advisories/new))
rather than a public issue.

Ikshvaku is a shell tool that executes commands and downloads installers over
HTTPS. Of particular interest:

- Anything that executes code outside the user's explicit intent
  (e.g. injection through environment names or package arguments)
- Insecure download or extraction in the installers/bootstrap
- Path traversal in environment handling (`~/.Python-Env/<name>`)

## Scope

The installers intentionally download and run two things over TLS:
`uv` (from [astral.sh](https://astral.sh)) and Ikshvaku's own payload files
(from this repository). Reports about the uv installer itself belong
[upstream](https://github.com/astral-sh/uv/security).
