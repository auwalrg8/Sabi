import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ha.dart';
import 'app_localizations_pcm.dart';
import 'app_localizations_yo.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ha'),
    Locale('pcm'),
    Locale('yo'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Sabi Wallet'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep your Bitcoin safe. Nobody fit block your money or freeze your account.'**
  String get welcomeDescription;

  /// No description provided for @letsStart.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Sabi ₿'**
  String get letsStart;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get totalBalance;

  /// No description provided for @sats.
  ///
  /// In en, this message translates to:
  /// **'sats'**
  String get sats;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @airtime.
  ///
  /// In en, this message translates to:
  /// **'Airtime'**
  String get airtime;

  /// No description provided for @payBills.
  ///
  /// In en, this message translates to:
  /// **'Pay Bills'**
  String get payBills;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @failedToLoadTransactions.
  ///
  /// In en, this message translates to:
  /// **'Failed to load transactions'**
  String get failedToLoadTransactions;

  /// No description provided for @receivedPayment.
  ///
  /// In en, this message translates to:
  /// **'Received Payment'**
  String get receivedPayment;

  /// No description provided for @sentPayment.
  ///
  /// In en, this message translates to:
  /// **'Sent Payment'**
  String get sentPayment;

  /// No description provided for @chooseRecipient.
  ///
  /// In en, this message translates to:
  /// **'Choose Recipient'**
  String get chooseRecipient;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter Amount'**
  String get enterAmount;

  /// No description provided for @lightning.
  ///
  /// In en, this message translates to:
  /// **'Lightning'**
  String get lightning;

  /// No description provided for @bitcoin.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin'**
  String get bitcoin;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @zaps.
  ///
  /// In en, this message translates to:
  /// **'Zaps'**
  String get zaps;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @biometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric'**
  String get biometric;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @networkFee.
  ///
  /// In en, this message translates to:
  /// **'Network Fee'**
  String get networkFee;

  /// No description provided for @transactionLimit.
  ///
  /// In en, this message translates to:
  /// **'Transaction Limit'**
  String get transactionLimit;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hausa.
  ///
  /// In en, this message translates to:
  /// **'Hausa'**
  String get hausa;

  /// No description provided for @yoruba.
  ///
  /// In en, this message translates to:
  /// **'Yoruba'**
  String get yoruba;

  /// No description provided for @pidgin.
  ///
  /// In en, this message translates to:
  /// **'Pidgin'**
  String get pidgin;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @fees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get fees;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @invoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @at.
  ///
  /// In en, this message translates to:
  /// **'at'**
  String get at;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get copyToClipboard;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'{item} copied to clipboard'**
  String copiedToClipboard(String item);

  /// No description provided for @enterRecipient.
  ///
  /// In en, this message translates to:
  /// **'Enter recipient address or invoice'**
  String get enterRecipient;

  /// No description provided for @scanQR.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQR;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @paymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get paymentSuccess;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailed;

  /// No description provided for @paymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment Pending'**
  String get paymentPending;

  /// No description provided for @paymentSentHeadline.
  ///
  /// In en, this message translates to:
  /// **'Payment sent! We keep tracking the status in the background.'**
  String get paymentSentHeadline;

  /// No description provided for @shareOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'How do you want to share?'**
  String get shareOptionsTitle;

  /// No description provided for @shareImage.
  ///
  /// In en, this message translates to:
  /// **'Share as Image'**
  String get shareImage;

  /// No description provided for @sharePdf.
  ///
  /// In en, this message translates to:
  /// **'Share as PDF'**
  String get sharePdf;

  /// No description provided for @shareImageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send a quick snapshot of the receipt'**
  String get shareImageSubtitle;

  /// No description provided for @sharePdfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate and send a PDF summary'**
  String get sharePdfSubtitle;

  /// No description provided for @recipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipient;

  /// No description provided for @identifier.
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get identifier;

  /// No description provided for @transactionTime.
  ///
  /// In en, this message translates to:
  /// **'Transaction time'**
  String get transactionTime;

  /// No description provided for @memo.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get memo;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// No description provided for @shareReceipt.
  ///
  /// In en, this message translates to:
  /// **'Share receipt'**
  String get shareReceipt;

  /// No description provided for @createInvoice.
  ///
  /// In en, this message translates to:
  /// **'Create Invoice'**
  String get createInvoice;

  /// No description provided for @generateInvoice.
  ///
  /// In en, this message translates to:
  /// **'Generate Invoice'**
  String get generateInvoice;

  /// No description provided for @shareInvoice.
  ///
  /// In en, this message translates to:
  /// **'Share Invoice'**
  String get shareInvoice;

  /// No description provided for @backupWallet.
  ///
  /// In en, this message translates to:
  /// **'Backup Wallet'**
  String get backupWallet;

  /// No description provided for @recoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Recovery Phrase'**
  String get recoveryPhrase;

  /// No description provided for @seedPhrase.
  ///
  /// In en, this message translates to:
  /// **'Seed Phrase'**
  String get seedPhrase;

  /// No description provided for @writeDownSeedPhrase.
  ///
  /// In en, this message translates to:
  /// **'Write down your seed phrase'**
  String get writeDownSeedPhrase;

  /// No description provided for @verifySeedPhrase.
  ///
  /// In en, this message translates to:
  /// **'Verify seed phrase'**
  String get verifySeedPhrase;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @switchWallet.
  ///
  /// In en, this message translates to:
  /// **'Switch Wallet'**
  String get switchWallet;

  /// No description provided for @createNewWallet.
  ///
  /// In en, this message translates to:
  /// **'Create New Wallet'**
  String get createNewWallet;

  /// No description provided for @restoreWallet.
  ///
  /// In en, this message translates to:
  /// **'Restore Wallet'**
  String get restoreWallet;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get pleaseWait;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @lightningNetwork.
  ///
  /// In en, this message translates to:
  /// **'Lightning Network'**
  String get lightningNetwork;

  /// No description provided for @bitcoinAddress.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin Address'**
  String get bitcoinAddress;

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @recentContacts.
  ///
  /// In en, this message translates to:
  /// **'Recent Contacts'**
  String get recentContacts;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add Contact'**
  String get addContact;

  /// No description provided for @quickAmounts.
  ///
  /// In en, this message translates to:
  /// **'Quick Amounts'**
  String get quickAmounts;

  /// No description provided for @customAmount.
  ///
  /// In en, this message translates to:
  /// **'Custom Amount'**
  String get customAmount;

  /// No description provided for @livePrice.
  ///
  /// In en, this message translates to:
  /// **'Live Price'**
  String get livePrice;

  /// No description provided for @buyRate.
  ///
  /// In en, this message translates to:
  /// **'Buy rate'**
  String get buyRate;

  /// No description provided for @sellRate.
  ///
  /// In en, this message translates to:
  /// **'Sell rate'**
  String get sellRate;

  /// No description provided for @tapToSwitch.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch currency'**
  String get tapToSwitch;

  /// No description provided for @liveMarketRate.
  ///
  /// In en, this message translates to:
  /// **'Live market rate'**
  String get liveMarketRate;

  /// No description provided for @exitWallet.
  ///
  /// In en, this message translates to:
  /// **'Exit Sabi Wallet'**
  String get exitWallet;

  /// No description provided for @exitWalletConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to quit Sabi Wallet?'**
  String get exitWalletConfirm;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactions;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @paymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment Received'**
  String get paymentReceived;

  /// No description provided for @paymentSent.
  ///
  /// In en, this message translates to:
  /// **'Payment Sent'**
  String get paymentSent;

  /// No description provided for @insufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get insufficientBalance;

  /// No description provided for @invalidAddress.
  ///
  /// In en, this message translates to:
  /// **'Invalid address'**
  String get invalidAddress;

  /// No description provided for @invalidInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invalid invoice'**
  String get invalidInvoice;

  /// No description provided for @economy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get economy;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @onchainBitcoin.
  ///
  /// In en, this message translates to:
  /// **'On-chain Bitcoin'**
  String get onchainBitcoin;

  /// No description provided for @bitcoinDeposits.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin Deposits'**
  String get bitcoinDeposits;

  /// No description provided for @pendingDeposits.
  ///
  /// In en, this message translates to:
  /// **'Pending Deposits'**
  String get pendingDeposits;

  /// No description provided for @unclaimedDeposits.
  ///
  /// In en, this message translates to:
  /// **'Unclaimed Deposits'**
  String get unclaimedDeposits;

  /// No description provided for @noPendingDeposits.
  ///
  /// In en, this message translates to:
  /// **'No Pending Deposits'**
  String get noPendingDeposits;

  /// No description provided for @allDepositsClaimedDesc.
  ///
  /// In en, this message translates to:
  /// **'All your on-chain deposits have been claimed'**
  String get allDepositsClaimedDesc;

  /// No description provided for @claimDeposit.
  ///
  /// In en, this message translates to:
  /// **'Claim Deposit'**
  String get claimDeposit;

  /// No description provided for @refundDeposit.
  ///
  /// In en, this message translates to:
  /// **'Refund Deposit'**
  String get refundDeposit;

  /// No description provided for @depositAmount.
  ///
  /// In en, this message translates to:
  /// **'Deposit Amount'**
  String get depositAmount;

  /// No description provided for @claimFee.
  ///
  /// In en, this message translates to:
  /// **'Claim Fee'**
  String get claimFee;

  /// No description provided for @feeExceeded.
  ///
  /// In en, this message translates to:
  /// **'Fee too high - manual claim needed'**
  String get feeExceeded;

  /// No description provided for @utxoNotFound.
  ///
  /// In en, this message translates to:
  /// **'UTXO not found'**
  String get utxoNotFound;

  /// No description provided for @claimFailed.
  ///
  /// In en, this message translates to:
  /// **'Claim failed'**
  String get claimFailed;

  /// No description provided for @depositClaimedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deposit claimed successfully!'**
  String get depositClaimedSuccess;

  /// No description provided for @refundBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Refund transaction broadcast!'**
  String get refundBroadcast;

  /// No description provided for @transactionSpeed.
  ///
  /// In en, this message translates to:
  /// **'Transaction Speed'**
  String get transactionSpeed;

  /// No description provided for @economySpeed.
  ///
  /// In en, this message translates to:
  /// **'Economy (~1 hour)'**
  String get economySpeed;

  /// No description provided for @standardSpeed.
  ///
  /// In en, this message translates to:
  /// **'Standard (~30 min)'**
  String get standardSpeed;

  /// No description provided for @fastSpeed.
  ///
  /// In en, this message translates to:
  /// **'Fast (~10 min)'**
  String get fastSpeed;

  /// No description provided for @staticBitcoinAddress.
  ///
  /// In en, this message translates to:
  /// **'Static Bitcoin Address'**
  String get staticBitcoinAddress;

  /// No description provided for @onchainDepositsInfo.
  ///
  /// In en, this message translates to:
  /// **'On-chain Bitcoin Deposits'**
  String get onchainDepositsInfo;

  /// No description provided for @reusableAddress.
  ///
  /// In en, this message translates to:
  /// **'This is a reusable static address'**
  String get reusableAddress;

  /// No description provided for @depositsRequireConfirmations.
  ///
  /// In en, this message translates to:
  /// **'Deposits require 1+ confirmations'**
  String get depositsRequireConfirmations;

  /// No description provided for @fundsAutoClaimedToBalance.
  ///
  /// In en, this message translates to:
  /// **'Funds are auto-claimed to your balance'**
  String get fundsAutoClaimedToBalance;

  /// No description provided for @networkFeesApply.
  ///
  /// In en, this message translates to:
  /// **'Network fees apply for claiming deposits'**
  String get networkFeesApply;

  /// No description provided for @enterBitcoinAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter Bitcoin address'**
  String get enterBitcoinAddress;

  /// No description provided for @bitcoinPayment.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin Payment'**
  String get bitcoinPayment;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ha', 'pcm', 'yo'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ha':
      return AppLocalizationsHa();
    case 'pcm':
      return AppLocalizationsPcm();
    case 'yo':
      return AppLocalizationsYo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
