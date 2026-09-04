flutter run -d windows --dart-define-from-file=dart_defines.env.

flutter run --dart-define-from-file=dart_defines.env -d 36201JEHN13024

flutter build apk --release --dart-define-from-file=dart_defines.env
adb install -r build/app/outputs/flutter-apk/app-release.apk