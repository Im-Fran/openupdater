# Security Policy

OpenUpdater downloads and installs code, so security reports are taken seriously.

## Supported versions

Only the latest commit on `dev` (and the latest release, once releases exist) receives security fixes.

## Reporting a vulnerability

**Please do not open a public issue.** Report it privately through
[GitHub Security Advisories](https://github.com/Im-Fran/openupdater/security/advisories/new).

Include:

- A description of the issue and its impact
- Steps to reproduce or a proof of concept
- The affected commit or version

You can expect an initial response within 7 days. Once a fix is ready, it will be released and the
advisory published, crediting you unless you prefer otherwise.

## Scope

In scope, for example:

- Bypassing the Ed25519 signature or code-signature verification
- Installing a bundle other than the verified one, or path manipulation during install
- Leaking or mishandling keys in `openupdater-cli`

Out of scope:

- Compromise of a developer's private signing key or GitHub account
- Apps that don't follow the documented requirements (e.g. ad-hoc signed or sandboxed apps)
