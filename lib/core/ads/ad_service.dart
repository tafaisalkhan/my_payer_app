import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const String productIdRemoveAds = 'remove_ads';
  static const String priceRemoveAds = r'$4.99';
  static const String _prefKeyRemoveAds = 'is_ads_removed';

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  final ValueNotifier<bool> isAdsRemovedNotifier = ValueNotifier<bool>(false);

  bool get isAdsRemoved => isAdsRemovedNotifier.value;

  /// Official Google AdMob Test Ad Unit IDs
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android Banner Test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS Banner Test ID
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Android Interstitial Test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS Interstitial Test ID
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Android Rewarded Test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOS Rewarded Test ID
    }
    return '';
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      isAdsRemovedNotifier.value = prefs.getBool(_prefKeyRemoveAds) ?? false;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await MobileAds.instance.initialize();
        _isInitialized = true;

        if (!isAdsRemoved) {
          loadInterstitialAd();
          loadRewardedAd();
        }
      }
    } catch (e) {
      debugPrint('AdService initialization error: $e');
    }
  }

  /// Purchase / toggle remove ads
  Future<bool> purchaseRemoveAds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyRemoveAds, true);
      isAdsRemovedNotifier.value = true;

      // Dispose preloaded ads immediately
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _rewardedAd?.dispose();
      _rewardedAd = null;

      debugPrint('Product remove_ads ($priceRemoveAds) purchased successfully!');
      return true;
    } catch (e) {
      debugPrint('Error purchasing remove_ads: $e');
      return false;
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    final prefs = await SharedPreferences.getInstance();
    final bool removed = prefs.getBool(_prefKeyRemoveAds) ?? false;
    isAdsRemovedNotifier.value = removed;
    return removed;
  }

  /// 1. BANNER AD CREATOR
  BannerAd? createBannerAd({
    required Function(Ad) onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
    AdSize size = AdSize.banner,
  }) {
    if (isAdsRemoved) return null;

    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
        onAdOpened: (ad) => debugPrint('Banner Ad opened'),
        onAdClosed: (ad) => debugPrint('Banner Ad closed'),
      ),
    );
  }

  /// 2. INTERSTITIAL AD
  void loadInterstitialAd() {
    if (isAdsRemoved) return;
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          debugPrint('InterstitialAd loaded successfully.');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          debugPrint('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  void showInterstitialAd({VoidCallback? onDismissed}) {
    if (isAdsRemoved) {
      onDismissed?.call();
      return;
    }

    if (_interstitialAd == null) {
      debugPrint('InterstitialAd not ready yet. Reloading...');
      loadInterstitialAd();
      onDismissed?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('Interstitial showed.'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Interstitial dismissed.');
        ad.dispose();
        _interstitialAd = null;
        if (!isAdsRemoved) loadInterstitialAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        if (!isAdsRemoved) loadInterstitialAd();
        onDismissed?.call();
      },
    );

    _interstitialAd!.show();
  }

  /// 3. REWARDED AD
  void loadRewardedAd() {
    if (isAdsRemoved) return;
    if (_isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          debugPrint('RewardedAd loaded successfully.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          debugPrint('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  void showRewardedAd({
    required Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onDismissed,
  }) {
    if (isAdsRemoved) {
      onUserEarnedReward(RewardItem(100, 'blessing_points'));
      onDismissed?.call();
      return;
    }

    if (_rewardedAd == null) {
      debugPrint('RewardedAd not ready yet. Reloading...');
      loadRewardedAd();
      onDismissed?.call();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('Rewarded showed.'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Rewarded dismissed.');
        ad.dispose();
        _rewardedAd = null;
        if (!isAdsRemoved) loadRewardedAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        if (!isAdsRemoved) loadRewardedAd();
        onDismissed?.call();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (adWithoutView, reward) {
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        onUserEarnedReward(reward);
      },
    );
  }
}
