import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/core/services/secure_storage_service.dart';
import 'package:sabi_wallet/services/breez_spark_service.dart';
import 'package:bip39/bip39.dart' as bip39;

class SeedRecoveryScreen extends ConsumerStatefulWidget {
  const SeedRecoveryScreen({super.key});

  @override
  ConsumerState<SeedRecoveryScreen> createState() => _SeedRecoveryScreenState();
}

class _SeedRecoveryScreenState extends ConsumerState<SeedRecoveryScreen> {
  final TextEditingController _pasteController = TextEditingController();
  List<TextEditingController> _controllers = [];
  List<FocusNode> _focusNodes = [];
  int _wordCount = 12; // Default to 12 words
  bool _isRestoring = false;
  String? _errorMessage;
  bool _usePasteMode = true; // Start in paste mode

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // Clear existing
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    
    // Create new controllers based on word count
    _controllers = List.generate(_wordCount, (index) => TextEditingController());
    _focusNodes = List.generate(_wordCount, (index) => FocusNode());
  }

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

  void _onPasteChanged(String value) {
    setState(() => _errorMessage = null);
    
    if (value.trim().isEmpty) return;
    
    // Split by whitespace
    final words = value.trim().toLowerCase().split(RegExp(r'\s+'));
    
    // Validate word count (12, 15, 18, 21, or 24 words)
    if (words.length >= 12 && words.length <= 24) {
      // Auto-detect and set word count
      final detectedCount = words.length;
      if (detectedCount != _wordCount) {
        setState(() {
          _wordCount = detectedCount;
          _initializeControllers();
        });
      }
      
      // Fill in the words
      for (int i = 0; i < words.length && i < _wordCount; i++) {
        _controllers[i].text = words[i];
      }
    }
  }

  void _onWordChanged(int index, String value) {
    if (value.contains(' ')) {
      // User pasted multiple words in grid mode
      final words = value.trim().split(RegExp(r'\s+'));
      for (int i = 0; i < words.length && (index + i) < _wordCount; i++) {
        _controllers[index + i].text = words[i].toLowerCase().trim();
      }
      final nextIndex = (index + words.length).clamp(0, _wordCount - 1);
      if (nextIndex < _wordCount) {
        _focusNodes[nextIndex].requestFocus();
      }
      setState(() => _errorMessage = null);
      return;
    }

    // Auto-advance on space
    if (value.endsWith(' ') && index < _wordCount - 1) {
      _controllers[index].text = value.trim();
      _focusNodes[index + 1].requestFocus();
    }

    setState(() => _errorMessage = null);
  }

  Future<void> _restoreWallet() async {
    String mnemonic;
    
    if (_usePasteMode) {
      mnemonic = _pasteController.text.trim().toLowerCase();
    } else {
      // Collect all words from grid
      final words = _controllers.map((c) => c.text.trim().toLowerCase()).toList();
      if (words.any((w) => w.isEmpty)) {
        setState(() => _errorMessage = 'Please enter all $_wordCount words');
        return;
      }
      mnemonic = words.join(' ');
    }

    if (mnemonic.isEmpty) {
      setState(() => _errorMessage = 'Please enter your seed phrase');
      return;
    }

    // Validate word count
    final wordList = mnemonic.split(RegExp(r'\s+'));
    if (wordList.length < 12 || wordList.length > 24) {
      setState(() => _errorMessage = 'Seed phrase must be 12-24 words');
      return;
    }

    // Validate BIP39 mnemonic (checksum validation)
    if (!bip39.validateMnemonic(mnemonic)) {
      setState(() => _errorMessage = 'Invalid seed phrase — check spelling and word count');
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
      
      // CRITICAL: Mark onboarding complete so app never loops back
      await BreezSparkService.setOnboardingComplete();

      if (!mounted) return;

      // Navigate to home screen using named route
      Navigator.pushReplacementNamed(context, '/home');

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
                    Text(
                      _usePasteMode ? 'Paste your seed phrase (12-24 words)' : 'Enter your $_wordCount-word seed phrase',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Mode toggle
                    Row(
                      children: [
                        _buildModeButton('Paste', _usePasteMode, () {
                          setState(() => _usePasteMode = true);
                        }),
                        const SizedBox(width: 8),
                        _buildModeButton('Type', !_usePasteMode, () {
                          setState(() => _usePasteMode = false);
                        }),
                        const Spacer(),
                        if (!_usePasteMode) _buildWordCountSelector(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _usePasteMode ? _buildPasteField() : _buildWordGrid(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF4D4F).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFFFF4D4F),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFFF4D4F),
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
                              'Supports 12-24 word BIP39 seed phrases. Paste your full phrase or type word by word.',
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

  Widget _buildPasteField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _pasteController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        maxLines: 6,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Paste your seed phrase here...\n\ne.g., word1 word2 word3 ... word12',
          hintStyle: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 13,
          ),
        ),
        onChanged: _onPasteChanged,
      ),
    );
  }

  Widget _buildModeButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildWordCountSelector() {
    return Row(
      children: [
        const Text(
          'Words:',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        ...[12, 24].map((count) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _wordCount = count;
                _initializeControllers();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _wordCount == count ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _wordCount == count ? AppColors.primary : Colors.transparent,
                ),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: _wordCount == count ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        )),
      ],
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
      itemCount: _wordCount,
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
                if (index < _wordCount - 1) {
                  _focusNodes[index + 1].requestFocus();
                }
              },
              textInputAction:
                  index < _wordCount - 1 ? TextInputAction.next : TextInputAction.done,
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
