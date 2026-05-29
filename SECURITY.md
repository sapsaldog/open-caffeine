# Security Policy

## Supported versions

Open Caffeine is a small, actively developed utility. Security fixes are made
against the latest released version only.

| Version | Supported |
| ------- | --------- |
| 1.0.x   | ✅        |
| < 1.0   | ❌        |

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Instead, report privately via GitHub's
[private vulnerability reporting](https://github.com/sapsaldog/open-caffeine/security/advisories/new)
(Security → Report a vulnerability), or email the maintainer at
**sapsaldog@gmail.com**.

Please include:

- a description of the issue and its impact,
- steps to reproduce (or a proof of concept),
- the app version and your macOS version.

You can expect an initial acknowledgement within a few days. Once a fix is
ready, it will ship in a new release and the report will be credited unless you
prefer to remain anonymous.

## Update integrity

Automatic updates are delivered through [Sparkle](https://sparkle-project.org)
and are **EdDSA-signed**. The public key (`SUPublicEDKey`) is embedded in the
app's `Info.plist`, and Sparkle verifies every downloaded update against it, so
a tampered or unsigned update will be rejected. The app is currently distributed
unsigned (local/personal builds), so macOS Gatekeeper may quarantine downloads.
