import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:sabi_wallet/features/p2p/data/payment_method_model.dart';

/// Service for managing user's payment methods
class PaymentMethodService {
  static const String _boxName = 'p2p_payment_methods';
  static const String _methodsKey = 'saved_methods';
  
  Box? _box;
  
  /// Initialize the service
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox(_boxName);
    debugPrint('💳 PaymentMethodService initialized');
  }
  
  /// Get all saved payment methods
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    await init();
    final jsonList = _box?.get(_methodsKey) as String?;
    if (jsonList == null || jsonList.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(jsonList) as List<dynamic>;
      return decoded
          .map((e) => PaymentMethodModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          // Sort: default first, then by creation date
          if (a.isDefault && !b.isDefault) return -1;
          if (!a.isDefault && b.isDefault) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
    } catch (e) {
      debugPrint('❌ Failed to parse payment methods: $e');
      return [];
    }
  }
  
  /// Get payment methods by type
  Future<List<PaymentMethodModel>> getPaymentMethodsByType(PaymentMethodType type) async {
    final methods = await getPaymentMethods();
    return methods.where((m) => m.type == type).toList();
  }
  
  /// Get default payment method
  Future<PaymentMethodModel?> getDefaultPaymentMethod() async {
    final methods = await getPaymentMethods();
    try {
      return methods.firstWhere((m) => m.isDefault);
    } catch (_) {
      return methods.isNotEmpty ? methods.first : null;
    }
  }
  
  /// Add a new payment method
  Future<PaymentMethodModel> addPaymentMethod(PaymentMethodModel method) async {
    await init();
    final methods = await getPaymentMethods();
    
    // Generate ID if not provided
    final newMethod = method.copyWith(
      id: method.id.isEmpty ? const Uuid().v4() : method.id,
      createdAt: DateTime.now(),
    );
    
    // If this is the first method or marked as default, clear other defaults
    if (newMethod.isDefault || methods.isEmpty) {
      for (int i = 0; i < methods.length; i++) {
        if (methods[i].isDefault) {
          methods[i] = methods[i].copyWith(isDefault: false);
        }
      }
    }
    
    // Set as default if it's the first method
    final methodToAdd = methods.isEmpty 
        ? newMethod.copyWith(isDefault: true)
        : newMethod;
    
    methods.add(methodToAdd);
    await _savePaymentMethods(methods);
    
    debugPrint('✅ Added payment method: ${methodToAdd.name}');
    return methodToAdd;
  }
  
  /// Update an existing payment method
  Future<void> updatePaymentMethod(PaymentMethodModel method) async {
    await init();
    final methods = await getPaymentMethods();
    
    final index = methods.indexWhere((m) => m.id == method.id);
    if (index == -1) {
      throw Exception('Payment method not found');
    }
    
    // If setting as default, clear other defaults
    if (method.isDefault) {
      for (int i = 0; i < methods.length; i++) {
        if (methods[i].id != method.id && methods[i].isDefault) {
          methods[i] = methods[i].copyWith(isDefault: false);
        }
      }
    }
    
    methods[index] = method.copyWith(updatedAt: DateTime.now());
    await _savePaymentMethods(methods);
    
    debugPrint('✅ Updated payment method: ${method.name}');
  }
  
  /// Delete a payment method
  Future<void> deletePaymentMethod(String id) async {
    await init();
    final methods = await getPaymentMethods();
    
    final methodToDelete = methods.firstWhere(
      (m) => m.id == id,
      orElse: () => throw Exception('Payment method not found'),
    );
    
    methods.removeWhere((m) => m.id == id);
    
    // If deleted method was default, set first remaining as default
    if (methodToDelete.isDefault && methods.isNotEmpty) {
      methods[0] = methods[0].copyWith(isDefault: true);
    }
    
    await _savePaymentMethods(methods);
    debugPrint('🗑️ Deleted payment method: ${methodToDelete.name}');
  }
  
  /// Set a payment method as default
  Future<void> setDefaultPaymentMethod(String id) async {
    await init();
    final methods = await getPaymentMethods();
    
    for (int i = 0; i < methods.length; i++) {
      methods[i] = methods[i].copyWith(isDefault: methods[i].id == id);
    }
    
    await _savePaymentMethods(methods);
    debugPrint('⭐ Set default payment method: $id');
  }
  
  /// Save payment methods to storage
  Future<void> _savePaymentMethods(List<PaymentMethodModel> methods) async {
    final jsonList = jsonEncode(methods.map((m) => m.toJson()).toList());
    await _box?.put(_methodsKey, jsonList);
  }
  
  /// Clear all payment methods
  Future<void> clearAll() async {
    await init();
    await _box?.delete(_methodsKey);
    debugPrint('🗑️ Cleared all payment methods');
  }
}

/// Provider for PaymentMethodService
final paymentMethodServiceProvider = Provider<PaymentMethodService>((ref) {
  return PaymentMethodService();
});

/// Provider for the list of payment methods
final paymentMethodsProvider = FutureProvider<List<PaymentMethodModel>>((ref) async {
  final service = ref.watch(paymentMethodServiceProvider);
  return service.getPaymentMethods();
});

/// Provider for default payment method
final defaultPaymentMethodProvider = FutureProvider<PaymentMethodModel?>((ref) async {
  final service = ref.watch(paymentMethodServiceProvider);
  return service.getDefaultPaymentMethod();
});
