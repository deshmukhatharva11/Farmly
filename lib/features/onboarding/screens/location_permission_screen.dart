import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/providers.dart';

class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends ConsumerState<LocationPermissionScreen> {
  bool _isLoading = false;
  String? _errorMsg;

  Future<void> _requestLocation() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Location services are disabled. Please enable them in settings.';
        });
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _errorMsg = 'Location permission denied. You can enable it later in Profile settings.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Location permission permanently denied. You can enable it in your browser settings.';
        });
        return;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Reverse geocode to get city name
      String locationName = '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = <String>[];
          if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) parts.add(place.administrativeArea!);
          if (parts.isNotEmpty) locationName = parts.join(', ');
        }
      } catch (_) {
        // Keep coordinate-based name
      }

      // Save to providers
      ref.read(userLocationProvider.notifier).state = locationName;
      ref.read(locationEnabledProvider.notifier).state = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Location set: $locationName'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Could not get location. You can set it manually in profile.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Illustration area
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.06),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 64,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.eco, size: 24, color: AppColors.primary.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Icon(Icons.person_rounded, size: 28, color: AppColors.primary.withValues(alpha: 0.8)),
                            const SizedBox(width: 4),
                            Icon(Icons.eco, size: 24, color: AppColors.primary.withValues(alpha: 0.6)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 40),
              // Heading
              Text(
                'Allow location access',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
              const SizedBox(height: 12),
              // Subtext
              Text(
                'To see localized weather, crop tips, and connect with nearby farmers.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
              // Error message
              if (_errorMsg != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(flex: 3),
              // Allow button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _requestLocation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: Text(
                    _isLoading ? 'Detecting location...' : 'Allow',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.2),
              const SizedBox(height: 16),
              // Skip button
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        ref.read(locationEnabledProvider.notifier).state = false;
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                child: Text(
                  'Skip',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
