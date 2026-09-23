import 'package:flutter/material.dart';
import '../profile_screen.dart';
import '../theme/app_theme.dart';

class VeerMitraAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showProfileButton;
  final bool automaticallyImplyLeading;
  final List<Widget>? extraActions;

  const VeerMitraAppBar({
    super.key,
    this.showProfileButton = true,
    this.automaticallyImplyLeading = true,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final isDark = ThemeController.instance.isDarkMode;

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          if (automaticallyImplyLeading && canPop) ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.arrow_back_rounded,
                color: theme.appBarTheme.foregroundColor,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
          ],

          /// Logo Image Asset
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/logo.png',
              width: 26,
              height: 26,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 8),

          /// App Title
          Expanded(
            child: Text(
              'VEER MITRA',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightPrimaryNavy,
              ),
            ),
          ),
        ],
      ),
      actions: [
        ...?extraActions,
        if (showProfileButton)
          IconButton(
            icon: Icon(
              Icons.account_circle_outlined,
              size: 26,
              color: theme.appBarTheme.foregroundColor,
            ),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: theme.dividerColor,
          height: 1,
        ),
      ),
    );
  }
}
