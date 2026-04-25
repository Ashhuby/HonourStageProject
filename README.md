# OneRep — Strength Tracker

A Flutter fitness application for tracking personal bests, workout splits, and strength progression. Built as a final-year honours dissertation project.

---

## Architecture

OneRep follows a feature-first folder structure with an offline-first data layer.

```
lib/
├── core/
│   ├── database/          # Drift SQLite schema and provider
│   ├── notifications/     # Local notification service
│   ├── sync/              # Supabase sync service and background worker
│   ├── theme/             # Colour palette and Material theme
│   └── utils/             # Shared utilities (date formatting)
└── features/
    ├── auth/              # Supabase auth — repository, providers, screens
    ├── profile/           # User profile (bodyweight, sex) via SharedPreferences
    └── workout/
        ├── data/          # Repositories, badge service, strength standards
        └── presentation/  # Screens: splits, session, progress, badges, exercises
```

**State management:** Riverpod (code-generation via `@riverpod`)

**Local database:** Drift (SQLite) — all data is written locally first, synced later

**Remote database:** Supabase (PostgreSQL with Row Level Security)

**Sync strategy:** Dirty-flag pattern — every table has `syncedAt` and `deletedAt` columns. Records with `syncedAt = null` are uploaded on manual sync or periodic background task. Deletes are soft-deleted locally and propagated upstream.

---

## Setup

### Prerequisites

- Flutter 3.x SDK
- Dart 3.x
- A [Supabase](https://supabase.com) project with the schema applied

### Environment

Create a `dart_defines.env` file at the project root:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

This file is `.gitignore`d and must never be committed.

### Install dependencies

```bash
flutter pub get
```

### Regenerate code (after schema changes only)

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Running the app

```bash
flutter run --dart-define-from-file=dart_defines.env
```

---

## Running tests

```bash
flutter test
```

The test suite covers the repository layer, badge service, sync service, and strength standards calculations. All tests run against an in-memory SQLite database — no network required.

---

## Building a release

### Android APK (sideload)

```bash
flutter build apk --dart-define-from-file=dart_defines.env
```

### Android App Bundle (Play Store)

```bash
flutter build appbundle --dart-define-from-file=dart_defines.env
```

The AAB is output to `build/app/outputs/bundle/release/app-release.aab`.

---

## Key design decisions

**Metric types.** Exercises are categorised as `weightReps`, `bodyweightReps`, `timeOnly`, or `distanceTime`. This drives which fields are shown in the set logger, how personal bests are compared, and how PR banners display results.

**Personal best model.** One PR row per exercise is maintained via an upsert conflict target on `(exerciseId, reps)`. For non-rep-based exercises, `reps = 0` acts as a sentinel slot, so the unique constraint still holds without a schema change.

**Strength percentiles.** Population data from [Strengthlevel.com](https://strengthlevel.com) is embedded as lookup tables in `strength_standards_data.dart`. Percentile is interpolated linearly between the nearest bodyweight brackets. Requires the user to set bodyweight and sex in their profile.

**Background sync.** Workmanager schedules a weekly background task that initialises Supabase in a separate isolate and uploads dirty records. The isolate cannot use Flutter bindings, so all dependencies are manually constructed.