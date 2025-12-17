import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_screen.dart';

void main() {
  testWidgets('P2PScreen displays title and offers list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (_, __) => const MaterialApp(home: P2PScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('P2P'), findsOneWidget);
    // Expect some Trade buttons on the screen from mocked provider
    expect(find.text('Trade'), findsWidgets);
  });
}
