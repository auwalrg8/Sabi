import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sabi_wallet/core/widgets/buttons/dialog_action_buttons.dart';
import 'package:sabi_wallet/core/widgets/buttons/dialog_button.dart';
import 'package:sabi_wallet/core/widgets/dialogs/content/dialog_content.dart';
import 'package:sabi_wallet/core/widgets/dialogs/icons/dialog_icon.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// App-wide dialogs using Wolt Modal Sheet
///
/// Provides static methods to show different types of dialogs:
/// - info: Information dialog with blue icon
/// - success: Success dialog with green icon
/// - error: Error dialog with red icon
/// - warning: Warning dialog with orange icon
/// - danger: Danger/confirmation dialog with red icon and two buttons
/// - confirm: Confirmation dialog that returns a `Future<bool?>`
/// - showCustomSheet: Custom sheet with custom content
///
/// Usage:
/// ```dart
/// AppDialogs.info(
///   context,
///   title: 'Info',
///   message: 'This is an info message',
/// );
///
/// final confirmed = await AppDialogs.confirm(
///   context,
///   title: 'Delete Account',
///   message: 'Are you sure you want to delete your account?',
/// );
/// ```
class AppDialogs {
  // Private constructor to prevent instantiation
  AppDialogs._();

  /// Show info dialog
  static void info(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onConfirm,
  }) {
    _showDialog(
      context,
      title: title,
      message: message,
      icon: Iconsax.info_circle5,
      iconColor: Colors.blue,
      iconBackgroundColor: Colors.blue.withValues(alpha: 0.1),
      buttonText: buttonText ?? 'OK',
      onConfirm: onConfirm,
    );
  }

  /// Show success dialog
  static void success(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onConfirm,
  }) {
    _showDialog(
      context,
      title: title,
      message: message,
      icon: Iconsax.tick_circle5,
      iconColor: Colors.green,
      iconBackgroundColor: Colors.green.withValues(alpha: 0.1),
      buttonText: buttonText ?? 'OK',
      onConfirm: onConfirm,
    );
  }

  /// Show error dialog
  static void error(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onConfirm,
  }) {
    _showDialog(
      context,
      title: title,
      message: message,
      icon: Iconsax.close_circle5,
      iconColor: Colors.red,
      iconBackgroundColor: Colors.red.withValues(alpha: 0.1),
      buttonText: buttonText ?? 'OK',
      onConfirm: onConfirm,
    );
  }

  /// Show warning dialog
  static void warning(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onConfirm,
  }) {
    _showDialog(
      context,
      title: title,
      message: message,
      icon: Iconsax.warning_25,
      iconColor: Colors.orange,
      iconBackgroundColor: Colors.orange.withValues(alpha: 0.1),
      buttonText: buttonText ?? 'OK',
      onConfirm: onConfirm,
      applyShake: true,
    );
  }

  /// Show confirmation dialog that returns a `Future<bool?>`
  ///
  /// Returns true if confirmed, false if cancelled, null if dismissed
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
  }) async {
    bool? result;

    await WoltModalSheet.show(
      context: context,
      barrierDismissible: true,
      enableDrag: true,
      pageListBuilder:
          (context) => [
            _buildConfirmationPage(
              context: context,
              title: title,
              message: message,
              confirmText: confirmText ?? 'Confirm',
              cancelText: cancelText ?? 'Cancel',
              onConfirm: () {
                result = true;
                Navigator.of(context).pop();
              },
              onCancel: () {
                result = false;
                Navigator.of(context).pop();
              },
            ),
          ],
    );

    return result;
  }

  /// Show danger/confirmation dialog
  ///
  /// Similar to confirm() but doesn't return a value
  static void danger(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    WoltModalSheet.show(
      context: context,
      barrierDismissible: true,
      enableDrag: true,
      pageListBuilder:
          (context) => [
            _buildConfirmationPage(
              context: context,
              title: title,
              message: message,
              confirmText: confirmText ?? 'Confirm',
              cancelText: cancelText ?? 'Cancel',
              onConfirm: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              onCancel: () {
                Navigator.of(context).pop();
                onCancel?.call();
              },
            ),
          ],
    );
  }

  /// Show custom sheet with custom content
  static void showCustomSheet(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    WoltModalSheet.show(
      context: context,
      pageListBuilder:
          (context) => [
            WoltModalSheetPage(
              backgroundColor: Theme.of(context).colorScheme.surface,
              topBarTitle: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              isTopBarLayerAlwaysVisible: true,
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ],
    );
  }

  // ========== PRIVATE HELPER METHODS ==========

  /// Internal helper to show single-button dialog
  static void _showDialog(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    required String buttonText,
    VoidCallback? onConfirm,
    bool applyShake = false,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    DialogIcon(
                      icon: icon,
                      iconColor: iconColor,
                      backgroundColor: iconBackgroundColor,
                      applyShake: applyShake,
                    ),
                    const SizedBox(height: 24),

                    // Title and Message
                    DialogContent(title: title, message: message),
                    const SizedBox(height: 32),

                    // Button
                    DialogButton(
                      text: buttonText,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onConfirm?.call();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
    );
  }

  /// Internal helper to build confirmation page
  static WoltModalSheetPage _buildConfirmationPage({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return WoltModalSheetPage(
      backgroundColor: Theme.of(context).colorScheme.surface,
      hasTopBarLayer: false,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Danger Icon
            DialogIcon(
              icon: Iconsax.danger5,
              iconColor: Colors.red,
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              applyShake: true,
            ),
            const SizedBox(height: 24),

            // Title and Message
            DialogContent(title: title, message: message),
            const SizedBox(height: 32),

            // Action Buttons
            DialogActionButtons(
              cancelText: cancelText,
              confirmText: confirmText,
              onCancel: onCancel,
              onConfirm: onConfirm,
            ),
          ],
        ),
      ),
    );
  }
}
