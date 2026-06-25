import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';
import 'package:farmly/core/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final weatherAsync = ref.watch(weatherProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final detectedLocation = ref.watch(userLocationProvider);
    final locationEnabled = ref.watch(locationEnabledProvider);

    String userName = locale.languageCode == 'mr' ? 'शेतकरी' : 'Farmer';
    String userLocation = locale.languageCode == 'mr' ? 'पुणे, महाराष्ट्र' : 'Pune, Maharashtra';
    if (locationEnabled && detectedLocation.isNotEmpty) userLocation = detectedLocation;
    profileAsync.whenData((profile) {
      if (!profile.containsKey('error')) {
        if (profile['name'] != null && (profile['name'] as String).isNotEmpty) userName = profile['name'];
        if (!(locationEnabled && detectedLocation.isNotEmpty)) {
          if (profile['location'] != null && (profile['location'] as String).isNotEmpty) userLocation = profile['location'];
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            // Header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l10n.translate('hello_farmer')}${userName.isNotEmpty ? ', $userName' : ''}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                Row(children: [
                  Icon(Icons.location_on, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(userLocation, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant)),
                ]),
              ])),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
                icon: Badge(smallSize: 8, child: Icon(Icons.notifications_outlined, size: 28, color: AppColors.onSurface)),
              ),
            ]).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 24),



            // Scan hero button
            Center(child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/scan'),
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, gradient: AppColors.heroGradient,
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 10))],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.camera_alt_rounded, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(l10n.translate('scan_crop'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            ))
                .animate().scale(duration: 600.ms, curve: Curves.elasticOut)
                .animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.04, 1.04), duration: 2.seconds),
            const SizedBox(height: 28),

            // Weather card
            weatherAsync.when(
              data: (weather) => _WeatherCard(weather: weather, locale: locale, l10n: l10n, onTap: () => Navigator.pushNamed(context, '/weather-dashboard')),
              loading: () => Container(
                width: double.infinity, height: 120,
                decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(20)),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => _WeatherCard(
                weather: {'temperature': 28, 'humidity': 65, 'wind_speed': 12, 'condition': 'Partly Cloudy', 'condition_mr': 'अंशतः ढगाळ', 'icon': '⛅', 'rain_chance': 20, 'advisory': '', 'advisory_mr': ''},
                locale: locale, l10n: l10n, onTap: () => Navigator.pushNamed(context, '/weather-dashboard'),
              ),
            ),
            const SizedBox(height: 24),

            // Crop tips
            Text(l10n.translate('crop_tips'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)).animate().fadeIn(duration: 400.ms, delay: 300.ms),
            const SizedBox(height: 12),
            SizedBox(height: 140, child: ListView(scrollDirection: Axis.horizontal, children: [
              _CropTipCard(crop: l10n.translate('sugarcane'), icon: '🌾', tip: locale.languageCode == 'mr' ? 'ऊसाला योग्य पाणी व्यवस्थापन करा' : 'Manage sugarcane irrigation properly', color: AppColors.primary, delay: 400),
              _CropTipCard(crop: l10n.translate('cotton'), icon: '🌿', tip: locale.languageCode == 'mr' ? 'कापसावर बोंडअळीसाठी लक्ष ठेवा' : 'Watch for bollworm in cotton', color: AppColors.secondary, delay: 500),
              _CropTipCard(crop: l10n.translate('soybean'), icon: '🫘', tip: locale.languageCode == 'mr' ? 'सोयाबीनला गंज रोगापासून वाचवा' : 'Protect soybean from rust disease', color: AppColors.tertiary, delay: 600),
            ])),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int delay;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    )).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: delay)).slideY(begin: 0.3);
  }
}

class _WeatherCard extends StatelessWidget {
  final Map<String, dynamic> weather;
  final Locale locale;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  const _WeatherCard({required this.weather, required this.locale, required this.l10n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMarathi = locale.languageCode == 'mr';
    final condition = isMarathi ? (weather['condition_mr'] ?? weather['condition'] ?? 'Partly Cloudy') : (weather['condition'] ?? 'Partly Cloudy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.primaryContainer.withValues(alpha: 0.05)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.wb_sunny_rounded, color: AppColors.tertiary, size: 20), const SizedBox(width: 8),
            Text(l10n.translate('weather'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
              child: Text('🟢 ${l10n.translate('live')}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Text('${weather['icon'] ?? '⛅'}', style: const TextStyle(fontSize: 48)), const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${weather['temperature'] ?? 28}°C', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(condition.toString(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant)),
            ]),
            const Spacer(),
            Column(children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.water_drop_outlined, size: 16, color: AppColors.onSurfaceVariant), const SizedBox(width: 4),
                Text('${weather['humidity'] ?? 65}%', style: Theme.of(context).textTheme.labelMedium),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.umbrella_rounded, size: 16, color: AppColors.onSurfaceVariant), const SizedBox(width: 4),
                Text('${weather['rain_chance'] ?? 20}%', style: Theme.of(context).textTheme.labelMedium),
              ]),
            ]),
          ]),
        ]),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.1);
  }
}

class _CropTipCard extends StatelessWidget {
  final String crop;
  final String icon;
  final String tip;
  final Color color;
  final int delay;
  const _CropTipCard({required this.crop, required this.icon, required this.tip, required this.color, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 24)), const SizedBox(width: 8),
          Text(crop, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 12),
        Expanded(child: Text(tip, style: Theme.of(context).textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis)),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: delay)).slideX(begin: 0.2);
  }
}
