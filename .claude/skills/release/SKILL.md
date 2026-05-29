---
name: release
description: Use when cutting / publishing a new Open Caffeine version — bumps the version, builds & EdDSA-signs the app, regenerates the Sparkle appcast, creates the GitHub release, and pushes the update feed so existing installs auto-update.
---

# Release Open Caffeine

Publishes a new versioned build as a Sparkle auto-update. Updates are served from
`appcast.xml` in this repo (the app's `SUFeedURL` is
`https://raw.githubusercontent.com/sapsaldog/open-caffeine/main/appcast.xml`) and
EdDSA-signed with the private key in the login keychain.

## Checklist

1. **Pick the version.** Ask the user for the new version if they didn't say one
   (semver, e.g. `0.2.0`). In `project.yml` set `MARKETING_VERSION` to it and bump
   `CURRENT_PROJECT_VERSION` by 1 (Sparkle compares the build number).

2. **Build, sign, and regenerate the appcast:**
   ```bash
   Scripts/release.sh
   ```
   This builds Release, zips the app to `dist/Open-Caffeine-<version>.zip`,
   EdDSA-signs it, and rewrites `appcast.xml`. If it reports the Sparkle tools are
   missing, build once in Xcode (or run the coverage gate) to resolve packages,
   then retry.

3. **Create the GitHub release and upload the zip:**
   ```bash
   gh release create v<version> "dist/Open-Caffeine-<version>.zip" \
       --title "v<version>" --notes "<notes>"
   ```
   For notes, summarize `git log <previous tag>..HEAD` (ask the user to confirm).
   The appcast's download URL is
   `…/releases/download/v<version>/Open-Caffeine-<version>.zip`, so the tag and
   asset name must match exactly.

4. **Publish the feed:**
   ```bash
   git add appcast.xml project.yml
   git commit -m "Release v<version>"
   git push
   ```
   `SUFeedURL` now serves the new entry; existing installs pick it up on their
   next check (or via Updates › Check Now).

5. **Verify** in `appcast.xml`: there is an `<item>` for the new version with a
   `sparkle:edSignature`, a `sparkle:version` equal to `CURRENT_PROJECT_VERSION`,
   and a `url` pointing at the uploaded GitHub asset.

## Notes / gotchas

- Run from a clean tree on `main`; the coverage gate runs on push (pre-push hook).
- `dist/` is gitignored — only `appcast.xml` (+ the version bump) is committed.
- The EdDSA **private key** lives in the login keychain; never commit it. The
  public key is `SUPublicEDKey` in `Info.plist`.
- The app is currently unsigned (local-only). Updates are EdDSA-signed so Sparkle
  trusts them, but macOS may quarantine the downloaded app. For frictionless
  updates, Developer ID sign + notarize the `.app` and zip before step 3.
- Update channels (Stable/Beta) are a stored preference but not yet wired to
  Sparkle channels — a single Stable feed is published today.
