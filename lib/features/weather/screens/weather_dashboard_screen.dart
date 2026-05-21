import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';
import 'package:farmly/core/providers.dart';

class WeatherDashboardScreen extends ConsumerWidget {
  const WeatherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final weatherAsync = ref.watch(weatherProvider);
    final forecastAsync = ref.watch(weatherForecastProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('weather_dashboard'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Current weather hero card
          weatherAsync.when(
            data: (w) => _CurrentWeatherCard(weather: w, locale: locale, l10n: l10n),
            loading: () => _shimmerCard(context, 200),
            error: (_, __) => _CurrentWeatherCard(weather: _defaultWeather(), locale: locale, l10n: l10n),
          ),
          const SizedBox(height: 24),

          // Agricultural advisory
          weatherAsync.when(
            data: (w) {
              final key = locale.languageCode == 'mr' ? 'advisory_mr' : locale.languageCode == 'hi' ? 'advisory_hi' : 'advisory';
              final advisory = w[key] ?? w['advisory'] ?? '';
              if (advisory.toString().isEmpty) return const SizedBox.shrink();
              return _AdvisoryCard(advisory: advisory.toString(), l10n: l10n);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          // 7-day forecast
          Text(l10n.translate('forecast_7day'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))
              .animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 12),
          forecastAsync.when(
            data: (forecast) {
              if (forecast.isEmpty) return Center(child: Text(l10n.translate('no_results')));
              return Column(
                children: forecast.asMap().entries.map((e) {
                  final i = e.key;
                  final fc = e.value;
                  final condKey = locale.languageCode == 'mr' ? 'condition_mr' : locale.languageCode == 'hi' ? 'condition_hi' : 'condition';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15)),
                    ),
                    child: Row(children: [
                      Text(fc['icon']?.toString() ?? '⛅', style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fc['date']?.toString() ?? '', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        Text(fc[condKey]?.toString() ?? fc['condition']?.toString() ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${fc['temp_max'] ?? 0}° / ${fc['temp_min'] ?? 0}°', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.water_drop, size: 12, color: Colors.blue.shade400),
                          const SizedBox(width: 2),
                          Text('${fc['rain_chance'] ?? 0}%', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.blue.shade400)),
                        ]),
                      ]),
                    ]),
                  ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: 100 + i * 60)).slideX(begin: 0.05);
                }).toList(),
              );
            },
            loading: () => Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _shimmerCard(context, 64)))),
            error: (_, __) => Center(child: Text(l10n.translate('weather_failed'))),
          ),
          const SizedBox(height: 24),

          // Disease risk based on weather
          weatherAsync.when(
            data: (w) => _DiseaseRiskCard(weather: w, l10n: l10n, locale: locale),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Map<String, dynamic> _defaultWeather() => {
    'temperature': 28, 'humidity': 65, 'wind_speed': 12, 'icon': '⛅',
    'condition': 'Partly Cloudy', 'condition_mr': 'अंशतः ढगाळ', 'rain_chance': 20,
  };

  static Widget _shimmerCard(BuildContext context, double height) {
    return Container(
      width: double.infinity, height: height,
      decoration: BoxDecoration(color: AppColors.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms);
  }
}

class _CurrentWeatherCard extends StatelessWidget {
  final Map<String, dynamic> weather;
  final Locale locale;
  final AppLocalizations l10n;
  const _CurrentWeatherCard({required this.weather, required this.locale, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final condKey = locale.languageCode == 'mr' ? 'condition_mr' : locale.languageCode == 'hi' ? 'condition_hi' : 'condition';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.12), AppColors.primaryContainer.withValues(alpha: 0.06)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.wb_sunny_rounded, color: AppColors.tertiary, size: 20),
          const SizedBox(width: 8),
          Text(l10n.translate('weather'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text('🟢 ${l10n.translate('live')}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Text(weather['icon']?.toString() ?? '⛅', style: const TextStyle(fontSize: 56)),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${weather['temperature'] ?? 28}°C', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
            Text(weather[condKey]?.toString() ?? 'Partly Cloudy', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant)),
          ]),
        ]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _WeatherStat(icon: Icons.water_drop_outlined, value: '${weather['humidity'] ?? 65}%', label: l10n.translate('humidity')),
          _WeatherStat(icon: Icons.air, value: '${weather['wind_speed'] ?? 12} km/h', label: l10n.translate('wind')),
          _WeatherStat(icon: Icons.umbrella_rounded, value: '${weather['rain_chance'] ?? 20}%', label: l10n.translate('rain_chance')),
          _WeatherStat(icon: Icons.thermostat, value: '${weather['precipitation'] ?? 0} mm', label: l10n.translate('precipitation')),
        ]),
      ]),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _WeatherStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
      const SizedBox(height: 4),
      Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant)),
    ]);
  }
}

class _AdvisoryCard extends StatelessWidget {
  final String advisory;
  final AppLocalizations l10n;
  const _AdvisoryCard({required this.advisory, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.agriculture_rounded, size: 20, color: AppColors.tertiary),
          const SizedBox(width: 8),
          Text(l10n.translate('agri_advisory'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.tertiary)),
        ]),
        const SizedBox(height: 8),
        Text(advisory, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }
}

class _DiseaseRiskCard extends StatelessWidget {
  final Map<String, dynamic> weather;
  final AppLocalizations l10n;
  final Locale locale;
  const _DiseaseRiskCard({required this.weather, required this.l10n, required this.locale});

  @override
  Widget build(BuildContext context) {
    final humidity = (weather['humidity'] as num?)?.toInt() ?? 65;
    final rainChance = (weather['rain_chance'] as num?)?.toInt() ?? 20;
    final riskLevel = humidity > 80 || rainChance > 60 ? 'high' : humidity > 65 ? 'medium' : 'low';
    final riskColor = riskLevel == 'high' ? AppColors.error : riskLevel == 'medium' ? AppColors.tertiary : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, color: riskColor.withValues(alpha: 0.15)),
          child: Icon(Icons.bug_report_rounded, color: riskColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.translate('disease_risk'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(l10n.translate(riskLevel), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: riskColor, fontWeight: FontWeight.w600)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: riskColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
          child: Text(l10n.translate(riskLevel).toUpperCase(), style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
}
