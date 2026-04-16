import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/split_repository.dart';
import '../../../core/database/local_database.dart';
import 'split_detail_screen.dart';

class SplitListScreen extends ConsumerWidget {
  const SplitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitsAsync = ref.watch(watchSplitsProvider);

    return Scaffold(
      body: splitsAsync.when(
        data: (splits) => splits.isEmpty
            ? const _EmptyState(
                icon: Icons.view_week_outlined,
                message: 'No splits yet.',
                sub: 'Create a training split to organise your workouts.',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: splits.length,
                itemBuilder: (context, index) {
                  final split = splits[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SplitCard(
                      split: split,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SplitDetailScreen(split: split),
                        ),
                      ),
                      onDelete: () => ref
                          .read(splitRepositoryProvider.notifier)
                          .deleteSplit(split.id),
                    ),
                  );
                },
              ),
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'split_fab',
        onPressed: () => _showCreateSplitDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('NEW SPLIT',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
      ),
    );
  }

  void _showCreateSplitDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    void submit() {
      if (nameController.text.isNotEmpty) {
        ref.read(splitRepositoryProvider.notifier).createSplit(nameController.text);
        Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Split'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Split Name',
            hintText: 'e.g. 6-Day PPL',
          ),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: submit,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Split card — no icon, clean typography
// ---------------------------------------------------------------------------

class _SplitCard extends StatelessWidget {
  final WorkoutSplit split;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SplitCard({
    required this.split,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(split.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: OneRepColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: OneRepColors.error),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: OneRepColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: const Border(
              left: BorderSide(
                color: OneRepColors.gold,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      split.name,
                      style: const TextStyle(
                        color: OneRepColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Created ${formatShortDate(split.createdAt)}',
                      style: const TextStyle(
                        color: OneRepColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: OneRepColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: OneRepColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: OneRepColors.textSecondary, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: OneRepColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: OneRepColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}