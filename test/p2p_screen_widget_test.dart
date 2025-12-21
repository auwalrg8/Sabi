import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_screen.dart';
import 'package:sabi_wallet/services/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Hive with a temp path for testing
    final tempDir = Directory.systemTemp.createTempSync('p2p_test');
    Hive.init(tempDir.path);
    // Initialize ProfileService to prevent LateInitializationError
    await ProfileService.init();
  });

  testWidgets('P2PScreen displays title and offers list', (tester) async {
    // Wrap in a wider screen to prevent overflow errors
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    
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
    
    // Reset surface size
    await tester.binding.setSurfaceSize(null);
  });
}
