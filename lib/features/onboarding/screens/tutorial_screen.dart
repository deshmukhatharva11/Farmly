import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _tutorials = [
    {'icon': Icons.camera_alt_rounded, 'color': AppColors.primary},
    {'icon': Icons.biotech_rounded, 'color': AppColors.tertiary},
    {'icon': Icons.medical_services_rounded, 'color': AppColors.secondary},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Skip button
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/location-permission'),
                            child: Text(l10n.translate('skip')),
                          ),
                        ),
                      ),
                      // Pages
                      Expanded(
                        child: SizedBox(
                          height: 500, // Reasonable height for page content
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) => setState(() => _currentPage = index),
                            itemCount: 3,
                            itemBuilder: (context, index) {
                              return _TutorialPage(
                                icon: _tutorials[index]['icon'] as IconData,
                                color: _tutorials[index]['color'] as Color,
                                title: l10n.translate('tutorial_${index + 1}_title'),
                                description: l10n.translate('tutorial_${index + 1}_desc'),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Dots indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 32 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? AppColors.primary : AppColors.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 40),
                      // Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_currentPage < 2) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              } else {
                                Navigator.pushReplacementNamed(context, '/location-permission');
                              }
                            },
                            child: Text(
                              _currentPage < 2 ? l10n.translate('next') : l10n.translate('get_started'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
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

class _TutorialPage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _TutorialPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: color),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 48),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: 16),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
        ],
      ),
    );
  }
}
