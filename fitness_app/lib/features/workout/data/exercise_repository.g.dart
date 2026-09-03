// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$watchExercisesHash() => r'afdaa7fbb1d0fc600dd0d9e765cb420cf039918c';

/// Every exercise, name-ordered. Unchanged: the session and progress screens
/// only need names and metric types, so they do not pay for the muscle join.
///
/// Copied from [watchExercises].
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
String _$watchExerciseCatalogueHash() =>
    r'75f43417f3913efd5fe4582e75e0b914f989c7ac';

/// Every exercise with the muscles it trains — what the library, the picker
/// and the body map read.
///
/// A *left* outer join, deliberately: an exercise carrying no muscle rows must
/// still appear (under "Unassigned"), not vanish. Drift watches both tables,
/// so editing a muscle row re-emits the catalogue.
///
/// Copied from [watchExerciseCatalogue].
@ProviderFor(watchExerciseCatalogue)
final watchExerciseCatalogueProvider =
    AutoDisposeStreamProvider<List<ExerciseWithMuscles>>.internal(
      watchExerciseCatalogue,
      name: r'watchExerciseCatalogueProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$watchExerciseCatalogueHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WatchExerciseCatalogueRef =
    AutoDisposeStreamProviderRef<List<ExerciseWithMuscles>>;
String _$exerciseRepositoryHash() =>
    r'87173cb5d5f4a6590d4881d018d9eefeeabb9443';

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
