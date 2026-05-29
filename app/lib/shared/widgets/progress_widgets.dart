import 'package:flutter/material.dart';
import 'dart:math' as math;

class ProcessProgressRing extends StatelessWidget {
  const ProcessProgressRing({
    super.key,
    required this.completed,
    required this.total,
    this.size = 44,
  });

  final int completed;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 1.0 : completed / total;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: colorScheme.surfaceContainerHigh,
            color: progress >= 1 ? colorScheme.tertiary : colorScheme.primary,
          ),
          Text(
            total == 0 ? '✓' : '${(progress * 100).round()}',
            style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    if (streak <= 0) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department,
              size: 16, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            '$streak 天',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

void showCelebrateOverlay(BuildContext context) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        onEnd: () => entry.remove(),
        builder: (context, value, child) {
          return IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: (1 - value).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.8 + value * 0.4,
                  child: Icon(
                    Icons.celebration_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
  overlay.insert(entry);
}

int computeStreak(Map<String, int> dailyArchived) {
  if (dailyArchived.isEmpty) return 0;

  var streak = 0;
  var day = DateTime.now();
  final keys = dailyArchived.keys.toSet();

  while (true) {
    final key = _dayKey(day);
    final count = dailyArchived[key] ?? 0;
    if (count > 0) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    } else if (streak == 0 && _isToday(day)) {
      day = day.subtract(const Duration(days: 1));
    } else {
      break;
    }
    if (streak > 365) break;
  }
  return streak;
}

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool _isToday(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

void recordArchivedDay(Map<String, int> daily, DateTime when) {
  final key = _dayKey(when);
  daily[key] = (daily[key] ?? 0) + 1;
}

String encodeDailyMap(Map<String, int> map) =>
    map.entries.map((e) => '${e.key}:${e.value}').join(',');

Map<String, int> decodeDailyMap(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  final result = <String, int>{};
  for (final part in raw.split(',')) {
    final pieces = part.split(':');
    if (pieces.length == 2) {
      result[pieces[0]] = int.tryParse(pieces[1]) ?? 0;
    }
  }
  return result;
}

double inboxProgress(int archivedToday, int inboxRemaining) {
  final total = archivedToday + inboxRemaining;
  if (total == 0) return 1;
  return archivedToday / total;
}

int clampPercent(double p) => (p * 100).clamp(0, 100).round();

int maxStreakDisplay(int streak) => math.max(0, streak);
