import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/exercise_catalogue.dart';
import '../../data/exercise_repository.dart';
import '../../data/session_repository.dart';
import '../../domain/activity.dart';
import '../../domain/muscle.dart';
import 'exercise_filter.dart';
import 'category_chips.dart';
import 'exercise_list_tile.dart';
import 'muscle_chips.dart';

/// Opens the shared exercise picker and resolves to the chosen exercise, or
/// null if the sheet was dismissed.
///
/// Replaces the flat dropdowns and the fixed-height dialog that each screen
/// used to roll for itself. Search, a recently-used row and muscle-group chips
/// mean the full library is reachable in one or two taps mid-workout.
///
/// [restrictToIds] narrows the pool — a routine-backed session passes only the
/// exercises planned for that day. Ids rather than rows, because the sheet
/// reads the catalogue stream (which carries muscle data) rather than being
/// handed a plain exercise list. [excludeIds] hides rows entirely, which the
/// routine builder uses so an exercise cannot be added to the same day twice.
/// [trailingLabels] maps exercise id to a right-aligned label, e.g. `3 × 10`.
Future<Exercise?> showExercisePicker(
  BuildContext context, {
  Set<int>? restrictToIds,
  Set<int> excludeIds = const {},
  String title = 'Add exercise',
  Map<int, String> trailingLabels = const {},
}) {
  // The sheet is built by the root navigator, whose context sits above this
  // screen's ProviderScope, so the container is carried across by hand.
  final container = ProviderScope.containerOf(context);

  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: _ExercisePickerSheet(
        restrictToIds: restrictToIds,
        excludeIds: excludeIds,
        title: title,
        trailingLabels: trailingLabels,
      ),
    ),
  );
}

class _ExercisePickerSheet extends ConsumerStatefulWidget {
  final Set<int>? restrictToIds;
  final Set<int> excludeIds;
  final String title;
  final Map<int, String> trailingLabels;

  const _ExercisePickerSheet({
    required this.restrictToIds,
    required this.excludeIds,
    required this.title,
    required this.trailingLabels,
  });

  @override
  ConsumerState<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<_ExercisePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  ExerciseCategory? _category;
  MuscleGroup? _group;
  Muscle? _muscle;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(watchExerciseCatalogueProvider);
    return catalogueAsync.when(
      data: (catalogue) {
        final restrict = widget.restrictToIds;
        if (restrict == null) return _buildSheet(catalogue);
        return _buildSheet([
          for (final entry in catalogue)
            if (restrict.contains(entry.id)) entry,
        ]);
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) =>
          SizedBox(height: 200, child: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildSheet(List<ExerciseWithMuscles> pool) {
    final available = pool
        .where((e) => !widget.excludeIds.contains(e.id))
        .toList();

    final inCategory = _category == null
        ? available
        : [
            for (final e in available)
              if (e.category == _category) e,
          ];

    final matches = filterExercises(
      pool,
      query: _query,
      category: _category,
      group: _group,
      muscle: _muscle,
      excludeIds: widget.excludeIds,
    );
    final sections = groupExercises(
      matches,
      category: _category,
      group: _group,
      muscle: _muscle,
    );
    final isBrowsing = _query.isEmpty && _category == null && _group == null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            const _GrabHandle(),
            _buildHeader(),
            _buildSearchField(),
            if (isBrowsing) _RecentRow(pool: available, onPick: _pick),
            // Category sits below Recent, not above search: this is a sheet
            // over a half-finished set, so the fast paths stay at the top.
            CategoryChips(
              selected: _category,
              counts: _categoryCounts(available),
              onSelected: (category) => setState(() {
                _category = category;
                _group = null;
                _muscle = null;
              }),
            ),
            if (!(_category?.isSectionedByModality ?? false))
              _buildGroupChips(inCategory),
            if (_group != null)
              MuscleChips(
                group: _group!,
                selected: _muscle,
                counts: countByMuscle(inCategory),
                onSelected: (muscle) => setState(() => _muscle = muscle),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: matches.isEmpty
                  ? const _NoMatches()
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: sections.length,
                      itemBuilder: (context, index) =>
                          _buildSection(sections[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: OneRepColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: OneRepColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search exercises',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
    );
  }

  Map<ExerciseCategory, int> _categoryCounts(List<ExerciseWithMuscles> pool) {
    final counts = <ExerciseCategory, int>{};
    for (final entry in pool) {
      counts[entry.category] = (counts[entry.category] ?? 0) + 1;
    }
    return counts;
  }

  /// The muscle level: one chip per muscle group present in the pool.
  ///
  /// The picker has no room for the body diagram — it is a sheet over a
  /// half-finished set — so the group level is chips here and the diagram on
  /// the Exercises tab. Selecting one reveals [MuscleChips] beneath.
  Widget _buildGroupChips(List<ExerciseWithMuscles> pool) {
    final counts = countByMuscleGroup(pool);
    final present = MuscleGroup.values
        .where((group) => (counts[group]?.total ?? 0) > 0)
        .toList();
    if (present.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: present.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = present[index];
          final isSelected = _group == group;
          return FilterChip(
            label: Text(group.label),
            selected: isSelected,
            showCheckmark: false,
            selectedColor: group.color.withValues(alpha: 0.25),
            side: BorderSide(
              color: isSelected ? group.color : OneRepColors.surfaceHighest,
            ),
            labelStyle: TextStyle(
              color: isSelected
                  ? OneRepColors.textPrimary
                  : OneRepColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) => setState(() {
              _group = isSelected ? null : group;
              // Changing group abandons any muscle narrowed within the old one.
              _muscle = null;
            }),
          );
        },
      ),
    );
  }

  Widget _buildSection(ExerciseSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Text(
            section.title.toUpperCase(),
            style: const TextStyle(
              color: OneRepColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        for (final entry in section.exercises)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ExerciseListTile(
              entry: entry,
              trailingLabel: widget.trailingLabels[entry.id],
              onTap: () => _pick(entry),
            ),
          ),
      ],
    );
  }

  void _pick(ExerciseWithMuscles entry) =>
      Navigator.pop(context, entry.exercise);
}

// ---------------------------------------------------------------------------
// Recently used
// ---------------------------------------------------------------------------

/// The exercises logged most recently, so a repeat session is a single tap.
class _RecentRow extends ConsumerWidget {
  final List<ExerciseWithMuscles> pool;
  final ValueChanged<ExerciseWithMuscles> onPick;

  const _RecentRow({required this.pool, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(watchRecentExerciseIdsProvider());

    final recentIds = recentAsync.valueOrNull ?? const <int>[];
    if (recentIds.isEmpty) return const SizedBox.shrink();

    final byId = {for (final entry in pool) entry.id: entry};
    final recent = [
      for (final id in recentIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'RECENT',
            style: TextStyle(
              color: OneRepColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entry = recent[index];
              final color = entry.color;
              return GestureDetector(
                onTap: () => onPick(entry),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: OneRepColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: color, width: 3)),
                  ),
                  child: Text(
                    entry.name,
                    style: const TextStyle(
                      color: OneRepColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Small pieces
// ---------------------------------------------------------------------------

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: OneRepColors.surfaceHighest,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: OneRepColors.textDisabled, size: 40),
            SizedBox(height: 12),
            Text(
              'No exercises match.',
              style: TextStyle(color: OneRepColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
