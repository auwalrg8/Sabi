import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_screen.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';

void main() {
  testWidgets('P2PCard displays offer details', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (_, __) => MaterialApp(
            home: Scaffold(body: _buildTestCard()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mubarak'), findsOneWidget);
    expect(find.textContaining('₦'), findsWidgets);
    expect(find.text('Trade'), findsOneWidget);
  });
}

Widget _buildTestCard() {
  final offer = P2POfferModel(
    id: '1',
    name: 'Mubarak',
    pricePerBtc: 131448939.22,
    paymentMethod: 'GTBank',
    eta: '5–15 min',
    ratingPercent: 98,
    trades: 1247,
    minLimit: 50000,
    maxLimit: 8000000,
  );

  return P2PCard(offer: offer, onTap: () {});
}
