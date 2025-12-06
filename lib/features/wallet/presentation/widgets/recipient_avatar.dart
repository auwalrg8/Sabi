import 'package:flutter/material.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

class RecipientAvatar extends StatelessWidget {
  final String initial;
  final double size;

  const RecipientAvatar({
    super.key,
    required this.initial,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
