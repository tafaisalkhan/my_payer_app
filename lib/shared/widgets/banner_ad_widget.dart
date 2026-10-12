import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mynamaz_scheduler/core/ads/ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  final AdSize size;
  final EdgeInsetsGeometry padding;

  const BannerAdWidget({
    super.key,
    this.size = AdSize.banner,
    this.padding = const EdgeInsets.symmetric(vertical: 8.0),
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    _bannerAd = AdService.instance.createBannerAd(
      size: widget.size,
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint('BannerAd failed to load: ${error.message}');
        ad.dispose();
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
            _bannerAd = null;
          });
        }
      },
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdService.instance.isAdsRemovedNotifier,
      builder: (context, isAdsRemoved, _) {
        if (isAdsRemoved || !_isAdLoaded || _bannerAd == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: widget.padding,
          child: Center(
            child: Container(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
          ),
        );
      },
    );
  }
}
