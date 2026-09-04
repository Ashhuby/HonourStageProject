/// The celebration shown when a badge is earned.
///
/// Mounted once, above the whole app, from `MaterialApp.builder` — not from
/// the badges screen and not from the home screen. Most badges are earned
/// mid-set, on the active session screen, which is pushed as its own route; an
/// overlay owned by a screen underneath it would never be seen. Drawn in a
/// [Stack] rather than through `showDialog` for the same reason: it has no
/// route of its own to lose, and it cannot be dismissed by a `Navigator.pop`
/// meant for something else.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/badge_unlock_queue.dart';
import '../../domain/badge_catalogue.dart';
import 'badge_visuals.dart';

/// How long the reveal takes end to end.
const Duration _kRevealDuration = Duration(milliseconds: 1400);

/// How long the overlay takes to fade away once dismissed.
const Duration _kExitDuration = Duration(milliseconds: 200);

/// Wraps the app and shows a celebration for each badge on the unlock queue.
class BadgeUnlockHost extends ConsumerStatefulWidget {
  const BadgeUnlockHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BadgeUnlockHost> createState() => _BadgeUnlockHostState();
}

class _BadgeUnlockHostState extends ConsumerState<BadgeUnlockHost>
    with SingleTickerProviderStateMixin {
  // Created in initState rather than as a `late final` initialiser: a host
  // disposed before any badge was celebrated would otherwise construct the
  // controller from inside dispose(), and createTicker looks up TickerMode on
  // an element that is by then deactivated.
  late final AnimationController _reveal;

  /// The badge on screen. Tracked separately from the queue head so the
  /// overlay can finish fading out after the queue has already moved on.
  BadgeDefinition? _showing;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: _kRevealDuration);
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  /// Picks up the head of the queue when nothing is being shown.
  ///
  /// Deliberately ignores the queue while a badge is on screen: several badges
  /// can land at once, and they are celebrated one after another rather than
  /// replacing each other mid-animation.
  void _adoptQueueHead(List<BadgeDefinition> queue) {
    if (_showing != null || queue.isEmpty) return;

    // Called from build, so the state change has to wait for the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showing != null) return;
      final head = ref.read(badgeUnlockQueueProvider);
      if (head.isEmpty) return;

      setState(() {
        _showing = head.first;
        _visible = true;
      });
      HapticFeedback.heavyImpact();
      _reveal.forward(from: 0);
    });
  }

  void _dismiss() {
    if (!_visible) return;
    setState(() => _visible = false);
  }

  /// Runs when the exit fade completes — clears the badge and lets the next
  /// one be adopted on the following build.
  void _onFadeEnd() {
    if (_visible || _showing == null) return;
    ref.read(badgeUnlockQueueProvider.notifier).dismissCurrent();
    setState(() => _showing = null);
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(badgeUnlockQueueProvider);
    _adoptQueueHead(queue);

    final badge = _showing;

    return Stack(
      children: [
        widget.child,
        if (badge != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_visible,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: _kExitDuration,
                curve: Curves.easeOut,
                onEnd: _onFadeEnd,
                child: _BadgeUnlockView(
                  badge: badge,
                  reveal: _reveal,
                  onDismiss: _dismiss,
                  remaining: queue.length - 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The reveal
// ---------------------------------------------------------------------------

class _BadgeUnlockView extends StatelessWidget {
  const _BadgeUnlockView({
    required this.badge,
    required this.reveal,
    required this.onDismiss,
    required this.remaining,
  });

  final BadgeDefinition badge;
  final Animation<double> reveal;
  final VoidCallback onDismiss;

  /// How many more badges are queued behind this one.
  final int remaining;

  /// A stage of the reveal, as a 0..1 value curved over its own window.
  double _stage(double begin, double end, Curve curve) =>
      curve.transform(Interval(begin, end).transform(reveal.value));

  @override
  Widget build(BuildContext context) {
    final tint = badge.tier.color;

    return AnimatedBuilder(
      animation: reveal,
      builder: (context, _) {
        final scrim = _stage(0, 0.18, Curves.easeOut);
        final pop = _stage(0.07, 0.43, Curves.elasticOut);
        final burst = _stage(0.21, 0.64, Curves.easeOut);
        final shine = const Interval(0.36, 0.79).transform(reveal.value);
        final text = _stage(0.43, 0.64, Curves.easeOut);
        final action = _stage(0.6, 0.85, Curves.easeOut);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: ColoredBox(
            color: OneRepColors.background.withValues(alpha: 0.93 * scrim),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (burst > 0 && burst < 1)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _BurstPainter(
                                    progress: burst,
                                    tint: tint,
                                  ),
                                ),
                              ),
                            Transform.scale(
                              scale: pop.clamp(0.0, 1.4),
                              child: BadgeMedallion(
                                badge: badge,
                                earned: true,
                                size: 104,
                                shine: shine,
                              ),
                            ),
                          ],
                        ),
                      ),

                      _Rise(
                        t: text,
                        child: Column(
                          children: [
                            Text(
                              'BADGE UNLOCKED',
                              style: TextStyle(
                                color: tint,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              badge.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: OneRepColors.textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _TierPill(tier: badge.tier),
                            const SizedBox(height: 14),
                            Text(
                              badge.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: OneRepColors.textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      _Rise(
                        t: action,
                        child: Column(
                          children: [
                            TextButton(
                              onPressed: onDismiss,
                              style: TextButton.styleFrom(
                                foregroundColor: OneRepColors.background,
                                backgroundColor: tint,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 44,
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                'NICE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            // Several badges can fall at once. Saying so up
                            // front stops the second celebration reading as a
                            // stuck screen.
                            if (remaining > 0) ...[
                              const SizedBox(height: 12),
                              Text(
                                remaining == 1
                                    ? '1 more to go'
                                    : '$remaining more to go',
                                style: const TextStyle(
                                  color: OneRepColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fades a block in while lifting it a few pixels.
class _Rise extends StatelessWidget {
  const _Rise({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - t.clamp(0.0, 1.0))),
        child: child,
      ),
    );
  }
}

/// The tier this badge belongs to, as a small outlined pill.
class _TierPill extends StatelessWidget {
  const _TierPill({required this.tier});

  final BadgeTier tier;

  @override
  Widget build(BuildContext context) {
    final tint = tier.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Text(
        tier.label.toUpperCase(),
        style: TextStyle(
          color: tint,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Particle burst
// ---------------------------------------------------------------------------

/// Shards thrown outward from the medallion as it lands.
///
/// Generated from a fixed seed rather than at random, so the burst is the same
/// every time — a celebration that looks subtly different on each unlock reads
/// as a glitch, not as variety. Cheap enough to repaint every frame: fourteen
/// line segments and no allocation beyond the paint.
class _BurstPainter extends CustomPainter {
  const _BurstPainter({required this.progress, required this.tint});

  /// 0..1 through the burst's own window.
  final double progress;
  final Color tint;

  static const int _count = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final random = math.Random(7);
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < _count; i++) {
      // Evenly spaced, then nudged, so the ring never looks mechanical.
      final angle =
          (i / _count) * math.pi * 2 + (random.nextDouble() - 0.5) * 0.4;
      final reach = size.width * (0.30 + random.nextDouble() * 0.20);
      final direction = Offset(math.cos(angle), math.sin(angle));

      // The head flies outward; the tail trails 26px behind it, clamped to
      // the centre so the streak grows out of the medallion rather than
      // starting life pointing back at it.
      final distance = reach * eased;
      final head = centre + direction * distance;
      final tail = centre + direction * math.max(0.0, distance - 26);

      paint
        ..strokeWidth = 1.5 + random.nextDouble() * 1.5
        ..color = tint.withValues(alpha: 0.75 * fade);

      canvas.drawLine(tail, head, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.tint != tint;
}
