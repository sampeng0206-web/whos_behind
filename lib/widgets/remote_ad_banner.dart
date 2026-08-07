import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';

class RemoteAdBanner extends StatelessWidget {
  final bool shouldShow;

  const RemoteAdBanner({
    super.key,
    required this.shouldShow,
  });

  @override
  Widget build(BuildContext context) {
    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final remoteConfig = FirebaseRemoteConfig.instance;
    final bool enabled = remoteConfig.getBool('ad_banner_enabled');
    final String imageUrl = remoteConfig.getString('ad_banner_image_url');
    final String targetUrl = remoteConfig.getString('ad_banner_target_url');
    final String linkType = remoteConfig.getString('ad_banner_link_type');

    if (!enabled || imageUrl.isEmpty) {
      return const SizedBox.shrink();
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
          child: ClipRRect(
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
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }
}
