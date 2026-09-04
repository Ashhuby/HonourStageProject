/// The celebrations shown when a badge is earned or a rank is reached.
///
/// Mounted once, above the whole app, from `MaterialApp.builder` — not from
/// the badges screen and not from the home screen. Most badges are earned
/// mid-set, on the active session screen, which is pushed as its own route; an
/// overlay owned by a screen underneath it would never be seen. Drawn in a
/// [Stack] rather than through `showDialog` for the same reason: it has no
/// route of its own to lose, and it cannot be dismissed by a `Navigator.pop`
/// meant for something else.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/badge_unlock_queue.dart';
import '../../data/rank_up_queue.dart';
import '../../domain/badge_catalogue.dart';
import '../../domain/rank.dart';
import 'badge_visuals.dart';
import 'rank_visuals.dart';

/// How long the reveal takes end to end.
const Duration _kRevealDuration = Duration(milliseconds: 1400);

/// How long the overlay takes to fade away once dismissed.
const Duration _kExitDuration = Duration(milliseconds: 200);

/// How many badges are celebrated one after another before they are rolled
/// into a single card instead.
///
/// Three is about as many full-screen celebrations as a good session can
/// justify. Beyond that the queue stops being a reward and becomes a wall: an
/// upgrade that adds badges retroactively awards a dozen on the first set, and
/// every one of them puts a modal barrier over the app that has to be tapped
/// away before the workout can even be finished.
const int _kMaxIndividual = 3;

/// How long a celebration stays up on its own.
///
/// A [Timer] rather than a listener on the reveal, deliberately: the timer is
/// what guarantees the overlay comes down. If the animation never runs — a
/// muted ticker, animations turned off at the OS level — an overlay waiting on
/// it would sit there fully transparent and swallow every tap in the app.
const Duration _kSingleHold = Duration(milliseconds: 3200);
const Duration _kBatchHold = Duration(milliseconds: 5200);

/// Wraps the app and celebrates whatever is waiting to be announced.
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

  /// The badges on screen. Tracked separately from the queue so the overlay
  /// can finish fading out after the queue has already moved on. Usually one;
  /// more than one when a pile landed together and is being shown as a single
  /// card.
  List<BadgeDefinition> _batch = const [];

  /// The rank on screen, when a rank-up is what is being celebrated.
  Rank? _rank;

  bool _visible = false;

  /// How long the current celebration holds before taking itself down.
  Duration _holdFor = _kSingleHold;

  /// Brings the celebration down without the user having to.
  Timer? _hold;

  /// Whether something is on screen or still fading out.
  bool get _busy => _batch.isNotEmpty || _rank != null;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: _kRevealDuration);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  /// Picks up whatever is waiting when nothing is being shown.
  ///
  /// Deliberately ignores new arrivals while a celebration is on screen: a
  /// badge landing mid-reveal waits its turn rather than replacing what the
  /// user is looking at.
  void _adoptNext() {
    if (_busy) return;

    // Called from build, so the state change has to wait for the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _busy) return;

      final pending = ref.read(badgeUnlockQueueProvider);
      final climbed = ref.read(rankUpQueueProvider);
      if (pending.isEmpty && climbed == null) return;

      setState(() {
        // Badges first: the rank is what they added up to, so announcing it
        // before them would give away the ending.
        if (pending.isNotEmpty) {
          _batch = pending.length > _kMaxIndividual
              ? List<BadgeDefinition>.unmodifiable(pending)
              : [pending.first];
          _holdFor = _batch.length > 1 ? _kBatchHold : _kSingleHold;
        } else {
          _rank = climbed;
          _holdFor = _kBatchHold;
        }
        _visible = true;
      });

      HapticFeedback.heavyImpact();
      _reveal.forward(from: 0);

      _hold?.cancel();
      _hold = Timer(_holdFor, _dismiss);
    });
  }

  void _dismiss() {
    _hold?.cancel();
    if (!_visible || !mounted) return;
    setState(() => _visible = false);
  }

  /// Runs when the exit fade completes — clears what was shown and lets the
  /// next thing be adopted on the following build.
  void _onFadeEnd() {
    if (_visible || !_busy) return;

    if (_rank != null) {
      ref.read(rankUpQueueProvider.notifier).clear();
      setState(() => _rank = null);
      return;
    }

    ref.read(badgeUnlockQueueProvider.notifier).dismissFirst(_batch.length);
    setState(() => _batch = const []);
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(badgeUnlockQueueProvider);
    final climbed = ref.watch(rankUpQueueProvider);
    if (queue.isNotEmpty || climbed != null) _adoptNext();

    final rank = _rank;
    final batch = _batch;

    final Widget? view = rank != null
        ? _RankUpView(rank: rank, reveal: _reveal, onDismiss: _dismiss)
        : batch.isNotEmpty
        ? _BadgeUnlockView(
            batch: batch,
            reveal: _reveal,
            onDismiss: _dismiss,
            remaining: queue.length - batch.length + (climbed != null ? 1 : 0),
          )
        : null;

    return Stack(
      children: [
        widget.child,
        if (view != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_visible,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: _kExitDuration,
                curve: Curves.easeOut,
                onEnd: _onFadeEnd,
                child: view,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The shared choreography
// ---------------------------------------------------------------------------

/// The staging both celebrations are built on.
///
/// One controller, split into overlapping windows: the scrim arrives first,
/// the emblem lands, the burst and shockwave fire off the landing, and the
/// words follow it. Shared rather than written twice so a badge unlock and a
/// rank-up feel like the same moment at two sizes.
class _Celebration extends StatelessWidget {
  const _Celebration({
    required this.reveal,
    required this.tint,
    required this.onDismiss,
    required this.emblem,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.pill,
    this.footnote,
  });

  final Animation<double> reveal;
  final Color tint;
  final VoidCallback onDismiss;

  /// The thing that scales into view. Laid out at the centre of the burst.
  final Widget emblem;

  /// The small line above the title — "BADGE UNLOCKED", "RANK UP".
  final String eyebrow;
  final String title;
  final String body;
  final Widget? pill;

  /// Small print under the button, for what is still waiting.
  final String? footnote;

  /// A stage of the reveal, as a 0..1 value curved over its own window.
  double _stage(double begin, double end, Curve curve) =>
      curve.transform(Interval(begin, end).transform(reveal.value));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, _) {
        final scrim = _stage(0, 0.18, Curves.easeOut);
        final pop = _stage(0.07, 0.43, Curves.elasticOut);
        final burst = _stage(0.21, 0.64, Curves.easeOut);
        final wave = _stage(0.16, 0.58, Curves.easeOutCubic);
        final halo = _stage(0.24, 0.72, Curves.easeOut);
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
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Lit from behind, so the emblem looks like a
                            // source rather than a sticker on a dark screen.
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _GlowPainter(
                                  progress: halo,
                                  tint: tint,
                                ),
                              ),
                            ),
                            if (halo > 0)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _HaloPainter(
                                    progress: halo,
                                    tint: tint,
                                  ),
                                ),
                              ),
                            if (wave > 0 && wave < 1)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _ShockwavePainter(
                                    progress: wave,
                                    tint: tint,
                                  ),
                                ),
                              ),
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
                              child: emblem,
                            ),
                          ],
                        ),
                      ),

                      _Rise(
                        t: text,
                        child: Column(
                          children: [
                            Text(
                              eyebrow,
                              style: TextStyle(
                                color: tint,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: OneRepColors.textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                height: 1.1,
                              ),
                            ),
                            if (pill != null) ...[
                              const SizedBox(height: 12),
                              pill!,
                            ],
                            const SizedBox(height: 14),
                            Text(
                              body,
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
                            _DismissButton(tint: tint, onPressed: onDismiss),
                            if (footnote != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                footnote!,
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

/// The button that closes a celebration.
///
/// No countdown bar under it. It was there to explain why the overlay closes
/// itself, but a coloured hairline sitting beneath a pill button reads as an
/// underline that does not belong to anything — and the celebration is short
/// enough, and dismissible enough, that nothing needed explaining.
class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.tint, required this.onPressed});

  final Color tint;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: OneRepColors.background,
        backgroundColor: tint,
        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: const Text(
        'NICE',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge unlock
// ---------------------------------------------------------------------------

class _BadgeUnlockView extends StatelessWidget {
  const _BadgeUnlockView({
    required this.batch,
    required this.reveal,
    required this.onDismiss,
    required this.remaining,
  });

  /// The badges this celebration covers. One normally; several when a pile
  /// landed together and is being shown as a single card.
  final List<BadgeDefinition> batch;

  final Animation<double> reveal;
  final VoidCallback onDismiss;

  /// How many more celebrations are waiting behind this one.
  final int remaining;

  bool get _isBatch => batch.length > 1;

  /// The badge the medallion is drawn as: the best one in the batch, which is
  /// the one worth putting on screen.
  BadgeDefinition get badge => _isBatch
      ? batch.reduce((best, b) => b.tier.index > best.tier.index ? b : best)
      : batch.first;

  @override
  Widget build(BuildContext context) {
    return _Celebration(
      reveal: reveal,
      tint: badge.tier.color,
      onDismiss: onDismiss,
      emblem: BadgeMedallion(
        badge: badge,
        earned: true,
        size: 104,
        shine: const Interval(0.36, 0.79).transform(reveal.value),
      ),
      eyebrow: _isBatch ? '${batch.length} BADGES UNLOCKED' : 'BADGE UNLOCKED',
      title: badge.name,
      pill: _isBatch ? null : _TierPill(tier: badge.tier),
      // In a batch the other names stand in for the description: a dozen
      // descriptions is a wall of text, but the user should still see what
      // they got rather than only a count.
      body: _isBatch
          ? batch.where((b) => b != badge).map((b) => b.name).join('  ·  ')
          : badge.description,
      // Several badges can fall at once. Saying so up front stops the second
      // celebration reading as a stuck screen.
      footnote: remaining > 0
          ? (remaining == 1 ? '1 more to go' : '$remaining more to go')
          : null,
    );
  }
}

/// The tier a badge belongs to, as a small outlined pill.
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
// Rank up
// ---------------------------------------------------------------------------

/// Shown after the badges that caused it.
///
/// Deliberately the same choreography at a larger size rather than a different
/// effect: a rank is the sum of the badges just celebrated, and it should read
/// as the end of that moment rather than as a separate feature.
class _RankUpView extends StatelessWidget {
  const _RankUpView({
    required this.rank,
    required this.reveal,
    required this.onDismiss,
  });

  final Rank rank;
  final Animation<double> reveal;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) {
    final next = rank.next;

    return _Celebration(
      reveal: reveal,
      tint: rank.color,
      onDismiss: onDismiss,
      emblem: RankCrest(rank: rank, size: 120, glow: true),
      eyebrow: 'RANK UP',
      title: rank.label,
      body: next == null
          ? 'The top of the ladder. There is nothing above this.'
          : 'Every badge you earn counts towards ${next.label}.',
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

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

/// A soft pool of the emblem's colour behind it.
class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.progress, required this.tint});

  final double progress;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.5 * (0.6 + 0.4 * progress);

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: 0.28 * progress),
            tint.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.progress != progress || old.tint != tint;
}

/// Spokes radiating from behind the emblem, turning slightly as they arrive.
///
/// Static once the reveal finishes. A halo that keeps spinning turns a
/// two-second moment into something the eye has to keep tracking, and the
/// celebration has words on it that are meant to be read.
class _HaloPainter extends CustomPainter {
  const _HaloPainter({required this.progress, required this.tint});

  final double progress;
  final Color tint;

  static const int _spokes = 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final centre = Offset(size.width / 2, size.height / 2);
    final inner = size.width * 0.30;
    final outer = size.width * (0.34 + 0.10 * progress);
    final turn = (1 - progress) * 0.18;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = tint.withValues(alpha: 0.22 * progress);

    for (var i = 0; i < _spokes; i++) {
      final angle = (i / _spokes) * math.pi * 2 + turn;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        centre + direction * inner,
        centre + direction * outer,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.progress != progress || old.tint != tint;
}

/// A single ring thrown off as the emblem lands.
class _ShockwavePainter extends CustomPainter {
  const _ShockwavePainter({required this.progress, required this.tint});

  final double progress;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width * (0.18 + 0.34 * progress);

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        // Thins as it expands, the way a ring of light would.
        ..strokeWidth = 3 * (1 - progress)
        ..color = tint.withValues(alpha: 0.5 * (1 - progress)),
    );
  }

  @override
  bool shouldRepaint(_ShockwavePainter old) =>
      old.progress != progress || old.tint != tint;
}

/// Shards thrown outward from the emblem as it lands, with a slower scatter of
/// motes behind them for depth.
///
/// Generated from a fixed seed rather than at random, so the burst is the same
/// every time — a celebration that looks subtly different on each unlock reads
/// as a glitch, not as variety. Cheap enough to repaint every frame: a couple
/// of dozen primitives and no allocation beyond the paint.
class _BurstPainter extends CustomPainter {
  const _BurstPainter({required this.progress, required this.tint});

  /// 0..1 through the burst's own window.
  final double progress;
  final Color tint;

  static const int _shards = 14;
  static const int _motes = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final random = math.Random(7);
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < _shards; i++) {
      // Evenly spaced, then nudged, so the ring never looks mechanical.
      final angle =
          (i / _shards) * math.pi * 2 + (random.nextDouble() - 0.5) * 0.4;
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

    // The motes travel further and linger, so the burst has a far edge rather
    // than stopping dead at the end of the streaks.
    final moteFade = (1 - progress * progress).clamp(0.0, 1.0);
    final dot = Paint()..color = tint.withValues(alpha: 0.55 * moteFade);

    for (var i = 0; i < _motes; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final reach = size.width * (0.34 + random.nextDouble() * 0.16);
      final direction = Offset(math.cos(angle), math.sin(angle));

      canvas.drawCircle(
        centre + direction * reach * eased,
        1 + random.nextDouble(),
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.tint != tint;
}
