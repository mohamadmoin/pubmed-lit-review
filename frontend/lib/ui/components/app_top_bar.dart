import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/constants/app_colors.dart';

/// Top app bar for LitReview — documents hub and logout.
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
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        if (auth.username != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                auth.username!,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await auth.logout();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            }
          },
        ),
      ],
    );
  }
}
