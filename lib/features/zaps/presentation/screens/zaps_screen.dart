import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
import 'package:sabi_wallet/features/zaps/presentation/providers/zaps_provider.dart';
import 'package:sabi_wallet/features/zaps/domain/models/post.dart';
import 'package:sabi_wallet/services/nostr_service.dart';
import 'package:sabi_wallet/features/zaps/presentation/widgets/zap_slider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:sabi_wallet/services/notification_service.dart';

class ZapsScreen extends ConsumerWidget {
  const ZapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(zapsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
                    child: Text(
                      'Zaps & Feed',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(30, 30, 30, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 17),
                          child: PostCard(
                            post: posts[index],
                            onLike: () {
                              ref.read(zapsNotifierProvider.notifier).toggleLike(posts[index].id);
                            },
                            onComment: () {},
                            onZap: () async {
                              int selectedAmount = 1000;
                              await showDialog(
                                context: context,
                                builder: (ctx) {
                                  return AlertDialog(
                                    title: const Text('Send Zap'),
                                    content: ZapSlider(
                                      initialValue: 1000,
                                      onChanged: (val) => selectedAmount = val,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Zap!'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (selectedAmount > 0) {
                                final npub = 'npub1...'; // TODO: get real npub from post
                                try {
                                  await NostrService.init();
                                  await NostrService.sendZap(toNpub: npub, amount: selectedAmount);
                                  // Haptic feedback
                                  HapticFeedback.mediumImpact();
                                  // Play zap sound
                                  final player = AudioPlayer();
                                  await player.play(AssetSource('audio/zap_success.mp3'));
                                  // Show animated zap icon
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (ctx) => Center(
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 1.0, end: 1.5),
                                        duration: const Duration(milliseconds: 600),
                                        curve: Curves.elasticOut,
                                        builder: (context, scale, child) => Transform.scale(
                                          scale: scale,
                                          child: Icon(Icons.bolt, color: Colors.amber, size: 120),
                                        ),
                                        onEnd: () => Navigator.of(ctx).pop(),
                                      ),
                                    ),
                                  );
                                  // Add notification
                                  await NotificationService.addNotification(
                                    NotificationModel(
                                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                                      title: 'Zap Sent',
                                      message: 'You zapped $selectedAmount sats!',
                                      timestamp: DateTime.now(),
                                      type: 'zap',
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Zap sent! ⚡')),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Zap failed: $e')),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      },
                      childCount: posts.length,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 30,
              bottom: 30,
              child: FloatingActionButton(
                onPressed: () {},
                backgroundColor: AppColors.primary,
                shape: const CircleBorder(),
                elevation: 4,
                child: const Icon(
                  Icons.bolt,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onZap;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onZap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  post.authorInitial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.71,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.71,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.bolt,
                              color: AppColors.primary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              post.zapAmount,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.67,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.timestamp,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.67,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.content,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.71,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.surface,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                _ActionButton(
                  icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                  label: post.likes.toString(),
                  color: post.isLiked ? AppColors.primary : AppColors.textSecondary,
                  onTap: onLike,
                ),
                const SizedBox(width: 24),
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: post.comments.toString(),
                  color: AppColors.textSecondary,
                  onTap: onComment,
                ),
                const SizedBox(width: 24),
                _ActionButton(
                  icon: Icons.bolt,
                  label: 'Zap',
                  color: AppColors.primary,
                  onTap: onZap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.67,
            ),
          ),
        ],
      ),
    );
  }
}
