/// Trade Timer Widget - 4-minute countdown with visual warnings
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/p2p_trade_service.dart';

/// Callback for timer events
typedef TimerCallback = void Function(int secondsRemaining);

/// Trade timer with visual feedback and warnings
class TradeTimerWidget extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback? onExpired;
  final TimerCallback? onTick;
  final TimerCallback? onWarning;
  final bool showLabels;
  final bool compact;

  const TradeTimerWidget({
    super.key,
    this.initialSeconds = kTradeTimerSeconds,
    this.onExpired,
    this.onTick,
    this.onWarning,
    this.showLabels = true,
    this.compact = false,
  });

  @override
  State<TradeTimerWidget> createState() => _TradeTimerWidgetState();
}

class _TradeTimerWidgetState extends State<TradeTimerWidget>
    with SingleTickerProviderStateMixin {
  late int _secondsRemaining;
  Timer? _timer;
  late AnimationController _pulseController;
  bool _warned2Min = false;
  bool _warned1Min = false;
  bool _warned30Sec = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.initialSeconds;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
        widget.onTick?.call(_secondsRemaining);
        _checkWarnings();
      } else {
        _timer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  void _checkWarnings() {
    if (_secondsRemaining <= kWarning2Min && !_warned2Min) {
      _warned2Min = true;
      widget.onWarning?.call(_secondsRemaining);
    }
    if (_secondsRemaining <= kWarning1Min && !_warned1Min) {
      _warned1Min = true;
      widget.onWarning?.call(_secondsRemaining);
      _pulseController.repeat(reverse: true);
    }
    if (_secondsRemaining <= kWarning30Sec && !_warned30Sec) {
      _warned30Sec = true;
      widget.onWarning?.call(_secondsRemaining);
    }
  }

  Color get _timerColor {
    if (_secondsRemaining <= kWarning30Sec) {
      return const Color(0xFFFF4444); // Critical red
    } else if (_secondsRemaining <= kWarning1Min) {
      return const Color(0xFFFF6B6B); // Warning red
    } else if (_secondsRemaining <= kWarning2Min) {
      return const Color(0xFFFFB347); // Orange warning
    }
    return const Color(0xFF00FFB2); // Safe green
  }

  String get _formattedTime {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _progress => _secondsRemaining / widget.initialSeconds;

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompact();
    }
    return _buildFull();
  }

  Widget _buildCompact() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _secondsRemaining <= kWarning1Min
            ? 1.0 + (_pulseController.value * 0.05)
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _timerColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: _timerColor.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: _timerColor,
                  size: 16.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  _formattedTime,
                  style: TextStyle(
                    color: _timerColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFull() {
    return Column(
      children: [
        // Circular progress
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = _secondsRemaining <= kWarning1Min
                ? 1.0 + (_pulseController.value * 0.03)
                : 1.0;
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 120.w,
                height: 120.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background circle
                    SizedBox(
                      width: 120.w,
                      height: 120.w,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 8.w,
                        backgroundColor: const Color(0xFF2A2A3E),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF2A2A3E)),
                      ),
                    ),
                    // Progress circle
                    SizedBox(
                      width: 120.w,
                      height: 120.w,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 8.w,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(_timerColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    // Time text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formattedTime,
                          style: TextStyle(
                            color: _timerColor,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (widget.showLabels)
                          Text(
                            'remaining',
                            style: TextStyle(
                              color: const Color(0xFFA1A1B2),
                              fontSize: 12.sp,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (widget.showLabels) ...[
          SizedBox(height: 12.h),
          _buildWarningText(),
        ],
      ],
    );
  }

  Widget _buildWarningText() {
    String text;
    Color color;

    if (_secondsRemaining <= kWarning30Sec) {
      text = '⚠️ Less than 30 seconds! Complete payment NOW!';
      color = const Color(0xFFFF4444);
    } else if (_secondsRemaining <= kWarning1Min) {
      text = '⚠️ Less than 1 minute remaining!';
      color = const Color(0xFFFF6B6B);
    } else if (_secondsRemaining <= kWarning2Min) {
      text = '⏰ 2 minutes left - hurry up!';
      color = const Color(0xFFFFB347);
    } else {
      text = 'Complete payment before timer expires';
      color = const Color(0xFFA1A1B2);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 13.sp,
          fontWeight: _secondsRemaining <= kWarning1Min
              ? FontWeight.w600
              : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Linear timer bar (alternative compact view)
class TradeTimerBar extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback? onExpired;

  const TradeTimerBar({
    super.key,
    this.initialSeconds = kTradeTimerSeconds,
    this.onExpired,
  });

  @override
  State<TradeTimerBar> createState() => _TradeTimerBarState();
}

class _TradeTimerBarState extends State<TradeTimerBar> {
  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.initialSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  Color get _timerColor {
    if (_secondsRemaining <= kWarning30Sec) {
      return const Color(0xFFFF4444);
    } else if (_secondsRemaining <= kWarning1Min) {
      return const Color(0xFFFF6B6B);
    } else if (_secondsRemaining <= kWarning2Min) {
      return const Color(0xFFFFB347);
    }
    return const Color(0xFF00FFB2);
  }

  double get _progress => _secondsRemaining / widget.initialSeconds;

  String get _formattedTime {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment Window',
              style: TextStyle(
                color: const Color(0xFFA1A1B2),
                fontSize: 12.sp,
              ),
            ),
            Text(
              _formattedTime,
              style: TextStyle(
                color: _timerColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6.h,
            backgroundColor: const Color(0xFF2A2A3E),
            valueColor: AlwaysStoppedAnimation(_timerColor),
          ),
        ),
      ],
    );
  }
}
