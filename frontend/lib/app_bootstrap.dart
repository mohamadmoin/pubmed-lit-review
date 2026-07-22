import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/document_provider.dart';
import 'core/services/auth_service.dart';
import 'core/services/api_service.dart';
import 'app.dart';

/// Boots guest auth, then shows the main app.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthService>();
    try {
      await auth.bootstrapAuth().timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('Auth bootstrap failed: $e');
    }

    if (auth.token != null) {
      ApiService().setAuthToken(auth.token!);
    }

    if (mounted) {
      try {
        await context
            .read<DocumentProvider>()
            .loadAllDocuments()
            .timeout(const Duration(seconds: 45));
      } catch (e) {
        debugPrint('Initial document load failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Starting LitReview...'),
                  ],
                ),
              ),
            ),
          );
        }

        return const LitReviewApp();
      },
    );
  }
}
