/// Every badge the app defines, and the shape of a badge's criterion.
///
/// Pure data with no database and no Flutter dependency, so the catalogue can
/// be read by the seed in `local_database.dart`, by the award engine in
/// `badge_service.dart`, by the stats queries in `badge_stats.dart` and by the
/// UI without any of them importing each other.
///
/// A criterion is deliberately *not* a closure. Every badge is "some counter
/// reached some threshold", expressed as a [BadgeStat] plus a [target]. That
/// makes the criterion introspectable rather than merely executable: the same
/// pair yields the award decision (`value >= target`) and the progress the UI
/// draws on a locked tile (`value / target`). Badges written as imperative
/// `_check()` methods could answer the first question and not the second.
library;

/// How rare a badge is meant to be.
///
/// Colours live in the UI layer (`OneRepColors`) — this file stays free of
/// Flutter so it can be imported by the database.
enum BadgeTier {
  bronze('Bronze'),
  silver('Silver'),
  gold('Gold'),
  platinum('Platinum');

  const BadgeTier(this.label);

  final String label;
}

/// The axis of training a badge recognises. Drives the filter chips.
enum BadgeCategory {
  consistency('Consistency'),
  strength('Strength'),
  endurance('Endurance'),
  exploration('Exploration'),
  oddities('Oddities');

  const BadgeCategory(this.label);

  final String label;
}

/// A counter derived from the user's training history.
///
/// One stat can back several badges at different thresholds — the four session
/// milestones are one `COUNT`, not four. [formatPair] belongs here rather than
/// on [BadgeDefinition] because a badge's unit is fully determined by its stat;
/// storing it per badge would be a second place for the two to disagree.
enum BadgeStat {
  completedSessions('sessions'),
  totalSets('sets'),
  currentStreakDays('days'),
  totalVolumeKg('kg'),
  totalDistanceMetres('m'),
  prCount('PRs'),
  distinctExercises('exercises'),
  muscleGroupsTrained('groups'),
  customExercises('exercises'),
  cardioSets('sets'),
  mobilitySets('sets'),
  sessionsWithNotes('notes'),
  splitsCreated('splits'),
  longestSessionMinutes('min'),
  maxSessionsInWeek('sessions'),
  earlyMorningSessions('sessions'),
  lateNightSessions('sessions'),
  weekendPairs('weekends'),
  comebackReturns('returns'),
  maxRepsOneExerciseOneSession('reps'),
  bestBigLiftBodyweightRatio('x bodyweight');

  const BadgeStat(this.unit);

  /// Short unit word, used when a value needs no rescaling.
  final String unit;

  /// Renders progress as "current / target", unit included once.
  ///
  /// One method rather than a formatter per value because the unit belongs to
  /// the pair: writing each side separately produces "10.0 t / 100.0 t kg",
  /// which is both wrong and twice as long as the tile has room for.
  ///
  /// Volume and distance are stored in kilograms and metres because that is
  /// what the set rows hold, but a million kilograms is unreadable — the
  /// milestones that use them are named in tonnes and kilometres, so the
  /// progress line has to be too.
  ///
  /// [compact] drops the trailing unit word, for the grid tile where the badge
  /// name directly above already says what is being counted.
  String formatPair(num current, num target, {bool compact = false}) {
    switch (this) {
      case BadgeStat.totalVolumeKg:
        // Decimals chosen from the target so both sides of the pair agree.
        final places = target < 100000 ? 1 : 0;
        return '${(current / 1000).toStringAsFixed(places)} / '
            '${(target / 1000).toStringAsFixed(places)} t';
      case BadgeStat.totalDistanceMetres:
        return '${(current / 1000).toStringAsFixed(1)} / '
            '${(target / 1000).toStringAsFixed(1)} km';
      case BadgeStat.bestBigLiftBodyweightRatio:
        return '${current.toStringAsFixed(2)} / '
            '${target.toStringAsFixed(2)}x';
      default:
        final pair = '${current.round()} / ${target.round()}';
        return compact ? pair : '$pair $unit';
    }
  }
}

/// One badge: what it is called, what earns it, and how rare it is.
class BadgeDefinition {
  final String key;
  final String name;
  final String description;

  /// Material icon codepoint name — no external assets needed.
  ///
  /// Must also appear in `badgeIconData()` in
  /// `presentation/widgets/session_chips.dart`, which is the only place the
  /// name is resolved to an `IconData`. An unlisted name falls back to a star
  /// with no error, so the two are covered by a test.
  final String icon;

  final BadgeTier tier;
  final BadgeCategory category;

  /// The counter this badge reads, and the value it must reach.
  final BadgeStat stat;
  final num target;

  /// Whether a locked tile should draw a progress ring.
  ///
  /// False for badges whose progress is only ever 0 or 1 — "train before 6am"
  /// has no meaningful halfway point, and a ring stuck at 0% reads as broken
  /// rather than as unstarted. Explicit rather than derived from `target > 1`:
  /// [BadgeStat.bestBigLiftBodyweightRatio] has a target of 1.0 and very much
  /// does want a ring.
  final bool showsProgress;

  const BadgeDefinition({
    required this.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.tier,
    required this.category,
    required this.stat,
    required this.target,
    this.showsProgress = true,
  });
}

/// Single source of truth for every badge in the system.
///
/// Also drives the database seed (`_seedBadges()` in `local_database.dart`),
/// so adding an entry here and bumping `schemaVersion` is all a new badge
/// needs on the data side.
///
/// Order matters: it is the display order within the earned and locked groups
/// on the badges screen, so entries are grouped by category and run easiest to
/// hardest within each ladder.
const List<BadgeDefinition> kAllBadges = [
  // ---------------------------------------------------------------------------
  // Consistency — showing up
  // ---------------------------------------------------------------------------
  BadgeDefinition(
    key: 'first_workout',
    name: 'First Rep',
    description: 'Complete your first workout session.',
    icon: 'fitness_center',
    tier: BadgeTier.bronze,
    category: BadgeCategory.consistency,
    stat: BadgeStat.completedSessions,
    target: 1,
    showsProgress: false,
  ),
  BadgeDefinition(
    key: 'sessions_10',
    name: 'Regular',
    description: 'Complete 10 workout sessions.',
    icon: 'event_available',
    tier: BadgeTier.bronze,
    category: BadgeCategory.consistency,
    stat: BadgeStat.completedSessions,
    target: 10,
  ),
  BadgeDefinition(
    key: 'sessions_50',
    name: 'Committed',
    description: 'Complete 50 workout sessions.',
    icon: 'calendar_month',
    tier: BadgeTier.silver,
    category: BadgeCategory.consistency,
    stat: BadgeStat.completedSessions,
    target: 50,
  ),
  BadgeDefinition(
    key: 'sessions_100',
    name: 'Century Club',
    description: 'Complete 100 workout sessions.',
    icon: 'verified',
    tier: BadgeTier.gold,
    category: BadgeCategory.consistency,
    stat: BadgeStat.completedSessions,
    target: 100,
  ),
  BadgeDefinition(
    key: 'sessions_250',
    name: 'Lifer',
    description: 'Complete 250 workout sessions.',
    icon: 'diamond',
    tier: BadgeTier.platinum,
    category: BadgeCategory.consistency,
    stat: BadgeStat.completedSessions,
    target: 250,
  ),
  BadgeDefinition(
    key: 'streak_3_day',
    name: 'Warm-Up',
    description: 'Log a session three days running.',
    icon: 'whatshot',
    tier: BadgeTier.bronze,
    category: BadgeCategory.consistency,
    stat: BadgeStat.currentStreakDays,
    target: 3,
  ),
  BadgeDefinition(
    key: 'streak_7_day',
    name: '7-Day Streak',
    description: 'Log at least one session every day for 7 consecutive days.',
    icon: 'local_fire_department',
    tier: BadgeTier.silver,
    category: BadgeCategory.consistency,
    stat: BadgeStat.currentStreakDays,
    target: 7,
  ),
  BadgeDefinition(
    key: 'streak_30_day',
    name: '30-Day Streak',
    description: 'Log at least one session every day for 30 consecutive days.',
    icon: 'emoji_events',
    tier: BadgeTier.gold,
    category: BadgeCategory.consistency,
    stat: BadgeStat.currentStreakDays,
    target: 30,
  ),
  BadgeDefinition(
    key: 'streak_100_day',
    name: 'Unbroken',
    description: 'Log a session every day for 100 consecutive days.',
    icon: 'shield',
    tier: BadgeTier.platinum,
    category: BadgeCategory.consistency,
    stat: BadgeStat.currentStreakDays,
    target: 100,
  ),
  BadgeDefinition(
    key: 'week_4_sessions',
    name: 'Full Week',
    description: 'Train four times inside a single week.',
    icon: 'date_range',
    tier: BadgeTier.silver,
    category: BadgeCategory.consistency,
    stat: BadgeStat.maxSessionsInWeek,
    target: 4,
  ),
  BadgeDefinition(
    key: 'comeback',
    name: 'Back at It',
    description: 'Return to training after two weeks away.',
    icon: 'replay',
    tier: BadgeTier.bronze,
    category: BadgeCategory.consistency,
    stat: BadgeStat.comebackReturns,
    target: 1,
    showsProgress: false,
  ),

  // ---------------------------------------------------------------------------
  // Strength — the work under the bar
  // ---------------------------------------------------------------------------
  BadgeDefinition(
    key: 'sets_50',
    name: 'Getting Started',
    description: 'Log 50 total sets.',
    icon: 'bolt',
    tier: BadgeTier.bronze,
    category: BadgeCategory.strength,
    stat: BadgeStat.totalSets,
    target: 50,
  ),
  BadgeDefinition(
    key: 'sets_500',
    name: 'Iron Consistency',
    description: 'Log 500 total sets.',
    icon: 'workspace_premium',
    tier: BadgeTier.silver,
    category: BadgeCategory.strength,
    stat: BadgeStat.totalSets,
    target: 500,
  ),
  BadgeDefinition(
    key: 'volume_10t',
    name: 'Ten Tonnes',
    description: 'Move 10,000 kg in total across every set you have logged.',
    icon: 'scale',
    tier: BadgeTier.bronze,
    category: BadgeCategory.strength,
    stat: BadgeStat.totalVolumeKg,
    target: 10000,
  ),
  BadgeDefinition(
    key: 'volume_100t',
    name: 'Hundred Tonnes',
    description: 'Move 100,000 kg in total.',
    icon: 'inventory_2',
    tier: BadgeTier.silver,
    category: BadgeCategory.strength,
    stat: BadgeStat.totalVolumeKg,
    target: 100000,
  ),
  BadgeDefinition(
    key: 'volume_1000t',
    name: 'Kilotonne',
    description: 'Move 1,000,000 kg in total.',
    icon: 'landscape',
    tier: BadgeTier.platinum,
    category: BadgeCategory.strength,
    stat: BadgeStat.totalVolumeKg,
    target: 1000000,
  ),
  BadgeDefinition(
    key: 'first_pr',
    name: 'Personal Record',
    description: 'Set your first personal best.',
    icon: 'military_tech',
    tier: BadgeTier.bronze,
    category: BadgeCategory.strength,
    stat: BadgeStat.prCount,
    target: 1,
    showsProgress: false,
  ),
  BadgeDefinition(
    key: 'pr_10',
    name: 'PR Machine',
    description: 'Set 10 personal bests across any exercises.',
    icon: 'trending_up',
    tier: BadgeTier.silver,
    category: BadgeCategory.strength,
    stat: BadgeStat.prCount,
    target: 10,
  ),
  BadgeDefinition(
    key: 'pr_50',
    name: 'Record Breaker',
    description: 'Set 50 personal bests.',
    icon: 'leaderboard',
    tier: BadgeTier.gold,
    category: BadgeCategory.strength,
    stat: BadgeStat.prCount,
    target: 50,
  ),
  // Restricted to the barbell lifts the strength standards cover. "Lift your
  // bodyweight" on a leg press is not the same claim, and the app already
  // knows which exercises are comparable — hasStrengthStandards().
  BadgeDefinition(
    key: 'bodyweight_lift',
    name: 'Even Money',
    description: 'Lift your own bodyweight on a barbell lift.',
    icon: 'accessibility_new',
    tier: BadgeTier.silver,
    category: BadgeCategory.strength,
    stat: BadgeStat.bestBigLiftBodyweightRatio,
    target: 1.0,
  ),
  BadgeDefinition(
    key: 'double_bodyweight',
    name: 'Double Up',
    description: 'Lift twice your bodyweight on a barbell lift.',
    icon: 'filter_2',
    tier: BadgeTier.gold,
    category: BadgeCategory.strength,
    stat: BadgeStat.bestBigLiftBodyweightRatio,
    target: 2.0,
  ),

  // ---------------------------------------------------------------------------
  // Endurance — cardio and mobility
  // ---------------------------------------------------------------------------
  BadgeDefinition(
    key: 'first_cardio',
    name: 'Off the Rack',
    description: 'Log your first cardio activity.',
    icon: 'directions_run',
    tier: BadgeTier.bronze,
    category: BadgeCategory.endurance,
    stat: BadgeStat.cardioSets,
    target: 1,
    showsProgress: false,
  ),
  BadgeDefinition(
    key: 'distance_10k',
    name: 'First Ten',
    description: 'Cover 10 km in total across all cardio.',
    icon: 'directions_walk',
    tier: BadgeTier.bronze,
    category: BadgeCategory.endurance,
    stat: BadgeStat.totalDistanceMetres,
    target: 10000,
  ),
  BadgeDefinition(
    key: 'marathon_distance',
    name: 'The Long Way',
    description: 'Cover 42.2 km in total across all cardio.',
    icon: 'route',
    tier: BadgeTier.silver,
    category: BadgeCategory.endurance,
    stat: BadgeStat.totalDistanceMetres,
    target: 42195,
  ),
  BadgeDefinition(
    key: 'distance_100k',
    name: 'Century Ride',
    description: 'Cover 100 km in total across all cardio.',
    icon: 'map',
    tier: BadgeTier.gold,
    category: BadgeCategory.endurance,
    stat: BadgeStat.totalDistanceMetres,
    target: 100000,
  ),
  BadgeDefinition(
    key: 'session_90min',
    name: 'Long Haul',
    description: 'Train for 90 minutes in a single session.',
    icon: 'timer',
    tier: BadgeTier.silver,
    category: BadgeCategory.endurance,
    stat: BadgeStat.longestSessionMinutes,
    target: 90,
  ),
  BadgeDefinition(
    key: 'first_mobility',
    name: 'Loosen Up',
    description: 'Log your first mobility work.',
    icon: 'self_improvement',
    tier: BadgeTier.bronze,
    category: BadgeCategory.endurance,
    stat: BadgeStat.mobilitySets,
    target: 1,
    showsProgress: false,
  ),

  // ---------------------------------------------------------------------------
  // Exploration — breadth, and curating the app itself
  // ---------------------------------------------------------------------------
  BadgeDefinition(
    key: 'first_custom_exercise',
    name: 'Your Own Rules',
    description: 'Create your first custom exercise.',
    icon: 'add_circle',
    tier: BadgeTier.bronze,
    category: BadgeCategory.exploration,
    stat: BadgeStat.customExercises,
    target: 1,
    showsProgress: false,
  ),
  BadgeDefinition(
    key: 'first_split',
    name: 'Architect',
    description: 'Build your first training split.',
    icon: 'architecture',
    tier: BadgeTier.bronze,
    category: BadgeCategory.exploration,
    stat: BadgeStat.splitsCreated,
    target: 1,
    showsProgress: false,
  ),
  BadgeDefinition(
    key: 'exercises_25',
    name: 'Well Rounded',
    description: 'Log a set on 25 different exercises.',
    icon: 'grid_view',
    tier: BadgeTier.silver,
    category: BadgeCategory.exploration,
    stat: BadgeStat.distinctExercises,
    target: 25,
  ),
  BadgeDefinition(
    key: 'all_muscle_groups',
    name: 'Anatomist',
    description: 'Train every muscle group at least once.',
    icon: 'accessibility',
    tier: BadgeTier.gold,
    category: BadgeCategory.exploration,
    stat: BadgeStat.muscleGroupsTrained,
    target: 6,
  ),
  BadgeDefinition(
    key: 'notes_10',
    name: 'Journalist',
    description: 'Write a note on 10 sessions.',
    icon: 'edit_note',
    tier: BadgeTier.silver,
    category: BadgeCategory.exploration,
    stat: BadgeStat.sessionsWithNotes,
    target: 10,
  ),

  // ---------------------------------------------------------------------------
  // Oddities — the ones you earn by accident
  // ---------------------------------------------------------------------------
  BadgeDefinition(
    key: 'early_bird',
    name: 'Early Bird',
    description: 'Start a session before 6am.',
    icon: 'wb_twilight',
    tier: BadgeTier.bronze,
    category: BadgeCategory.oddities,
    stat: BadgeStat.earlyMorningSessions,
    target: 1,
    showsProgress: false,
  ),
  BadgeDefinition(
    key: 'night_owl',
    name: 'Night Owl',
    description: 'Start a session at 10pm or later.',
    icon: 'bedtime',
    tier: BadgeTier.bronze,
    category: BadgeCategory.oddities,
    stat: BadgeStat.lateNightSessions,
    target: 1,
    showsProgress: false,
  ),
  BadgeDefinition(
    key: 'weekend_warrior',
    name: 'Weekend Warrior',
    description: 'Train on both days of the same weekend.',
    icon: 'weekend',
    tier: BadgeTier.silver,
    category: BadgeCategory.oddities,
    stat: BadgeStat.weekendPairs,
    target: 1,
    showsProgress: false,
  ),
  BadgeDefinition(
    key: 'century_set',
    name: 'Century',
    description: 'Log 100 reps of one exercise in a single session.',
    icon: 'repeat',
    tier: BadgeTier.gold,
    category: BadgeCategory.oddities,
    stat: BadgeStat.maxRepsOneExerciseOneSession,
    target: 100,
  ),
];

/// Looks up a badge by its stored key.
///
/// Null rather than a throw for an unknown key, so a row synced from a newer
/// app version cannot crash an older client — the same contract as
/// `Muscle.byNameOrNull`.
BadgeDefinition? badgeByKeyOrNull(String key) {
  for (final badge in kAllBadges) {
    if (badge.key == key) return badge;
  }
  return null;
}
