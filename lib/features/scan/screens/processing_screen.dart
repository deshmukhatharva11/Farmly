import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});
  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> with TickerProviderStateMixin {
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _advanceSteps();
  }

  void _advanceSteps() async {
    for (int i = 0; i < 4; i++) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() => _currentStep = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [
      {'icon': Icons.verified_user_rounded, 'label': l10n.translate('validating')},
      {'icon': Icons.upload_rounded, 'label': l10n.translate('uploading_image')},
      {'icon': Icons.search_rounded, 'label': l10n.translate('analyzing_crop')},
      {'icon': Icons.check_circle_rounded, 'label': l10n.translate('preparing_results')},
    ];
    final stepLabels = [l10n.translate('upload'), l10n.translate('analyze'), l10n.translate('identify'), l10n.translate('done')];

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
            AppColors.primary.withValues(alpha: 0.02), AppColors.surfaceContainerLowest,
          ]),
        ),
        child: SafeArea(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Spacer(flex: 2),
            Stack(alignment: Alignment.center, children: [
              Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.05)))
                  .animate(onPlay: (c) => c.repeat())
                  .scale(begin: const Offset(1, 1), end: const Offset(1.6, 1.6), duration: 1500.ms)
                  .fadeOut(duration: 1500.ms),
              Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.08)))
                  .animate(onPlay: (c) => c.repeat())
                  .scale(begin: const Offset(1, 1), end: const Offset(1.35, 1.35), duration: 1500.ms, delay: 300.ms)
                  .fadeOut(duration: 1500.ms, delay: 300.ms),
              Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, gradient: AppColors.primaryGradient,
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 8))],
                ),
                child: Icon(steps[_currentStep]['icon'] as IconData, size: 48, color: Colors.white),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1.seconds),
            ]),
            const SizedBox(height: 48),
            Text(l10n.translate('analyzing'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))
                .animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                steps[_currentStep]['label'] as String,
                key: ValueKey(_currentStep),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final isActive = i <= _currentStep;
                  final isCurrent = i == _currentStep;
                  return Expanded(child: Row(children: [
                    Container(
                      width: isCurrent ? 12 : 10, height: isCurrent ? 12 : 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? AppColors.primary : AppColors.outlineVariant,
                        boxShadow: isCurrent ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8)] : null,
                      ),
                    ),
                    if (i < 3) Expanded(child: Container(height: 2, color: i < _currentStep ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.3))),
                  ]));
                }),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: stepLabels.map((label) => Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant))).toList(),
              ),
            ),
            const Spacer(flex: 2),
            const Text('🌿', style: TextStyle(fontSize: 32)).animate(onPlay: (c) => c.repeat(reverse: true)).rotate(duration: 2.seconds),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}
