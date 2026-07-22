import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_fonts.dart';

/// Top app bar for LitReview — documents hub, sign-in, and logout.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.surface,
      title: Text(
        'LitReview',
        style: AppFonts.inter(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        if (auth.isGuest)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                'Guest',
                style: AppFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else if (auth.username != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                auth.username!,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        if (auth.isGuest)
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            child: const Text('Sign in'),
          )
        else
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                if (AppConfig.autoGuestLogin) {
                  await auth.loginAsGuest();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/documents', (_) => false);
                  }
                } else {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                }
              }
            },
          ),
      ],
    );
  }
}
