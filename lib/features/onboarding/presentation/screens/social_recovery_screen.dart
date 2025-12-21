// lib/features/onboarding/presentation/screens/social_recovery_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/recovery/social_recovery_setup_screen.dart';
import '../providers/onboarding_provider.dart';

class SocialRecoveryScreen extends ConsumerWidget {
  const SocialRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingState = ref.watch(onboardingNotifierProvider);
    final masterSeed = onboardingState.wallet?.mnemonic ?? '';

    // Navigate directly to setup screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => SocialRecoverySetupScreen(
            masterSeed: masterSeed,
          ),
        ),
        (route) => route.isFirst,
      );
    });

    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
    );
  }
}

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 29),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back + Title
                    Row(
                      children: [
                        IconButton(
  onPressed: () => Navigator.pop(context),
  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
),
                        const SizedBox(width: 10),
                        const Text(
                          'Social Recovery',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Info card
                    Container(
                      padding: const EdgeInsets.all(21),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: CustomPaint(painter: ShieldIconPainter()),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Who you want to trust with your money if phone loss or spoil?',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(fontSize: 12, height: 1.6),
                              children: [
                                TextSpan(
                                  text: 'No seed phrase. ',
                                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text:
                                      'Just pick 3 of your people who use Bitcoin/Nostr. We go split your wallet into secret shares and send to them via encrypted Nostr DM.',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Counter + Add Contact
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Selected: $selectedCount/3',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                            const Text('Pick 3 people wey you trust',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                          ],
                        ),
                        TextButton.icon(
  onPressed: () {},
  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
  label: const Text('Add Contact', style: TextStyle(color: AppColors.primary)),
),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Contact List
                    ...availableContacts.map((contact) {
                      final isSelected = selectedContacts.contains(contact);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: GestureDetector(
                          onTap: () => ref.read(onboardingNotifierProvider.notifier).toggleContact(contact),
                          child: ContactCard(contact: contact, isSelected: isSelected),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.all(31),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: hasFullSelection
                          ? () {
                              // TODO: Implement actual recovery share encryption and distribution via Nostr
                              // Show wallet creation animation, then navigate to home
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const WalletCreationAnimationScreen()),
                                (route) => false,
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasFullSelection ? AppColors.primary : AppColors.disabled,
                      ),
                      child: const Text('Encrypt & send recovery shares'),
                    ),
                  ),
                  if (hasFullSelection) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Each person will receive one encrypted share via Nostr DM',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}