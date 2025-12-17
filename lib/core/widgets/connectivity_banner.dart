import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/services/connectivity_service.dart';
import 'package:sabi_wallet/services/connectivity_service_provider.dart';

class ConnectivityBanner extends ConsumerStatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  ConsumerState<ConnectivityBanner> createState() => _State();
}

class _State extends ConsumerState<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  bool _visible = false;
  bool _listenersAttached = false;
  BackendStatus? _dismissedBackend;
  Timer? _autoHideTimer;

  String _message = '';
  Color _color = Colors.red;
  IconData _icon = Icons.wifi_off;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slide = Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_listenersAttached) {
      _listenersAttached = true;

      ref.listen<AsyncValue<ConnectionStatus>>(connectionStatusProvider, (
        _,
        next,
      ) {
        next.whenData((status) {
          if (status == ConnectionStatus.disconnected) {
            _show('Check your internet connection', Colors.red, Icons.wifi_off);
          } else {
            _hide();
          }
        });
      });

      ref.listen<AsyncValue<BackendStatus>>(backendStatusProvider, (_, next) {
        next.whenData((status) {
          if (status == _dismissedBackend) return;

          switch (status) {
            case BackendStatus.unavailable:
              _show('Unable to reach server', Colors.orange, Icons.cloud_off);
              break;
            case BackendStatus.timeout:
              _show('Server timeout', Colors.orange, Icons.access_time);
              break;
            case BackendStatus.error:
              _show('Server error', Colors.red, Icons.error_outline);
              break;
            case BackendStatus.available:
              _hide();
              break;
            default:
              break;
          }
        });
      });
    }

    return Stack(
      children: [
        widget.child,
        if (_visible)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slide,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.1), // 10% background
                      border: Border.all(color: _color.withOpacity(1.0), width: 1), // stroke 100%
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                    child: Row(
                      children: [
                        Icon(_icon, color: _color, size: 22.sp),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            _message,
                            style: TextStyle(
                              color: _color,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            _dismissedBackend = ref.read(backendStatusProvider).value;
                            _hide();
                          },
                          child: Icon(Icons.close, color: _color, size: 20.sp),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _show(String msg, Color c, IconData i) {
    if (_visible && _message == msg) return;
    // cancel any existing auto-hide timer
    _autoHideTimer?.cancel();

    setState(() {
      _message = msg;
      _color = c;
      _icon = i;
      _visible = true;
    });
    _controller.forward();

    // Auto-hide after 10 seconds
    _autoHideTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) _hide();
    });
  }

  void _hide() {
    if (!_visible) return;
    // cancel timer when hiding
    _autoHideTimer?.cancel();
    _autoHideTimer = null;

    _controller.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
