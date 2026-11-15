import 'package:flutter/material.dart';
import '../config/theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final double? trend;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppTheme.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (subtitle != null || trend != null) ...[
              const SizedBox(height: AppTheme.spacingXs),
              Row(
                children: [
                  if (trend != null) ...[
                    Icon(
                      trend! >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: trend! >= 0 ? AppTheme.success : AppTheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${trend! >= 0 ? '+' : ''}${trend!.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: trend! >= 0 ? AppTheme.success : AppTheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (subtitle != null)
                    Expanded(
                      child: Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
