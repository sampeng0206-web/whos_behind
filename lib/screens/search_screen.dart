import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../services/pdf_generator_service.dart';
import '../services/billing_service.dart';
import '../services/ad_service.dart';

class SearchScreen extends StatefulWidget {
  final bool autoOpenImagePicker;
  const SearchScreen({super.key, this.autoOpenImagePicker = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenImagePicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickImage(ImageSource.gallery);
      });
    }
  }
  
  XFile? _selectedImage;
  String? _evidenceTimestamp;
  int _searchCount = 0;

  bool _isUploading = false;
  bool _uploadFailed = false;
  bool _hasAutoOpened = false;
  String? _uploadErrorMessage;
  String? _uploadedImageUrl;
  final Set<String> _clickedPlatforms = {};

  String? _selectedObservation;
  final TextEditingController _otherObservationController = TextEditingController();
  final List<String> _observationOptions = [
    '發現盜圖 / Image misuse detected',
    '出現於新聞或公開媒體 / Found in news or public media',
    '未發現相符結果 / No results found',
    '其他 / Other'
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
          _evidenceTimestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
          _searchCount = 0;
          _uploadedImageUrl = null;
          _isUploading = false;
          _uploadFailed = false;
          _hasAutoOpened = false;
          _uploadErrorMessage = null;
          _clickedPlatforms.clear();
          _selectedObservation = null;
          _otherObservationController.clear();
        });
        _uploadToCloudinary(pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('讀取圖片失敗：$e')),
        );
      }
    }
  }

  Future<void> _uploadToCloudinary(XFile file) async {
    if (mounted) {
      setState(() {
        _isUploading = true;
        _uploadFailed = false;
        _uploadErrorMessage = null;
      });
    }

    try {
      final bytes = await file.readAsBytes();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/dkdcf7h3l/image/upload'),
      );
      request.fields['upload_preset'] = 'whos_behind_upload';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'upload.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String link = data['secure_url'];
        if (mounted) {
          setState(() {
            _uploadedImageUrl = link;
            _isUploading = false;
          });
          _autoOpenSearchPlatforms(link);
        }
      } else {
        throw Exception('${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上傳失敗：$errorMsg')),
        );
        setState(() {
          _isUploading = false;
          _uploadFailed = true;
          _uploadErrorMessage = errorMsg;
        });
      }
    }
  }

  Future<void> _autoOpenSearchPlatforms(String imageUrl) async {
    final encodedUrl = Uri.encodeComponent(imageUrl);
    final platforms = [
      {'id': 'google_lens', 'url': 'https://lens.google.com/uploadbyurl?url=$encodedUrl'},
      {'id': 'tineye', 'url': 'https://tineye.com/search?url=$encodedUrl'},
      {'id': 'bing', 'url': 'https://www.bing.com/images/search?q=imgurl:$encodedUrl&view=detailv2&iss=sbi'},
      {'id': 'google_images', 'url': 'https://www.google.com/searchbyimage?image_url=$encodedUrl'},
    ];

    for (var p in platforms) {
      if (mounted) {
        setState(() {
          if (!_clickedPlatforms.contains(p['id']!)) {
            _searchCount++;
            _clickedPlatforms.add(p['id']!);
          }
        });
      }
      try {
        await launchUrl(Uri.parse(p['url']!), mode: LaunchMode.externalApplication);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (mounted) {
      setState(() {
        _hasAutoOpened = true;
      });
    }
  }

  Future<void> _openPlatform(String url, String platformId) async {
    if (mounted) {
      setState(() {
        if (!_clickedPlatforms.contains(platformId)) {
          _searchCount++;
          _clickedPlatforms.add(platformId);
        }
      });
    }

    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法開啟連結')),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法開啟連結')),
        );
      }
    }
  }

  Future<void> _generatePdf() async {
    if (_selectedImage == null) return;
    
    final isGrace = await BillingService.checkGracePeriod();
    if (isGrace) {
      await _executePdfGeneration();
    } else {
      final isPremium = await BillingService.isPremiumUser();
      if (isPremium) {
        await _executePdfGeneration();
      } else {
        if (mounted) {
          BillingService.showPaywallDialog(context, () async {
            await _executePdfGeneration();
          });
        }
      }
    }
  }

  Future<void> _executePdfGeneration() async {
    await PdfGeneratorService.generateEvidenceReport(
      context: context,
      selectedImage: _selectedImage!,
      evidenceTimestamp: _evidenceTimestamp ?? '',
      uploadedImageUrl: _uploadedImageUrl,
      selectedObservation: _selectedObservation,
      otherObservation: _otherObservationController.text.trim(),
    );
  }

  Widget _buildPlatformCard({
    required IconData icon,
    required String title,
    required String desc,
    required String url,
    required String platformId,
  }) {
    final bool isReady = _uploadedImageUrl != null;
    final bool isClicked = _clickedPlatforms.contains(platformId);

    Widget? extraWidget;
    if (isClicked) {
      extraWidget = const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text('已開啟搜尋，請查看新視窗\n若未找到結果代表：\n系統目前未搜尋到被盜用紀錄\n（不包含私密社團與私人Line群組）', style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5)),
      );
    }

    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isReady ? Colors.white24 : Colors.transparent),
      ),
      elevation: 2,
      child: InkWell(
        onTap: isReady ? () => _openPlatform(url, platformId) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: isReady ? Colors.white : Colors.grey[600], size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: isReady ? Colors.white : Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 13), overflow: TextOverflow.ellipsis),
                    if (extraWidget != null) extraWidget,
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: isReady ? Colors.grey : Colors.grey[800]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required IconData icon,
    required String title,
    required String desc,
    required String url,
  }) {
    return Card(
      color: Colors.blue.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => _openUrl(url),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(color: Colors.blueGrey, fontSize: 13), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadState() {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '上傳你懷疑被盜用的照片，\n系統會自動存證並開啟多平台以圖搜圖',
              style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: const Text('📷 上傳圖片', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsBox() {
    if (_isUploading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        child: const Column(
          children: [
            CircularProgressIndicator(color: Colors.redAccent),
            SizedBox(height: 12),
            Text('⏳ 正在上傳圖片...', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (_uploadFailed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        child: Text('❌ 上傳失敗：${_uploadErrorMessage ?? "請重試"}', style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      );
    }

    if (_uploadedImageUrl != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
        ),
        child: Text(
          _hasAutoOpened ? '搜尋已在瀏覽器開啟，確認證據後請回本頁面產出 PDF。' : '✅ 圖片已就緒，正在開啟搜尋平台...',
          style: const TextStyle(color: Colors.greenAccent, height: 1.5, fontWeight: FontWeight.bold, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildResultState() {
    return Column(
      children: [
        Card(
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black26,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(
                            _selectedImage!.path,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50)),
                          )
                        : Image.file(
                            File(_selectedImage!.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50)),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '已於 $_evidenceTimestamp 存證',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        _buildSearchResultsBox(),

        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('🔍 以圖搜圖平台', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        
        _buildPlatformCard(
          icon: Icons.search,
          title: 'Google Lens',
          desc: '搜尋全網，含FB/IG公開貼文',
          url: 'https://lens.google.com/uploadbyurl?url=${_uploadedImageUrl != null ? Uri.encodeComponent(_uploadedImageUrl!) : ''}',
          platformId: 'google_lens',
        ),
        _buildPlatformCard(
          icon: Icons.remove_red_eye,
          title: 'TinEye',
          desc: '833億張圖片反向比對',
          url: 'https://tineye.com/search?url=${_uploadedImageUrl != null ? Uri.encodeComponent(_uploadedImageUrl!) : ''}',
          platformId: 'tineye',
        ),
        _buildPlatformCard(
          icon: Icons.image_search,
          title: 'Bing Visual Search',
          desc: '微軟圖像搜尋引擎',
          url: 'https://www.bing.com/images/search?q=imgurl:${_uploadedImageUrl != null ? Uri.encodeComponent(_uploadedImageUrl!) : ''}&view=detailv2&iss=sbi',
          platformId: 'bing',
        ),
        _buildPlatformCard(
          icon: Icons.travel_explore,
          title: 'Google Images',
          desc: '對詐騙圖片辨識率最高',
          url: 'https://www.google.com/searchbyimage?image_url=${_uploadedImageUrl != null ? Uri.encodeComponent(_uploadedImageUrl!) : ''}',
          platformId: 'google_images',
        ),
        
        if (_searchCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              '✅ 已開啟 $_searchCount 個搜尋平台',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('查圖片是否被盜用？', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (_selectedImage == null)
                      _buildUploadState()
                    else
                      _buildResultState(),
                      
                    const SizedBox(height: 32),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('📢 向平台檢舉盜圖', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildReportCard(
                      icon: Icons.facebook,
                      title: '向 Facebook 檢舉',
                      desc: '開啟FB官方檢舉頁面',
                      url: 'https://www.facebook.com/help/reportlinks',
                    ),
                    _buildReportCard(
                      icon: Icons.camera_alt,
                      title: '向 Instagram 檢舉',
                      desc: '開啟IG官方檢舉頁面',
                      url: 'https://help.instagram.com/contact/372592039593085',
                    ),
                    _buildReportCard(
                      icon: Icons.alternate_email,
                      title: '向 Threads 檢舉',
                      desc: '開啟 Threads 官方智慧財產權檢舉頁面',
                      url: 'https://help.instagram.com/contact/372592039497531',
                    ),
                    _buildReportCard(
                      icon: Icons.security,
                      title: '向165檢舉',
                      desc: '台灣反詐騙專線官網',
                      url: 'https://165.npa.gov.tw/',
                    ),
                    
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                            _evidenceTimestamp = null;
                            _searchCount = 0;
                            _uploadedImageUrl = null;
                            _isUploading = false;
                            _uploadFailed = false;
                            _hasAutoOpened = false;
                            _uploadErrorMessage = null;
                            _clickedPlatforms.clear();
                            _selectedObservation = null;
                            _otherObservationController.clear();
                          });
                        },
                        icon: const Icon(Icons.refresh, color: Colors.grey),
                        label: const Text('重新選擇圖片', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              if (_selectedImage != null)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedObservation,
                          hint: const Text('選擇查核結果 / Select Observation', style: TextStyle(color: Colors.grey)),
                          dropdownColor: Colors.grey[850],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: _observationOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedObservation = newValue;
                            });
                          },
                        ),
                        if (_selectedObservation == '其他 / Other') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _otherObservationController,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (value) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Enter your observation in English...',
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.grey[900],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (_selectedObservation != null &&
                                    (_selectedObservation != '其他 / Other' ||
                                        _otherObservationController.text.trim().isNotEmpty))
                                ? _generatePdf
                                : null,
                            icon: const Icon(Icons.description),
                            label: const Text('📄 產出PDF證據包 / Generate Evidence Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[800],
                              disabledForegroundColor: Colors.grey[500],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }
}
