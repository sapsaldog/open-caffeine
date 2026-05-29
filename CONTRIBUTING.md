# Contributing to Open Caffeine

Thanks for your interest in improving Open Caffeine! This is a small, focused
macOS menu-bar utility. Contributions of all sizes are welcome — bug reports,
fixes, and well-scoped features.

## Prerequisites

- macOS 26 (Tahoe) or newer, Apple Silicon
- Xcode 26+
- Command-line tools:

  ```bash
  brew install xcodegen swiftlint
  ```

The Xcode project is **generated** from `project.yml` by XcodeGen and is not
committed. Always regenerate it after pulling or editing `project.yml`:

```bash
xcodegen generate
```

## Build & run

```bash
xcodegen generate
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Debug build
```

Or open `OpenCaffeine.xcodeproj` in Xcode and run the `OpenCaffeine` scheme.

## Tests & the coverage gate

```bash
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -destination 'platform=macOS' test
```

Every **logic** file must keep **100% line coverage**. The gate enforces this:

```bash
Scripts/coverage-gate.sh
```

It runs automatically on `git push` via a pre-push hook. Enable it once per clone:

```bash
git config core.hooksPath Scripts/hooks
```

Only UI/AppKit/system *shells* are exempt (the justified list lives in
`Scripts/coverage_check.py`). New source files are **not** exempt by default —
adding one forces a choice: test it, or extract its logic and list the shell.
See the README's "Coverage" section for the rationale.

## Code style

- SwiftLint runs as a build phase; the build fails on rule errors. Run
  `swiftlint` locally before pushing.
- Hard cap of **500 lines per file** (warning at 400). Split before you hit it.
- Match the conventions and naming already in the surrounding code.

## Pull requests

1. Fork and branch from `main` (e.g. `fix/...`, `feat/...`, `chore/...`).
2. Keep PRs focused; one logical change per PR.
3. Make sure `swiftlint`, the test suite, and `Scripts/coverage-gate.sh` all pass.
4. Update `CHANGELOG.md` under an `## [Unreleased]` section when your change is
   user-facing.
5. Fill out the PR template and describe what you changed and why.

## Releases

Releases are cut with the `Scripts/release.sh` flow (version bump in
`project.yml`, signed Sparkle appcast, GitHub release). Most contributors don't
need to touch this — maintainers handle release tagging.

## Reporting bugs & requesting features

Use the GitHub issue templates. For security-sensitive reports, follow
[`SECURITY.md`](SECURITY.md) instead of opening a public issue.

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
