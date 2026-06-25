import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';
import 'package:farmly/core/providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final historyAsync = ref.watch(scanHistoryApiProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('scan_history'))),
      body: historyAsync.when(
        data: (scans) {
          if (scans.isEmpty) {
            return _EmptyHistoryView(l10n: l10n);
          }
          if (scans.length == 1 && scans.first.containsKey('error')) {
            if (scans.first['error'] == 'unauthorized') {
              return Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('Please login to view your scan history', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    icon: const Icon(Icons.login),
                    label: Text('Login'),
                  ),
                ]),
              );
            }
            return _EmptyHistoryView(l10n: l10n);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scans.length,
            itemBuilder: (context, index) {
              final scan = scans[index];
              if (scan.containsKey('error')) return const SizedBox.shrink();

              final diseaseName = locale.languageCode == 'mr'
                  ? (scan['detected_disease_mr'] ?? scan['detected_disease'] ?? '')
                  : locale.languageCode == 'hi'
                      ? (scan['detected_disease_hi'] ?? scan['detected_disease'] ?? '')
                      : (scan['detected_disease'] ?? '');
              final confidence = (scan['confidence'] as num?)?.toDouble() ?? 0.0;
              final severity = scan['severity']?.toString() ?? 'Medium';
              final date = scan['created_at']?.toString() ?? '';

              Color severityColor() {
                switch (severity.toLowerCase()) {
                  case 'critical': return AppColors.error;
                  case 'high': return const Color(0xFFE65100);
                  case 'medium': return AppColors.tertiary;
                  default: return AppColors.primary;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: severityColor().withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      severity.toLowerCase() == 'none' ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: severityColor(),
                    ),
                  ),
                  title: Text(diseaseName.toString(), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: severityColor().withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(l10n.translate(severity.toLowerCase()), style: TextStyle(color: severityColor(), fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text('${(confidence * 100).toInt()}%', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant)),
                    ]),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(_formatDate(date), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ]),
                  trailing: Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
                  onTap: () {
                    // Could navigate to stored result detail
                  },
                ),
              ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: 50 + index * 60)).slideX(begin: 0.05);
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.cloud_off, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(l10n.translate('connection_error'), style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(scanHistoryApiProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.translate('try_again')),
            ),
          ]),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _EmptyHistoryView extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyHistoryView({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.06)),
          child: Icon(Icons.history_rounded, size: 56, color: AppColors.primary.withValues(alpha: 0.3)),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text(l10n.translate('no_scans_yet'), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/scan'),
          icon: const Icon(Icons.camera_alt),
          label: Text(l10n.translate('scan_crop')),
        ),
      ]),
    );
  }
}
