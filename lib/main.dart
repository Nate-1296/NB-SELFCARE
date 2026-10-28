import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // La app está en español: cifras y fechas con su formato ("82,5", "2.500").
  Intl.defaultLocale = 'es';

  runApp(
    const ProviderScope(
      child: NbSelfcareApp(),
    ),
  );
}
