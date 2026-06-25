import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:printing/printing.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/api_config.dart';
import 'package:farmly/core/providers.dart';
import 'package:farmly/models/new_detection_result.dart';
import 'package:farmly/services/report_pdf_generator.dart';

class NewResultScreen extends ConsumerStatefulWidget {
  const NewResultScreen({super.key});
  @override
  ConsumerState<NewResultScreen> createState() => _NewResultScreenState();
}

class _NewResultScreenState extends ConsumerState<NewResultScreen> {
  bool _isGeneratingPdf = false;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _maybeLoadAdvisory();
  }

  void _maybeLoadAdvisory() {
    final data = ref.read(leafDetectionResultProvider);
    if (data == null) return;
    final result = LeafDetectionResult.fromJson(data);
    if (result.isSuccess) {
      if (!_isSaved && !_isSaving && result.diseaseConfidence > 0.4) {
        _saveDiagnosis(result);
      }
      
      if (result.advisory != null) {
        // Use inline advisory from vision pipeline safely outside build phase
        Future.microtask(() {
          ref.read(advisoryResultProvider.notifier).state = result.advisory;
          ref.read(isAdvisoryLoadingProvider.notifier).state = false;
        });
      } else {
        _loadAdvisory(result);
      }
    }
  }

  Future<void> _saveDiagnosis(LeafDetectionResult result) async {
    if (_isSaving || _isSaved) return;
    setState(() => _isSaving = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.saveScan(
        detectedDisease: result.disease,
        confidence: result.diseaseConfidence,
        cropType: result.crop,
        imageUrl: result.originalImageUrl,
      );

      if (!mounted) return;

      if (!response.containsKey('error')) {
        setState(() {
          _isSaved = true;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Saved to Scan History ✅'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _isSaving = false);
        // Silently fail or show warning, user requested non-blocking warning
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Diagnosis result is available, but it could not be saved to your history.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadAdvisory(LeafDetectionResult result) async {
    final lang = ref.read(selectedLanguageProvider);
    ref.read(isAdvisoryLoadingProvider.notifier).state = true;
    ref.read(advisoryResultProvider.notifier).state = null;

    try {
      final service = ref.read(newDetectionServiceProvider);
      final advisory = await service.generateAdvisory(
        crop: result.crop,
        disease: result.disease,
        confidence: result.diseaseConfidence,
        language: lang,
      );
      ref.read(advisoryResultProvider.notifier).state = advisory;
    } catch (_) {}

    ref.read(isAdvisoryLoadingProvider.notifier).state = false;
  }

  Future<void> _translateAdvisory(String newLanguage) async {
    final current = ref.read(advisoryResultProvider);
    if (current == null || current.containsKey('_error')) return;

    ref.read(selectedLanguageProvider.notifier).state = newLanguage;
    ref.read(isAdvisoryLoadingProvider.notifier).state = true;

    try {
      final service = ref.read(newDetectionServiceProvider);
      final translated = await service.translateAdvisory(
        advisory: current,
        language: newLanguage,
      );
      ref.read(advisoryResultProvider.notifier).state = translated;
    } catch (_) {}

    ref.read(isAdvisoryLoadingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(leafDetectionResultProvider);

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analysis Result')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.search_off, size: 64, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('No result available'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.popUntil(context, (r) => r.settings.name == '/home' || r.isFirst),
              icon: const Icon(Icons.home),
              label: const Text('Go Home'),
            ),
          ]),
        ),
      );
    }

    final result = LeafDetectionResult.fromJson(data);

    if (result.isSuccess) return _buildSuccessScreen(result);
    if (result.isUncertain) return _buildUncertainScreen(result);
    if (result.isNoLeaf) return _buildNoLeafScreen(result);
    return _buildInvalidScreen(result);
  }

  // ═══════════════════════════════════════════════════════
  //  SUCCESS SCREEN
  // ═══════════════════════════════════════════════════════
  Widget _buildSuccessScreen(LeafDetectionResult result) {
    final advisory = ref.watch(advisoryResultProvider);
    final isAdvLoading = ref.watch(isAdvisoryLoadingProvider);
    final selectedLang = ref.watch(selectedLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-Based Crop Disease Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.popUntil(context, (r) => r.settings.name == '/home' || r.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),

          // ── Images: Original + Annotated ──
          _buildImageComparison(result),
          const SizedBox(height: 20),

          // ── Crop Detection Info ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.eco_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Crop leaf localized by YOLOv8',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${result.crop} — ${(result.cropConfidence * 100).toStringAsFixed(1)}% confidence',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 16),

          // ── Disease Result ──
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Disease analyzed using a pretrained plant disease classifier',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(result.disease,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ])),
            CircularPercentIndicator(
              radius: 38, lineWidth: 7,
              percent: result.diseaseConfidence.clamp(0.0, 1.0),
              center: Text('${(result.diseaseConfidence * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: result.diseaseConfidence > 0.80 ? AppColors.primary : AppColors.tertiary,
                )),
              progressColor: result.diseaseConfidence > 0.80 ? AppColors.primary : AppColors.tertiary,
              backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.3),
              circularStrokeCap: CircularStrokeCap.round,
            ),
          ]).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: 16),

          // ── Top 3 Predictions ──
          if (result.topPredictions.isNotEmpty)
            _buildTopPredictions(result.topPredictions),
          const SizedBox(height: 20),

          // ── Language Selector ──
          Row(children: [
            Icon(Icons.translate_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Advisory Language:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            ...['English', 'Hindi', 'Marathi'].map((lang) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(lang, style: const TextStyle(fontSize: 12)),
                selected: selectedLang == lang,
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                onSelected: (_) => _translateAdvisory(lang),
                visualDensity: VisualDensity.compact,
              ),
            )),
          ]).animate().fadeIn(duration: 300.ms, delay: 300.ms),
          const SizedBox(height: 16),

          // ── Advisory Section ──
          _SectionHeader(icon: Icons.medical_information_rounded, title: 'AI-Generated Advisory'),
          const SizedBox(height: 8),
          if (isAdvLoading)
            _buildAdvisorySkeleton()
          else if (advisory != null && !advisory.containsKey('_error'))
            _buildAdvisoryContent(AdvisoryResult.fromJson(advisory))
          else if (advisory != null && advisory.containsKey('_error'))
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(14)),
              child: Text('Advisory unavailable: ${advisory['_error']}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onErrorContainer)),
            )
          else
            const SizedBox.shrink(),
          const SizedBox(height: 24),

          // ── Action Buttons ──
          _buildPdfActions(result),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                _resetState();
                Navigator.popUntil(context, (r) => r.settings.name == '/home' || r.isFirst);
                Navigator.pushNamed(context, '/scan');
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Analyze Another Image'),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  UNCERTAIN SCREEN
  // ═══════════════════════════════════════════════════════
  Widget _buildUncertainScreen(LeafDetectionResult result) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Result')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Warning header
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.tertiaryFixed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Icon(Icons.help_outline_rounded, size: 48, color: AppColors.tertiary),
              const SizedBox(height: 12),
              Text('Result needs a clearer image',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700, color: AppColors.tertiary)),
              const SizedBox(height: 8),
              Text(result.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
            ]),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 24),

          // Top 3 predictions
          if (result.topPredictions.isNotEmpty) ...[
            _SectionHeader(icon: Icons.format_list_numbered, title: 'Possible Matches'),
            const SizedBox(height: 12),
            _buildTopPredictions(result.topPredictions),
            const SizedBox(height: 24),
          ],

          // Photo tips
          _buildPhotoTips(),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                _resetState();
                Navigator.popUntil(context, (r) => r.settings.name == '/home' || r.isFirst);
                Navigator.pushNamed(context, '/scan');
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Try Another Image'),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  NO LEAF / INVALID SCREEN
  // ═══════════════════════════════════════════════════════
  Widget _buildNoLeafScreen(LeafDetectionResult result) {
    return _buildRejectionScreen(
      icon: Icons.eco_outlined,
      color: AppColors.tertiary,
      title: 'No Crop Leaf Detected',
      message: result.message,
    );
  }

  Widget _buildInvalidScreen(LeafDetectionResult result) {
    return _buildRejectionScreen(
      icon: Icons.image_not_supported_outlined,
      color: AppColors.error,
      title: 'Image Could Not Be Analyzed',
      message: result.message,
    );
  }

  Widget _buildRejectionScreen({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Result')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 48, color: color),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.onSurfaceVariant, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          _buildPhotoTips(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                _resetState();
                Navigator.popUntil(context, (r) => r.settings.name == '/home' || r.isFirst);
                Navigator.pushNamed(context, '/scan');
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Upload Another Image'),
            ),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  SHARED COMPONENTS
  // ═══════════════════════════════════════════════════════

  Widget _buildImageComparison(LeafDetectionResult result) {
    final baseUrl = ApiConfig.baseUrl;

    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          if (result.originalImageUrl.isNotEmpty)
            Image.network('$baseUrl${result.originalImageUrl}',
              fit: BoxFit.cover, width: double.infinity, height: 200,
              errorBuilder: (_, __, ___) => _imgPlaceholder('Image')),
          Positioned(left: 6, bottom: 6, child: _imageLabel('Uploaded Image')),
        ]),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _imageLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _imgPlaceholder(String label) {
    return Container(
      width: double.infinity, height: 200,
      color: AppColors.surfaceContainerHighest,
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.image_outlined, size: 32, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant.withValues(alpha: 0.5))),
      ])),
    );
  }

  Widget _buildTopPredictions(List<PredictionItem> predictions) {
    return ExpansionTile(
      title: Text('Top ${predictions.length} Predictions',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      initiallyExpanded: false,
      tilePadding: EdgeInsets.zero,
      children: predictions.asMap().entries.map((e) {
        final idx = e.key;
        final pred = e.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: idx == 0 ? AppColors.primaryFixed.withValues(alpha: 0.08) : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: idx == 0 ? AppColors.primary : AppColors.outlineVariant,
              ),
              child: Center(child: Text('${idx + 1}',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(pred.label, style: Theme.of(context).textTheme.bodyMedium)),
            Text('${(pred.confidence * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        );
      }).toList(),
    ).animate().fadeIn(duration: 300.ms, delay: 250.ms);
  }

  Widget _buildAdvisoryContent(AdvisoryResult advisory) {
    if (advisory.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (advisory.summary.isNotEmpty)
        Container(
          width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(advisory.summary, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
        ).animate().fadeIn(duration: 300.ms),
      const SizedBox(height: 16),

      if (advisory.symptoms.isNotEmpty) ...[
        _SectionHeader(icon: Icons.medical_services_outlined, title: 'Symptoms'),
        const SizedBox(height: 8),
        ...advisory.symptoms.map((s) => _bulletItem(s, AppColors.error)),
        const SizedBox(height: 16),
      ],

      if (advisory.possibleCauses.isNotEmpty) ...[
        _SectionHeader(icon: Icons.warning_amber_rounded, title: 'Possible Causes'),
        const SizedBox(height: 8),
        ...advisory.possibleCauses.map((c) => _bulletItem(c, AppColors.tertiary)),
        const SizedBox(height: 16),
      ],

      if (advisory.recommendedActions.isNotEmpty) ...[
        _SectionHeader(icon: Icons.task_alt_rounded, title: 'Recommended Actions'),
        const SizedBox(height: 8),
        ...advisory.recommendedActions.asMap().entries.map((e) =>
          _numberedItem(e.key + 1, e.value, AppColors.primary)),
        const SizedBox(height: 16),
      ],

      if (advisory.prevention.isNotEmpty) ...[
        _SectionHeader(icon: Icons.shield_rounded, title: 'Prevention'),
        const SizedBox(height: 8),
        ...advisory.prevention.map((p) => _bulletItem(p, AppColors.primary)),
        const SizedBox(height: 16),
      ],

      if (advisory.safetyNote.isNotEmpty)
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.tertiaryFixed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 18, color: AppColors.tertiary),
            const SizedBox(width: 8),
            Expanded(child: Text(advisory.safetyNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.tertiary, fontStyle: FontStyle.italic, height: 1.5))),
          ]),
        ).animate().fadeIn(duration: 300.ms),
    ]);
  }

  Widget _buildAdvisorySkeleton() {
    return Column(children: List.generate(4, (i) =>
      Container(
        width: double.infinity, height: 16, margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, delay: Duration(milliseconds: i * 150)),
    ));
  }

  Widget _buildPhotoTips() {
    final tips = [
      {'icon': Icons.wb_sunny_outlined, 'text': 'Take photo in daylight'},
      {'icon': Icons.center_focus_strong, 'text': 'Keep one leaf in focus'},
      {'icon': Icons.contrast, 'text': 'Avoid heavy shadows'},
      {'icon': Icons.flip, 'text': 'Capture both sides if symptoms are visible'},
    ];

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('Photo Tips', style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        ...tips.map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(tip['icon'] as IconData, size: 18, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(tip['text'] as String, style: Theme.of(context).textTheme.bodyMedium),
          ]),
        )),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _bulletItem(String text, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5))),
      ]),
    );
  }

  Widget _numberedItem(int num, String text, Color numColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22, margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(shape: BoxShape.circle, color: numColor.withValues(alpha: 0.1)),
          child: Center(child: Text('$num', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: numColor))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5))),
      ]),
    );
  }

  Widget _buildPdfActions(LeafDetectionResult result) {
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isGeneratingPdf ? null : () => _sharePdf(result),
            icon: _isGeneratingPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(_isGeneratingPdf ? 'Generating...' : 'Share PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        height: 52, width: 52,
        child: OutlinedButton(
          onPressed: _isGeneratingPdf ? null : () => _printPdf(result),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Icon(Icons.print_rounded),
        ),
      ),
    ]).animate().fadeIn(duration: 400.ms, delay: 450.ms);
  }

  Future<void> _sharePdf(LeafDetectionResult result) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final advisoryData = ref.read(advisoryResultProvider);
      final lang = ref.read(selectedLanguageProvider);
      AdvisoryResult? advisory;
      if (advisoryData != null && !advisoryData.containsKey('_error')) {
        advisory = AdvisoryResult.fromJson(advisoryData);
      }

      final pdfBytes = await ReportPdfGenerator.generateReport(
        detection: result,
        advisory: advisory,
        language: lang,
      );

      if (!mounted) return;

      final crop = result.crop.replaceAll(' ', '_').toLowerCase();
      final disease = result.disease.replaceAll(' ', '_').replaceAll('—', '-').toLowerCase();
      
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'farmly_report_${crop}_${disease}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF generation failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }

    if (mounted) setState(() => _isGeneratingPdf = false);
  }

  Future<void> _printPdf(LeafDetectionResult result) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final advisoryData = ref.read(advisoryResultProvider);
      final lang = ref.read(selectedLanguageProvider);
      AdvisoryResult? advisory;
      if (advisoryData != null && !advisoryData.containsKey('_error')) {
        advisory = AdvisoryResult.fromJson(advisoryData);
      }

      final pdfBytes = await ReportPdfGenerator.generateReport(
        detection: result,
        advisory: advisory,
        language: lang,
      );

      if (!mounted) return;

      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }

    if (mounted) setState(() => _isGeneratingPdf = false);
  }

  void _resetState() {
    ref.read(leafDetectionResultProvider.notifier).state = null;
    ref.read(advisoryResultProvider.notifier).state = null;
    ref.read(isAdvisoryLoadingProvider.notifier).state = false;
    ref.read(detectionStepProvider.notifier).state = 0;
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
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    ]).animate().fadeIn(duration: 300.ms);
  }
}
