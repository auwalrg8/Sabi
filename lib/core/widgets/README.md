# Core Widgets

This directory contains all reusable UI components and utilities for the Sabi Wallet app.

## Directory Structure

```
lib/core/widgets/
├── dialogs/              # Dialog components
│   ├── app_dialogs.dart          # Main dialog utility class
│   ├── dialog_icon.dart          # Reusable dialog icon widget
│   ├── dialog_content.dart       # Reusable dialog content widget
│   ├── dialog_button.dart        # Reusable dialog button widget
│   ├── dialog_action_buttons.dart # Reusable action buttons widget
│   ├── dialog_examples.dart      # Example implementations
│   ├── dialogs.dart              # Export file
│   └── README.md                 # Dialog documentation
│
├── sheets/               # Bottom sheet components
│   ├── app_sheets.dart           # Main sheet utility class
│   ├── sheet_loading_indicator.dart   # Loading indicator widget
│   ├── sheet_success_content.dart     # Success content widget
│   ├── sheet_auth_content.dart        # Auth content widget
│   ├── sheet_examples.dart       # Example implementations
│   ├── sheets.dart               # Export file
│   └── README.md                 # Sheet documentation
│
├── widgets.dart          # Main export file (exports all widgets)
└── README.md            # This file
```

## Quick Start

### Import Everything
```dart
import 'package:sabi_wallet/core/widgets/widgets.dart';
```

### Import Specific Categories
```dart
// Only dialogs
import 'package:sabi_wallet/core/widgets/dialogs/dialogs.dart';

// Only sheets
import 'package:sabi_wallet/core/widgets/sheets/sheets.dart';
```

## Available Components

### 1. Dialogs (`AppDialogs`)

Modal dialogs for important user interactions and feedback.

```dart
// Info dialog
AppDialogs.info(
  title: 'Information',
  message: 'Your wallet is synced.',
);

// Success dialog
AppDialogs.success(
  title: 'Success',
  message: 'Transaction completed!',
);

// Error dialog
AppDialogs.error(
  title: 'Error',
  message: 'Failed to process transaction.',
);

// Warning dialog
AppDialogs.warning(
  title: 'Warning',
  message: 'This action cannot be undone.',
);

// Confirmation dialog (returns Future<bool?>)
final confirmed = await AppDialogs.confirm(
  title: 'Delete Wallet',
  message: 'Are you sure?',
);

// Danger dialog
AppDialogs.danger(
  title: 'Delete Account',
  message: 'This will permanently delete your account.',
  onConfirm: () => deleteAccount(),
);
```

**See [dialogs/README.md](dialogs/README.md) for detailed documentation.**

### 2. Bottom Sheets (`AppSheets`)

Bottom sheets for loading states, quick feedback, and non-blocking interactions.

```dart
// Loading sheet
AppSheets.loading(message: 'Processing...');

// Success sheet (auto-dismisses)
AppSheets.success(
  title: 'Success',
  message: 'Payment sent!',
);

// Auth required sheet
AppSheets.authRequired(
  onAuthenticate: () => showLogin(),
);

// Dismiss any sheet
AppSheets.dismiss();
```

**See [sheets/README.md](sheets/README.md) for detailed documentation.**

## Design Principles

### 1. **Reusability**
All components are designed to be reused across the app. Each component is:
- Self-contained
- Highly configurable
- Well-documented

### 2. **Consistency**
All components follow the same:
- Visual language
- Animation patterns
- API design patterns

### 3. **Composability**
Components can be:
- Used independently
- Combined together
- Extended for custom use cases

### 4. **Type Safety**
All components use:
- Strong typing
- Required parameters for critical data
- Optional parameters with sensible defaults

### 5. **Accessibility**
All components provide:
- Proper semantic structure
- Sufficient color contrast
- Keyboard navigation support

## Common Patterns

### Loading → Success Flow
```dart
try {
  AppSheets.loading(message: 'Sending payment...');
  await sendPayment();
  AppSheets.dismiss();
  AppSheets.success(message: 'Payment sent!');
} catch (e) {
  AppSheets.dismiss();
  AppDialogs.error(
    title: 'Error',
    message: 'Failed to send payment',
  );
}
```

### Confirmation → Action Flow
```dart
final confirmed = await AppDialogs.confirm(
  title: 'Delete Transaction',
  message: 'Are you sure you want to delete this transaction?',
);

if (confirmed == true) {
  AppSheets.loading(message: 'Deleting...');
  await deleteTransaction();
  AppSheets.dismiss();
  AppSheets.success(message: 'Transaction deleted');
}
```

## Testing

Example screens are provided for testing all components:

```dart
// Test dialogs
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => DialogExamplesScreen(),
  ),
);

// Test sheets
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => SheetExamplesScreen(),
  ),
);
```

## Contributing

When adding new widgets:

1. Create the widget in the appropriate subdirectory
2. Export it in the category's export file (e.g., `dialogs.dart`)
3. Add documentation and examples
4. Update this README

## Dependencies

- `wolt_modal_sheet`: Modal sheet and dialog implementation
- `flutter_animate`: Animation utilities
- `iconsax`: Icon library
- `get`: For accessing context globally

