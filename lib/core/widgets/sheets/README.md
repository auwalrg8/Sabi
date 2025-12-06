# Bottom Sheet Widgets

This directory contains reusable bottom sheet components and utilities for the Sabi Wallet app.

## Overview

The bottom sheet system is built on top of `wolt_modal_sheet` and provides a consistent, animated sheet experience across the app.

## Components

### 1. **AppSheets** (Main Utility Class)
The main entry point for showing bottom sheets. Provides static methods for different sheet types.

### 2. **SheetLoadingIndicator**
Reusable loading indicator with circular progress and message. Supports continuous rotation animation.

### 3. **SheetSuccessContent**
Displays success icon with optional title and message with slide-in animations.

### 4. **SheetAuthContent**
Authentication prompt with icon, message, and action buttons (Cancel + Sign In).

## Usage

### Import
```dart
import 'package:sabi_wallet/core/widgets/sheets/sheets.dart';
```

### Loading Sheet
```dart
// Show loading sheet
AppSheets.loading(message: 'Processing transaction...');

// Show dismissible loading sheet
AppSheets.loading(
  message: 'Syncing wallet...',
  isDismissible: true,
);

// Dismiss when done
AppSheets.dismiss();
```

### Success Sheet
```dart
// Simple success message
AppSheets.success(
  message: 'Transaction completed successfully!',
);

// Success with title
AppSheets.success(
  title: 'Payment Sent',
  message: 'Your payment of ₦5,000 has been sent.',
  duration: Duration(seconds: 3), // Auto-dismiss after 3 seconds
);
```

### Authentication Required Sheet
```dart
// Default behavior (navigates to '/auth')
AppSheets.authRequired();

// Custom message
AppSheets.authRequired(
  title: 'Sign In Required',
  message: 'Please sign in to send payments.',
);

// Custom authentication handler
AppSheets.authRequired(
  title: 'Unlock Wallet',
  message: 'Please authenticate to continue.',
  onAuthenticate: () {
    // Custom authentication logic
    showBiometricAuth();
  },
);
```

### Custom Sheet
```dart
AppSheets.showCustomSheet(
  context: context,
  child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Custom Sheet Content'),
        // ... more widgets
      ],
    ),
  ),
);
```

## Common Patterns

### Loading with Auto-Dismiss
```dart
// Show loading
AppSheets.loading(message: 'Processing...');

// Perform async operation
await processTransaction();

// Dismiss loading
AppSheets.dismiss();

// Show success
AppSheets.success(message: 'Transaction completed!');
```

### Error Handling
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
    message: 'Failed to send payment: $e',
  );
}
```

### Authentication Flow
```dart
void performSecureAction() {
  if (!isAuthenticated) {
    AppSheets.authRequired(
      onAuthenticate: () async {
        final success = await authenticate();
        if (success) {
          performSecureAction(); // Retry after auth
        }
      },
    );
    return;
  }
  
  // Proceed with secure action
  AppSheets.loading(message: 'Processing...');
  // ...
}
```

## Customization

### Using Individual Components

You can use the individual components directly for custom sheets:

```dart
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:sabi_wallet/core/widgets/sheets/sheets.dart';

WoltModalSheet.show(
  context: context,
  pageListBuilder: (context) => [
    WoltModalSheetPage(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: SheetLoadingIndicator(
          message: 'Custom loading message',
          indicatorSize: 56,
        ),
      ),
    ),
  ],
);
```

## Design Principles

1. **Consistency**: All sheets follow the same visual language
2. **Animations**: Smooth, delightful animations for better UX
3. **Auto-dismiss**: Success sheets auto-dismiss to avoid blocking the UI
4. **Accessibility**: Proper semantic structure and contrast
5. **Reusability**: Components can be used independently or together

## Differences from Dialogs

| Feature | Dialogs | Sheets |
|---------|---------|--------|
| Position | Center of screen | Bottom of screen |
| Use Case | Important decisions, errors | Loading states, quick feedback |
| Dismissal | Requires user action | Can auto-dismiss |
| Blocking | Always blocks interaction | Can be non-blocking |

## Dependencies

- `wolt_modal_sheet`: Modal sheet implementation
- `flutter_animate`: Animation utilities
- `iconsax`: Icon library
- `get`: For accessing context globally

