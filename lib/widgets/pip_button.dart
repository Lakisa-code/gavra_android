import 'package:flutter/material.dart';

import '../services/pip_service.dart';

/// Floating PiP dugme koje se može dodati bilo gde
/// Prikazuje se samo na Android 8.0+
class PipButton extends StatefulWidget {
  /// Da li prikazati tooltip
  final bool showTooltip;

  /// Boja ikone
  final Color? iconColor;

  /// Veličina ikone
  final double iconSize;

  const PipButton({
    super.key,
    this.showTooltip = true,
    this.iconColor,
    this.iconSize = 24,
  });

  @override
  State<PipButton> createState() => _PipButtonState();
}

class _PipButtonState extends State<PipButton> {
  final PipService _pipService = PipService();
  bool _isPipSupported = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPipSupport();
  }

  Future<void> _checkPipSupport() async {
    final supported = await _pipService.isPipSupported();
    if (mounted) {
      setState(() {
        _isPipSupported = supported;
        _isLoading = false;
      });
    }
  }

  Future<void> _enterPip() async {
    final result = await _pipService.tryEnterPip();

    if (!result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ne prikazuj dok se učitava ili ako nije podržano
    if (_isLoading || !_isPipSupported) {
      return const SizedBox.shrink();
    }

    final button = IconButton(
      icon: Icon(
        Icons.picture_in_picture_alt,
        color: widget.iconColor ?? Theme.of(context).colorScheme.onPrimary,
        size: widget.iconSize,
      ),
      onPressed: _enterPip,
    );

    if (widget.showTooltip) {
      return Tooltip(
        message: 'Mali prozor (PiP)',
        child: button,
      );
    }

    return button;
  }
}

/// Floating Action Button za PiP
class PipFab extends StatefulWidget {
  /// Pozicija FAB-a
  final FloatingActionButtonLocation? location;

  const PipFab({super.key, this.location});

  @override
  State<PipFab> createState() => _PipFabState();
}

class _PipFabState extends State<PipFab> {
  final PipService _pipService = PipService();
  bool _isPipSupported = false;

  @override
  void initState() {
    super.initState();
    _checkPipSupport();
  }

  Future<void> _checkPipSupport() async {
    final supported = await _pipService.isPipSupported();
    if (mounted) {
      setState(() {
        _isPipSupported = supported;
      });
    }
  }

  Future<void> _enterPip() async {
    final result = await _pipService.tryEnterPip();

    if (!result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPipSupported) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.small(
      heroTag: 'pip_fab',
      onPressed: _enterPip,
      tooltip: 'Mali prozor (PiP)',
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.picture_in_picture_alt),
    );
  }
}

/// Widget koji sluša PiP stanje i prikazuje različit sadržaj
class PipAwareBuilder extends StatelessWidget {
  /// Widget za prikaz u normalnom modu
  final Widget normalChild;

  /// Widget za prikaz u PiP modu (kompaktan prikaz)
  final Widget pipChild;

  const PipAwareBuilder({
    super.key,
    required this.normalChild,
    required this.pipChild,
  });

  @override
  Widget build(BuildContext context) {
    final pipService = PipService();

    return ValueListenableBuilder<bool>(
      valueListenable: pipService.isPipActive,
      builder: (context, isInPip, _) {
        return isInPip ? pipChild : normalChild;
      },
    );
  }
}
