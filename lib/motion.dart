import 'dart:math' as math;
import 'package:flutter/material.dart';

class SoftPageTransitions extends PageTransitionsBuilder {
  const SoftPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.025, 0),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}

const softPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: SoftPageTransitions(),
    TargetPlatform.iOS: SoftPageTransitions(),
    TargetPlatform.windows: SoftPageTransitions(),
    TargetPlatform.macOS: SoftPageTransitions(),
    TargetPlatform.linux: SoftPageTransitions(),
    TargetPlatform.fuchsia: SoftPageTransitions(),
  },
);

class RainbowMomentCard extends StatefulWidget {
  const RainbowMomentCard({super.key});
  @override
  State<RainbowMomentCard> createState() => _RainbowMomentCardState();
}

class _RainbowMomentCardState extends State<RainbowMomentCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  bool resumed = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    resumed = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final enabled =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.of(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        resumed;
    if (enabled && !controller.isAnimating) {
      controller.repeat();
    }
    if (!enabled && controller.isAnimating) {
      controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final hue = controller.value * 360;
      return Container(
        key: const ValueKey('rainbow-card-gradient'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              HSVColor.fromAHSV(1, hue, .75, .65).toColor(),
              HSVColor.fromAHSV(1, (hue + 95) % 360, .75, .65).toColor(),
              HSVColor.fromAHSV(1, (hue + 210) % 360, .75, .65).toColor(),
            ],
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: child,
      );
    },
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xCC1D171B),
        borderRadius: BorderRadius.circular(21),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.waving_hand_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Un día a la vez',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sus recuerdos empiezan aquí.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showSaveConfirmation(BuildContext context) async {
  final reduced = MediaQuery.disableAnimationsOf(context);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Guardado',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => _SaveConfirmation(reduced: reduced),
  );
}

class _SaveConfirmation extends StatefulWidget {
  const _SaveConfirmation({required this.reduced});
  final bool reduced;
  @override
  State<_SaveConfirmation> createState() => _SaveConfirmationState();
}

class _SaveConfirmationState extends State<_SaveConfirmation>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.reduced ? 800 : 2800),
  );
  @override
  void initState() {
    super.initState();
    controller.forward().whenCompleteOrCancel(() {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox.expand(
        key: const ValueKey('save-confirmation-screen'),
        child: Semantics(
          liveRegion: true,
          label: 'Guardado',
          child: ExcludeSemantics(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final t = widget.reduced ? 1.0 : controller.value;
                  final ascent = Curves.easeOutCubic.transform(
                    ((t - .46) / .25).clamp(0.0, 1.0),
                  );
                  final bounce = t > .68 && t < .82
                      ? math.sin((t - .68) / .14 * math.pi) *
                            12 *
                            (1 - (t - .68) / .14)
                      : 0.0;
                  final offset = widget.reduced
                      ? 0.0
                      : (1 - ascent) * constraints.maxHeight * .43 + bounce;
                  final visible = widget.reduced
                      ? 1.0
                      : ((t - .46) / .12).clamp(0.0, 1.0) *
                            (1 - ((t - .91) / .09).clamp(0.0, 1.0));
                  final spin = widget.reduced
                      ? 0.0
                      : Curves.easeInCubic.transform(
                              ((t - .62) / .35).clamp(0.0, 1.0),
                            ) *
                            math.pi *
                            4;
                  final iconScale = widget.reduced
                      ? 1.0
                      : (.35 + 1.15 * ascent) *
                            (1 -
                                Curves.easeInCubic.transform(
                                  ((t - .68) / .29).clamp(0.0, 1.0),
                                ));
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (!widget.reduced)
                        CustomPaint(
                          key: const ValueKey('save-water-animation'),
                          painter: _DropPainter(t),
                        ),
                      Center(
                        child: Opacity(
                          opacity: visible,
                          child: Transform.translate(
                            offset: Offset(0, offset),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.rotate(
                                  angle: spin,
                                  child: Transform.scale(
                                    scale: iconScale,
                                    child: const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF258052),
                                      size: 62,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: _SavedLabel(
                                    t: t,
                                    reduced: widget.reduced,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SavedLabel extends StatelessWidget {
  const _SavedLabel({required this.t, required this.reduced});
  final double t;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    if (reduced) {
      return Text('Guardado', key: const ValueKey('save-label'), style: style);
    }
    return FittedBox(
      key: const ValueKey('save-label'),
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 'Guardado'.length; i++)
            Builder(
              builder: (context) {
                final step = Curves.easeOutBack.transform(
                  ((t - .53 - i * .025) / .12).clamp(0.0, 1.0),
                );
                final opacity = ((t - .53 - i * .025) / .05).clamp(0.0, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - step)),
                    child: Text('Guardado'[i], style: style),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DropPainter extends CustomPainter {
  _DropPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF258052)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final progress = Curves.easeInCubic.transform((t / .42).clamp(0.0, 1.0));
    final inset = 5.0;
    final radius = math.min(40.0, size.width / 5);
    final bottom = size.height - inset;
    final fade = 1 - ((t - .55) / .16).clamp(0.0, 1.0);
    paint.color = const Color(0xFF258052).withValues(alpha: fade);
    for (final left in [true, false]) {
      final x = left ? inset : size.width - inset;
      final sign = left ? 1.0 : -1.0;
      final path = Path()
        ..moveTo(x, inset)
        ..lineTo(x, bottom - radius)
        ..quadraticBezierTo(x, bottom, x + sign * radius, bottom)
        ..lineTo(size.width / 2, bottom);
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
      }
    }
    if (t >= .42 && t < .64) {
      final wave = ((t - .42) / .22).clamp(0.0, 1.0);
      paint.color = const Color(0xFF258052).withValues(alpha: 1 - wave);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, bottom - 5),
          width: 12 + 110 * wave,
          height: 6 + 22 * wave,
        ),
        paint,
      );
      paint.style = PaintingStyle.fill;
      for (var i = 0; i < 11; i++) {
        final angle = math.pi + i * math.pi / 10;
        final distance = 15 + 100 * Curves.easeOutCubic.transform(wave);
        canvas.drawCircle(
          Offset(
            size.width / 2 + math.cos(angle) * distance,
            bottom - 8 + math.sin(angle) * distance * .7,
          ),
          3 + 5 * (1 - wave),
          paint,
        );
      }
      paint.style = PaintingStyle.stroke;
    }
    if (t >= .46 && t < .68) {
      final ascent = Curves.easeOutCubic.transform(
        ((t - .46) / .22).clamp(0.0, 1.0),
      );
      paint.color = const Color(0xFF258052);
      canvas.drawCircle(
        Offset(size.width / 2, bottom - (size.height * .46 * ascent)),
        6 + 3 * math.sin(ascent * math.pi),
        paint..style = PaintingStyle.fill,
      );
    }
    if (t >= .87 && t < .99) {
      final splash = Curves.easeOutCubic.transform(
        ((t - .87) / .12).clamp(0.0, 1.0),
      );
      paint.color = const Color(0xFF258052).withValues(alpha: 1 - splash);
      paint.style = PaintingStyle.fill;
      for (var i = 0; i < 10; i++) {
        final angle = i * math.pi * 2 / 10;
        final distance = 35 + 80 * splash;
        canvas.drawCircle(
          Offset(
            size.width / 2 + math.cos(angle) * distance,
            size.height / 2 - 15 + math.sin(angle) * distance,
          ),
          4 * (1 - splash) + 1,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DropPainter oldDelegate) => oldDelegate.t != t;
}
