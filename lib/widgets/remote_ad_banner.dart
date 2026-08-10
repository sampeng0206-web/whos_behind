import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';

class RemoteAdBanner extends StatelessWidget {
  final bool shouldShow;

  const RemoteAdBanner({
    super.key,
    required this.shouldShow,
  });

  Widget _buildTextFallbackBanner(String targetUrl) {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A1A),
            Colors.red.shade900.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.campaign_rounded,
            color: Colors.redAccent.shade200,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  '廣告版位招租中 / Ad Space For Rent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  '歡迎聯絡：sampeng0206@gmail.com',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.redAccent.shade200,
            size: 20,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    bool isEnabled = true;
    String imageUrl = "";
    String targetUrl = "mailto:sampeng0206@gmail.com";
    String linkType = "mailto";

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      isEnabled = remoteConfig.getBool('ad_banner_enabled');
      imageUrl = remoteConfig.getString('ad_banner_image_url');
      targetUrl = remoteConfig.getString('ad_banner_target_url');
      linkType = remoteConfig.getString('ad_banner_link_type');
    } catch (e) {
      debugPrint("Failed to fetch Firebase Remote Config: $e");
    }

    if (!isEnabled) {
      return const SizedBox.shrink();
    }

    final Widget bannerContent;
    if (imageUrl.isNotEmpty) {
      bannerContent = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          height: 60,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 60,
              color: const Color(0xFF1E1E1E),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildTextFallbackBanner(targetUrl);
          },
        ),
      );
    } else {
      bannerContent = _buildTextFallbackBanner(targetUrl);
    }

    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: GestureDetector(
        onTap: () async {
          if (targetUrl.isNotEmpty) {
            try {
              final uri = Uri.parse(targetUrl);
              if (linkType == 'web') {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                await launchUrl(uri, mode: LaunchMode.platformDefault);
              }
            } catch (e) {
              debugPrint("Failed to launch ad target URL: $e");
            }
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: bannerContent,
        ),
      ),
    );
  }
}
