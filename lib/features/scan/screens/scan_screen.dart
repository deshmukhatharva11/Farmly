import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';
import 'package:farmly/core/providers.dart';
import 'package:farmly/core/error_handler.dart';
import 'package:farmly/services/detection_service.dart';
import 'package:farmly/models/detection_result.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scanAnimController;
  final _imagePicker = ImagePicker();
  List<String> _selectedImages = [];
  bool _isMultiMode = false;

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
      if (_isMultiMode && source == ImageSource.gallery) {
        final picked = await _imagePicker.pickMultiImage(imageQuality: 80, maxWidth: 1024);
        if (picked.isNotEmpty) {
          setState(() {
            for (final img in picked) {
              if (_selectedImages.length < 5) _selectedImages.add(img.path);
            }
          });
        }
      } else {
        final picked = await _imagePicker.pickImage(source: source, imageQuality: 80, maxWidth: 1024);
        if (picked != null) {
          if (_isMultiMode) {
            setState(() {
              if (_selectedImages.length < 5) _selectedImages.add(picked.path);
            });
          } else {
            ref.read(selectedImagePathProvider.notifier).state = picked.path;
            _startDetection([picked.path]);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getLocalizedMessage('image_invalid', ref.read(localeProvider).languageCode))),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _startDetection(List<String> paths) async {
    ref.read(isDetectingProvider.notifier).state = true;
    if (paths.isNotEmpty) ref.read(selectedImagePathProvider.notifier).state = paths.first;
    Navigator.pushNamed(context, '/processing');

    try {
      final service = ref.read(detectionServiceProvider);
      List<DetectionResult> results;
      if (paths.length > 1) {
        results = await service.detectMulti(paths);
      } else {
        results = await service.detect(paths.first);
      }
      ref.read(detectionResultProvider.notifier).state = results;
      ref.read(isDetectingProvider.notifier).state = false;
      if (mounted) Navigator.pushReplacementNamed(context, '/result');
    } on ValidationException catch (e) {
      ref.read(isDetectingProvider.notifier).state = false;
      ref.read(validationResultProvider.notifier).state = e.validation;
      if (mounted) {
        Navigator.pop(context);
        _showValidationError(e.validation.message);
      }
    } catch (e) {
      try {
        final mockService = MockDetectionService();
        final mockResults = await mockService.detect(paths.first);
        ref.read(detectionResultProvider.notifier).state = mockResults;
        ref.read(isDetectingProvider.notifier).state = false;
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/result');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorHandler.getLocalizedMessage('detection_failed', ref.read(localeProvider).languageCode)),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (_) {
        ref.read(isDetectingProvider.notifier).state = false;
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHandler.getLocalizedMessage('api_error', ref.read(localeProvider).languageCode))),
          );
        }
      }
    }
  }

  void _showValidationError(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.warning_amber_rounded, size: 40, color: AppColors.error),
          ),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.camera_alt),
              label: Text(AppLocalizations.of(context).translate('retake_photo')),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('scan_crop')),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
        // Mode selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Expanded(child: _ModeTab(
                label: l10n.translate('quick_scan'),
                icon: Icons.bolt_rounded,
                isActive: !_isMultiMode,
                onTap: () => setState(() { _isMultiMode = false; _selectedImages.clear(); }),
              )),
              Expanded(child: _ModeTab(
                label: l10n.translate('advanced_scan'),
                icon: Icons.auto_awesome,
                isActive: _isMultiMode,
                onTap: () => setState(() => _isMultiMode = true),
              )),
            ]),
          ),
        ).animate().fadeIn(duration: 300.ms),

        // Image preview area
        Expanded(
          flex: 3,
          child: _isMultiMode && _selectedImages.isNotEmpty
              ? _buildMultiImagePreview()
              : _buildSingleScanArea(l10n),
        ),

        // Multi-image tip
        if (_isMultiMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.lightbulb_outline, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  l10n.translate('multi_scan_tip'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary),
                )),
              ]),
            ),
          ).animate().fadeIn(duration: 400.ms),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_isMultiMode && _selectedImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${_selectedImages.length}/5 ${l10n.translate('images_selected')}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            Row(children: [
              Expanded(
                child: SizedBox(height: 56, child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(l10n.translate('take_photo')),
                )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(height: 56, child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text(l10n.translate('gallery')),
                )),
              ),
            ]).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.3),
            if (_isMultiMode && _selectedImages.length >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _startDetection(_selectedImages),
                    icon: const Icon(Icons.search_rounded),
                    label: Text('${l10n.translate('analyze')} (${_selectedImages.length} ${l10n.translate('images_selected')})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSingleScanArea(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.camera_alt_rounded, size: 80, color: AppColors.onSurfaceVariant.withValues(alpha: 0.2)),
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
            child: Text(
              l10n.translate('scan_instruction'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn().then().fadeOut(duration: 2.seconds),
        ),
      ]),
    );
  }

  Widget _buildMultiImagePreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: _selectedImages.length + (_selectedImages.length < 5 ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _selectedImages.length) {
            return GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_rounded, size: 32, color: AppColors.primary),
                  const SizedBox(height: 4),
                  Text(AppLocalizations.of(context).translate('add_more_images'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
            ).animate().fadeIn(duration: 300.ms);
          }

          return Stack(children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: kIsWeb
                    ? null
                    : DecorationImage(image: FileImage(File(_selectedImages[index])), fit: BoxFit.cover),
              ),
              child: kIsWeb
                  ? Center(child: Icon(Icons.image, size: 40, color: AppColors.primary))
                  : null,
            ),
            Positioned(
              right: 4, top: 4,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: 4, bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ]).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: index * 100)).scale(begin: const Offset(0.8, 0.8));
        },
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: isActive ? Colors.white : AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.onSurfaceVariant,
          )),
        ]),
      ),
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
