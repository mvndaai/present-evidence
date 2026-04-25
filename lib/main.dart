import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  assert(
    supabaseUrl.isNotEmpty && !supabaseUrl.contains('YOUR_PROJECT'),
    'SUPABASE_URL must be set via --dart-define=SUPABASE_URL=https://...',
  );
  assert(
    supabaseAnonKey.isNotEmpty && !supabaseAnonKey.contains('YOUR_ANON'),
    'SUPABASE_ANON_KEY must be set via --dart-define=SUPABASE_ANON_KEY=...',
  );

  await Supabase.initialize(
    url: supabaseUrl.isEmpty ? 'https://placeholder.supabase.co' : supabaseUrl,
    anonKey: supabaseAnonKey.isEmpty ? 'placeholder' : supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: PresentEvidenceApp(),
    ),
  );
}
