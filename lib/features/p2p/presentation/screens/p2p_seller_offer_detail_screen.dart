import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sabi_wallet/features/p2p/data/p2p_offer_model.dart';
import 'package:sabi_wallet/features/p2p/providers/p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/providers/nip99_p2p_providers.dart';
import 'package:sabi_wallet/features/p2p/services/p2p_notification_service.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_offer_messages_screen.dart';
import 'package:sabi_wallet/features/p2p/presentation/screens/p2p_edit_offer_screen.dart';

/// P2P Seller Offer Detail Screen - Management view for offer owners
class P2PSellerOfferDetailScreen extends ConsumerStatefulWidget {
  final P2POfferModel offer;

  const P2PSellerOfferDetailScreen({super.key, required this.offer});

  @override
  ConsumerState<P2PSellerOfferDetailScreen> createState() =>
      _P2PSellerOfferDetailScreenState();
}

class _P2PSellerOfferDetailScreenState
    extends ConsumerState<P2PSellerOfferDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final formatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get notification count for this offer
    final notificationService = ref.watch(p2pNotificationServiceProvider);
    final offerNotifications = notificationService.getNotificationsForOffer(
      widget.offer.id,
    );
    final unreadCount = offerNotifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C1A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Offer',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          // Messages with badge
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.chat_bubble_outline, color: Colors.white),
                onPressed: () => _navigateToMessages(),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF1A1A2E),
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: _handleMenuAction,
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.white, size: 18),
                        SizedBox(width: 12),
                        Text(
                          'Edit Offer',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pause',
                    child: Row(
                      children: [
                        Icon(
                          Icons.pause_circle_outline,
                          color: Colors.amber,
                          size: 18,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Pause Offer',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        SizedBox(width: 12),
                        Text(
                          'Delete Offer',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Offer Summary Card
          _buildOfferSummaryCard(),

          // Quick Stats
          _buildQuickStats(),

          // Tabs
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF111128),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10.r),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Details'),
                Tab(text: 'Messages'),
                Tab(text: 'Trades'),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OfferDetailsTab(offer: widget.offer, formatter: formatter),
                _MessagesTab(
                  offerId: widget.offer.id,
                  notifications: offerNotifications,
                  onViewAll: _navigateToMessages,
                ),
                _ActiveTradesTab(offerId: widget.offer.id),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferSummaryCard() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF1A1A2E).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                widget.offer.type == OfferType.buy
                    ? 'Buying BTC'
                    : 'Selling BTC',
                style: TextStyle(
                  color:
                      widget.offer.type == OfferType.buy
                          ? Colors.green
                          : Colors.orange,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Price
          Text(
            '₦${formatter.format(widget.offer.pricePerBtc.toInt())}',
            style: TextStyle(
              color: const Color(0xFF00FFB2),
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'per BTC',
            style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
          ),
          SizedBox(height: 16.h),

          // Limits & Available
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Limits',
                  value:
                      '₦${_formatShort(widget.offer.minLimit)} - ₦${_formatShort(widget.offer.maxLimit)}',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey[800]),
              Expanded(
                child: _SummaryItem(
                  label: 'Available',
                  value:
                      '${formatter.format(widget.offer.availableSats ?? 0)} sats',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    // TODO: Get real stats from trade manager
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.visibility,
              label: 'Views',
              value: '0',
              color: Colors.blue,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _StatCard(
              icon: Icons.chat_bubble_outline,
              label: 'Inquiries',
              value: '0',
              color: Colors.purple,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _StatCard(
              icon: Icons.handshake,
              label: 'Trades',
              value: '0',
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  String _formatShort(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toString();
  }

  void _navigateToMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => P2POfferMessagesScreen(
              offerId: widget.offer.id,
              offerTitle: widget.offer.name,
            ),
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => P2PEditOfferScreen(offer: widget.offer),
          ),
        );
        break;

      case 'pause':
        // TODO: Implement pause functionality
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pause feature coming soon'),
            backgroundColor: Colors.amber[700],
          ),
        );
        break;

      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'Delete Offer',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  'Are you sure you want to delete this offer? This action cannot be undone.',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
        );

        if (confirm == true) {
          final success = await ref
              .read(nip99OfferNotifierProvider.notifier)
              .deleteOffer(widget.offer.id);

          if (mounted) {
            if (success) {
              ref.invalidate(userNip99OffersProvider);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Offer deleted'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to delete offer'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        break;
    }
  }
}

// Summary Item Widget
class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12.sp)),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111128),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}

// Details Tab
class _OfferDetailsTab extends StatelessWidget {
  final P2POfferModel offer;
  final NumberFormat formatter;

  const _OfferDetailsTab({required this.offer, required this.formatter});

  @override
  Widget build(BuildContext context) {
    // Get payment methods from paymentMethod string or acceptedMethods
    final paymentMethods =
        offer.acceptedMethods?.map((m) => m.name).toList() ??
        [offer.paymentMethod];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Methods
          _SectionTitle(title: 'Payment Methods'),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children:
                paymentMethods.map((method) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111128),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance,
                          color: Colors.orange,
                          size: 16,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          method,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
          SizedBox(height: 24.h),

          // Payment Instructions
          if (offer.paymentInstructions != null) ...[
            _SectionTitle(title: 'Payment Instructions'),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFF111128),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                offer.paymentInstructions!,
                style: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
              ),
            ),
            SizedBox(height: 24.h),
          ],

          // Payment Account Details
          if (offer.paymentAccountDetails != null &&
              offer.paymentAccountDetails!.isNotEmpty) ...[
            _SectionTitle(title: 'Account Details'),
            SizedBox(height: 8.h),
            ...offer.paymentAccountDetails!.entries.map((entry) {
              return Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF111128),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11.sp,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          entry.value,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.grey, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: entry.value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: 24.h),
          ],

          // Offer Info
          _SectionTitle(title: 'Offer Info'),
          SizedBox(height: 8.h),
          _InfoRow(
            label: 'Offer ID',
            value:
                offer.id.length >= 16
                    ? '${offer.id.substring(0, 16)}...'
                    : offer.id,
          ),
          _InfoRow(label: 'Response Time', value: offer.eta),
          _InfoRow(label: 'Rating', value: '${offer.ratingPercent}%'),
        ],
      ),
    );
  }
}

// Messages Tab
class _MessagesTab extends StatelessWidget {
  final String offerId;
  final List<P2PNotification> notifications;
  final VoidCallback onViewAll;

  const _MessagesTab({
    required this.offerId,
    required this.notifications,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final inquiries =
        notifications
            .where(
              (n) =>
                  n.type == P2PNotificationType.inquiry ||
                  n.type == P2PNotificationType.tradeMessage,
            )
            .toList();

    if (inquiries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[700]),
            SizedBox(height: 16.h),
            Text(
              'No messages yet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Inquiries about your offer will appear here',
              style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: inquiries.length > 5 ? 5 : inquiries.length,
            itemBuilder: (context, index) {
              final notification = inquiries[index];
              return _MessagePreviewTile(notification: notification);
            },
          ),
        ),
        if (inquiries.length > 5)
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextButton(
              onPressed: onViewAll,
              child: Text(
                'View all ${inquiries.length} messages',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ),
      ],
    );
  }
}

// Message Preview Tile
class _MessagePreviewTile extends StatelessWidget {
  final P2PNotification notification;

  const _MessagePreviewTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color:
            notification.isRead
                ? const Color(0xFF111128).withOpacity(0.5)
                : const Color(0xFF111128),
        borderRadius: BorderRadius.circular(12.r),
        border:
            notification.isRead
                ? null
                : Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[800],
            child: Text(
              notification.senderName?.substring(0, 1).toUpperCase() ?? '?',
              style: TextStyle(color: Colors.white),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.senderName ?? 'Unknown',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  notification.body,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _formatTimeAgo(notification.timestamp),
            style: TextStyle(color: Colors.grey[600], fontSize: 11.sp),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

// Active Trades Tab
class _ActiveTradesTab extends ConsumerWidget {
  final String offerId;

  const _ActiveTradesTab({required this.offerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Get trades for this offer from trade manager
    // final trades = ref.watch(tradesForOfferProvider(offerId));

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horiz, size: 64, color: Colors.grey[700]),
          SizedBox(height: 16.h),
          Text(
            'No active trades',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Active trades for this offer will appear here',
            style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}

// Section Title Widget
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// Info Row Widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 13.sp),
          ),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 13.sp)),
        ],
      ),
    );
  }
}
