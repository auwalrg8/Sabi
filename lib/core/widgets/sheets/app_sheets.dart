import 'package:flutter/material.dart';
import 'package:sabi_wallet/core/widgets/sheets/content/sheet_auth_content.dart';
import 'package:sabi_wallet/core/widgets/sheets/content/sheet_success_content.dart';
import 'package:sabi_wallet/core/widgets/sheets/indicators/sheet_loading_indicator.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// App-wide bottom sheets using Wolt Modal Sheet
///
/// Provides static methods to show different types of bottom sheets:
/// - loading: Loading sheet with progress indicator
/// - success: Success sheet with auto-dismiss
/// - authRequired: Authentication required sheet with sign-in action
///
/// Usage:
/// ```dart
/// // Show loading sheet
/// AppSheets.loading(context, message: 'Processing transaction...');
///
/// // Show success sheet
/// AppSheets.success(
///   context,
///   title: 'Success',
///   message: 'Transaction completed!',
/// );
///
/// // Show auth required sheet
/// AppSheets.authRequired(
///   context,
///   onAuthenticate: () => navigateToLogin(),
/// );
/// ```
class AppSheets {
  // Private constructor to prevent instantiation
  AppSheets._();

  /// Show loading bottom sheet
  ///
  /// Displays a loading indicator with a message.
  /// Set [isDismissible] to true to allow user to dismiss the sheet.
  static void loading(
    BuildContext context, {
    String message = 'Loading...',
    bool isDismissible = false,
  }) {
    WoltModalSheet.show(
      context: context,
      barrierDismissible: isDismissible,
      enableDrag: isDismissible,
      pageListBuilder:
          (context) => [
            WoltModalSheetPage(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hasTopBarLayer: false,
              isTopBarLayerAlwaysVisible: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: SheetLoadingIndicator(message: message),
              ),
            ),
          ],
    );
  }

  /// Show success bottom sheet
  ///
  /// Displays a success icon with optional title and message.
  /// Auto-dismisses after [duration] (default: 2 seconds).
  static void success(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 2),
  }) {
    WoltModalSheet.show(
      context: context,
      barrierDismissible: true,
      enableDrag: true,
      pageListBuilder:
          (context) => [
            WoltModalSheetPage(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hasTopBarLayer: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: SheetSuccessContent(title: title, message: message),
              ),
            ),
          ],
    );

    // Auto dismiss after duration
    Future.delayed(duration, () {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  /// Show authentication required bottom sheet
  ///
  /// Displays a sheet prompting the user to sign in.
  /// If [onAuthenticate] is provided, it will be called when user taps "Sign In".
  static void authRequired(
    BuildContext context, {
    String title = 'Sign In Required',
    String message = 'Please sign in to continue with this action',
    VoidCallback? onAuthenticate,
  }) {
    WoltModalSheet.show(
      context: context,
      barrierDismissible: true,
      enableDrag: true,
      pageListBuilder:
          (context) => [
            WoltModalSheetPage(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hasTopBarLayer: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: SheetAuthContent(
                  title: title,
                  message: message,
                  onCancel: () => Navigator.of(context).pop(),
                  onSignIn: () {
                    Navigator.of(context).pop();
                    if (onAuthenticate != null) {
                      onAuthenticate();
                    }
                  },
                ),
              ),
            ),
          ],
    );
  }

  /// Dismiss the currently shown sheet
  ///
  /// Helper method to dismiss any active sheet
  static void dismiss(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Show custom sheet with custom content
  ///
  /// For advanced use cases where you need complete control over the sheet content
  static void showCustomSheet({
    required BuildContext context,
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    WoltModalSheet.show(
      context: context,
      barrierDismissible: isDismissible,
      enableDrag: enableDrag,
      pageListBuilder:
          (context) => [
            WoltModalSheetPage(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hasTopBarLayer: false,
              child: child,
            ),
          ],
    );
  }
}
