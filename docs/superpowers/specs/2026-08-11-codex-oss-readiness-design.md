# Codex for Open Source Readiness Design

## Goal

Present Open Caffeine and its maintainer accurately as an active open-source
project, add independently verifiable continuous integration, and prepare a
fact-based Codex for Open Source application without inflating adoption or
promising unsupported work.

## Scope

This work covers four surfaces:

1. Open Caffeine repository documentation and GitHub metadata.
2. A GitHub Actions quality gate for pull requests and the default branch.
3. The maintainer's public GitHub profile and pinned repositories.
4. A private application-answer draft built from verified public and
   maintainer-visible metrics.

It does not change application behavior, add macOS 15 support, sign or notarize
the application, submit the OpenAI application, or modify the other portfolio
repositories. GitHub issue #4 has already been answered and closed as not
planned because Open Caffeine intentionally targets macOS 26 and its native
Liquid Glass UI.

## Positioning and Copy

Open Caffeine will be described as an open-source macOS menu-bar utility rather
than a personal utility. The opening documentation will state the actual
platform floor (Apple Silicon and macOS 26 or newer) and distinguish two facts
that are currently easy to confuse: release archives are available from GitHub,
but the application itself is not code-signed or notarized.

The README will add a compact feature summary and an installation path through
GitHub Releases before the source-build instructions. It will retain the
Product Hunt recognition, testing policy, contribution guidance, release
process, and existing architecture documentation. It will not embed volatile
star, clone, view, or download counters in repository copy.

The repository About description will summarize the product and the topics will
make its technology and purpose discoverable. Proposed topics are `macos`,
`swift`, `swiftui`, `menu-bar`, `productivity`, `open-source`, and `sparkle`.

The maintainer profile bio will use a short factual line:

> Building practical open-source tools for macOS, developer workflows, and
> Korean SaaS integrations.

Existing company, location, and other profile fields will be preserved. The
profile will pin `open-caffeine`, `oh-my-worktree`, and
`supabase-naver-oidc-proxy`, in that order, using GitHub's authenticated web UI
because the public GitHub API does not expose user-profile pin management.

## Continuous Integration

Create `.github/workflows/ci.yml` with one quality-gate job:

- Trigger on pull requests, pushes to `main`, and manual dispatch.
- Use the standard public-repository `macos-26` GitHub-hosted runner so the
  repository's macOS 26 deployment target and Xcode 26 toolchain are available.
- Grant only `contents: read` permission.
- Cancel superseded runs for the same branch or pull request.
- Check out the repository, install XcodeGen and SwiftLint with Homebrew, and
  run `Scripts/coverage-gate.sh`.

The existing coverage script remains the single source of truth: it generates
the Xcode project, runs the test suite with coverage, and rejects any tested
logic file below 100% line coverage. CI will not duplicate those commands or
introduce a separate coverage policy. Dependency caching is deliberately out of
scope until runtime data shows it is necessary.

## Application Evidence

The application draft will lead with Open Caffeine and use the other two
projects as supporting evidence of sustained maintenance breadth. Every number
will be timestamped and traceable to GitHub or the existing Product Hunt badge.
The initial evidence set is:

- Open Caffeine: 45 stars, three releases, 166 release-asset downloads, Product
  Hunt #10 Product of the Day, MIT license, and active maintainer controls.
- Oh My Worktree: 15 stars, two forks, 21 releases, 82 release-asset downloads,
  and 109 maintainer commits.
- Supabase Naver OIDC Proxy: 19 stars and eight forks, addressing a specific
  Supabase/Naver interoperability gap for Korean developers.

The narrative will identify the applicant as the core maintainer with write
access and explain concrete Codex uses: issue triage, compatibility analysis,
test generation, pull-request review, documentation maintenance, and release
automation. It will not claim that any project is widely used, that download
counts equal unique users, or that external contributors exist where they do
not.

The application draft is a user-facing artifact and will be saved outside the
repository under the current Codex task's `outputs` directory. Final submission
will remain a separate, explicit user-approved action.

## Delivery and Verification

Repository file changes will be committed on `agent/codex-oss-readiness`,
pushed, and opened as a draft pull request. The pull request must show a passing
GitHub Actions run before it is considered ready. Local checks will run first
when the installed macOS and Xcode versions satisfy the project's version floor;
otherwise the hosted `macos-26` job is the authoritative verification.

GitHub repository metadata and profile bio are small direct API updates and will
be verified by reading them back. Profile pins will be verified visually after
the authenticated UI update. The application draft will include a final source
check so metrics that changed during implementation are refreshed before handoff.

If CI fails because of runner-image provisioning or tool availability, the
failure will be investigated from the Actions logs and corrected in the same
branch. The quality gate will not be weakened or marked optional merely to make
the workflow green.
