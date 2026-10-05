import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../dashboard/widgets/feedback_dialog.dart';

class FeedbackBarWidget extends StatefulWidget {
  final int logId;
  final String? currentFeedback; // 'like', 'dislike', null
  final Function(String feedback)? onFeedbackChanged;

  const FeedbackBarWidget({
    super.key,
    required this.logId,
    this.currentFeedback,
    this.onFeedbackChanged,
  });

  @override
  State<FeedbackBarWidget> createState() => _FeedbackBarWidgetState();
}

class _FeedbackBarWidgetState extends State<FeedbackBarWidget> with TickerProviderStateMixin {
  String? _feedback;
  bool _sending = false;

  late final AnimationController _likeController;
  late final Animation<double> _likeScaleAnimation;
  late final Animation<double> _likeRotationAnimation;

  late final AnimationController _burstController;
  late final Animation<double> _burstProgressAnimation;

  late final AnimationController _dislikeController;
  late final Animation<double> _dislikeScaleAnimation;
  late final Animation<double> _dislikeRotationAnimation;

  @override
  void initState() {
    super.initState();
    _feedback = widget.currentFeedback;

    // Controlador de animación del Like (pop elástico + inclinación gestual)
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _likeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.72).chain(CurveTween(curve: Curves.easeIn)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.72, end: 1.48).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 48,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.48, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_likeController);

    _likeRotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.26).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.26, end: 0.06).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.06, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_likeController);

    // Controlador de la explosión de destellos / partículas celebratorias
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _burstProgressAnimation = CurvedAnimation(
      parent: _burstController,
      curve: Curves.easeOutCubic,
    );

    // Controlador de animación del Dislike (rebote sutil y wobble)
    _dislikeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _dislikeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.80).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.80, end: 1.30).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.30, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_dislikeController);

    _dislikeRotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.18).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.18, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_dislikeController);
  }

  @override
  void didUpdateWidget(covariant FeedbackBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentFeedback != widget.currentFeedback) {
      setState(() => _feedback = widget.currentFeedback);
    }
  }

  @override
  void dispose() {
    _likeController.dispose();
    _burstController.dispose();
    _dislikeController.dispose();
    super.dispose();
  }

  Future<void> _handleLike() async {
    if (_sending || _feedback == 'like') return;

    // Disparo háptico en el dispositivo móvil
    HapticFeedback.mediumImpact();

    // Iniciar de inmediato la animación visual (optimistic update con 0 latencia)
    _likeController.forward(from: 0.0);
    _burstController.forward(from: 0.0);

    setState(() {
      _sending = true;
      _feedback = 'like';
    });

    try {
      final ok = await ApiService().sendAiFeedback(
        logId: widget.logId,
        feedback: 'like',
      );
      if (ok && mounted) {
        widget.onFeedbackChanged?.call('like');
      } else if (!ok && mounted) {
        setState(() => _feedback = widget.currentFeedback);
      }
    } catch (_) {
      if (mounted) setState(() => _feedback = widget.currentFeedback);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _handleDislike() {
    HapticFeedback.lightImpact();
    _dislikeController.forward(from: 0.0);

    FeedbackDialog.show(
      context,
      logId: widget.logId,
      onFeedbackSent: () {
        if (mounted) {
          setState(() => _feedback = 'dislike');
          widget.onFeedbackChanged?.call('dislike');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = _feedback == 'like';
    final isDisliked = _feedback == 'dislike';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: isLiked
            ? const Color(0xFFECFDF5)
            : isDisliked
                ? const Color(0xFFFEF2F2)
                : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLiked
              ? const Color(0xFF6EE7B7)
              : isDisliked
                  ? const Color(0xFFFCA5A5)
                  : AppColors.borderLight,
          width: isLiked || isDisliked ? 1.2 : 1.0,
        ),
        boxShadow: isLiked
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : isDisliked
                ? [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Texto descriptivo animado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.25),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: isLiked
                ? const Row(
                    key: ValueKey('liked_text'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: AppColors.successDark),
                      SizedBox(width: 4),
                      Text(
                        '¡Validación registrada!',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.successDark,
                        ),
                      ),
                    ],
                  )
                : isDisliked
                    ? const Row(
                        key: ValueKey('disliked_text'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.report_problem_rounded, size: 13, color: AppColors.errorDark),
                          SizedBox(width: 4),
                          Text(
                            'Inconsistencia reportada',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.errorDark,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        '¿Fue útil esta respuesta?',
                        key: ValueKey('unvoted_text'),
                        style: TextStyle(fontSize: 10.5, color: AppColors.textSubtle),
                      ),
          ),
          const SizedBox(width: 8),

          // Botón LIKE con destello y animación de rebote
          GestureDetector(
            onTap: _handleLike,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 30,
              height: 26,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Destello / Partículas celebratorias
                  AnimatedBuilder(
                    animation: _burstProgressAnimation,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(28, 28),
                        painter: _BurstPainter(
                          progress: _burstProgressAnimation.value,
                          color: const Color(0xFF10B981),
                        ),
                      );
                    },
                  ),
                  // Icono animado de Like
                  AnimatedBuilder(
                    animation: _likeController,
                    builder: (context, _) {
                      return Transform.scale(
                        scale: _likeScaleAnimation.value,
                        child: Transform.rotate(
                          angle: _likeRotationAnimation.value,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isLiked ? const Color(0xFFD1FAE5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.successDark,
                                    ),
                                  )
                                : Icon(
                                    isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                                    size: 15,
                                    color: isLiked ? AppColors.successDark : AppColors.textMuted,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 2),

          // Botón DISLIKE con animación de rebote y wobble
          GestureDetector(
            onTap: _handleDislike,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 30,
              height: 26,
              child: AnimatedBuilder(
                animation: _dislikeController,
                builder: (context, _) {
                  return Transform.scale(
                    scale: _dislikeScaleAnimation.value,
                    child: Transform.rotate(
                      angle: _dislikeRotationAnimation.value,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDisliked ? const Color(0xFFFEE2E2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          isDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_alt_outlined,
                          size: 15,
                          color: isDisliked ? AppColors.errorDark : AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Efecto visual de partículas y anillo radiante expansivo para la celebración del Like
class _BurstPainter extends CustomPainter {
  final double progress; // 0.0 a 1.0
  final Color color;

  _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.95;
    final currentRadius = maxRadius * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    // Anillo expansivo que se desvanece
    final ringPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.2 * (1.0 - progress)).clamp(0.6, 2.2);
    canvas.drawCircle(center, currentRadius, ringPaint);

    // 6 destellos / chispas radiales
    final dotPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.95)
      ..style = PaintingStyle.fill;

    final dotDistance = currentRadius * 1.15;
    final dotRadius = (2.2 * (1.0 - progress)).clamp(0.6, 2.2);

    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) + (progress * 0.25);
      final dx = center.dx + dotDistance * math.cos(angle);
      final dy = center.dy + dotDistance * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
