import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/workers/background_workers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Deferred registration so startup is not blocked.
  // Errors are logged; the app continues with limited background capability.
  registerBackgroundWorkers().catchError((Object e, StackTrace s) {
    debugPrint('Background worker registration failed: $e\n$s');
  });

  runApp(
    const ProviderScope(
      child: LifeOSApp(),
    ),
  );
}
