import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';

class ScanDetailScreen extends StatelessWidget {
  final Map<String, dynamic> scan;

  const ScanDetailScreen({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Parse fields safely
    final disease = scan['detected_disease'] ?? 'Unknown';
    final diseaseMr = scan['detected_disease_mr'] ?? disease;
    final crop = scan['crop_type'] ?? '';
    final confidence = (scan['confidence'] as num?)?.toDouble() ?? 0.0;
    final severity = scan['severity'] ?? 'Medium';
    final imageUrl = scan['image_url'] as String?;
    final explanation = scan['explanation'] as String? ?? '';
    
    // JSON lists
    List<String> treatments = _parseJsonList(scan['treatments_json']);
    List<String> causes = _parseJsonList(scan['causes_json']);
    List<String> prevention = _parseJsonList(scan['prevention_json']);

    Color severityColor() {
      switch (severity.toString().toLowerCase()) {
        case 'critical': return AppColors.error;
        case 'high': return const Color(0xFFE65100);
        case 'medium': return AppColors.tertiary;
        default: return AppColors.primary;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('scan_details') != 'scan_details' ? l10n.translate('scan_details') : 'Scan Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            if (imageUrl != null && imageUrl.isNotEmpty)
              Container(
                height: 250,
                color: AppColors.surfaceContainerHigh,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                ),
              )
            else
              _buildPlaceholder(),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Disease Title
                  Text(
                    disease,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                  ),
                  if (diseaseMr != disease && diseaseMr.isNotEmpty)
                    Text(
                      diseaseMr,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                    ),
                  const SizedBox(height: 16),

                  // Info Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(Icons.eco, crop.isNotEmpty ? crop : 'Unknown', AppColors.primary),
                      _buildChip(
                        Icons.warning_rounded,
                        'Severity: $severity',
                        severityColor(),
                      ),
                      _buildChip(
                        Icons.analytics,
                        'Confidence: ${(confidence * 100).toInt()}%',
                        Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Summary/Explanation
                  if (explanation.isNotEmpty) ...[
                    _buildSectionTitle(context, 'Analysis Summary'),
                    const SizedBox(height: 8),
                    Text(
                      explanation,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Causes
                  if (causes.isNotEmpty) ...[
                    _buildSectionTitle(context, 'Possible Causes'),
                    const SizedBox(height: 8),
                    _buildList(causes, Icons.search, AppColors.tertiary),
                    const SizedBox(height: 24),
                  ],

                  // Treatments
                  if (treatments.isNotEmpty) ...[
                    _buildSectionTitle(context, 'Recommended Treatments'),
                    const SizedBox(height: 8),
                    _buildList(treatments, Icons.medical_services_outlined, AppColors.error),
                    const SizedBox(height: 24),
                  ],

                  // Prevention
                  if (prevention.isNotEmpty) ...[
                    _buildSectionTitle(context, 'Prevention Strategies'),
                    const SizedBox(height: 8),
                    _buildList(prevention, Icons.shield_outlined, AppColors.primary),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 200,
      color: AppColors.surfaceContainerHigh,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 64,
          color: AppColors.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildList(List<String> items, IconData icon, Color color) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(height: 1.5, fontSize: 15),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<String> _parseJsonList(dynamic source) {
    if (source == null) return [];
    if (source is String) {
      if (source.isEmpty || source == '[]') return [];
      try {
        final decoded = jsonDecode(source);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return [source];
      }
    }
    if (source is List) return source.map((e) => e.toString()).toList();
    return [];
  }
}
