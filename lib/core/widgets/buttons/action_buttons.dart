import 'package:flutter/material.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onBuy;

  const ActionButtons({super.key, required this.onSend, required this.onReceive, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(icon: Icons.send, label: 'Send', color: Colors.red, onTap: onSend),
        _ActionButton(icon: Icons.download, label: 'Receive', color: AppColors.accentGreen, onTap: onReceive),
        _ActionButton(icon: Icons.shopping_cart, label: 'Buy', color: AppColors.primary, onTap: onBuy),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}