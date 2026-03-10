import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/split_repository.dart';
import 'split_detail_screen.dart';

class SplitListScreen extends ConsumerWidget {
  const SplitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitsAsync = ref.watch(watchSplitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Splits'),
        centerTitle: true,
      ),
      body: splitsAsync.when(
        data: (splits) => splits.isEmpty
            ? const Center(
                child: Text('No splits yet. Create one to get started.'),
              )
            : ListView.builder(
                itemCount: splits.length,
                itemBuilder: (context, index) {
                  final split = splits[index];
                  return Dismissible(
                    key: ValueKey(split.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(splitRepositoryProvider.notifier)
                          .deleteSplit(split.id);
                    },
                    child: ListTile(
                      title: Text(split.name),
                      subtitle: Text(
                        'Created ${_formatDate(split.createdAt)}',
                      ),
                      leading: const CircleAvatar(
                        child: Icon(Icons.calendar_view_week),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SplitDetailScreen(split: split),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSplitDialog(context, ref),
        label: const Text('New Split'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showCreateSplitDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Split'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Split Name',
            hintText: 'e.g. 6-Day PPL',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref
                    .read(splitRepositoryProvider.notifier)
                    .createSplit(nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}