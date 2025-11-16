import 'dart:async';

import 'package:flutter/material.dart';

/// ClockTicker - a lightweight widget that updates once per second and
/// only rebuilds itself (the time text), reducing rebuild impact on
/// surrounding widgets. It pauses updates when the app is in background.
class ClockTicker extends StatefulWidget {
  const ClockTicker({
    Key? key,
    this.style,
    this.showSeconds = true,
  }) : super(key: key);

  final TextStyle? style;
  final bool showSeconds;

  @override
  _ClockTickerState createState() => _ClockTickerState();
}

class _ClockTickerState extends State<ClockTicker> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  void _stopTimer() {
    try {
      _timer?.cancel();
    } catch (_) {}
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopTimer();
    } else if (state == AppLifecycleState.resumed) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    final display = widget.showSeconds ? '$h:$m:$s' : '$h:$m';

    return Text(
      display,
      style: widget.style,
    );
  }
}
