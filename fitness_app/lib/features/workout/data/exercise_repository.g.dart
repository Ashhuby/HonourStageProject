// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$watchExercisesHash() => r'7996c50d964a6ee036191e1dd080e96ccabb51c1';

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
    r'70bebcb6938632098e1662b7c3b22ef094d519b0';

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
