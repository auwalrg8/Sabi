# ReceivePaymentMethod Enum Constructor Workaround

## Problem

The Spark SDK's `ReceivePaymentMethod` enum cannot be constructed in Dart because `flutter_rust_bridge` v2.9.0 doesn't expose Rust enum variants as Dart constructors.

### Rust Definition (SDK Side)
```rust
pub enum ReceivePaymentMethod {
    SparkAddress,
    SparkInvoice {
        amount: Option<u128>,              // millisats (sats * 1000)
        token_identifier: Option<String>,  // Bitcoin if null
        expiry_time: Option<u64>,          // Unix timestamp seconds
        description: Option<String>,
        sender_public_key: Option<String>, // Accept from any sender if null
    },
    BitcoinAddress,
    Bolt11Invoice {
        description: String,
        amount_sats: Option<u64>,
    },
}

pub struct ReceivePaymentRequest {
    pub payment_method: ReceivePaymentMethod,
}

pub async fn receive_payment(
    sdk: &BreezSdk, 
    request: ReceivePaymentRequest
) -> Result<ReceivePaymentResponse> { ... }
```

### What Doesn't Work in Dart
```dart
// ❌ This doesn't compile - enum variants aren't exposed as constructors
final method = ReceivePaymentMethod.sparkInvoice(
  amount: sats * 1000,
  description: memo,
);

// ❌ Even factory patterns don't work
final method = ReceivePaymentMethod.sparsInvoice(...);

// ❌ This might work for simple unit enums but not variants with data
final method = ReceivePaymentMethod.sparkAddress;
```

### Root Cause: flutter_rust_bridge Limitation

`flutter_rust_bridge` automatically generates:
- ✅ Struct constructors: `struct Foo { a: i32, b: String }` → `Foo(a: int, b: String)`
- ❌ Enum variant constructors: `enum Bar { Variant { x: i32 } }` → NO auto-generation

This is a known limitation of the FFI binding generator.

## Available Solutions (Ranked by Feasibility)

### Solution 1: **SDK Team Adds Dart Helper Function** (RECOMMENDED)

**What:** Breez SDK team adds a helper function that constructs the enum internally.

**In breez-sdk-spark-flutter/lib/src/models.dart:**
```dart
extension ReceivePaymentMethodFactory on BreezSdk {
  /// Create a Spark Invoice payment request
  Future<ReceivePaymentResponse> createSparkInvoice({
    required int amountSats,
    String? description,
    String? tokenIdentifier,
    int? expiryTime,
    String? senderPublicKey,
  }) async {
    // This function receives the params and calls Rust-side code that
    // constructs the ReceivePaymentMethod enum internally
    return receivePayment(
      request: ReceivePaymentRequest(
        paymentMethod: _ConstructReceivePaymentMethod.sparkInvoice(
          amount: amountSats * 1000, // msat
          description: description,
          tokenIdentifier: tokenIdentifier,
          expiryTime: expiryTime,
          senderPublicKey: senderPublicKey,
        ),
      ),
    );
  }
}
```

**Timeline:** Contact Breez SDK team - they can add this in one commit
**Complexity:** Low (SDK side only)
**Recommended:** ✅ YES

---

### Solution 2: **Use SDK's Default Payment Method** (If Available)

**What:** Check if Spark SDK provides a simpler API that doesn't require enum construction.

**Example:**
```dart
// If the SDK provides a simpler method
final response = await _sdk.receivePaymentDefault(
  amountSats: sats,
  description: memo,
);
```

**To Investigate:**
- Check `BreezSdk` class methods in generated bindings
- Look for `receive_payment`, `create_invoice`, `get_payment_request` methods
- Check if any use `Option<ReceivePaymentMethod>` or alternative patterns

**Timeline:** Could work immediately if method exists
**Complexity:** Low (just API discovery)
**Recommended:** ✅ Try this first

---

### Solution 3: **Manually Implement in Rust (Advanced Fork)**

**What:** Create a custom Rust function and fork the Breez SDK.

**Fork breez-sdk-spark-flutter and add:**

In `lib.rs`:
```rust
#[flutter_rust_bridge::frb(init_from_dart = false)]
pub async fn create_spark_invoice(
    sdk_ptr: usize,
    amount_sats: u64,
    description: String,
) -> anyhow::Result<ReceivePaymentResponse> {
    let sdk = unsafe { &*(sdk_ptr as *const BreezSdk) };
    
    let request = ReceivePaymentRequest {
        payment_method: ReceivePaymentMethod::SparkInvoice {
            amount: Some((amount_sats * 1000) as u128),
            token_identifier: None,
            expiry_time: None,
            description: Some(description),
            sender_public_key: None,
        },
    };
    
    sdk.receive_payment(request).await
}
```

**Dart binding (auto-generated):**
```dart
Future<ReceivePaymentResponse> createSparkInvoice({
  required int amountSats,
  required String description,
}) => _api.createSparkInvoice(amountSats: amountSats, description: description);
```

**Timeline:** 1-2 hours
**Complexity:** Medium (requires Rust + FFI knowledge)
**Recommended:** ⚠️ Only if SDK team doesn't respond quickly

---

### Solution 4: **Raw FFI Workaround** (Hacky, Not Recommended)

**What:** Call FFI functions directly using `dart:ffi`.

**Problems:**
- Extremely fragile - dependent on binary layout
- No type safety
- Will break if SDK updates
- Memory management nightmare

**Not Recommended:** ❌ AVOID

---

## Immediate Action Plan

### Step 1: Verify No Simpler API
```dart
// Check if receivePayment has a simpler overload
await _sdk!.receivePayment(...); // What parameters does it actually accept?

// Or check for alternative methods
_sdk!.getPaymentRequest(...)?
_sdk!.generateInvoice(...)?
_sdk!.createReceiveRequest(...)?
```

### Step 2: Contact Breez SDK Team
- File GitHub issue: https://github.com/breez/breez-sdk-spark-flutter/issues
- Reference this workaround doc
- Request helper factory method

**Sample Issue:**
```
Title: [Feature] Dart helper for ReceivePaymentMethod enum construction

Description:
flutter_rust_bridge doesn't expose enum variant constructors in Dart.
This blocks invoice generation in mobile apps.

Rust definition:
pub enum ReceivePaymentMethod { 
    SparkInvoice { amount, description, ... },
    ... 
}

Dart cannot construct:
final method = ReceivePaymentMethod.sparkInvoice(...); // ❌ Not available

Workaround needed:
Add a helper function that constructs the enum internally:

BreezSdk.createSparkInvoice(amountSats, description) -> ReceivePaymentResponse

This would unblock mobile payment receipt generation.
```

### Step 3: Implement Fallback (If Needed)
If SDK team needs time, use Solution 3 (fork with custom Rust function).

---

## Testing the Solution

Once you have a working enum constructor, test with:

```dart
// In receive_screen.dart or test
final response = await BreezSparkService.createInvoice(
  50000, // sats
  'Coffee at Nairobi Café'
);

expect(response.paymentRequest, startsWith('lnbc'));
expect(response.fee, greaterThan(0));
```

---

## Current Status

**Status:** 🔴 Blocked  
**File:** `lib/services/breez_spark_service.dart` → `createInvoice()`  
**Error:** `UnimplementedError`  
**Workaround:** See `lib/extensions/receive_payment_method_extension.dart`

---

## References

- **Breez SDK Flutter:** https://github.com/breez/breez-sdk-spark-flutter
- **flutter_rust_bridge Docs:** https://cjycode.com/flutter_rust_bridge/
- **Rust Enum FFI:** https://docs.rs/flutter_rust_bridge/latest/flutter_rust_bridge/
- **Related Issues:**
  - flutter_rust_bridge#2064: Enum variant constructors
  - flutter_rust_bridge#1899: FFI enum support
