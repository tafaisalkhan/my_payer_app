import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/support_service.dart';
import '../../shared/widgets/no_ads_popup.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const String productIdRemoveAds = 'remove_ads';
  static const String priceRemoveAds = r'$4.99';
  static const String _prefKeyRemoveAds = 'is_ads_removed';
  static const String _prefKeyRewardAdFreeUntil = 'reward_ad_free_until';
  static const String _prefKeyStreakDays = 'consecutive_open_days';
  static const String _prefKeyLastOpenDate = 'last_open_date';
  static const String _prefKeyAdFreeStreakDate = 'ad_free_streak_date';
  static const String _prefKeyPopupStep = 'no_ads_popup_step';

  bool _isInitialized = false;
  final ValueNotifier<bool> isInitializedNotifier = ValueNotifier<bool>(false);
  bool _dashboardVisible = false;
  bool _isLifetimeRemoveAds = false;
  bool _isAdFreeToday = false;
  bool _noFillThisLaunch = false;
  bool _popupShownThisLaunch = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  DateTime? _rewardAdFreeUntil;
  DateTime? get rewardAdFreeUntil => _rewardAdFreeUntil;

  final ValueNotifier<bool> isAdsRemovedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isNoFillNotifier = ValueNotifier<bool>(false);

  bool get isLifetimeRemoveAds => _isLifetimeRemoveAds;
  bool get isAdFreeToday => _isAdFreeToday;
  bool get noFillThisLaunch => _noFillThisLaunch;

  /// Checks if lifetime purchase, 3-day streak ad-free day, or temporary rewarded ad-free is active.
  bool get isAdsRemoved {
    if (_isLifetimeRemoveAds || _isAdFreeToday || isAdsRemovedNotifier.value) {
      return true;
    }
    if (isRewardAdFreeActive) return true;
    return false;
  }

  bool get isAdsDisabledForSession => isAdsRemoved || _noFillThisLaunch;

  static bool isValidAdUnitId(String id) {
    return id.isNotEmpty && id.startsWith('ca-app-pub-') && id.contains('/');
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

  /// Production AdMob IDs from gitignored admob_secrets.json (--dart-define-from-file=admob_secrets.json)
  static const String appId = String.fromEnvironment('ADMOB_APP_ID');
  static const String bannerId = String.fromEnvironment('ADMOB_BANNER_ID');
  static const String interstitialId = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');
  static const String rewardId = String.fromEnvironment('ADMOB_REWARDED_ID');

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

  /// Start loading ads after the first dashboard frame, and defer interstitials.
  void onDashboardVisible() {
    if (_dashboardVisible) return;
    _dashboardVisible = true;
    initialize();
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
      await _recordDailyOpenAndCheckStreak(prefs);

      final untilMs = prefs.getInt(_prefKeyRewardAdFreeUntil);
      if (untilMs != null) {
        _rewardAdFreeUntil = DateTime.fromMillisecondsSinceEpoch(untilMs);
      }
      _isLifetimeRemoveAds = prefs.getBool(_prefKeyRemoveAds) ?? false;
      isAdsRemovedNotifier.value =
          _isLifetimeRemoveAds || isRewardAdFreeActive || _isAdFreeToday;

      await SupportService.instance.initIap(
        onRemoveAdsPurchased: _activateLifetimeRemoveAds,
      );

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (!isAdsRemoved) {
          await MobileAds.instance.initialize();
        }
        _isInitialized = true;
        isInitializedNotifier.value = true;

        if (!isAdsRemoved) {
          loadInterstitialAd();
          loadRewardedAd();
        }
      }
    } catch (e) {
      debugPrint('AdService initialization error: $e');
    }
  }

  String _dateKey(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  Future<void> _recordDailyOpenAndCheckStreak(SharedPreferences prefs) async {
    final now = DateTime.now();
    final today = _dateKey(now);
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));

    final lastDate = prefs.getString(_prefKeyLastOpenDate);
    final adFreeStreakDate = prefs.getString(_prefKeyAdFreeStreakDate);

    if (lastDate == today) {
      _isAdFreeToday = adFreeStreakDate == today;
      return;
    }

    int streak;
    if (lastDate == yesterday) {
      streak = (prefs.getInt(_prefKeyStreakDays) ?? 0) + 1;
    } else {
      streak = 1;
    }

    if (streak >= 3) {
      _isAdFreeToday = true;
      await prefs.setString(_prefKeyAdFreeStreakDate, today);
      await prefs.setInt(_prefKeyStreakDays, 0);
    } else {
      _isAdFreeToday = false;
      await prefs.setInt(_prefKeyStreakDays, streak);
    }
    await prefs.setString(_prefKeyLastOpenDate, today);
  }

  Future<void> _activateLifetimeRemoveAds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyRemoveAds, true);
    _isLifetimeRemoveAds = true;
    isAdsRemovedNotifier.value = true;

    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  void markNoFillTodayAndNotify() {
    _noFillThisLaunch = true;
    if (!isNoFillNotifier.value) {
      isNoFillNotifier.value = true;
    }
  }

  Future<void> showNoAdsPopupIfNeeded(BuildContext context) async {
    if (_popupShownThisLaunch) return;
    if (!_isLifetimeRemoveAds && !_isAdFreeToday && !_noFillThisLaunch) {
      return;
    }

    _popupShownThisLaunch = true;
    final prefs = await SharedPreferences.getInstance();
    final step = prefs.getInt(_prefKeyPopupStep) ?? 0;
    await prefs.setInt(_prefKeyPopupStep, (step + 1) % 3);

    if (!context.mounted) return;
    await NoAdsPopup.show(
      context,
      step: step,
      isStreakReward: _isAdFreeToday && !_isLifetimeRemoveAds,
      isAdFreePurchased: _isLifetimeRemoveAds,
    );
  }

  /// Purchase remove ads via Google Play / App Store IAP
  Future<bool> purchaseRemoveAds() async {
    try {
      return await SupportService.instance.buyRemoveAds();
    } catch (e) {
      debugPrint('Error purchasing remove_ads: $e');
      return false;
    }
  }

  /// Restore purchases via store + local prefs
  Future<bool> restorePurchases() async {
    await SupportService.instance.restorePurchases();
    final prefs = await SharedPreferences.getInstance();
    _isLifetimeRemoveAds = prefs.getBool(_prefKeyRemoveAds) ?? false;
    isAdsRemovedNotifier.value =
        _isLifetimeRemoveAds || isRewardAdFreeActive || _isAdFreeToday;
    return isAdsRemoved;
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
    if (!_dashboardVisible ||
        !_isInitialized ||
        isAdsDisabledForSession ||
        !isValidAdUnitId(bannerAdUnitId)) {
      return null;
    }

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
    if (!_dashboardVisible ||
        !_isInitialized ||
        isAdsDisabledForSession ||
        !isValidAdUnitId(interstitialAdUnitId)) {
      return;
    }
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
          markNoFillTodayAndNotify();
          debugPrint('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  void showInterstitialAd({VoidCallback? onDismissed}) {
    if (!_dashboardVisible || !_isInitialized || isAdsRemoved) {
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
    if (isAdsDisabledForSession || !isValidAdUnitId(rewardedAdUnitId)) return;
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
          markNoFillTodayAndNotify();
          debugPrint('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  void showRewardedAd({
    required Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onDismissed,
  }) {
    if (isAdsDisabledForSession) {
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
