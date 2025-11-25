import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'welcome_screen.dart';

// 🔄 V3.0 Loading Stages
enum LoadingStage {
  initializing('Pokretanje aplikacije...', 0.1),
  connectingDB('Povezujem sa bazom podataka...', 0.3),
  loadingConfig('Učitavam konfiguraciju...', 0.5),
  authenticating('Proveravam autentifikaciju...', 0.7),
  loadingUserData('Učitavam korisničke podatke...', 0.9),
  finalizing('Finalizujem pokretanje...', 1.0);

  const LoadingStage(this.message, this.progress);
  final String message;
  final double progress;
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({Key? key, this.error}) : super(key: key);
  final String? error;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  // 🎯 V3.0 State Management
  final ValueNotifier<LoadingStage> _currentStage = ValueNotifier(LoadingStage.initializing);
  final ValueNotifier<double> _progress = ValueNotifier(0.0);
  final ValueNotifier<String> _statusMessage = ValueNotifier('Pokretanje aplikacije...');
  final ValueNotifier<bool> _hasError = ValueNotifier(false);
  final ValueNotifier<String?> _errorMessage = ValueNotifier(null);

  // 🎨 V3.0 Advanced Animations
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  // ⏱️ V3.0 Timeout & Retry Management
  Timer? _loadingTimer;
  Timer? _timeoutTimer;

  static const Duration timeoutDuration = Duration(seconds: 30);
  static const Duration stageDelay = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();

    // Initialize error state if provided
    if (widget.error != null) {
      _hasError.value = true;
      _errorMessage.value = widget.error;
    } else {
      _initializeV3Loading();
    }
  }

  void _initializeV3Loading() {
    _initializeAnimations();
    _setupTimeout();
    _startLoadingProcess();
  }

  void _initializeAnimations() {
    // Pulsing animation for enhanced visual feedback
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Rotation animation for progress indicator
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_rotationController);

    // Start animations
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
  }

  void _setupTimeout() {
    _timeoutTimer = Timer(timeoutDuration, () {
      if (mounted && !_hasError.value) {
        _handleLoadingError('Učitavanje traje predugo. Pokušajte ponovo.');
      }
    });
  }

  Future<void> _startLoadingProcess() async {
    try {
      await _executeLoadingStages();

      if (mounted && !_hasError.value) {
        _navigateToMainApp();
      }
    } catch (e) {
      _handleLoadingError(e.toString());
    }
  }

  Future<void> _executeLoadingStages() async {
    for (final stage in LoadingStage.values) {
      if (!mounted || _hasError.value) break;

      // Update current stage
      _currentStage.value = stage;
      _statusMessage.value = stage.message;
// Simulate realistic loading with progressive delay
      final delay = stageDelay.inMilliseconds;
      await Future<void>.delayed(Duration(milliseconds: delay));

      // Update progress with smooth animation
      _animateProgressTo(stage.progress);

      // Add realistic failure simulation for testing resilience
      if (stage == LoadingStage.connectingDB && _shouldSimulateFailure()) {
        throw Exception('Neuspešna konekcija sa serverom');
      }

      // Additional delay for visual feedback
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  void _animateProgressTo(double targetProgress) {
    const duration = Duration(milliseconds: 400);
    final currentProgress = _progress.value;

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final elapsed = timer.tick * 16;
      final t = (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);

      _progress.value = currentProgress + (targetProgress - currentProgress) * t;

      if (t >= 1.0) {
        timer.cancel();
      }
    });
  }

  bool _shouldSimulateFailure() {
    // Simulate 5% failure rate for testing
    return false; // Set to true for testing error handling
  }

  void _handleLoadingError(String error) {
    _timeoutTimer?.cancel();
    _loadingTimer?.cancel();

    if (mounted) {
      setState(() {
        _hasError.value = true;
        _errorMessage.value = error;
      });
    }
  }

  void _navigateToMainApp() {
    _timeoutTimer?.cancel();
    _loadingTimer?.cancel();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => const WelcomeScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _loadingTimer?.cancel();
    _timeoutTimer?.cancel();

    // Dispose ValueNotifiers
    _currentStage.dispose();
    _progress.dispose();
    _statusMessage.dispose();
    _hasError.dispose();
    _errorMessage.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ValueListenableBuilder<bool>(
          valueListenable: _hasError,
          builder: (context, hasError, child) {
            if (hasError) {
              return _buildV3ErrorState();
            }
            return _buildV3LoadingState();
          },
        ),
      ),
    );
  }

  // 🎨 V3.0 ENHANCED LOADING STATE
  Widget _buildV3LoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: tripleBlueFashionGradient,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎯 V3.0 ENHANCED LOADING ANIMATION
            _buildAdvancedLoadingIndicator(),

            const SizedBox(height: 48),

            // 📱 APP LOGO/TITLE
            _buildAppBranding(),

            const SizedBox(height: 40),

            // 📊 DYNAMIC STATUS MESSAGE
            ValueListenableBuilder<String>(
              valueListenable: _statusMessage,
              builder: (context, message, child) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  message,
                  key: ValueKey(message),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 📈 V3.0 PROGRESS BAR
            _buildEnhancedProgressBar(),

            const SizedBox(height: 16),

            // 🔄 STAGE INDICATOR
            ValueListenableBuilder<LoadingStage>(
              valueListenable: _currentStage,
              builder: (context, stage, child) => Text(
                'Korak ${stage.index + 1} od ${LoadingStage.values.length}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 ADVANCED LOADING INDICATOR
  Widget _buildAdvancedLoadingIndicator() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing background circle
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ),

        // Rotating outer ring
        AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) => Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Main progress indicator
        ValueListenableBuilder<double>(
          valueListenable: _progress,
          builder: (context, progress, child) => SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),

        // Center transport icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_bus,
            color: Color(0xFF1E3A8A),
            size: 24,
          ),
        ),
      ],
    );
  }

  // 📱 APP BRANDING
  Widget _buildAppBranding() {
    return Column(
      children: [
        Text(
          'GAVRA TRANSPORT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            shadows: [
              Shadow(
                offset: const Offset(0, 2),
                blurRadius: 4,
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sistem za upravljanje prevozom',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // 📈 ENHANCED PROGRESS BAR
  Widget _buildEnhancedProgressBar() {
    return Container(
      width: 240,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: ValueListenableBuilder<double>(
        valueListenable: _progress,
        builder: (context, progress, child) => Column(
          children: [
            // Progress bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.white, Color(0xFFE0F2FE)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Progress percentage
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ❌ V3.0 ENHANCED ERROR STATE
  Widget _buildV3ErrorState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}
