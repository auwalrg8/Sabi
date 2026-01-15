# Good First Issues for Sabi Wallet

Below are 5 beginner-friendly issues that new contributors can work on. Create these as GitHub issues using the templates.

---

## Issue #1: Improve Button Spacing on Send Screen

**Labels**: `good first issue`, `ui/ux`, `help wanted`

### Description
The Send screen buttons need better spacing for improved user experience on different screen sizes.

### Acceptance Criteria
- [ ] Add consistent 16px padding between action buttons
- [ ] Ensure buttons are evenly spaced on tablet devices
- [ ] Test on at least 2 different screen sizes

### Where to Look
- File: `lib/features/wallet/presentation/screens/send_screen.dart`
- Look for the button Row/Column widgets

### Hints
- Use `SizedBox(height: 16.h)` for responsive spacing
- Consider using `MainAxisAlignment.spaceEvenly`

### Difficulty
Easy (< 1 hour)

---

## Issue #2: Add Loading Skeleton to Transaction List

**Labels**: `good first issue`, `ui/ux`, `help wanted`

### Description
When transactions are loading, show skeleton placeholders instead of a spinner for better UX.

### Acceptance Criteria
- [ ] Create a `TransactionSkeleton` widget
- [ ] Show 5 skeleton items while loading
- [ ] Match the height of actual transaction list items

### Where to Look
- File: `lib/features/wallet/presentation/screens/transactions_screen.dart`
- Reference: `lib/core/widgets/skeleton/app_skeleton.dart`

### Hints
- Use the `skeletonizer` package (already in pubspec)
- Look at how other screens implement skeletons

### Difficulty
Easy (< 1 hour)

---

## Issue #3: Add Copy Button to Lightning Address Card

**Labels**: `good first issue`, `enhancement`, `help wanted`

### Description
Users should be able to easily copy their Lightning address with one tap.

### Acceptance Criteria
- [ ] Add a copy icon button next to the Lightning address
- [ ] Show a snackbar confirmation when copied
- [ ] Use the existing app color scheme

### Where to Look
- File: `lib/features/wallet/presentation/widgets/lightning_address_card.dart`

### Hints
- Use `Clipboard.setData()` from `flutter/services.dart`
- Use `ScaffoldMessenger.of(context).showSnackBar()` for feedback

### Difficulty
Easy (< 1 hour)

---

## Issue #4: Add Hausa Translation for VTU Screen

**Labels**: `good first issue`, `localization`, `help wanted`

### Description
The VTU (airtime/data) screen needs Hausa translations for better accessibility.

### Acceptance Criteria
- [ ] Translate all strings on the VTU screen to Hausa
- [ ] Ensure translations are grammatically correct
- [ ] Test by running with `--dart-define=LOCALE=ha`

### Where to Look
- Files in: `lib/l10n/`
- Screens in: `lib/features/vtu/presentation/screens/`

### Hints
- Look for existing translation patterns in the l10n files
- Native Hausa speakers are welcome to review!

### Difficulty
Medium (1-3 hours)

---

## Issue #5: Add Unit Tests for Date Utilities

**Labels**: `good first issue`, `testing`, `help wanted`

### Description
The date utility functions need comprehensive unit tests for reliability.

### Acceptance Criteria
- [ ] Add tests for `formatRelativeTime()` function
- [ ] Add tests for edge cases (null, empty, future dates)
- [ ] Achieve 90%+ coverage for the file

### Where to Look
- Source: `lib/core/utils/date_utils.dart`
- Test file: `test/date_utils_test.dart`

### Hints
- Use Flutter's built-in test framework
- Check existing tests for patterns

### Difficulty
Medium (1-3 hours)

---

## How to Claim an Issue

1. Comment on the issue saying you'd like to work on it
2. Wait for a maintainer to assign it to you
3. Fork the repo and create a branch
4. Submit a PR when ready

Happy contributing! 🚀
