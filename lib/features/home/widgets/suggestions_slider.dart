import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/features/home/providers/suggestions_provider.dart';

class SuggestionsSlider extends StatelessWidget {
  final List<SuggestionType> suggestions;
  final void Function(SuggestionType) onDismiss;
  final void Function(SuggestionType) onTap;

  const SuggestionsSlider({
    super.key,
    required this.suggestions,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 92.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final type = suggestions[index];
          return _SuggestionCard(
            type: type,
            onDismiss: () => onDismiss(type),
            onTap: () => onTap(type),
          );
        },
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final SuggestionType type;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _SuggestionCard({required this.type, required this.onDismiss, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Card data based on type
    late final Color bgColor;
    late final String title;
    late final String subtitle;
    late final String actionText;
    late final Color actionColor;
    late final IconData icon;
    switch (type) {
      case SuggestionType.backup:
        bgColor = const Color.fromARGB(29, 249, 75, 75);
        title = 'Wallet Not Backed Up';
        subtitle = 'Set up a backup to project your funds';
        actionText = 'Set up';
        actionColor = Colors.white.withOpacity(0.7);
        icon = Icons.shield_outlined;
        break;
      case SuggestionType.nostr:
        bgColor = const Color.fromARGB(29, 122, 61, 254);
        title = 'Set Up Your Nostr';
        subtitle = 'To enable zaps and social features';
        actionText = 'Set up';
        actionColor = Colors.white.withOpacity(0.7);
        icon = Icons.alternate_email_rounded;
        break;
      case SuggestionType.pin:
        bgColor = const Color.fromARGB(29, 0, 242, 181);
        title = 'Secure wallet';
        subtitle = 'Set up a pin code to secure wallet';
        actionText = '';
        actionColor = Colors.white.withOpacity(0.7);
        icon = Icons.lock_outline_rounded;
        break;
    }
    // Border color should be the same RGB as the background but fully opaque
    Color borderColor;
    switch (type) {
      case SuggestionType.backup:
        borderColor = const Color.fromARGB(255, 249, 75, 75);
        break;
      case SuggestionType.nostr:
        borderColor = const Color.fromARGB(255, 122, 61, 254);
        break;
      case SuggestionType.pin:
        borderColor = const Color.fromARGB(255, 0, 242, 181);
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280.w,
        padding: EdgeInsets.all(13.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24.sp),
            SizedBox(width: 12.w),
            // Main content: title+dismiss on a single row, body text below
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with dismiss aligned to the end
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.sp,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: onDismiss,
                        child: Icon(Icons.close, color: Colors.white.withOpacity(0.7), size: 18.sp),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  // Body text placed below title row and spanning full width
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: actionColor,
                      fontWeight: FontWeight.w400,
                      fontSize: 12.sp,
                    ),
                  ),
                  if (actionText.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: onTap,
                          child: Text(
                            actionText,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.sp,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
