import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:farmly/core/theme/app_colors.dart';
import 'package:farmly/core/localization/app_localizations.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final notifications = [
      {
        'type': 'disease',
        'icon': Icons.warning_amber_rounded,
        'color': AppColors.error,
        'title': l10n.translate('disease_alert'),
        'message': 'Leaf Spot outbreak reported in Pune region',
        'messageMr': 'पुणे भागात पानावरील डाग रोगाचा उद्रेक',
        'time': '1h ago',
        'timeMr': '१ तास पूर्वी',
      },
      {
        'type': 'weather',
        'icon': Icons.cloud_rounded,
        'color': const Color(0xFF1976D2),
        'title': l10n.translate('weather_warning'),
        'message': 'Heavy rainfall expected in Marathwada this week',
        'messageMr': 'या आठवड्यात मराठवाड्यात मुसळधार पाऊस',
        'time': '3h ago',
        'timeMr': '३ तास पूर्वी',
      },
      {
        'type': 'tip',
        'icon': Icons.lightbulb_outline_rounded,
        'color': AppColors.tertiary,
        'title': l10n.translate('farming_tip'),
        'message': 'Best time to apply fertilizer for Kharif crops',
        'messageMr': 'खरीप पिकांसाठी खत देण्याची योग्य वेळ',
        'time': '1d ago',
        'timeMr': '१ दिवस पूर्वी',
      },
      {
        'type': 'disease',
        'icon': Icons.bug_report_outlined,
        'color': AppColors.error,
        'title': l10n.translate('disease_alert'),
        'message': 'Powdery Mildew risk high for grape crops in Nashik',
        'messageMr': 'नाशिक भागातील द्राक्ष पिकांसाठी भुरी रोगाचा धोका',
        'time': '2d ago',
        'timeMr': '२ दिवस पूर्वी',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('notifications')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (notif['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(notif['icon'] as IconData, color: notif['color'] as Color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif['title'] as String,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif['message'] as String,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notif['time'] as String,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: index * 100)).slideX(begin: 0.1);
        },
      ),
    );
  }
}
