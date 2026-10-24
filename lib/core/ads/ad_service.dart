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
  static const String _prefKeyRewardAdFreeUntil = 'reward_ad_free_until';

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  DateTime? _rewardAdFreeUntil;
  DateTime? get rewardAdFreeUntil => _rewardAdFreeUntil;

  final ValueNotifier<bool> isAdsRemovedNotifier = ValueNotifier<bool>(false);

  /// Checks if either lifetime purchase is active OR temporary rewarded ad-free is active
  bool get isAdsRemoved {
    if (isAdsRemovedNotifier.value) return true;
    if (isRewardAdFreeActive) return true;
    return false;
  }

  bool get isRewardAdFreeActive {
    return _rewardAdFreeUntil != null && DateTime.now().isBefore(_rewardAdFreeUntil!);
  }

  String get remainingRewardAdFreeText {
    if (!isRewardAdFreeActive) return '';
    final diff = _rewardAdFreeUntil!.difference(DateTime.now());
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m left';
    }
    return '${minutes}m left';
  }

  /// User Google AdMob App ID: ca-app-pub-1852108665659812~6416657460
  static const String appId = 'ca-app-pub-1852108665659812~6416657460';
  static const String bannerId = 'ca-app-pub-1852108665659812/2589093096';
  static const String interstitialId = 'ca-app-pub-1852108665659812/3598922433';
  static const String rewardId = 'ca-app-pub-1852108665659812/2520635328';

  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    return bannerId;
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    return interstitialId;
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    return rewardId;
  }

  int _navigationCount = 0;
  bool _canShowInterstitial = false;
  static const int _interstitialNavigationFrequency = 4; // Trigger on every 4 to 5 navigations

  /// Enables interstitial ads only after the app has fully settled (15s after startup)
  void enableInterstitialAfterStartup() {
    Future.delayed(const Duration(seconds: 15), () {
      _canShowInterstitial = true;
    });
  }

  /// Tracks screen or tab navigation and shows interstitial every 4 to 5 navigations
  void registerNavigationAndMaybeShowInterstitial() {
    if (!_canShowInterstitial) return;
    if (isAdsRemoved) return;
    _navigationCount++;
    debugPrint('AdService: Navigation count = $_navigationCount / $_interstitialNavigationFrequency');
    if (_navigationCount >= _interstitialNavigationFrequency) {
      _navigationCount = 0;
      showInterstitialAd();
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final untilMs = prefs.getInt(_prefKeyRewardAdFreeUntil);
      if (untilMs != null) {
        _rewardAdFreeUntil = DateTime.fromMillisecondsSinceEpoch(untilMs);
      }
      final isLifetime = prefs.getBool(_prefKeyRemoveAds) ?? false;
      isAdsRemovedNotifier.value = isLifetime || isRewardAdFreeActive;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await MobileAds.instance.initialize();
        _isInitialized = true;
        enableInterstitialAfterStartup();

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
    isAdsRemovedNotifier.value = removed || isRewardAdFreeActive;
    return removed || isRewardAdFreeActive;
  }

  /// Grants 24 hours of ad-free experience as a reward for watching a Rewarded Ad
  Future<void> grantRewardAdFreeHours([int hours = 24]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final base = (_rewardAdFreeUntil != null && now.isBefore(_rewardAdFreeUntil!))
          ? _rewardAdFreeUntil!
          : now;
      final newUntil = base.add(Duration(hours: hours));
      _rewardAdFreeUntil = newUntil;
      await prefs.setInt(_prefKeyRewardAdFreeUntil, newUntil.millisecondsSinceEpoch);
      isAdsRemovedNotifier.value = true;

      // Dispose preloaded interstitial
      _interstitialAd?.dispose();
      _interstitialAd = null;
      debugPrint('Granted $hours hours ad-free reward until $newUntil');
    } catch (e) {
      debugPrint('Error granting reward: $e');
    }
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
