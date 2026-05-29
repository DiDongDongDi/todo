import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/shared/widgets/progress_widgets.dart';

const _streakKey = 'todo_streak_daily_v1';
const _archivedTodayKey = 'todo_archived_today_v1';
const _archivedTodayDateKey = 'todo_archived_today_date_v1';

class StatsState {
  const StatsState({
    required this.dailyArchived,
    required this.archivedToday,
  });

  final Map<String, int> dailyArchived;
  final int archivedToday;

  int get streak => computeStreak(dailyArchived);
}

final statsProvider =
    AsyncNotifierProvider<StatsNotifier, StatsState>(StatsNotifier.new);

class StatsNotifier extends AsyncNotifier<StatsState> {
  SharedPreferences? _prefs;

  @override
  Future<StatsState> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _load();
  }

  StatsState _load() {
    final prefs = _prefs!;
    final daily = decodeDailyMap(prefs.getString(_streakKey));
    final todayKey = _dayKey(DateTime.now());
    final savedDate = prefs.getString(_archivedTodayDateKey);
    var archivedToday = prefs.getInt(_archivedTodayKey) ?? 0;
    if (savedDate != todayKey) {
      archivedToday = 0;
    }
    return StatsState(dailyArchived: daily, archivedToday: archivedToday);
  }

  Future<void> recordArchive() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    final daily = decodeDailyMap(prefs.getString(_streakKey));
    recordArchivedDay(daily, now);
    await prefs.setString(_streakKey, encodeDailyMap(daily));

    final savedDate = prefs.getString(_archivedTodayDateKey);
    var archivedToday = prefs.getInt(_archivedTodayKey) ?? 0;
    if (savedDate != todayKey) {
      archivedToday = 0;
    }
    archivedToday += 1;
    await prefs.setString(_archivedTodayDateKey, todayKey);
    await prefs.setInt(_archivedTodayKey, archivedToday);
    state = AsyncData(_load());
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
