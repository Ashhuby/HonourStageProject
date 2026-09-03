import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/local_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/exercise_repository.dart';
import '../../data/session_repository.dart';
import 'body_part.dart';
import 'exercise_filter.dart';
import 'exercise_list_tile.dart';

/// Opens the shared exercise picker and resolves to the chosen exercise, or
/// null if the sheet was dismissed.
///
/// Replaces the flat dropdowns and the fixed-height dialog that each screen
/// used to roll for itself. Search, a recently-used row and body-part chips
/// mean the full library is reachable in one or two taps mid-workout.
///
/// [restrictTo] narrows the pool — a routine-backed session passes only the
/// exercises planned for that day. [excludeIds] hides rows entirely, which the
/// routine builder uses so an exercise cannot be added to the same day twice.
/// [trailingLabels] maps exercise id to a right-aligned label, e.g. `3 × 10`.
Future<Exercise?> showExercisePicker(
  BuildContext context, {
  List<Exercise>? restrictTo,
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
        restrictTo: restrictTo,
        excludeIds: excludeIds,
        title: title,
        trailingLabels: trailingLabels,
      ),
    ),
  );
}

class _ExercisePickerSheet extends ConsumerStatefulWidget {
  final List<Exercise>? restrictTo;
  final Set<int> excludeIds;
  final String title;
  final Map<int, String> trailingLabels;

  const _ExercisePickerSheet({
    required this.restrictTo,
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
  BodyPart? _bodyPart;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A restricted pool is already in hand; otherwise stream the library.
    final restrictTo = widget.restrictTo;
    if (restrictTo != null) return _buildSheet(restrictTo);

    final exercisesAsync = ref.watch(watchExercisesProvider);
    return exercisesAsync.when(
      data: _buildSheet,
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) =>
          SizedBox(height: 200, child: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildSheet(List<Exercise> pool) {
    final available = pool
        .where((e) => !widget.excludeIds.contains(e.id))
        .toList();

    final matches = filterExercises(
      pool,
      query: _query,
      bodyPart: _bodyPart,
      excludeIds: widget.excludeIds,
    );
    final sections = groupExercisesByBodyPart(matches);
    final isBrowsing = _query.isEmpty && _bodyPart == null;

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
            _buildBodyPartChips(available),
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

  Widget _buildBodyPartChips(List<Exercise> pool) {
    final counts = countByBodyPart(pool);
    final present = BodyPart.values
        .where((part) => (counts[part] ?? 0) > 0)
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
          final part = present[index];
          final isSelected = _bodyPart == part;
          return FilterChip(
            label: Text(part.label),
            selected: isSelected,
            showCheckmark: false,
            selectedColor: part.color.withValues(alpha: 0.25),
            side: BorderSide(
              color: isSelected ? part.color : OneRepColors.surfaceHighest,
            ),
            labelStyle: TextStyle(
              color: isSelected
                  ? OneRepColors.textPrimary
                  : OneRepColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) =>
                setState(() => _bodyPart = isSelected ? null : part),
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
        for (final exercise in section.exercises)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ExerciseListTile(
              exercise: exercise,
              trailingLabel: widget.trailingLabels[exercise.id],
              onTap: () => _pick(exercise),
            ),
          ),
      ],
    );
  }

  void _pick(Exercise exercise) => Navigator.pop(context, exercise);
}

// ---------------------------------------------------------------------------
// Recently used
// ---------------------------------------------------------------------------

/// The exercises logged most recently, so a repeat session is a single tap.
class _RecentRow extends ConsumerWidget {
  final List<Exercise> pool;
  final ValueChanged<Exercise> onPick;

  const _RecentRow({required this.pool, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(watchRecentExerciseIdsProvider());

    final recentIds = recentAsync.valueOrNull ?? const <int>[];
    if (recentIds.isEmpty) return const SizedBox.shrink();

    final byId = {for (final exercise in pool) exercise.id: exercise};
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
              final exercise = recent[index];
              final color = BodyPart.colorFor(exercise.bodyPart);
              return GestureDetector(
                onTap: () => onPick(exercise),
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
                    exercise.name,
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
