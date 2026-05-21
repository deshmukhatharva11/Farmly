import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';
import 'package:farmly/core/providers.dart';
import 'package:farmly/models/detection_result.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});
  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _isSaving = false;
  bool _isSaved = false;

  Future<void> _saveScanToDb() async {
    final results = ref.read(detectionResultProvider);
    if (results == null || results.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    final result = results.first;
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.saveScan(
        detectedDisease: result.label,
        detectedDiseaseMr: result.labelMarathi,
        detectedDiseaseHi: result.labelHindi,
        confidence: result.confidence,
        severity: result.severity,
        treatmentsJson: jsonEncode(result.treatments.map((t) => {'title': t.title, 'title_mr': t.titleMarathi, 'description': t.description, 'icon': t.icon}).toList()),
        explanation: result.explanation.isNotEmpty ? result.explanation : result.fullDescription,
        causesJson: jsonEncode(result.causes),
        preventionJson: jsonEncode(result.prevention),
        cropType: 'Rice',
      );
      if (!response.containsKey('error')) {
        ref.invalidate(scanHistoryApiProvider);
        setState(() { _isSaved = true; _isSaving = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate('diagnosis_saved')), backgroundColor: AppColors.primary));
      } else {
        setState(() => _isSaving = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${response['error']}'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate('connection_error')), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(detectionResultProvider);
    final locale = ref.watch(localeProvider);
    final imagePath = ref.watch(selectedImagePathProvider);

    if (results == null || results.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.translate('detection_result'))),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off, size: 64, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(l10n.translate('no_results'), style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: () => Navigator.popUntil(context, (r) => r.settings.name == '/home' || r.isFirst), icon: const Icon(Icons.home), label: Text(l10n.translate('go_home'))),
        ])),
      );
    }

    final result = results.first;
    final diseaseName = locale.languageCode == 'mr' ? result.labelMarathi : locale.languageCode == 'hi' ? result.labelHindi : result.label;

    Color sevColor() {
      switch (result.severity.toLowerCase()) {
        case 'critical': return AppColors.error;
        case 'high': return const Color(0xFFE65100);
        case 'medium': return AppColors.tertiary;
        default: return AppColors.primary;
      }
    }

    Color confColor() {
      if (result.confidence > 0.80) return AppColors.primary;
      if (result.confidence > 0.65) return AppColors.tertiary;
      return AppColors.error;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('detection_result')),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.popUntil(context, (r) => r.settings.name == '/home' || r.isFirst)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),

          // Healthy celebration or image
          if (result.isHealthy)
            _HealthyCelebration(l10n: l10n)
          else
            _buildImageWithBox(result, imagePath, diseaseName),
          const SizedBox(height: 20),

          // Low confidence warning
          if (result.isLowConfidence && !result.isHealthy)
            Container(
              width: double.infinity, margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.tertiary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.2))),
              child: Row(children: [
                Icon(Icons.info_outline, size: 20, color: AppColors.tertiary),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.translate('retake_suggestion'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.tertiary))),
              ]),
            ).animate().fadeIn(duration: 300.ms),

          // Disease name + confidence
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(diseaseName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: sevColor().withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${l10n.translate('severity')}: ${l10n.translate(result.severity.toLowerCase())}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: sevColor(), fontWeight: FontWeight.w600)),
              ),
            ])),
            CircularPercentIndicator(
              radius: 40, lineWidth: 8, percent: result.confidence.clamp(0.0, 1.0),
              center: Text('${(result.confidence * 100).toInt()}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: confColor())),
              progressColor: confColor(), backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.3), circularStrokeCap: CircularStrokeCap.round,
            ),
          ]).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: 16),

          // Save button
          _buildSaveButton(l10n),
          const SizedBox(height: 24),

          // AI Explanation
          if (result.explanation.isNotEmpty) ...[
            _SectionHeader(icon: Icons.psychology_rounded, title: l10n.translate('ai_analysis')),
            const SizedBox(height: 8),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.primaryFixed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))),
              child: Text(result.explanation, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
            const SizedBox(height: 24),
          ],

          // Causes
          if (result.causes.isNotEmpty) ...[
            _SectionHeader(icon: Icons.warning_amber_rounded, title: l10n.translate('causes')),
            const SizedBox(height: 12),
            ...result.causes.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 7), decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value, style: Theme.of(context).textTheme.bodyMedium)),
              ]),
            ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: 350 + e.key * 80))),
            const SizedBox(height: 24),
          ],

          // Treatments
          if (result.treatments.isNotEmpty) ...[
            _SectionHeader(icon: Icons.medical_services_rounded, title: l10n.translate('treatment')),
            const SizedBox(height: 12),
            ...result.treatments.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              final title = locale.languageCode == 'mr' ? t.titleMarathi : locale.languageCode == 'hi' ? t.titleHindi : t.title;
              final desc = locale.languageCode == 'mr' ? t.descriptionMarathi : locale.languageCode == 'hi' ? t.descriptionHindi : t.description;
              return Container(
                margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
                  ])),
                ]),
              ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: 400 + i * 100)).slideX(begin: 0.1);
            }),
            const SizedBox(height: 24),
          ],

          // Prevention
          if (result.prevention.isNotEmpty) ...[
            _SectionHeader(icon: Icons.shield_rounded, title: l10n.translate('prevention')),
            const SizedBox(height: 12),
            ...result.prevention.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check_circle_outline, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value, style: Theme.of(context).textTheme.bodyMedium)),
              ]),
            ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: 500 + e.key * 80))),
            const SizedBox(height: 24),
          ],

          // New advisory sections
          if (result.sprayTiming.isNotEmpty)
            _AdvisoryTile(icon: Icons.timer_outlined, title: l10n.translate('spray_timing'), content: result.sprayTiming),
          if (result.diseaseSpreadRisk.isNotEmpty)
            _AdvisoryTile(icon: Icons.bug_report_outlined, title: l10n.translate('disease_spread_risk'), content: result.diseaseSpreadRisk),
          if (result.next7DayCare.isNotEmpty)
            _AdvisoryTile(icon: Icons.calendar_today_rounded, title: l10n.translate('next_7_day_care'), content: result.next7DayCare),
          if (result.wateringAdvice.isNotEmpty)
            _AdvisoryTile(icon: Icons.water_drop_outlined, title: l10n.translate('watering_advice'), content: result.wateringAdvice),
          if (result.fertilizerCaution.isNotEmpty)
            _AdvisoryTile(icon: Icons.science_outlined, title: l10n.translate('fertilizer_caution'), content: result.fertilizerCaution),
          if (result.medicineAvailability.isNotEmpty)
            _AdvisoryTile(icon: Icons.local_pharmacy_outlined, title: l10n.translate('medicine_availability'), content: result.medicineAvailability),

          // Action buttons
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: SizedBox(height: 56, child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/disease-detail', arguments: result.label),
              icon: const Icon(Icons.info_outline), label: Text(l10n.translate('view_details')),
            ))),
            const SizedBox(width: 12),
            Expanded(child: SizedBox(height: 56, child: OutlinedButton.icon(
              onPressed: () { Navigator.popUntil(context, (r) => r.settings.name == '/home' || r.isFirst); Navigator.pushNamed(context, '/scan'); },
              icon: const Icon(Icons.camera_alt), label: Text(l10n.translate('scan_again')),
            ))),
          ]).animate().fadeIn(duration: 400.ms, delay: 600.ms).slideY(begin: 0.2),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _buildSaveButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: _isSaved
          ? Container(
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: 20), const SizedBox(width: 8),
                Text(l10n.translate('diagnosis_saved'), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ]),
            )
          : OutlinedButton.icon(
              onPressed: _isSaving ? null : _saveScanToDb,
              icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bookmark_add_outlined),
              label: Text(_isSaving ? l10n.translate('saving') : l10n.translate('save_diagnosis')),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
    ).animate().fadeIn(duration: 400.ms, delay: 250.ms);
  }

  Widget _buildImageWithBox(DetectionResult result, String? imagePath, String diseaseName) {
    Widget imageWidget;
    if (imagePath != null && imagePath.isNotEmpty) {
      if (kIsWeb) {
        if (imagePath.startsWith('data:')) {
          imageWidget = Image.memory(base64Decode(imagePath.split(',').last), fit: BoxFit.cover, width: double.infinity, height: 240);
        } else {
          imageWidget = Image.network(imagePath, fit: BoxFit.cover, width: double.infinity, height: 240, errorBuilder: (_, __, ___) => _imagePlaceholder());
        }
      } else {
        imageWidget = Image.file(File(imagePath), fit: BoxFit.cover, width: double.infinity, height: 240, errorBuilder: (_, __, ___) => _imagePlaceholder());
      }
    } else {
      imageWidget = _imagePlaceholder();
    }

    return Container(
      width: double.infinity, height: 240,
      decoration: BoxDecoration(color: AppColors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        imageWidget,
        Positioned(left: 12, top: 12, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_rounded, color: Colors.white, size: 14), const SizedBox(width: 4),
            Text(diseaseName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ).animate().fadeIn(duration: 600.ms, delay: 400.ms)),
        Positioned(right: 12, top: 12, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
          child: Text('${(result.confidence * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ).animate().fadeIn(duration: 600.ms, delay: 400.ms)),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity, height: 240, color: AppColors.surfaceContainerHighest,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.eco_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Text('Rice Leaf Image', style: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5))),
      ]),
    );
  }
}

class _HealthyCelebration extends StatelessWidget {
  final AppLocalizations l10n;
  const _HealthyCelebration({required this.l10n});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.primaryContainer.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: [
        const Text('🌿', style: TextStyle(fontSize: 64)).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
        const SizedBox(height: 16),
        Text(l10n.translate('healthy_leaf'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
        const SizedBox(height: 8),
        Text(l10n.translate('no_disease'), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
      ]),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9));
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 22, color: AppColors.primary), const SizedBox(width: 8),
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
    ]).animate().fadeIn(duration: 300.ms);
  }
}

class _AdvisoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  const _AdvisoryTile({required this.icon, required this.title, required this.content});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: AppColors.primary), const SizedBox(width: 8),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        Text(content, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5, color: AppColors.onSurfaceVariant)),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }
}
