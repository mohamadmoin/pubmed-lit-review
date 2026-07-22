import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/providers/document_provider.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/connectivity_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
      ],
      child: const LitReviewApp(),
    ),
  );
}
