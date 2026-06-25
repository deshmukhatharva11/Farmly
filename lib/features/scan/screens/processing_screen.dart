import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/providers.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key});
  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> with TickerProviderStateMixin {
  bool _cancelled = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _runDetection();
  }

  Future<void> _runDetection() async {
    final imagePath = ref.read(selectedImagePathProvider);
    if (imagePath == null || imagePath.isEmpty) {
      setState(() { _hasError = true; _errorMessage = 'No image selected.'; });
      return;
    }

    final service = ref.read(newDetectionServiceProvider);

    try {
      // Step 1: Validating
      ref.read(detectionStepProvider.notifier).state = 0;
      await Future.delayed(const Duration(milliseconds: 300));
      if (_cancelled) return;

      // Step 2: Uploading & detecting leaf
      ref.read(detectionStepProvider.notifier).state = 1;
      await Future.delayed(const Duration(milliseconds: 200));
      if (_cancelled) return;

      // Step 3: Actually call the API (leaf + disease)
      ref.read(detectionStepProvider.notifier).state = 2;
      final result = await service.detectLeafAndDisease(imagePath);
      if (_cancelled) return;

      // Step 4: Preparing results
      ref.read(detectionStepProvider.notifier).state = 3;
      await Future.delayed(const Duration(milliseconds: 400));
      if (_cancelled) return;

      // Store result and navigate
      ref.read(leafDetectionResultProvider.notifier).state = result;

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/new-result');
      }
    } catch (e) {
      if (_cancelled) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(detectionStepProvider);

    final steps = [
      {'icon': Icons.verified_user_rounded, 'label': 'Checking image quality...'},
      {'icon': Icons.upload_rounded, 'label': 'Uploading & scanning...'},
      {'icon': Icons.search_rounded, 'label': 'Detecting crop leaf & disease...'},
      {'icon': Icons.check_circle_rounded, 'label': 'Preparing results...'},
    ];
    final stepLabels = ['Validate', 'Upload', 'Analyze', 'Done'];

    if (_hasError) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
              AppColors.error.withValues(alpha: 0.02), AppColors.surfaceContainerLowest,
            ]),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.error.withValues(alpha: 0.1),
                  ),
                  child: const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(height: 24),
                Text('Detection Failed', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(_errorMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant, height: 1.5),
                  textAlign: TextAlign.center),
                const SizedBox(height: 32),
                Row(children: [
                  Expanded(child: SizedBox(height: 52, child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                  ))),
                  const SizedBox(width: 12),
                  Expanded(child: SizedBox(height: 52, child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() { _hasError = false; _errorMessage = ''; });
                      _runDetection();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ))),
                ]),
              ]),
            ),
          ),
        ),
      );
    }

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
                child: Icon(steps[currentStep.clamp(0, 3)]['icon'] as IconData, size: 48, color: Colors.white),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1.seconds),
            ]),
            const SizedBox(height: 48),
            Text('Analyzing Crop', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))
                .animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                steps[currentStep.clamp(0, 3)]['label'] as String,
                key: ValueKey(currentStep),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 32),
            // Step indicators (Modern Animated Pills)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: List.generate(4, (i) {
                  final isActive = i <= currentStep;
                  final isCurrent = i == currentStep;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? AppColors.heroGradient
                          : LinearGradient(colors: [
                              AppColors.outlineVariant.withValues(alpha: 0.2),
                              AppColors.outlineVariant.withValues(alpha: 0.1),
                            ]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                      border: Border.all(
                        color: isActive ? Colors.transparent : AppColors.outlineVariant.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive && !isCurrent)
                          const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white)
                        else if (isCurrent)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(Icons.radio_button_unchecked_rounded, size: 18, color: AppColors.onSurfaceVariant),
                        
                        const SizedBox(width: 8),
                        Text(
                          stepLabels[i],
                          style: TextStyle(
                            color: isActive ? Colors.white : AppColors.onSurfaceVariant,
                            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ).animate(target: isCurrent ? 1 : 0)
                   .scale(end: const Offset(1.08, 1.08), duration: 400.ms, curve: Curves.easeOutBack)
                   .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.3));
                }),
              ),
            ),
            const Spacer(flex: 2),
            // Cancel button
            TextButton.icon(
              onPressed: () {
                _cancelled = true;
                Navigator.pop(context);
              },
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(foregroundColor: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}
