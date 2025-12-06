import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/services/services.dart';

/// Example screen demonstrating SecureStorageService usage
class SecureStorageExampleScreen extends ConsumerStatefulWidget {
  const SecureStorageExampleScreen({super.key});

  @override
  ConsumerState<SecureStorageExampleScreen> createState() =>
      _SecureStorageExampleScreenState();
}

class _SecureStorageExampleScreenState
    extends ConsumerState<SecureStorageExampleScreen> {
  String _output = 'No operations yet';

  @override
  Widget build(BuildContext context) {
    final storage = ref.read(secureStorageServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Secure Storage Example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Output display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _output,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 24),

            // Basic Operations
            const Text(
              'Basic Operations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await storage.write(key: 'test_key', value: 'Hello Secure!');
                setState(() => _output = 'Written: test_key = "Hello Secure!"');
              },
              child: const Text('Write Test Data'),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = await storage.read(key: 'test_key');
                setState(() => _output = 'Read: test_key = "$value"');
              },
              child: const Text('Read Test Data'),
            ),
            ElevatedButton(
              onPressed: () async {
                await storage.delete(key: 'test_key');
                setState(() => _output = 'Deleted: test_key');
              },
              child: const Text('Delete Test Data'),
            ),

            const SizedBox(height: 24),

            // Auth Token Operations
            const Text(
              'Authentication Tokens',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await storage.saveAuthTokens(
                  accessToken: 'access_token_123',
                  refreshToken: 'refresh_token_456',
                );
                setState(() => _output = 'Saved auth tokens');
              },
              child: const Text('Save Auth Tokens'),
            ),
            ElevatedButton(
              onPressed: () async {
                final accessToken = await storage.getAuthToken();
                final refreshToken = await storage.getRefreshToken();
                setState(() => _output =
                    'Access: $accessToken\nRefresh: $refreshToken');
              },
              child: const Text('Get Auth Tokens'),
            ),
            ElevatedButton(
              onPressed: () async {
                await storage.clearAuthTokens();
                setState(() => _output = 'Cleared auth tokens');
              },
              child: const Text('Clear Auth Tokens'),
            ),

            const SizedBox(height: 24),

            // Wallet Operations
            const Text(
              'Wallet Operations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await storage.saveWalletSeed(
                  'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
                );
                setState(() => _output = 'Saved wallet seed (12 words)');
              },
              child: const Text('Save Wallet Seed'),
            ),
            ElevatedButton(
              onPressed: () async {
                final seed = await storage.getWalletSeed();
                setState(() => _output = 'Wallet seed: ${seed?.substring(0, 30)}...');
              },
              child: const Text('Get Wallet Seed'),
            ),

            const SizedBox(height: 24),

            // Nostr Keys
            const Text(
              'Nostr Keys',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await storage.saveNostrKeys(
                  privateKey: 'nsec1...',
                  publicKey: 'npub1...',
                );
                setState(() => _output = 'Saved Nostr keys');
              },
              child: const Text('Save Nostr Keys'),
            ),
            ElevatedButton(
              onPressed: () async {
                final privateKey = await storage.getNostrPrivateKey();
                final publicKey = await storage.getNostrPublicKey();
                setState(() =>
                    _output = 'Private: $privateKey\nPublic: $publicKey');
              },
              child: const Text('Get Nostr Keys'),
            ),

            const SizedBox(height: 24),

            // Danger Zone
            const Text(
              'Danger Zone',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                await storage.clearUserData();
                setState(() => _output = 'Cleared user data (logout)');
              },
              child: const Text('Clear User Data'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await storage.completeWipe();
                setState(() => _output = 'COMPLETE WIPE - All data deleted!');
              },
              child: const Text('Complete Wipe (⚠️ Dangerous!)'),
            ),
          ],
        ),
      ),
    );
  }
}

