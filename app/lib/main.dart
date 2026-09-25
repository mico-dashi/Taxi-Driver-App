import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config.dart';
import 'services/backend.dart';
import 'services/demo_backend.dart';
import 'services/supabase_backend.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  final Backend backend = AppConfig.isDemo
      ? DemoBackend()
      : await SupabaseBackend.create();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(backend: backend),
      child: const TaxiApp(),
    ),
  );
}
