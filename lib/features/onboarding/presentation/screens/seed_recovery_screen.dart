import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:sabi_wallet/features/wallet/presentation/screens/home_screen.dart';
import 'package:bip39/bip39.dart' as bip39;

class SeedRecoveryScreen extends ConsumerStatefulWidget {
  const SeedRecoveryScreen({super.key});

  @override
  ConsumerState<SeedRecoveryScreen> createState() => _SeedRecoveryScreenState();
}

class _SeedRecoveryScreenState extends ConsumerState<SeedRecoveryScreen> {
  final List<TextEditingController> _controllers = List.generate(
    12,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(12, (index) => FocusNode());
  bool _isRestoring = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onWordChanged(int index, String value) {
    if (value.contains(' ')) {
      // User pasted multiple words
      final words = value.trim().split(RegExp(r'\s+'));
      for (int i = 0; i < words.length && (index + i) < 12; i++) {
        _controllers[index + i].text = words[i].toLowerCase().trim();
      }
      // Focus the next empty field or the last field
      final nextIndex = (index + words.length).clamp(0, 11);
      if (nextIndex < 12) {
        _focusNodes[nextIndex].requestFocus();
      }
      setState(() => _errorMessage = null);
      return;
    }

    // Auto-advance on space or when word is complete
    if (value.endsWith(' ') && index < 11) {
      _controllers[index].text = value.trim();
      _focusNodes[index + 1].requestFocus();
    }

    setState(() => _errorMessage = null);
  }

  Future<void> _restoreWallet() async {
    // Collect all words
    final words = _controllers.map((c) => c.text.trim().toLowerCase()).toList();

    // Check if all words are entered
    if (words.any((w) => w.isEmpty)) {
      setState(() => _errorMessage = 'Please enter all 12 words');
      return;
    }

    final mnemonic = words.join(' ');

    // Validate mnemonic
    if (!bip39.validateMnemonic(mnemonic)) {
      setState(
        () => _errorMessage = 'Invalid seed phrase. Please check your words.',
      );
      return;
    }

    setState(() {
      _isRestoring = true;
      _errorMessage = null;
    });

    try {
      // Restore wallet using Spark SDK (force restore flow)
      await BreezSparkService.initializeSparkSDK(
        mnemonic: mnemonic,
        isRestore: true,
      );

      // Persist mnemonic and backup status so UI detects backup
      final storage = ref.read(secureStorageServiceProvider);
      await storage.saveWalletSeed(mnemonic);
      await storage.saveBackupStatus('seed');

      if (!mounted) return;

      // Navigate to home screen and show success message
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );

      // Note: ScaffoldMessenger after navigation will fail - message shown in new screen instead
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _errorMessage = 'Failed to restore wallet: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Restore from Seed Phrase',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Enter your 12-word seed phrase',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildWordGrid(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Make sure you enter the words in the correct order. You can paste all 12 words at once.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildRestoreButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWordGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3.5,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return _buildWordField(index);
      },
    );
  }

  Widget _buildWordField(int index) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '${index + 1}.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'word',
                hintStyle: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
              ),
              onChanged: (value) => _onWordChanged(index, value),
              onSubmitted: (_) {
                if (index < 11) {
                  _focusNodes[index + 1].requestFocus();
                }
              },
              textInputAction:
                  index < 11 ? TextInputAction.next : TextInputAction.done,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isRestoring ? null : _restoreWallet,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child:
              _isRestoring
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Text(
                    'Restore Wallet',
                    style: TextStyle(
                      color: AppColors.surface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
        ),
      ),
    );
  }
}
