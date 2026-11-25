---
name: release
description: Use when cutting / publishing a new Open Caffeine version — bumps the version, builds the app, signs it with Developer ID and notarizes it, EdDSA-signs the zip, regenerates the Sparkle appcast, creates the GitHub release, and pushes the update feed so existing installs auto-update.
---

# Release Open Caffeine

Publishes a new versioned build as a Sparkle auto-update. Updates are served from
`appcast.xml` in this repo (the app's `SUFeedURL` is
`https://raw.githubusercontent.com/sapsaldog/open-caffeine/main/appcast.xml`) and
EdDSA-signed with the private key in the login keychain. The app itself is signed
with the team's Developer ID and notarized by Apple.

## Prerequisites (login keychain)

- A **Developer ID Application** certificate of team `KN8CUHG7SN`: Xcode › Settings ›
  Accounts › Manage Certificates… › + › Developer ID Application (Account Holder only).
- **notarytool credentials** saved as `open-caffeine-notary`. The user runs this
  (it asks for an app-specific password from account.apple.com — never ask for it):
  ```bash
  xcrun notarytool store-credentials open-caffeine-notary \
      --apple-id <Apple ID> --team-id KN8CUHG7SN
  ```
- Sparkle's **EdDSA private key**.

`Scripts/release.sh` checks the first two before it builds and says what's missing.

## Checklist

1. **Pick the version.** Ask the user for the new version if they didn't say one
   (semver, e.g. `0.2.0`). In `project.yml` set `MARKETING_VERSION` to it and bump
   `CURRENT_PROJECT_VERSION` by 1 (Sparkle compares the build number). In
   `CHANGELOG.md`, add `## [<version>] - <date>` under `## [Unreleased]`, point the
   `[Unreleased]` link at `v<version>...HEAD`, and add a `[<version>]` compare link.

2. **Build, sign, notarize, and regenerate the appcast:**
   ```bash
   Scripts/release.sh
   ```
   This builds Release without coverage instrumentation, signs every executable
   inside out with Developer ID (hardened runtime, secure timestamp), checks the
   lid-mode trust requirement, notarizes and staples the app, zips it to
   `dist/Open-Caffeine-<version>.zip`, EdDSA-signs the zip, and rewrites
   `appcast.xml`. Notarization usually takes a few minutes. To try the signing
   without notarizing, sign with another certificate of the team:
   `SIGN_ONLY=1 SIGN_IDENTITY=<SHA-1> Scripts/release.sh`.

3. **Commit and push the tag** (so the tag points at the version bump):
   ```bash
   git add appcast.xml project.yml CHANGELOG.md
   git commit -m "Release v<version>"
   git tag v<version>
   git push origin v<version>
   ```

4. **Create the GitHub release from that tag and upload the zip:**
   ```bash
   gh release create v<version> "dist/Open-Caffeine-<version>.zip" --verify-tag \
       --title "v<version>" --notes "<notes>"
   ```
   For notes, summarize `git log <previous tag>..HEAD` (ask the user to confirm).
   The appcast's download URL is
   `…/releases/download/v<version>/Open-Caffeine-<version>.zip`, so the tag and
   asset name must match exactly.

5. **Publish the feed** (only now, so the download already exists):
   ```bash
   git push origin HEAD:main
   ```
   `SUFeedURL` now serves the new entry; existing installs pick it up on their
   next check (or via Updates › Check Now).

6. **Verify** in `appcast.xml`: there is an `<item>` for the new version with a
   `sparkle:edSignature`, a `sparkle:version` equal to `CURRENT_PROJECT_VERSION`,
   and a `url` pointing at the uploaded GitHub asset. Download the asset and check
   `spctl -a -vv -t exec` on the app says `source=Notarized Developer ID`.

## Notes / gotchas

- Run from a clean tree at `origin/main` (a worktree branch at the same commit
  works, pushed with `HEAD:main`). The coverage gate runs on every push (pre-push
  hook), tag pushes included.
- `dist/` is gitignored — only `appcast.xml` (+ the version bump and CHANGELOG) is
  committed.
- The EdDSA **private key** lives in the login keychain; never commit it. The
  public key is `SUPublicEDKey` in `Info.plist`.
- Never ship an ad-hoc build: lid mode's helper only trusts peers signed by the
  same team (`LidSleepHelper.requirement(forPeer:)`), so an ad-hoc release shows a
  switch that can't work. `release.sh` stops if any executable lacks the team's
  signature.
- Sparkle ships its helpers (XPC services, `Autoupdate`, `Updater.app`) ad-hoc
  signed, and `release.sh` re-signs them. If a Sparkle update moves or adds one,
  the per-executable check fails; update the signing block to match.
- Update channels (Stable/Beta) are a stored preference but not yet wired to
  Sparkle channels — a single Stable feed is published today.
