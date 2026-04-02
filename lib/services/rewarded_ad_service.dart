import 'dart:async';
import 'dart:io';

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

    // Android rewarded ad unit id (real)
    const androidAdUnitId = 'ca-app-pub-4119925367707162/5976391224';

    // iOS rewarded ad unit id (placeholder until you share the real one)
    const iosAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

    final adUnitId = Platform.isAndroid ? androidAdUnitId : iosAdUnitId;

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

