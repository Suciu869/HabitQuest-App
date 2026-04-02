import 'package:shared_preferences/shared_preferences.dart';

class TimeService {
  static const _keyOffsetSeconds = 'hq_time_offset_seconds_v1';

  Duration _offset = Duration.zero;
  bool _loaded = false;

  Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt(_keyOffsetSeconds) ?? 0;
    _offset = Duration(seconds: seconds);
    _loaded = true;
  }

  DateTime now() {
    // Safe even if init() wasn't awaited yet (offset defaults to 0).
    return DateTime.now().add(_offset);
  }

  Future<void> addDays(int days) async {
    await init();
    _offset += Duration(days: days);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOffsetSeconds, _offset.inSeconds);
  }

  Future<void> reset() async {
    _offset = Duration.zero;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOffsetSeconds, 0);
  }
}

