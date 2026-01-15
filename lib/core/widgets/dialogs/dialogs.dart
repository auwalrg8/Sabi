/// Dialog widgets and utilities
///
/// This file exports all dialog-related widgets and utilities
/// for easy importing throughout the app.
///
/// Usage:
/// ```dart
/// import 'package:sabi_wallet/core/widgets/dialogs/dialogs.dart';
///
/// // Show a success dialog
/// AppDialogs.success(
///   title: 'Success',
///   message: 'Your transaction was successful!',
/// );
/// ```
library;

// Main dialog utility class
export 'app_dialogs.dart';

// Reusable dialog components
export 'package:sabi_wallet/core/widgets/buttons/dialog_action_buttons.dart';
export 'package:sabi_wallet/core/widgets/buttons/dialog_button.dart';
export 'package:sabi_wallet/core/widgets/dialogs/content/dialog_content.dart';
export 'package:sabi_wallet/core/widgets/dialogs/icons/dialog_icon.dart';
