## Release v1.0.3 — 2026-01-24

- **Version:** 1.0.3+4
- **Highlights:** Bug fixes, dependency updates, and polish across onboarding and payments.

### Notes
- Updated `pubspec.yaml` version to `1.0.3+4`.
- See full commit history for details.

---

## What's Changed

### Architecture Improvements
- Clean Architecture Enforcement: Restructured nostr/ and recovery/ features with proper data/domain/presentation/services subfolders
- 25+ files moved to correct architecture locations
- 50+ import paths fixed with proper package imports

### Documentation
- README.md: Complete rewrite with badges, architecture diagram, setup guide, and contribution links
- CONTRIBUTING.md: New comprehensive contributor guide with code style, testing, and PR process
- GitHub Issue Templates: Added bug-report, feature-request, and good-first-issue templates
- docs/GOOD_FIRST_ISSUES.md: 5 beginner-friendly issues documented

### Code Quality
- 144 files formatted with dart format
- 0 errors from flutter analyze
- Consistent code style across the entire codebase

### Stats
- 169 files changed
- 5,031 insertions
- 3,509 deletions

**Full Changelog**: https://github.com/auwalrg8/Sabi/compare/v1.0.0-beta.3...v1.0.0-beta.4
