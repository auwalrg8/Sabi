import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabi_wallet/features/p2p/services/p2p_notification_service.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/services/p2p_trade_manager.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_trade_chat_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_offer_messages_screen.dart';

/// P2P Notification Screen - Displays all P2P-related notifications
class P2PNotificationScreen extends ConsumerWidget {
  const P2PNotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(p2pNotificationsProvider);
    final notificationService = ref.watch(p2pNotificationServiceProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => notificationService.markAllAsRead(),
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Colors.orange, fontSize: 14),
            ),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                onTap:
                    () => _handleNotificationTap(
                      context,
                      notification,
                      notificationService,
                    ),
              );
            },
          );
        },
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
        error:
            (e, _) => Center(
              child: Text(
                'Error loading notifications',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'P2P trade updates will appear here',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    P2PNotification notification,
    P2PNotificationService service,
  ) {
    // Mark as read
    service.markAsRead(notification.id);

    // Navigate based on notification type
    if (notification.tradeId != null) {
      // Navigate to trade chat
      final tradeManager = P2PTradeManager();
      final trade = tradeManager.getTrade(notification.tradeId!);

      if (trade != null) {
        // Build offer from trade data
        final offer = P2POfferModel(
          id: trade.offerId,
          name:
              trade.isBuyer
                  ? (trade.sellerName ?? 'Seller')
                  : (trade.buyerName ?? 'Buyer'),
          pricePerBtc: trade.pricePerBtc,
          paymentMethod: trade.paymentMethod,
          eta: '< 15 min',
          ratingPercent: 100,
          trades: 0,
          minLimit: 0,
          maxLimit: trade.fiatAmount.toInt() * 2,
          paymentAccountDetails: trade.paymentDetails,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => P2PTradeChatScreen(
                  offer: offer,
                  tradeAmount: trade.fiatAmount,
                  receiveSats: trade.satsAmount.toDouble(),
                  isSeller: trade.isSeller,
                  existingTrade: trade,
                ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trade not found'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } else if (notification.offerId != null) {
      // Navigate to offer messages screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => P2POfferMessagesScreen(
                offerId: notification.offerId!,
                offerTitle: notification.title,
              ),
        ),
      );
    }
  }
}

/// Individual notification tile
class _NotificationTile extends StatelessWidget {
  final P2PNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color:
            notification.isRead
                ? Colors.grey[900]?.withOpacity(0.5)
                : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border:
            notification.isRead
                ? null
                : Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon or Avatar
                _buildIcon(),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight:
                                    notification.isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (notification.senderName != null) ...[
                            Text(
                              notification.senderName!,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              ' • ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                          Text(
                            _formatTimeAgo(notification.timestamp),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chevron
                Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    // Use avatar if available, otherwise use type icon
    if (notification.senderAvatar != null) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(notification.senderAvatar!),
        onBackgroundImageError: (_, __) {},
        child: const Icon(Icons.person, color: Colors.grey),
      );
    }

    // Type-based icon
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _getIconBackgroundColor(),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(notification.icon, style: const TextStyle(fontSize: 20)),
      ),
    );
  }

  Color _getIconBackgroundColor() {
    switch (notification.type) {
      case P2PNotificationType.inquiry:
        return Colors.blue.withOpacity(0.2);
      case P2PNotificationType.tradeStarted:
        return Colors.orange.withOpacity(0.2);
      case P2PNotificationType.paymentMarked:
        return Colors.amber.withOpacity(0.2);
      case P2PNotificationType.paymentConfirmed:
        return Colors.green.withOpacity(0.2);
      case P2PNotificationType.fundsReleased:
        return Colors.green.withOpacity(0.2);
      case P2PNotificationType.tradeCancelled:
        return Colors.red.withOpacity(0.2);
      case P2PNotificationType.tradeDisputed:
        return Colors.orange.withOpacity(0.2);
      case P2PNotificationType.tradeMessage:
        return Colors.purple.withOpacity(0.2);
    }
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
