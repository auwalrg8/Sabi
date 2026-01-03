import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'utilities_screen.dart';
import 'cable_tv_screen.dart';
import 'vtu_order_history_screen.dart';

/// Hub screen for all utility services (Electricity, Cable TV, etc.)
class UtilitiesHubScreen extends StatelessWidget {
  const UtilitiesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Utilities',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VtuOrderHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What would you like to pay for?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 20.h),
              
              // Utilities Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 16.h,
                crossAxisSpacing: 16.w,
                childAspectRatio: 1.1,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Electricity
                  _UtilityCard(
                    icon: Icons.bolt,
                    label: 'Electricity',
                    description: 'Pay for prepaid & postpaid meters',
                    color: const Color(0xFFF7931A),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UtilitiesScreen(),
                        ),
                      );
                    },
                  ),
                  
                  // Cable TV
                  _UtilityCard(
                    icon: Icons.tv,
                    label: 'Cable TV',
                    description: 'DStv, GOtv, Startimes',
                    color: const Color(0xFF1E88E5),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CableTvScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              SizedBox(height: 32.h),
              
              // Coming Soon Section
              Text(
                'Coming Soon',
                style: TextStyle(
                  color: const Color(0xFFA1A1B2),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12.h),
              
              Row(
                children: [
                  Expanded(
                    child: _ComingSoonCard(
                      icon: Icons.water_drop,
                      label: 'Water',
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _ComingSoonCard(
                      icon: Icons.public,
                      label: 'Internet',
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _ComingSoonCard(
                      icon: Icons.sports_soccer,
                      label: 'Betting',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UtilityCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _UtilityCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: const Color(0xFF2A2A3E),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                icon,
                color: color,
                size: 26.sp,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    color: const Color(0xFFA1A1B2),
                    fontSize: 11.sp,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ComingSoonCard({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFF2A2A3E).withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF6B7280),
            size: 24.sp,
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}
