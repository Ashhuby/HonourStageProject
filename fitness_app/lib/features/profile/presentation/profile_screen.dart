import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../workout/data/strength_standards_data.dart';
import '../data/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _bodyweightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _initialised = false;

  @override
  void dispose() {
    _bodyweightController.dispose();
    super.dispose();
  }

  // Pre-populate the text field once the profile loads.
  // Only runs once — _initialised guards against overwriting in-progress edits.
  void _initialiseFromProfile(UserProfile profile) {
    if (_initialised) return;
    _initialised = true;
    if (profile.bodyweightKg != null) {
      _bodyweightController.text = profile.bodyweightKg!
          .toStringAsFixed(profile.bodyweightKg! % 1 == 0 ? 0 : 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        centerTitle: true,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading profile: $err')),
        data: (profile) {
          _initialiseFromProfile(profile);
          return _buildForm(context, profile);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, UserProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------------------
            // Section: About
            // ----------------------------------------------------------------
            const Text(
              'Your Profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your bodyweight and sex are used to calculate strength '
              'percentiles against population data from Strengthlevel.com. '
              'These fields are optional — percentile benchmarks are hidden '
              'if not provided.',
              style: TextStyle(color: OneRepColors.textSecondary),
            ),
            const SizedBox(height: 32),

            // ----------------------------------------------------------------
            // Section: Bodyweight
            // ----------------------------------------------------------------
            const Text(
              'Bodyweight',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bodyweightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Bodyweight',
                suffixText: 'kg',
                border: OutlineInputBorder(),
                hintText: 'e.g. 80',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null; // optional
                final parsed = double.tryParse(value);
                if (parsed == null) return 'Enter a valid number';
                if (parsed <= 0 || parsed > 500) {
                  return 'Enter a bodyweight between 1 and 500 kg';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // ----------------------------------------------------------------
            // Section: Sex
            // ----------------------------------------------------------------
            const Text(
              'Sex',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Used to select the correct strength standards table.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildSexSelector(profile),
            const SizedBox(height: 40),

            // ----------------------------------------------------------------
            // Save button
            // ----------------------------------------------------------------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _save(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // Clear button — secondary action
            // ----------------------------------------------------------------
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _confirmClear(context),
                child: const Text(
                  'Clear profile data',
                  style: TextStyle(color: OneRepColors.textSecondary),
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // Attribution notice
            // ----------------------------------------------------------------
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Strength percentile data sourced from Strengthlevel.com.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSexSelector(UserProfile profile) {
    return Row(
      children: [
        Expanded(
          child: _SexOption(
            label: 'Male',
            icon: Icons.male,
            selected: profile.sex == Sex.male,
            onTap: () => ref
                .read(profileNotifierProvider.notifier)
                .setSex(Sex.male),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SexOption(
            label: 'Female',
            icon: Icons.female,
            selected: profile.sex == Sex.female,
            onTap: () => ref
                .read(profileNotifierProvider.notifier)
                .setSex(Sex.female),
          ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final text = _bodyweightController.text.trim();
    if (text.isNotEmpty) {
      final kg = double.parse(text);
      await ref.read(profileNotifierProvider.notifier).setBodyweight(kg);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Profile?'),
        content: const Text(
          'This will remove your bodyweight and sex. '
          'Strength percentile benchmarks will be hidden until '
          'you re-enter this information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(profileNotifierProvider.notifier).clearProfile();
      // Reset local form state
      setState(() {
        _bodyweightController.clear();
        _initialised = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile cleared')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Sex selector tile widget
// ---------------------------------------------------------------------------

class _SexOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SexOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}