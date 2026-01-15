import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../data/models/network_provider.dart';

/// Network selector widget for choosing mobile network
class NetworkSelector extends StatelessWidget {
  final NetworkProvider? selectedNetwork;
  final ValueChanged<NetworkProvider> onNetworkSelected;

  const NetworkSelector({
    super.key,
    this.selectedNetwork,
    required this.onNetworkSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Network',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children:
              NetworkProvider.values.map((network) {
                final isSelected = selectedNetwork == network;
                return _NetworkButton(
                  network: network,
                  isSelected: isSelected,
                  onTap: () => onNetworkSelected(network),
                );
              }).toList(),
        ),
      ],
    );
  }
}

class _NetworkButton extends StatelessWidget {
  final NetworkProvider network;
  final bool isSelected;
  final VoidCallback onTap;

  const _NetworkButton({
    required this.network,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72.w,
        height: 72.h,
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Color(network.primaryColor).withOpacity(0.2)
                  : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color:
                isSelected
                    ? Color(network.primaryColor)
                    : const Color(0xFF2A2A3E),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: Color(network.primaryColor),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  network.name[0],
                  style: TextStyle(
                    color:
                        network == NetworkProvider.mtn
                            ? Colors.black
                            : Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              network.name,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFA1A1B2),
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
