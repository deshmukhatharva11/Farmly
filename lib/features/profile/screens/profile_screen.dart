import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';
import 'package:farmly/core/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final scanHistoryAsync = ref.watch(scanHistoryApiProvider);
    final savedDiagnosesAsync = ref.watch(scanHistoryApiProvider);
    final isMarathi = locale.languageCode == 'mr';

    // Fallback profile data
    final fallbackProfile = {
      'name': isMarathi ? 'राजू पाटील' : 'Raju Patil',
      'location': 'Pune, Maharashtra',
      'mobile_number': '',
      'preferred_language': 'mr',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('my_profile')),
        actions: [
          IconButton(
            onPressed: () => _showSettingsDialog(context, ref, l10n),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Profile header - uses API data
            profileAsync.when(
              data: (profile) {
                if (profile.containsKey('error')) {
                  return _buildProfileHeader(context, ref, l10n, isMarathi, fallbackProfile);
                }
                return _buildProfileHeader(context, ref, l10n, isMarathi, profile);
              },
              loading: () => _buildProfileHeader(context, ref, l10n, isMarathi, fallbackProfile),
              error: (_, __) => _buildProfileHeader(context, ref, l10n, isMarathi, fallbackProfile),
            ),
            const SizedBox(height: 28),

            // Scan history from API
            Text(
              l10n.translate('scan_history'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
            const SizedBox(height: 12),
            scanHistoryAsync.when(
              data: (scans) {
                if (scans.isEmpty || (scans.length == 1 && scans.first.containsKey('error'))) {
                  return _buildEmptyHistory(context, isMarathi);
                }
                return Column(
                  children: scans.take(5).toList().asMap().entries.map((entry) {
                    final i = entry.key;
                    final scan = entry.value;
                    return _ApiScanHistoryCard(
                      scan: scan,
                      isMarathi: isMarathi,
                      delay: (300 + i * 100).toInt(),
                    );
                  }).toList(),
                );
              },
              loading: () => _buildEmptyHistory(context, isMarathi),
              error: (_, __) => _buildEmptyHistory(context, isMarathi),
            ),
            const SizedBox(height: 24),

            // Saved diagnoses from API
            Text(
              l10n.translate('saved_diagnoses'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ).animate().fadeIn(duration: 300.ms, delay: 500.ms),
            const SizedBox(height: 12),
            savedDiagnosesAsync.when(
              data: (scans) {
                if (scans.isEmpty || (scans.length == 1 && scans.first.containsKey('error'))) return _buildEmptyDiagnoses(context, isMarathi);
                if (scans.isEmpty) return _buildEmptyDiagnoses(context, isMarathi);
                return Column(
                  children: scans.take(3).map((scan) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bookmark, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMarathi
                                      ? (scan['detected_disease_mr'] ?? scan['detected_disease'] ?? 'Unknown')
                                      : (scan['detected_disease'] ?? 'Unknown'),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${scan['crop_type'] ?? ''} • ${scan['severity'] ?? 'Medium'}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${((scan['confidence'] as double?) != null ? ((scan['confidence'] as double) * 100).toInt() : 0)}%',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => _buildEmptyDiagnoses(context, isMarathi),
              error: (_, __) => _buildEmptyDiagnoses(context, isMarathi),
            ),
            const SizedBox(height: 24),

            // Logout button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  }
                },
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: Text(
                  l10n.translate('guest_login').contains('पाहुणे')
                      ? 'लॉगआउट'
                      : 'Logout',
                  style: TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 700.ms),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    bool isMarathi,
    Map<String, dynamic> profile,
  ) {
    final name = profile['name'] ?? (isMarathi ? 'राजू पाटील' : 'Raju Patil');
    final location = profile['location'] ?? 'Pune, Maharashtra';
    final initial = name.isNotEmpty ? name.substring(0, 1) : 'F';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primaryContainer.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primaryContainer,
            child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(location, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          if (profile['mobile_number'] != null && (profile['mobile_number'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_outlined, size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('+91 ${profile['mobile_number']}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoChip(label: isMarathi ? 'ऊस' : 'Sugarcane', icon: '🌾'),
              const SizedBox(width: 8),
              _InfoChip(label: isMarathi ? 'कापूस' : 'Cotton', icon: '🌿'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfileSheet(context, ref, l10n, profile),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.translate('edit_profile')),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildEmptyHistory(BuildContext context, bool isMarathi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(
            isMarathi ? 'अद्याप स्कॅन इतिहास नाही' : 'No scan history yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 300.ms);
  }

  Widget _buildEmptyDiagnoses(BuildContext context, bool isMarathi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.bookmark_outline, size: 48, color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(
            isMarathi ? 'स्कॅन केल्यावर निदान इथे दिसतील' : 'Scan your crops to see saved diagnoses here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 600.ms);
  }

  void _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Map<String, dynamic> currentProfile,
  ) {
    final nameController = TextEditingController(text: currentProfile['name'] ?? '');
    final locationController = TextEditingController(text: currentProfile['location'] ?? '');
    String selectedLang = currentProfile['preferred_language'] ?? 'mr';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  '✏️ ${l10n.translate('edit_profile')}',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 24),
              // Name
              Text('Full Name', style: Theme.of(ctx).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              // Location
              Text('Location', style: Theme.of(ctx).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  hintText: 'e.g. Pune, Maharashtra',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              // Language
              Text('Preferred Language', style: Theme.of(ctx).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  {'code': 'mr', 'label': 'मराठी'},
                  {'code': 'hi', 'label': 'हिंदी'},
                  {'code': 'en', 'label': 'English'},
                ].map((lang) {
                  final isSelected = selectedLang == lang['code'];
                  return ChoiceChip(
                    label: Text(lang['label']!),
                    selected: isSelected,
                    onSelected: (sel) => setSheetState(() => selectedLang = lang['code']!),
                    selectedColor: AppColors.primaryContainer,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setSheetState(() => isSaving = true);
                          try {
                            final apiService = ref.read(apiServiceProvider);
                            final result = await apiService.updateProfile(
                              name: nameController.text.trim(),
                              location: locationController.text.trim(),
                              preferredLanguage: selectedLang,
                            );

                            if (!result.containsKey('error')) {
                              // Update locale
                              ref.read(localeProvider.notifier).state = Locale(selectedLang);
                              // Refresh profile
                              ref.invalidate(userProfileProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: const Text('Profile updated! ✅'),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              }
                            } else {
                              setSheetState(() => isSaving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${result['error']}. Please login first.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setSheetState(() => isSaving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: const Text('Connection error. Please try again.'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? 'Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '⚙️ Settings',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              // Location toggle
              Consumer(
                builder: (ctx, innerRef, _) {
                  final locationEnabled = innerRef.watch(locationEnabledProvider);
                  final userLocation = innerRef.watch(userLocationProvider);
                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          locationEnabled ? Icons.location_on : Icons.location_off,
                          color: locationEnabled ? AppColors.primary : AppColors.onSurfaceVariant,
                        ),
                        title: const Text('Location'),
                        subtitle: Text(
                          locationEnabled && userLocation.isNotEmpty
                              ? '📍 $userLocation'
                              : 'Disabled — tap to enable',
                          style: TextStyle(
                            color: locationEnabled ? AppColors.primary : AppColors.onSurfaceVariant,
                          ),
                        ),
                        trailing: Switch(
                          value: locationEnabled,
                          activeColor: AppColors.primary,
                          onChanged: (enabled) async {
                            if (enabled) {
                              // Try to get location
                              await _detectLocation(ctx, innerRef);
                            } else {
                              innerRef.read(locationEnabledProvider.notifier).state = false;
                              innerRef.read(userLocationProvider.notifier).state = '';
                            }
                          },
                        ),
                      ),
                      if (locationEnabled && userLocation.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
                          child: Row(
                            children: [
                              const SizedBox(width: 40),
                              TextButton.icon(
                                onPressed: () async => await _detectLocation(ctx, innerRef),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Re-detect location'),
                                style: TextButton.styleFrom(
                                  textStyle: Theme.of(ctx).textTheme.labelSmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const Divider(),
              // Language switcher
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Language / भाषा'),
                subtitle: Text(_getLangName(ref.read(localeProvider).languageCode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  _showLanguagePicker(context, ref);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About Farmly'),
                subtitle: const Text('Version 1.0.0'),
                onTap: () {
                  Navigator.pop(ctx);
                  showAboutDialog(
                    context: context,
                    applicationName: 'Farmly',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2026 Farmly',
                    children: [
                      const SizedBox(height: 16),
                      const Text('AI-powered crop disease detection for Maharashtra farmers.'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _detectLocation(BuildContext context, WidgetRef ref) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location services are disabled. Enable in device settings.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Location permission denied.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permanently denied. Enable in browser settings.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      String locationName = '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = <String>[];
          if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) parts.add(place.administrativeArea!);
          if (parts.isNotEmpty) locationName = parts.join(', ');
        }
      } catch (_) {}

      ref.read(userLocationProvider.notifier).state = locationName;
      ref.read(locationEnabledProvider.notifier).state = true;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Location: $locationName'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      ref.read(locationEnabledProvider.notifier).state = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not detect location. Try again later.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('मराठी (Marathi)'),
              leading: Radio<String>(
                value: 'mr',
                groupValue: ref.read(localeProvider).languageCode,
                onChanged: (v) {
                  ref.read(localeProvider.notifier).state = const Locale('mr');
                  Navigator.pop(ctx);
                },
              ),
              onTap: () {
                ref.read(localeProvider.notifier).state = const Locale('mr');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('हिंदी (Hindi)'),
              leading: Radio<String>(
                value: 'hi',
                groupValue: ref.read(localeProvider).languageCode,
                onChanged: (v) {
                  ref.read(localeProvider.notifier).state = const Locale('hi');
                  Navigator.pop(ctx);
                },
              ),
              onTap: () {
                ref.read(localeProvider.notifier).state = const Locale('hi');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('English'),
              leading: Radio<String>(
                value: 'en',
                groupValue: ref.read(localeProvider).languageCode,
                onChanged: (v) {
                  ref.read(localeProvider.notifier).state = const Locale('en');
                  Navigator.pop(ctx);
                },
              ),
              onTap: () {
                ref.read(localeProvider.notifier).state = const Locale('en');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getLangName(String code) {
    switch (code) {
      case 'mr': return 'मराठी (Marathi)';
      case 'hi': return 'हिंदी (Hindi)';
      case 'en': return 'English';
      default: return code;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ScanHistoryCard extends StatelessWidget {
  final Map<String, dynamic> scan;
  final bool isMarathi;
  final int delay;

  const _ScanHistoryCard({required this.scan, required this.isMarathi, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.eco, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMarathi ? scan['diseaseMarathi'] as String : scan['disease'] as String,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isMarathi ? scan['cropMarathi'] : scan['crop']} • ${isMarathi ? scan['dateMarathi'] : scan['date']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${((scan['confidence'] as double) * 100).toInt()}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: delay)).slideX(begin: 0.1);
  }
}

class _ApiScanHistoryCard extends StatelessWidget {
  final dynamic scan;
  final bool isMarathi;
  final int delay;

  const _ApiScanHistoryCard({required this.scan, required this.isMarathi, required this.delay});

  @override
  Widget build(BuildContext context) {
    final disease = isMarathi
        ? (scan['detected_disease_mr'] ?? scan['detected_disease'] ?? 'Unknown')
        : (scan['detected_disease'] ?? 'Unknown');
    final crop = scan['crop_type'] ?? '';
    final confidence = (scan['confidence'] as num?)?.toDouble() ?? 0.0;
    final severity = scan['severity'] ?? 'Medium';
    final createdAt = scan['created_at'] ?? '';
    final dateStr = createdAt.toString().length > 10 ? createdAt.toString().substring(0, 10) : createdAt.toString();

    Color severityColor() {
      switch (severity.toString().toLowerCase()) {
        case 'critical': return AppColors.error;
        case 'high': return const Color(0xFFE65100);
        case 'medium': return AppColors.tertiary;
        default: return AppColors.primary;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: severityColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.eco, color: severityColor()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disease,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$crop • $dateStr',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(confidence * 100).toInt()}%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '🟢 DB',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: delay)).slideX(begin: 0.1);
  }
}
