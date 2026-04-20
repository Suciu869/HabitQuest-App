import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppOpenAdManager {
  AppOpenAdManager._internal();

  static final AppOpenAdManager _instance = AppOpenAdManager._internal();
  factory AppOpenAdManager() => _instance;

  static const String _lastAppOpenAdTimeKey = 'lastAppOpenAdTime';
  static const Duration _cooldown = Duration(hours: 4);

  static const String _debugAdUnitId =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _releaseAdUnitId =
      'ca-app-pub-4119925367707162/1308723170';

  AppOpenAd? _appOpenAd;
  bool _isLoadingAd = false;
  bool _isShowingAd = false;

  String get _adUnitId => kDebugMode ? _debugAdUnitId : _releaseAdUnitId;

  Future<void> loadAd() async {
    if (_isLoadingAd || _appOpenAd != null) {
      return;
    }

    _isLoadingAd = true;

    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isLoadingAd = false;
        },
        onAdFailedToLoad: (error) {
          _isLoadingAd = false;
        },
      ),
    );
  }

  Future<void> showAdIfAvailable() async {
    if (_isShowingAd) return;

    final prefs = await SharedPreferences.getInstance();
    final lastShownMillis = prefs.getInt(_lastAppOpenAdTimeKey);

    if (lastShownMillis != null) {
      final lastShownTime =
          DateTime.fromMillisecondsSinceEpoch(lastShownMillis);
      final elapsed = DateTime.now().difference(lastShownTime);
      if (elapsed < _cooldown) {
        return;
      }
    }

    final ad = _appOpenAd;
    if (ad == null) {
      await loadAd();
      return;
    }

    // Save immediately when we decide to show, enforcing strict cooldown.
    await prefs.setInt(
      _lastAppOpenAdTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    _isShowingAd = true;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _isShowingAd = false;
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        _isShowingAd = false;
        loadAd();
      },
    );

    await ad.show();
  }
}
