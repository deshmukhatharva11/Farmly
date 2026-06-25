import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';
import 'package:farmly/core/providers.dart';
import 'package:farmly/core/error_handler.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scanAnimController;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _scanAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _scanAnimController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null) {
        ref.read(selectedImagePathProvider.notifier).state = picked.path;
        // Reset previous results
        ref.read(leafDetectionResultProvider.notifier).state = null;
        ref.read(advisoryResultProvider.notifier).state = null;
        ref.read(detectionStepProvider.notifier).state = 0;
        // Navigate to processing (V2 pipeline)
        if (mounted) {
          Navigator.pushNamed(context, '/processing');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getLocalizedMessage(
            'image_invalid', ref.read(localeProvider).languageCode,
          ))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('scan_crop')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(children: [
        // Scan area
        Expanded(
          flex: 3,
          child: _buildScanArea(l10n),
        ),

        // Photo tips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(Icons.lightbulb_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(
                l10n.translate('scan_instruction'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w500,
                ),
              )),
            ]),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: Text(l10n.translate('take_photo')),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: Text(l10n.translate('gallery')),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ]).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.3),
        ),
      ]),
    );
  }

  Widget _buildScanArea(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.eco_rounded, size: 80, color: AppColors.onSurfaceVariant.withValues(alpha: 0.15)),
        AnimatedBuilder(
          animation: _scanAnimController,
          builder: (context, child) => CustomPaint(
            size: const Size(260, 260),
            painter: _ScanOverlayPainter(progress: _scanAnimController.value),
          ),
        ),
        Positioned(
          bottom: 30,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.touch_app_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                l10n.translate('take_photo'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn().then().fadeOut(duration: 2.seconds),
        ),
      ]),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  final double progress;
  _ScanOverlayPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final cornerLength = 40.0;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.width, height: size.height);

    canvas.drawLine(rect.topLeft, Offset(rect.left + cornerLength, rect.top), paint);
    canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + cornerLength), paint);
    canvas.drawLine(rect.topRight, Offset(rect.right - cornerLength, rect.top), paint);
    canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + cornerLength), paint);
    canvas.drawLine(rect.bottomLeft, Offset(rect.left + cornerLength, rect.bottom), paint);
    canvas.drawLine(rect.bottomLeft, Offset(rect.left, rect.bottom - cornerLength), paint);
    canvas.drawLine(rect.bottomRight, Offset(rect.right - cornerLength, rect.bottom), paint);
    canvas.drawLine(rect.bottomRight, Offset(rect.right, rect.bottom - cornerLength), paint);

    final scanPaint = Paint()
      ..shader = LinearGradient(colors: [
        AppColors.primary.withValues(alpha: 0.0),
        AppColors.primary.withValues(alpha: 0.6),
        AppColors.primary.withValues(alpha: 0.0),
      ]).createShader(Rect.fromLTWH(rect.left, 0, rect.width, 4));
    final scanY = rect.top + progress * rect.height;
    canvas.drawLine(Offset(rect.left + 10, scanY), Offset(rect.right - 10, scanY), scanPaint..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) => oldDelegate.progress != progress;
}
