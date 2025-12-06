import 'package:hive_flutter/hive_flutter.dart';

class SecureStorage {
  static late Box _box;
  static const _boxName = 'sabi_secure';

  static Future<void> init() async {
    await Hive.initFlutter();
    // HiveAesCipher requires a 32-byte key. In production, persist the key securely.
    final key = Hive.generateSecureKey();
    _box = await Hive.openBox(
      _boxName,
      encryptionCipher: HiveAesCipher(key),
    );
  }

  static String? get inviteCode => _box.get('invite_code');
  static String? get nodeId => _box.get('node_id');
  static bool get hasWallet => inviteCode != null;
  static bool get initialChannelOpened => _box.get('initial_channel_opened', defaultValue: false);

  static Future<void> saveWalletData({
    required String inviteCode,
    required String nodeId,
    required bool initialChannelOpened,
  }) async {
    await _box.put('invite_code', inviteCode);
    await _box.put('node_id', nodeId);
    await _box.put('initial_channel_opened', initialChannelOpened);
    await _box.put('has_onboarded', true);
  }

  static Future<void> clearAll() async => _box.clear();
}
