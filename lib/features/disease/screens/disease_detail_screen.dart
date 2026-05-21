import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';
import 'package:farmly/core/providers.dart';

/// Disease Detail Screen
/// Uses real Gemini AI advice from detection result when available,
/// falls back to the disease name display otherwise.
class DiseaseDetailScreen extends ConsumerWidget {
  final String diseaseName;

  const DiseaseDetailScreen({super.key, required this.diseaseName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final results = ref.watch(detectionResultProvider);

    // Get the detection result that matches this disease
    final result = results?.isNotEmpty == true ? results!.first : null;

    String getName() {
      if (result == null) return diseaseName;
      return locale.languageCode == 'mr'
          ? result.labelMarathi
          : locale.languageCode == 'hi'
              ? result.labelHindi
              : result.label;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(getName()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Disease header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.error.withValues(alpha: 0.08),
                    AppColors.tertiary.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.12)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.bug_report_rounded, size: 36, color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                  Text(getName(), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Crop: Rice 🌾',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (result != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _InfoChip(
                          label: '${l10n.translate('severity')}: ${result.severity}',
                          color: _severityColor(result.severity),
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          label: '${(result.confidence * 100).toInt()}% confidence',
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 24),

            // Full Description (detailed paragraph)
            if (result != null && result.fullDescription.isNotEmpty) ...[
              _SectionHeader(icon: Icons.description_rounded, title: l10n.translate('description')),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.12)),
                ),
                child: Text(
                  result.fullDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 80.ms),
              const SizedBox(height: 24),
            ],

            // AI Explanation (Plantix Says)
            if (result != null && result.explanation.isNotEmpty) ...[
              _SectionHeader(icon: Icons.psychology_rounded, title: l10n.translate('ai_analysis')),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        result.explanation,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(height: 24),
            ],

            // Causes
            if (result != null && result.causes.isNotEmpty) ...[
              _SectionHeader(icon: Icons.warning_amber_rounded, title: l10n.translate('causes')),
              const SizedBox(height: 12),
              ...result.causes.asMap().entries.map((e) => _BulletItem(
                    text: e.value,
                    icon: Icons.arrow_right_rounded,
                    color: AppColors.error,
                    delay: 200 + e.key * 80,
                  )),
              const SizedBox(height: 24),
            ],

            // Treatments (from Gemini)
            if (result != null && result.treatments.isNotEmpty) ...[
              _SectionHeader(icon: Icons.medical_services_outlined, title: l10n.translate('treatment_methods')),
              const SizedBox(height: 12),
              ...result.treatments.asMap().entries.map((e) {
                final t = e.value;
                final title = locale.languageCode == 'mr'
                    ? t.titleMarathi
                    : locale.languageCode == 'hi'
                        ? t.titleHindi
                        : t.title;
                final desc = locale.languageCode == 'mr'
                    ? t.descriptionMarathi
                    : locale.languageCode == 'hi'
                        ? t.descriptionHindi
                        : t.description;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(desc, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: 300 + e.key * 100)).slideX(begin: 0.1);
              }),
              const SizedBox(height: 24),
            ],

            // Prevention
            if (result != null && result.prevention.isNotEmpty) ...[
              _SectionHeader(icon: Icons.shield_outlined, title: l10n.translate('prevention')),
              const SizedBox(height: 12),
              ...result.prevention.asMap().entries.map((e) => _BulletItem(
                    text: e.value,
                    icon: Icons.check_circle_outline,
                    color: AppColors.primary,
                    delay: 400 + e.key * 80,
                  )),
              const SizedBox(height: 24),
            ],

            // Medicine Availability
            if (result != null && result.medicineAvailability.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🏪', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Where to Buy', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            result.medicineAvailability,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 550.ms),
              const SizedBox(height: 16),
            ],

            // Tips section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.tertiary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick Tip', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          'Visit your nearest Krishi Vigyan Kendra (KVK) for soil testing and personalized advice for your farm.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppColors.error;
      case 'high':
        return const Color(0xFFE65100);
      case 'medium':
        return AppColors.tertiary;
      default:
        return AppColors.primary;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final int delay;

  const _BulletItem({required this.text, required this.icon, required this.color, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: delay)).slideX(begin: 0.05);
  }
}
