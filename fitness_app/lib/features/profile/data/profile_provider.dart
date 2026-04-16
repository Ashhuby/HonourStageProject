import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitness_app/features/workout/data/strength_standards_data.dart';

part 'profile_provider.g.dart';

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

const _kBodyweight = 'profile_bodyweight';
const _kSex = 'profile_sex';

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class UserProfile {
  final double? bodyweightKg;
  final Sex? sex;

  const UserProfile({this.bodyweightKg, this.sex});

  /// Both fields must be present for percentile features to function.
  bool get isCompleteForPercentile =>
      bodyweightKg != null && bodyweightKg! > 0 && sex != null;

  UserProfile copyWith({double? bodyweightKg, Sex? sex}) {
    return UserProfile(
      bodyweightKg: bodyweightKg ?? this.bodyweightKg,
      sex: sex ?? this.sex,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<UserProfile> build() async {
    final prefs = await SharedPreferences.getInstance();
    final bw = prefs.getDouble(_kBodyweight);
    final sexIndex = prefs.getInt(_kSex);

    return UserProfile(
      bodyweightKg: bw,
      sex: sexIndex != null ? Sex.values[sexIndex] : null,
    );
  }

  Future<void> setBodyweight(double kg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kBodyweight, kg);
    final current = await future;
    state = AsyncData(current.copyWith(bodyweightKg: kg));
  }

  Future<void> setSex(Sex sex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSex, sex.index);
    final current = await future;
    state = AsyncData(current.copyWith(sex: sex));
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBodyweight);
    await prefs.remove(_kSex);
    state = const AsyncData(UserProfile());
  }
}
