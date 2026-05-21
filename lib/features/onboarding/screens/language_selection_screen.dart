import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';
import 'package:farmly/core/providers.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLocale = ref.watch(localeProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      // Logo
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(Icons.eco, color: Colors.white, size: 52),
                      ).animate().scale(
                            duration: 600.ms,
                            curve: Curves.elasticOut,
                          ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome to Farmly',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3),
                      const SizedBox(height: 8),
                      Text(
                        'भाषा निवडा / Choose your language',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                      const SizedBox(height: 36),
                      // Language options
                      _LanguageCard(
                        language: 'मराठी',
                        subtitle: 'Marathi',
                        icon: '🇮🇳',
                        isSelected: selectedLocale.languageCode == 'mr',
                        onTap: () => ref.read(localeProvider.notifier).state = const Locale('mr'),
                        delay: 300,
                      ),
                      const SizedBox(height: 12),
                      _LanguageCard(
                        language: 'हिंदी',
                        subtitle: 'Hindi',
                        icon: '🇮🇳',
                        isSelected: selectedLocale.languageCode == 'hi',
                        onTap: () => ref.read(localeProvider.notifier).state = const Locale('hi'),
                        delay: 400,
                      ),
                      const SizedBox(height: 12),
                      _LanguageCard(
                        language: 'English',
                        subtitle: 'English',
                        icon: '🌐',
                        isSelected: selectedLocale.languageCode == 'en',
                        onTap: () => ref.read(localeProvider.notifier).state = const Locale('en'),
                        delay: 500,
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      // Continue button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/tutorial');
                          },
                          child: Text(AppLocalizations.of(context).translate('continue_btn')),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 600.ms).slideY(begin: 0.5),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String language;
  final String subtitle;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int delay;

  const _LanguageCard({
    required this.language,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.15) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.primary : AppColors.onSurface,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const Spacer(),
            if (isSelected)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 18),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: delay)).slideX(begin: 0.2);
  }
}
