import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ImageSearchService {
  /// Uploads an image to catbox.moe anonymously and returns the public URL.
  /// Note: catbox.moe is a free, keyless, temporary file hosting service.
  static Future<String?> uploadImage(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://catbox.moe/user/api.php'),
      );

      request.fields['reqtype'] = 'fileupload';
      request.files.add(
        await http.MultipartFile.fromPath(
          'fileToUpload',
          imageFile.path,
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        // The response body contains the public URL as plain text
        if (responseData.startsWith('http')) {
          return responseData.trim();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Searches the given image URL using Google Lens.
  static Future<void> searchWithGoogleLens(String imageUrl) async {
    final searchUrl = Uri.parse('https://lens.google.com/uploadbyurl?url=${Uri.encodeComponent(imageUrl)}');
    
    if (!await launchUrl(searchUrl, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $searchUrl');
    }
  }
}
