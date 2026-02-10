import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/workout/presentation/exercise_library_screen.dart';

void main() {
  runApp(
    // ProviderScope is the "Engine Room" for Riverpod. 
    // Without this, the app will crash immediately.
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Honour Stage Fitness',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ExerciseLibraryScreen(),
    );
  }
}