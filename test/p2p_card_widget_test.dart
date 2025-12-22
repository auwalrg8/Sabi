import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_home_screen.dart';
import 'package:sabi_wallet/services/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Hive with a temp path for testing
    final tempDir = Directory.systemTemp.createTempSync('p2p_card_test');
    Hive.init(tempDir.path);
    // Initialize ProfileService to prevent LateInitializationError
    await ProfileService.init();
  });

  testWidgets('P2P offer cards display in P2PHomeScreen', (tester) async {
    // Wrap in a wider screen to prevent overflow errors
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (_, __) => const MaterialApp(home: P2PHomeScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify P2P screen renders
    expect(find.text('P2P'), findsOneWidget);
    // Expect Trade buttons from offer cards
    expect(find.text('Trade'), findsWidgets);
    
    // Reset surface size
    await tester.binding.setSurfaceSize(null);
  });
}
