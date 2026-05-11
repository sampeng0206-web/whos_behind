import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import '../services/image_search_service.dart';
import '../core/db_helper.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  Future<void> _searchAndSaveImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final File originalFile = File(pickedFile.path);
      
      // --- 1. 影像處理與存證 ---
      final img.Image? originalImage = img.decodeImage(await originalFile.readAsBytes());
      File fileToUpload = originalFile;

      if (originalImage != null) {
        final now = DateTime.now();
        final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
        final timeString = formatter.format(now);

        // 加上時間戳記
        img.drawString(
          originalImage,
          timeString,
          font: img.arial24,
          x: originalImage.width - 250, 
          y: originalImage.height - 40,
          color: img.ColorRgb8(255, 0, 0),
        );

        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'evidence_${now.millisecondsSinceEpoch}.jpg';
        final savedImagePath = path.join(directory.path, fileName);
        
        final File savedFile = File(savedImagePath);
        await savedFile.writeAsBytes(img.encodeJpg(originalImage));
        
        // 存入資料庫
        final record = EvidenceRecord(
          type: 'image',
          imagePath: savedImagePath,
          timestamp: now.toIso8601String(),
        );
        await DatabaseHelper.instance.insertEvidence(record);
        
        fileToUpload = savedFile;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('圖片已自動存入清單作為證據。準備上傳搜圖...')),
          );
        }
      }

      // --- 2. 上傳與搜尋 ---
      final String? imageUrl = await ImageSearchService.uploadImage(fileToUpload);
      
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await ImageSearchService.searchWithGoogleLens(imageUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('圖片上傳失敗，請稍後再試。')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發生錯誤: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('圖片被盜用查詢'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '以圖搜圖並自動存證',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '懷疑照片被盜用？上傳圖片後，系統會自動押上時間戳並存證，同時透過 Google Lens 幫您在網路上尋找相似的圖片，看看是否出現在可疑的網站上。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            if (_isProcessing)
              const Column(
                children: [
                  SizedBox(height: 32),
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('圖片處理與上傳中... 請稍候', style: TextStyle(color: Colors.grey)),
                ],
              )
            else ...[
              ElevatedButton.icon(
                onPressed: () => _searchAndSaveImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('從相簿選擇圖片搜尋'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _searchAndSaveImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('拍照搜尋'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
