import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/notifications/notification_service.dart';
import 'core/sync/background_sync.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/workout/presentation/widgets/badge_unlock_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  await NotificationService().init();
  await registerBackgroundSync();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: _App()));
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'One Rep',
      theme: buildAppTheme(),
      // Above the navigator rather than around `home`, so a badge earned
      // mid-set is celebrated over the active session screen — which is a
      // pushed route, and where most badges are actually earned.
      builder: (context, child) => BadgeUnlockHost(child: child!),
      home: const SplashScreen(child: AuthGate()),
    );
  }
}
