import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'core/localization/app_localizations.dart';
import 'features/home/screens/home_screen.dart';
import 'features/weather/screens/weather_dashboard_screen.dart';
import 'features/community/screens/community_screen.dart';
import 'features/profile/screens/profile_screen.dart';

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final l10n = AppLocalizations.of(context);

    final screens = const [
      HomeScreen(),
      WeatherDashboardScreen(),
      SizedBox(), // Scan placeholder
      CommunityScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          boxShadow: [BoxShadow(color: AppColors.onSurface.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _NavItem(icon: Icons.home_rounded, label: l10n.translate('home'), isSelected: currentIndex == 0, onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 0),
              _NavItem(icon: Icons.wb_sunny_rounded, label: l10n.translate('weather'), isSelected: currentIndex == 1, onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 1),
              _NavItem(icon: Icons.camera_alt_rounded, label: l10n.translate('scan'), isSelected: false, isPrimary: true, onTap: () => Navigator.pushNamed(context, '/scan')),
              _NavItem(icon: Icons.people_rounded, label: l10n.translate('community'), isSelected: currentIndex == 3, onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 3),
              _NavItem(icon: Icons.person_rounded, label: l10n.translate('profile'), isSelected: currentIndex == 4, onTap: () => ref.read(bottomNavIndexProvider.notifier).state = 4),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isPrimary;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.isSelected, this.isPrimary = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant, size: 22),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
