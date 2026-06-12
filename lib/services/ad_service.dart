import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'billing_service.dart';

class AdService {
  static InterstitialAd? _interstitialAd;

  static Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint("AdMob not supported on this platform.");
      return;
    }
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint("AdMob initialization failed: $e");
    }
  }

  static Future<void> loadInterstitialAd() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    if (await BillingService.isPremiumUser()) {
      debugPrint("Premium user, skipping interstitial ad load.");
      return;
    }

    final adUnitId = Platform.isIOS
        ? 'ca-app-pub-3755777658581400/5746783718'
        : 'ca-app-pub-3755777658581400/5746783718';

    try {
      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            debugPrint('InterstitialAd loaded successfully.');
            _interstitialAd = ad;
            _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (InterstitialAd ad) {
                debugPrint('InterstitialAd showed full screen content.');
              },
              onAdDismissedFullScreenContent: (InterstitialAd ad) {
                debugPrint('InterstitialAd dismissed full screen content.');
                ad.dispose();
                _interstitialAd = null;
                loadInterstitialAd(); // Preload next
              },
              onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
                debugPrint('InterstitialAd failed to show full screen content: $error');
                ad.dispose();
                _interstitialAd = null;
                loadInterstitialAd(); // Preload next
              },
              onAdImpression: (InterstitialAd ad) {
                debugPrint('InterstitialAd impression recorded.');
              },
            );
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('InterstitialAd failed to load: $error');
            _interstitialAd = null;
          },
        ),
      );
    } catch (e) {
      debugPrint("Failed to load InterstitialAd: $e");
    }
  }

  static Future<void> showInterstitialAd() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    if (await BillingService.isPremiumUser()) {
      debugPrint("Premium user, skipping interstitial ad show.");
      return;
    }

    if (_interstitialAd != null) {
      await _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      debugPrint("Interstitial ad not loaded yet.");
    }
  }
}

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumAndLoadAd();
  }

  Future<void> _checkPremiumAndLoadAd() async {
    // Hide ads for premium users
    _isPremium = await BillingService.isPremiumUser();
    if (_isPremium) return;

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      final adUnitId = Platform.isIOS
          ? 'ca-app-pub-3755777658581400/6122188232' // production iOS banner ID
          : 'ca-app-pub-3755777658581400/6122188232'; // production Android banner ID

      _bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted) {
              setState(() {
                _isAdLoaded = true;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('BannerAd failed to load: $error');
            ad.dispose();
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      debugPrint("Failed to load BannerAd: $e");
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPremium || !_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

