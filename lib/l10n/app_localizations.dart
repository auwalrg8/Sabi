import 'package:flutter/widgets.dart';

/// Stub for AppLocalizations to resolve missing import errors.
/// Replace with generated localization if using Flutter's intl tools.
class AppLocalizations {
        String get receive => 'Receive';
        String get airtime => 'Airtime';
        String get payBills => 'Pay Bills';
        String get recentTransactions => 'Recent Transactions';
        String get seeAll => 'See All';
        String get failedToLoadTransactions => 'Failed to load transactions';
        String get noTransactions => 'No transactions';
        String get receivedPayment => 'Received Payment';
        String get sentPayment => 'Sent Payment';
        String get lightning => 'Lightning';
        String get settings => 'Settings';
        String get account => 'Account';
        String get security => 'Security';
        String get preferences => 'Preferences';
        String get shareOptionsTitle => 'Share Options';
        String get shareImage => 'Share Image';
        String get shareImageSubtitle => 'Share image subtitle';
        String get sharePdf => 'Share PDF';
        String get sharePdfSubtitle => 'Share PDF subtitle';
        String get paymentSuccess => 'Payment Success';
        String get paymentSentHeadline => 'Payment Sent';
        String get amount => 'Amount';
        String get transactionTime => 'Transaction Time';
        String get memo => 'Memo';
        String get backToHome => 'Back to Home';
        String get shareReceipt => 'Share Receipt';
        String get recipient => 'Recipient';
        String get paymentPending => 'Payment Pending';
        String get pending => 'Pending';
      String get sent => 'Sent';
    String get received => 'Received';
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations? of(BuildContext context) => null;

  String get appTitle => 'Sabi Wallet';
  String get send => 'Send';
  String get chooseRecipient => 'Choose Recipient';
  String get enterAmount => 'Enter Amount';
  String get confirm => 'Confirm';
  // Add more getters as needed for your app's strings.
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations();

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
