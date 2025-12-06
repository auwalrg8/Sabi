// ignore_for_file: constant_identifier_names, dangling_library_doc_comments, unintended_html_in_doc_comment

/// Helper extensions and workarounds for ReceivePaymentMethod enum construction
///
/// Problem: flutter_rust_bridge v2.9.0 doesn't expose Rust enum variants as Dart constructors
/// Rust enum: pub enum ReceivePaymentMethod { SparkInvoice { ... }, Bolt11Invoice { ... }, ... }
/// Dart issue: No auto-generated constructors for enum variants

import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';

/// WORKAROUND OPTION 1: Parse Invoice String
/// If the SDK provides a way to receive a payment request string directly,
/// you can parse it back into a ReceivePaymentResponse
extension ReceivePaymentMethodWorkarounds on ReceivePaymentResponse {
  /// Extract the bolt11 invoice from the payment request string
  String get bolt11Invoice => paymentRequest;

  /// Check if this is a valid invoice format
  bool get isValidInvoice =>
      paymentRequest.startsWith('lnbc') || paymentRequest.startsWith('lntb');
}

/// WORKAROUND OPTION 2: Use parseInput to reconstruct payment methods
/// The Spark SDK provides a parse_input function that can parse payment request strings
/// This might work for invoice validation/parsing after creation
extension InvoiceCreationHelpers on ReceivePaymentRequest {
  /// Documentation for manual invoice creation
  ///
  /// Since enum variant constructors are not available, here's what you need to do:
  ///
  /// Step 1: Create the enum variant in Rust (you need SDK team support)
  ///   - Propose adding a Dart helper in breez-sdk-spark-flutter:
  ///     pub async fn create_spark_invoice(
  ///       sdk: &BreezSdk,
  ///       amount: Option<u128>,
  ///       description: Option<String>,
  ///     ) -> Result<ReceivePaymentResponse>
  ///
  /// Step 2: Bind it to Dart via FFI:
  ///   - This would generate the Dart wrapper automatically
  ///
  /// Step 3: Call from Dart:
  ///   final response = await createSparkInvoice(amount: sats * 1000, description: memo);

  static const String ENUM_CONSTRUCTION_BLOCKED = '''
  ReceivePaymentMethod cannot be constructed in Dart due to flutter_rust_bridge limitations.
  
  The Rust SDK defines:
  
  pub enum ReceivePaymentMethod {
    SparkAddress,
    SparkInvoice {
      amount: Option<u128>,
      token_identifier: Option<String>,
      expiry_time: Option<u64>,
      description: Option<String>,
      sender_public_key: Option<String>,
    },
    BitcoinAddress,
    Bolt11Invoice {
      description: String,
      amount_sats: Option<u64>,
    },
  }
  
  But flutter_rust_bridge only generates struct constructors, not enum variants.
  
  REQUIRED FIX:
  Add a Dart helper function in the Spark SDK bindings that constructs the enum.
  ''';
}

/// WORKAROUND OPTION 3: Raw FFI Call (Advanced)
/// If you have access to the native library, you could:
///
/// 1. Import dart:ffi
/// 2. Find the FFI binding for the underlying Rust function
/// 3. Call it directly with the correct struct layout
///
/// Example (pseudocode):
/// ```dart
/// import 'dart:ffi' as ffi;
///
/// typedef CreateInvoiceNative = ffi.Pointer<ReceivePaymentResponse> Function(
///   ffi.Pointer<ReceivePaymentMethod> method
/// );
///
/// typedef CreateInvoice = ffi.Pointer<ReceivePaymentResponse> Function(
///   ffi.Pointer<ReceivePaymentMethod> method
/// );
///
/// final createInvoice = nativeLib
///   .lookup<ffi.NativeFunction<CreateInvoiceNative>>('create_invoice')
///   .asFunction<CreateInvoice>();
/// ```
///
/// This is NOT recommended unless you're familiar with FFI memory management.

/// WORKAROUND OPTION 4: Manually Construct Using JSON
/// Some flutter_rust_bridge versions support JSON deserialization.
/// You could try:
///
/// ```dart
/// // This likely won't work with enums, but worth trying:
/// final jsonData = {
///   'spark_invoice': {
///     'amount': sats * 1000,
///     'description': memo,
///     'token_identifier': null,
///     'expiry_time': null,
///     'sender_public_key': null,
///   }
/// };
///
/// // Some FFI bindings provide a fromJson factory
/// // final method = ReceivePaymentMethod.fromJson(jsonData);
/// ```
///
/// This is also unlikely to work but could be tested.

class ReceivePaymentMethodConstructorFix {
  /// GitHub Issue Template for Breez SDK Team
  static const String GITHUB_ISSUE = '''
Issue: Enum Variant Constructors Not Exposed in Dart FFI Bindings

**Description:**
The Spark SDK's `ReceivePaymentMethod` enum is defined with variants like 
`SparkInvoice { ... }` and `Bolt11Invoice { ... }` in Rust, but flutter_rust_bridge 
v2.9.0 doesn't generate Dart constructors for these variants.

**Problem:**
Dart code cannot call `ReceivePaymentMethod.sparkInvoice(...)` because the FFI 
bindings only expose struct constructors, not enum variant constructors.

**Current Workaround:**
- Manual API calls that return `ReceivePaymentResponse` (if available)
- Custom FFI wrappers (complex, requires SDK fork)

**Solution Request:**
Add a Dart helper function in breez-sdk-spark-flutter that wraps enum construction:

```dart
// Proposed addition to Spark SDK Dart bindings
Future<ReceivePaymentResponse> receivePaymentSparkInvoice({
  required BigInt amount,
  String? description,
  String? tokenIdentifier,
  int? expiryTime,
  String? senderPublicKey,
}) async {
  // Internal: calls _receivePayment with constructed ReceivePaymentMethod
}
```

**Impact:**
This blocks invoice generation functionality for mobile users.

**Links:**
- flutter_rust_bridge issue: [Link to similar FFI enum issues]
- Spark SDK Flutter: https://github.com/breez/breez-sdk-spark-flutter
  ''';

  static const String RECOMMENDED_SDK_CHANGE = '''
To unblock this, the Breez SDK should add these functions to lib/src/models.dart:

extension ReceivePaymentMethodFactory on ReceivePaymentMethod {
  /// Factory constructor for SparkInvoice variant
  static ReceivePaymentMethod sparkInvoice({
    BigInt? amount,
    String? tokenIdentifier,
    int? expiryTime,
    String? description,
    String? senderPublicKey,
  }) {
    // Implementation would construct the enum internally
    // This requires SDK-level support since Dart can't access Rust enums directly
    throw UnimplementedError('SDK must implement this');
  }

  /// Factory constructor for Bolt11Invoice variant
  static ReceivePaymentMethod bolt11Invoice({
    required String description,
    int? amountSats,
  }) {
    throw UnimplementedError('SDK must implement this');
  }
}
''';
}
