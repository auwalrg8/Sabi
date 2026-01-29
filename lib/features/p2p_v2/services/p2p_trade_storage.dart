import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/p2p_state.dart';

/// Local storage service for P2P trades using Hive
/// 
/// Persists trades across app restarts so users can:
/// - See their trade history
/// - Resume active trades
/// - Track completed transactions
class P2PTradeStorage {
  static const String _boxName = 'p2p_trades_v2';
  static const String _lastSyncKey = 'last_sync';
  
  static Box? _box;
  static bool _initialized = false;

  /// Initialize the storage - call this on app startup
  static Future<void> init() async {
    if (_initialized) return;
    
    try {
      debugPrint('📦 P2PTradeStorage: Initializing...');
      
      // Open Hive box for P2P trades
      _box = await Hive.openBox(_boxName);
      _initialized = true;
      
      debugPrint('✅ P2PTradeStorage: Initialized with ${_box!.length} entries');
    } catch (e) {
      debugPrint('❌ P2PTradeStorage: Init failed: $e');
      rethrow;
    }
  }

  /// Check if storage is initialized
  static bool get isInitialized => _initialized && _box != null;

  /// Save a single trade
  static Future<void> saveTrade(P2PTrade trade) async {
    if (!isInitialized) await init();
    
    try {
      final json = trade.toJson();
      await _box!.put(trade.id, jsonEncode(json));
      debugPrint('💾 P2PTradeStorage: Saved trade ${trade.id.substring(0, 8)}...');
    } catch (e) {
      debugPrint('❌ P2PTradeStorage: Failed to save trade: $e');
      rethrow;
    }
  }

  /// Save multiple trades at once (batch operation)
  static Future<void> saveAllTrades(Map<String, P2PTrade> trades) async {
    if (!isInitialized) await init();
    
    try {
      final entries = <String, String>{};
      for (final entry in trades.entries) {
        entries[entry.key] = jsonEncode(entry.value.toJson());
      }
      await _box!.putAll(entries);
      debugPrint('💾 P2PTradeStorage: Batch saved ${trades.length} trades');
    } catch (e) {
      debugPrint('❌ P2PTradeStorage: Failed to batch save: $e');
      rethrow;
    }
  }

  /// Load all trades from storage
  static Future<Map<String, P2PTrade>> loadAllTrades() async {
    if (!isInitialized) await init();
    
    try {
      final trades = <String, P2PTrade>{};
      
      for (final key in _box!.keys) {
        if (key == _lastSyncKey) continue; // Skip metadata keys
        
        try {
          final jsonStr = _box!.get(key) as String?;
          if (jsonStr != null) {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            final trade = P2PTrade.fromJson(json);
            trades[trade.id] = trade;
          }
        } catch (e) {
          debugPrint('⚠️ P2PTradeStorage: Failed to parse trade $key: $e');
          // Continue with other trades even if one fails
        }
      }
      
      debugPrint('📦 P2PTradeStorage: Loaded ${trades.length} trades');
      return trades;
    } catch (e) {
      debugPrint('❌ P2PTradeStorage: Failed to load trades: $e');
      return {};
    }
  }

  /// Load a specific trade by ID
  static Future<P2PTrade?> loadTrade(String tradeId) async {
    if (!isInitialized) await init();
    
    try {
      final jsonStr = _box!.get(tradeId) as String?;
      if (jsonStr == null) return null;
      
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return P2PTrade.fromJson(json);
    } catch (e) {
      debugPrint('❌ P2PTradeStorage: Failed to load trade $tradeId: $e');
      return null;
    }
  }

  /// Delete a trade from storage
  static Future<void> deleteTrade(String tradeId) async {
    if (!isInitialized) await init();
    
    try {
      await _box!.delete(tradeId);
      debugPrint('🗑️ P2PTradeStorage: Deleted trade $tradeId');
    } catch (e) {
      debugPrint('❌ P2PTradeStorage: Failed to delete trade: $e');
      rethrow;
    }
  }

  /// Clear all trades (for debugging or reset)
  static Future<void> clearAll() async {
    if (!isInitialized) await init();
    
    try {
      await _box!.clear();
      debugPrint('🧹 P2PTradeStorage: Cleared all trades');
    } catch (e) {
      debugPrint('❌ P2PTradeStorage: Failed to clear: $e');
      rethrow;
    }
  }

  /// Get active trades (not completed or cancelled)
  static Future<List<P2PTrade>> getActiveTrades() async {
    final allTrades = await loadAllTrades();
    return allTrades.values
        .where((t) => !t.isCompleted && !t.isCancelled)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Get completed trades (for history)
  static Future<List<P2PTrade>> getCompletedTrades({int limit = 50}) async {
    final allTrades = await loadAllTrades();
    final completed = allTrades.values
        .where((t) => t.isCompleted || t.isCancelled)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    return completed.take(limit).toList();
  }

  /// Update last sync timestamp
  static Future<void> setLastSync(DateTime time) async {
    if (!isInitialized) await init();
    await _box!.put(_lastSyncKey, time.millisecondsSinceEpoch);
  }

  /// Get last sync timestamp
  static Future<DateTime?> getLastSync() async {
    if (!isInitialized) await init();
    final ms = _box!.get(_lastSyncKey) as int?;
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Export trades for backup (JSON format)
  static Future<String> exportTrades() async {
    final trades = await loadAllTrades();
    final exportData = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'trades': trades.values.map((t) => t.toJson()).toList(),
    };
    return jsonEncode(exportData);
  }

  /// Import trades from backup
  static Future<int> importTrades(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      final tradesJson = data['trades'] as List<dynamic>?;
      
      if (tradesJson == null) return 0;
      
      int imported = 0;
      for (final tradeJson in tradesJson) {
        try {
          final trade = P2PTrade.fromJson(tradeJson as Map<String, dynamic>);
          await saveTrade(trade);
          imported++;
        } catch (e) {
          debugPrint('⚠️ P2PTradeStorage: Failed to import trade: $e');
        }
      }
      
      debugPrint('📥 P2PTradeStorage: Imported $imported trades');
      return imported;
    } catch (e) {
      debugPrint('❌ P2PTradeStorage: Import failed: $e');
      return 0;
    }
  }
}
