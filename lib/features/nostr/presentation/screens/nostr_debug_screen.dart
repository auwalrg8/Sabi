import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/features/nostr/services/nostr_service.dart';
import 'package:sabi_wallet/features/nostr/services/nostr_debug_service.dart';

/// Debug screen for viewing Nostr connection status and logs
class NostrDebugScreen extends StatefulWidget {
  const NostrDebugScreen({super.key});

  @override
  State<NostrDebugScreen> createState() => _NostrDebugScreenState();
}

class _NostrDebugScreenState extends State<NostrDebugScreen> {
  List<NostrDebugEntry> _logs = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  bool _autoScroll = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();

    // Listen for new logs
    NostrService.debugService.logStream.listen((entry) {
      if (mounted) {
        setState(() {
          _logs = NostrService.debugService.logs;
        });
        if (_autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    // Get current status
    _summary = NostrService.getConnectionSummary();
    _logs = NostrService.debugService.logs;

    setState(() => _isLoading = false);
  }

  Future<void> _testFeed() async {
    NostrService.debugService.info('TEST', 'User requested feed test');

    // Use DIRECT WebSocket fetch (bypasses nostr_dart issues)
    NostrService.debugService.info('TEST', 'Using DIRECT WebSocket fetch...');
    final posts = await NostrService.fetchGlobalFeedDirect(limit: 10);

    NostrService.debugService.info(
      'TEST',
      'Feed test complete',
      '${posts.length} posts fetched',
    );
    _loadLogs();
  }

  Future<void> _testRawSubscription() async {
    NostrService.debugService.info(
      'TEST',
      'User requested RAW subscription test',
    );

    // Test the direct WebSocket connection
    NostrService.debugService.info('TEST', 'Using DIRECT WebSocket test...');
    final posts = await NostrService.fetchGlobalFeedDirect(limit: 5);

    NostrService.debugService.info(
      'TEST',
      'Direct test complete',
      '${posts.length} posts received',
    );
    _loadLogs();
  }

  void _copyLogs() {
    final logs = NostrService.getDebugLogs();
    Clipboard.setData(ClipboardData(text: logs));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logs copied to clipboard')));
  }

  void _clearLogs() {
    NostrService.debugService.clearLogs();
    _loadLogs();
  }

  Color _getLevelColor(String level) {
    return switch (level) {
      'SUCCESS' => Colors.green,
      'WARN' => Colors.orange,
      'ERROR' => Colors.red,
      _ => Colors.blue,
    };
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Nostr Debug', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
            tooltip: 'Copy logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Connection Summary Card
                  Container(
                    margin: EdgeInsets.all(12.w),
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _summary['isInitialized'] == true
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color:
                                  _summary['isInitialized'] == true
                                      ? Colors.green
                                      : Colors.red,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Initialized: ${_summary['isInitialized']}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Icon(
                              _summary['hasKeys'] == true
                                  ? Icons.key
                                  : Icons.key_off,
                              color:
                                  _summary['hasKeys'] == true
                                      ? Colors.green
                                      : Colors.orange,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                'Keys: ${_summary['hasKeys'] == true ? "Yes" : "No"}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Icon(
                              Icons.sensors,
                              color:
                                  (_summary['connectedRelays'] ?? 0) > 0
                                      ? Colors.green
                                      : Colors.red,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Relays: ${_summary['connectedRelays']}/${_summary['totalRelays']} connected',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                        if (_summary['currentNpub'] != null) ...[
                          SizedBox(height: 8.h),
                          Text(
                            'npub: ${_summary['currentNpub']?.substring(0, 20)}...',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Test Button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _testFeed,
                            icon: const Icon(Icons.bug_report),
                            label: const Text('Test Feed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              minimumSize: Size(0, 44.h),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _testRawSubscription,
                            icon: const Icon(Icons.electrical_services),
                            label: const Text('Raw Test'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              minimumSize: Size(0, 44.h),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Auto-scroll toggle
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      children: [
                        Text(
                          'Auto-scroll',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _autoScroll,
                          onChanged: (v) => setState(() => _autoScroll = v),
                          activeColor: Colors.orange,
                        ),
                      ],
                    ),
                  ),

                  // Logs List
                  Expanded(
                    child:
                        _logs.isEmpty
                            ? Center(
                              child: Text(
                                'No logs yet.\nNavigate to Nostr feed to generate logs.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14.sp,
                                ),
                              ),
                            )
                            : ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.all(12.w),
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                return Container(
                                  margin: EdgeInsets.only(bottom: 4.h),
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(6.r),
                                    border: Border.all(
                                      color: _getLevelColor(
                                        log.level,
                                      ).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6.w,
                                              vertical: 2.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getLevelColor(
                                                log.level,
                                              ).withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4.r),
                                            ),
                                            child: Text(
                                              log.category,
                                              style: TextStyle(
                                                color: _getLevelColor(
                                                  log.level,
                                                ),
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: Text(
                                              log.message,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (log.details != null) ...[
                                        SizedBox(height: 4.h),
                                        Text(
                                          log.details!,
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 11.sp,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                      SizedBox(height: 4.h),
                                      Text(
                                        '${log.timestamp.hour.toString().padLeft(2, '0')}:'
                                        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
                                        '${log.timestamp.second.toString().padLeft(2, '0')}.'
                                        '${log.timestamp.millisecond.toString().padLeft(3, '0')}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
