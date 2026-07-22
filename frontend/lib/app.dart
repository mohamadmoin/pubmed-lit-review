import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/theme/theme.dart';
import 'ui/pages/documents/document_generation_page.dart';
import 'ui/pages/documents/document_generation_progress_screen.dart';
import 'ui/pages/documents/document_preview_screen.dart';
import 'ui/pages/documents/document_view_page.dart';
import 'ui/pages/documents/documents_list_page.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/register_screen.dart';

class LitReviewApp extends StatelessWidget {
  const LitReviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    if (authService.isAuthenticated && authService.token != null) {
      ApiService().setAuthToken(authService.token!);
    } else {
      ApiService().clearAuthToken();
    }

    return MaterialApp(
      title: 'LitReview',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: authService.isAuthenticated
          ? const DocumentsListPage()
          : const LoginScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/documents': (_) => const DocumentsListPage(),
        '/document/generate': (_) => const DocumentGenerationPage(),
        '/document/progress': (_) => const DocumentGenerationProgressScreen(),
        '/document': (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments;
          if (args is String) {
            return DocumentViewPage(documentId: args);
          }
          return const DocumentsListPage();
        },
        '/document/preview': (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>?;
          return DocumentPreviewScreen(
            documentId: args?['documentId'] as String? ?? '',
          );
        },
      },
    );
  }
}
