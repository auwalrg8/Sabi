import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/features/wallet/presentation/providers/suggestions_provider.dart';

class SuggestionsSlider extends StatelessWidget {
  final List<SuggestionCardType> cards;
  final void Function(SuggestionCardType) onDismiss;

  const SuggestionsSlider({
    super.key,
    required this.cards,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 80.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (context, i) {
          final type = cards[i];
          return _SuggestionCard(type: type, onDismiss: () => onDismiss(type));
        },
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final SuggestionCardType type;
  final VoidCallback onDismiss;

  const _SuggestionCard({required this.type, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case SuggestionCardType.backup:
        return _FigmaSuggestionCard(
          color: const Color(0xFFF95F5F),
          icon: Icons.shield_outlined,
          title: 'Wallet Not Backed Up',
          subtitle: 'Set up a backup to project your funds',
          actionLabel: 'Set up',
          onAction: () {},
          onDismiss: onDismiss,
        );
      case SuggestionCardType.nostr:
        return _FigmaSuggestionCard(
          color: const Color(0xFF9747FF),
          icon: Icons.flash_on,
          title: 'Set Up Your Nostr',
          subtitle: 'To enable zaps and social features',
          actionLabel: 'Set up',
          onAction: () {},
          onDismiss: onDismiss,
        );
      case SuggestionCardType.pin:
        return _FigmaSuggestionCard(
          color: const Color(0xFF00F0B5),
          icon: Icons.lock_outline,
          title: 'Secure wallet',
          subtitle: 'Set up a pin code to secure wallet',
          actionLabel: 'Set up',
          onAction: () {},
          onDismiss: onDismiss,
        );
    }
  }
}

class _FigmaSuggestionCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  const _FigmaSuggestionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290.w,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 32.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w400,
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.sp,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white.withOpacity(0.7)),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
