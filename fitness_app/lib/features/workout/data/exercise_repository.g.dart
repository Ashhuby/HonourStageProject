// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$watchExercisesHash() => r'2ddb8979c49a81aa4f09697acf635a9c293c828e';

/// See also [watchExercises].
@ProviderFor(watchExercises)
final watchExercisesProvider =
    AutoDisposeStreamProvider<List<Exercise>>.internal(
      watchExercises,
      name: r'watchExercisesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$watchExercisesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WatchExercisesRef = AutoDisposeStreamProviderRef<List<Exercise>>;
String _$exerciseRepositoryHash() =>
    r'ace1c385dafb0fe9250c37790f13034d025db131';

/// See also [ExerciseRepository].
@ProviderFor(ExerciseRepository)
final exerciseRepositoryProvider =
    AutoDisposeNotifierProvider<ExerciseRepository, void>.internal(
      ExerciseRepository.new,
      name: r'exerciseRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$exerciseRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ExerciseRepository = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
