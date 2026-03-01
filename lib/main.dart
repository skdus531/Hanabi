import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishKey = String.fromEnvironment('SUPABASE_PUBLISH_KEY');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final supabaseKey =
      supabasePublishKey.isNotEmpty ? supabasePublishKey : supabaseAnonKey;
  assert(
    supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty,
    'Provide SUPABASE_URL and SUPABASE_PUBLISH_KEY (or SUPABASE_ANON_KEY) via --dart-define.',
  );
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );
  runApp(const ProviderScope(child: HanabiApp()));
}
