import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  static final RewardedAdService _instance = RewardedAdService._internal();
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();

  bool _mobileAdsInit = false;

  Future<void> ensureInitialized() async {
    if (_mobileAdsInit) return;
    await MobileAds.instance.initialize();
    _mobileAdsInit = true;
  }

  /// Shows a rewarded ad and returns true only if the user earned the reward.
  ///
  /// Uses the real Android rewarded ad unit ID you provided.
  /// Note: iOS ad unit ID is not provided here, so we keep the existing placeholder for iOS.
  Future<bool> showRewardedAdForStreakRestore() async {
    await ensureInitialized();

    final completer = Completer<bool>();

    const androidTestAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
    const iosTestAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

    const androidReleaseAdUnitId = 'ca-app-pub-4119925367707162/5976391224';
    const iosReleaseAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

    final adUnitId = Platform.isAndroid
        ? (kDebugMode ? androidTestAdUnitId : androidReleaseAdUnitId)
        : (kDebugMode ? iosTestAdUnitId : iosReleaseAdUnitId);

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) async {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );

          await ad.show(
            onUserEarnedReward: (ad, reward) {
              if (!completer.isCompleted) completer.complete(true);
            },
          );
        },
        onAdFailedToLoad: (err) {
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );

    return completer.future.timeout(const Duration(seconds: 45), onTimeout: () => false);
  }
}

