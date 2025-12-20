import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/p2p_theme.dart';

String formatDate(DateTime date, {bool includeYear = false}) {
  final fmt = includeYear ? DateFormat.yMMMMd() : DateFormat.MMMd();
  return fmt.format(date);
}

String formatFiat(double value) {
  final f = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
  return f.format(value);
}

class P2PEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const P2PEmptyState({Key? key, required this.message, required this.icon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: P2PColors.textMuted),
            const SizedBox(height: 12),
            Text(message, style: P2PTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

class P2PLoadingState extends StatelessWidget {
  const P2PLoadingState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class P2PErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const P2PErrorState({Key? key, required this.message, this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: P2PTextStyles.bodySmall),
          const SizedBox(height: 8),
          if (onRetry != null)
            ElevatedButton(onPressed: onRetry, child: const Text('Retry'))
        ],
      ),
    );
  }
}

class P2PAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showVerificationBadge;
  final bool isVerified;

  const P2PAvatar({Key? key, this.imageUrl, required this.name, this.size = 40, this.showVerificationBadge = false, this.isVerified = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final img = imageUrl;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: P2PColors.cardBackgroundLight,
      backgroundImage: img != null ? NetworkImage(img) : null,
      child: img == null ? Text(name[0]) : null,
    );
  }
}

class P2PStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool showPercentage;

  const P2PStatCard({Key? key, required this.label, required this.value, this.valueColor, this.showPercentage = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: P2PDecorations.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: P2PTextStyles.statLabel),
          const SizedBox(height: 8),
          Text(value, style: P2PTextStyles.bodyLarge.copyWith(color: valueColor ?? Colors.white)),
        ],
      ),
    );
  }
}

class P2PFeedbackThumbs extends StatelessWidget {
  final int positive;
  final int negative;

  const P2PFeedbackThumbs({Key? key, required this.positive, required this.negative}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(children: [Text('+$positive', style: P2PTextStyles.bodySmall), const SizedBox(width: 8), Text('-$negative', style: P2PTextStyles.bodySmall)]);
  }
}

class P2PPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const P2PPrimaryButton({Key? key, required this.label, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: P2PColors.primary), child: Text(label));
  }
}

class P2PCard extends StatelessWidget {
  final dynamic offer;
  final VoidCallback? onTap;

  const P2PCard({Key? key, required this.offer, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = offer?.name ?? '';
    final price = offer?.pricePerBtc != null ? '₦${offer.pricePerBtc.toStringAsFixed(0)}' : '₦0';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: P2PDecorations.cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: P2PTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(price, style: P2PTextStyles.bodySmall),
            ],
          ),
          ElevatedButton(onPressed: onTap, child: const Text('Trade')),
        ],
      ),
    );
  }
}

class P2PFilterChips<T> extends StatelessWidget {
  final List<T> filters;
  final T selectedFilter;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onSelected;

  const P2PFilterChips({Key? key, required this.filters, required this.selectedFilter, required this.labelBuilder, required this.onSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: filters.map((f) {
        final selected = f == selectedFilter;
        return ChoiceChip(label: Text(labelBuilder(f)), selected: selected, onSelected: (_) => onSelected(f));
      }).toList(),
    );
  }
}

class P2PTimeLeft extends StatelessWidget {
  final Duration timeLeft;

  const P2PTimeLeft({Key? key, required this.timeLeft}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mins = timeLeft.inMinutes;
    return Text('$mins min left', style: P2PTextStyles.bodySmall);
  }
}

class P2PStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const P2PStatusBadge({Key? key, required this.label, required this.color}) : super(key: key);

  factory P2PStatusBadge.paid() => P2PStatusBadge(label: 'Paid', color: P2PColors.success);
  factory P2PStatusBadge.awaitingPayment() => P2PStatusBadge(label: 'Awaiting', color: P2PColors.primary);
  factory P2PStatusBadge.completed() => P2PStatusBadge(label: 'Completed', color: P2PColors.success);
  factory P2PStatusBadge.cancelled() => P2PStatusBadge(label: 'Cancelled', color: P2PColors.error);
  factory P2PStatusBadge.disputed() => P2PStatusBadge(label: 'Disputed', color: P2PColors.error);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: P2PTextStyles.bodySmall.copyWith(color: color)),
    );
  }
}

class P2PVerificationBadge extends StatelessWidget {
  final String type;
  final bool isVerified;

  const P2PVerificationBadge({Key? key, required this.type, this.isVerified = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(isVerified ? Icons.check_circle : Icons.info_outline, size: 16, color: isVerified ? P2PColors.success : P2PColors.textMuted),
        const SizedBox(width: 8),
        Text(type, style: P2PTextStyles.bodySmall),
      ],
    );
  }
}

class P2PTradeTypeIcon extends StatelessWidget {
  final bool isBuy;

  const P2PTradeTypeIcon({Key? key, required this.isBuy}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: isBuy ? P2PColors.success : P2PColors.surface,
      child: Icon(isBuy ? Icons.arrow_downward : Icons.arrow_upward, color: Colors.white, size: 18),
    );
  }
}
