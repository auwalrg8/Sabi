# Dialog Widgets

This directory contains reusable dialog components and utilities for the Sabi Wallet app.

## Overview

The dialog system is built on top of `wolt_modal_sheet` and provides a consistent, animated dialog experience across the app.

## Components

### 1. **AppDialogs** (Main Utility Class)
The main entry point for showing dialogs. Provides static methods for different dialog types.

### 2. **DialogIcon**
Reusable animated icon widget with circular background. Supports shake animation for warning/danger dialogs.

### 3. **DialogContent**
Displays title and message with slide-in animations.

### 4. **DialogButton**
Full-width button with animations for single-action dialogs.

### 5. **DialogActionButtons**
Two-button layout (cancel + confirm) for confirmation dialogs.

## Usage

### Import
```dart
import 'package:sabi_wallet/core/widgets/dialogs/dialogs.dart';
```

### Info Dialog
```dart
AppDialogs.info(
  title: 'Information',
  message: 'This is an informational message.',
  buttonText: 'Got it', // Optional, defaults to 'OK'
  onConfirm: () {
    // Optional callback
    print('User acknowledged');
  },
);
```

### Success Dialog
```dart
AppDialogs.success(
  title: 'Success!',
  message: 'Your transaction was completed successfully.',
);
```

### Error Dialog
```dart
AppDialogs.error(
  title: 'Error',
  message: 'Something went wrong. Please try again.',
);
```

### Warning Dialog
```dart
AppDialogs.warning(
  title: 'Warning',
  message: 'This action cannot be undone.',
);
```

### Confirmation Dialog (Returns Future)
```dart
final confirmed = await AppDialogs.confirm(
  title: 'Delete Account',
  message: 'Are you sure you want to delete your account? This action cannot be undone.',
  confirmText: 'Delete', // Optional, defaults to 'Confirm'
  cancelText: 'Cancel',  // Optional, defaults to 'Cancel'
);

if (confirmed == true) {
  // User confirmed
  deleteAccount();
} else if (confirmed == false) {
  // User cancelled
  print('Cancelled');
} else {
  // User dismissed (tapped outside or swiped down)
  print('Dismissed');
}
```

### Danger Dialog (Void Callback)
```dart
AppDialogs.danger(
  title: 'Delete Wallet',
  message: 'This will permanently delete your wallet. Make sure you have backed up your recovery phrase.',
  confirmText: 'Delete',
  cancelText: 'Keep Wallet',
  onConfirm: () {
    // User confirmed the dangerous action
    deleteWallet();
  },
  onCancel: () {
    // Optional: User cancelled
    print('User kept wallet');
  },
);
```

### Custom Sheet
```dart
AppDialogs.showCustomSheet(
  context: context,
  title: 'Custom Content',
  child: Column(
    children: [
      Text('Your custom content here'),
      // ... more widgets
    ],
  ),
);
```

## Customization

### Using Individual Components

You can also use the individual components directly for custom dialogs:

```dart
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:sabi_wallet/core/widgets/dialogs/dialogs.dart';

WoltModalSheet.show(
  context: context,
  pageListBuilder: (context) => [
    WoltModalSheetPage(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            DialogIcon(
              icon: Icons.star,
              iconColor: Colors.amber,
              backgroundColor: Colors.amber.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 24),
            DialogContent(
              title: 'Custom Dialog',
              message: 'This is a custom dialog using individual components.',
            ),
            const SizedBox(height: 32),
            DialogButton(
              text: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  ],
);
```

## Design Principles

1. **Consistency**: All dialogs follow the same visual language
2. **Animations**: Smooth, delightful animations for better UX
3. **Accessibility**: Proper semantic structure and contrast
4. **Reusability**: Components can be used independently or together
5. **Type Safety**: Strong typing with required parameters

## Dependencies

- `wolt_modal_sheet`: Modal sheet implementation
- `flutter_animate`: Animation utilities
- `iconsax`: Icon library
- `get`: For accessing context globally

