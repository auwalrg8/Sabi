import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sabi_wallet/core/constants/colors.dart';
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
            _show('No internet connection', Colors.red, Icons.wifi_off);
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
                child: Material(
                  color: _color,
                  child: ListTile(
                    leading: Icon(_icon, color: AppColors.surface, size: 25.sp),
                    title: Text(
                      _message,
                      style: TextStyle(
                        color: AppColors.surface,
                        fontSize: 17.sp,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: AppColors.surface,
                        size: 25.sp,
                      ),
                      onPressed: () {
                        _dismissedBackend =
                            ref.read(backendStatusProvider).value;
                        _hide();
                      },
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
    setState(() {
      _message = msg;
      _color = c;
      _icon = i;
      _visible = true;
    });
    _controller.forward();
  }

  void _hide() {
    if (!_visible) return;
    _controller.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
