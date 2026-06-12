import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:printing/printing.dart';
import '../constants/evidence_capture_constants.dart';
import '../services/pdf_generator_service.dart';
import '../services/billing_service.dart';
import 'package:provider/provider.dart';

class EvidenceCaptureScreen extends StatefulWidget {
  const EvidenceCaptureScreen({super.key});

  @override
  State<EvidenceCaptureScreen> createState() => _EvidenceCaptureScreenState();
}

class _EvidenceCaptureScreenState extends State<EvidenceCaptureScreen> {
  late final WebViewController _webViewController;
  final TextEditingController _urlController = TextEditingController(text: 'https://www.google.com');
  final GlobalKey _boundaryKey = GlobalKey();
  final List<Map<String, dynamic>> _captures = []; // { 'imageBytes': Uint8List, 'url': String, 'timestamp': String, 'tags': List<String> }

  bool _isLoadingPage = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoadingPage = true;
              _urlController.text = url;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoadingPage = false;
              _urlController.text = url;
            });
          },
          onWebResourceError: (error) {
            debugPrint("WebView Error: ${error.description}");
          },
        ),
      );
    _webViewController.loadRequest(Uri.parse('https://www.google.com'));
  }

  void _loadUrl() {
    String text = _urlController.text.trim();
    if (text.isEmpty) return;
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      text = 'https://$text';
    }
    _urlController.text = text;
    FocusScope.of(context).unfocus();
    _webViewController.loadRequest(Uri.parse(text));
  }

  Future<void> _captureCurrentView() async {
    if (_captures.length >= EvidenceCaptureConstants.maxCaptures) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已達最大擷取數量限制（6筆）')),
      );
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      // 250ms delay to allow WebView drawing thread to sync before capture
      await Future.delayed(const Duration(milliseconds: 250));

      final RenderRepaintBoundary? boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("Failed to find RenderRepaintBoundary");
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception("Failed to serialize screenshot to PNG");
      }
      final Uint8List imageBytes = byteData.buffer.asUint8List();

      final String currentUrl = await _webViewController.currentUrl() ?? _urlController.text;
      final String timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      if (!mounted) return;

      // Show Tag Selection Dialog
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _TagSelectionDialog(
          screenshot: imageBytes,
        ),
      );

      if (result != null && result['confirmed'] == true) {
        setState(() {
          _captures.add({
            'imageBytes': imageBytes,
            'url': currentUrl,
            'timestamp': timestamp,
            'tags': result['tags'] as List<String>,
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('擷取成功！目前已有 ${_captures.length} 筆截圖。')),
        );
      }
    } catch (e) {
      debugPrint("Screenshot Capture Failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('擷取畫面失敗：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _deleteCapture(int index) {
    setState(() {
      _captures.removeAt(index);
    });
  }

  void _showPdfConfirmDialog(BuildContext screenContext) {
    bool isChecked = false;
    const String _pdfConfirmMessage = '本次查詢與報告產出之對象資料，為您本人之相關權益爭議所需，並非用於查詢、騷擾或調查與本案無關之第三人。';

    showDialog(
      context: screenContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                '產出 PDF 前確認 / PDF Declaration',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    _pdfConfirmMessage,
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text(
                      '我確認：這是我本人權益相關之資料',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    value: isChecked,
                    activeColor: const Color(0xFF9F75FF),
                    onChanged: (val) {
                      setState(() {
                        isChecked = val ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: isChecked
                      ? () async {
                          Navigator.pop(dialogContext); // Close confirmation dialog
                          
                          // Grace period / Premium check
                          final isGrace = await BillingService.checkGracePeriod();
                          if (isGrace) {
                            await _executePdfGeneration();
                          } else {
                            final isPremium = await BillingService.isPremiumUser();
                            if (isPremium) {
                              await _executePdfGeneration();
                            } else {
                              if (screenContext.mounted) {
                                BillingService.showPaywallDialog(screenContext, () async {
                                  await _executePdfGeneration();
                                });
                              }
                            }
                          }
                        }
                      : null,
                  child: Text(
                    '確認並產生 PDF',
                    style: TextStyle(
                      color: isChecked ? const Color(0xFF9F75FF) : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executePdfGeneration() async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final result = await PdfGeneratorService.generateWebEvidenceReport(
      context: context,
      captures: _captures,
      evidenceTimestamp: timestamp,
    );

    if (result != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EvidenceCaptureResultScreen(
            pdfBytes: result['bytes'] as Uint8List,
            sha256Hash: result['sha256'] as String,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canExportPdf = _captures.length >= EvidenceCaptureConstants.minCaptures &&
        _captures.length <= EvidenceCaptureConstants.maxCaptures;

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        title: const Text(
          EvidenceCaptureConstants.pageTitle,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top URL input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF141414),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: '貼上爭議網址 / Paste URL',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        ),
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _loadUrl(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF9F75FF)),
                    onPressed: _loadUrl,
                  ),
                ],
              ),
            ),

            // Operational guide banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF2E1A47).withOpacity(0.2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      EvidenceCaptureConstants.guideMessage,
                      style: const TextStyle(color: Color(0xFFC3B0E8), fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            // Webview display area with RepaintBoundary
            Expanded(
              child: Stack(
                children: [
                  RepaintBoundary(
                    key: _boundaryKey,
                    child: WebViewWidget(controller: _webViewController),
                  ),
                  if (_isLoadingPage)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black38,
                        child: const Center(
                          child: CircularProgressIndicator(color: Color(0xFF9F75FF)),
                        ),
                      ),
                    ),
                  if (_isCapturing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text('正在安全擷取快照中...', style: TextStyle(color: Colors.white, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Captured records preview strip
            if (_captures.isNotEmpty)
              Container(
                height: 100,
                color: const Color(0xFF121212),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _captures.length,
                  itemBuilder: (context, index) {
                    final cap = _captures[index];
                    final tags = cap['tags'] as List<String>;
                    final tagText = tags.isNotEmpty ? tags.join(', ') : '無標籤';

                    return Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF2E1A47)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.memory(
                              cap['imageBytes'] as Uint8List,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                tagText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 8),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => _deleteCapture(index),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close, color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            left: 2,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E1A47),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Bottom action panel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF141414),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingPage || _isCapturing ? null : _captureCurrentView,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('擷取此畫面', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E1A47),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[900],
                        disabledForegroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF9F75FF), width: 1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canExportPdf ? () => _showPdfConfirmDialog(context) : null,
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: Text(
                        '產出 PDF 報告 (${_captures.length}/$canExportPdfString)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9F75FF),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[900],
                        disabledForegroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get canExportPdfString => '${EvidenceCaptureConstants.minCaptures}~${EvidenceCaptureConstants.maxCaptures}張';
}

class _TagSelectionDialog extends StatefulWidget {
  final Uint8List screenshot;
  const _TagSelectionDialog({required this.screenshot});

  @override
  State<_TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<_TagSelectionDialog> {
  final List<String> _selectedTags = [];
  final TextEditingController _customTagController = TextEditingController();
  bool _isCustomSelected = false;

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '設定事件節點標籤 / Set Tag',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  widget.screenshot,
                  height: 110,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '請勾選此畫面所屬節點（可複選）：',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: EvidenceCaptureConstants.nodeTags.map((tag) {
                final isSelected = tag == '其他' ? _isCustomSelected : _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  selectedColor: const Color(0xFF9F75FF).withOpacity(0.3),
                  checkmarkColor: const Color(0xFF9F75FF),
                  backgroundColor: const Color(0xFF2E2E2E),
                  labelStyle: TextStyle(color: isSelected ? const Color(0xFF9F75FF) : Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSelected ? const Color(0xFF9F75FF) : Colors.white12),
                  ),
                  onSelected: (selected) {
                    if (tag == '其他') {
                      setState(() {
                        _isCustomSelected = selected;
                      });
                    } else {
                      _toggleTag(tag);
                    }
                  },
                );
              }).toList(),
            ),
            if (_isCustomSelected) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customTagController,
                maxLength: EvidenceCaptureConstants.maxCustomTagLength,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '輸入自訂標籤 (限10字)',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                  counterStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                  filled: true,
                  fillColor: const Color(0xFF2E2E2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, {'confirmed': false}),
                    child: const Text('捨棄此截圖', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final finalTags = List<String>.from(_selectedTags);
                      if (_isCustomSelected) {
                        String customText = _customTagController.text.trim();
                        // Defensively limit custom tag to 10 characters to prevent PDF overflow
                        if (customText.length > EvidenceCaptureConstants.maxCustomTagLength) {
                          customText = customText.substring(0, EvidenceCaptureConstants.maxCustomTagLength);
                        }
                        if (customText.isNotEmpty) {
                          finalTags.add(customText);
                        }
                      }
                      if (finalTags.isEmpty) {
                        finalTags.add('未標記');
                      }
                      Navigator.pop(context, {
                        'confirmed': true,
                        'tags': finalTags,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9F75FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('確認存檔', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EvidenceCaptureResultScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String sha256Hash;

  const EvidenceCaptureResultScreen({
    super.key,
    required this.pdfBytes,
    required this.sha256Hash,
  });

  void _sharePdf(BuildContext context) async {
    // Save/Share using name containing the SHA-256 fingerprint for verification
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Evidence_${sha256Hash.substring(0, 16)}.pdf',
    );
  }

  void _copyHash(BuildContext context) {
    // Copy SHA-256 hash to clipboard
    Clipboard.setData(ClipboardData(text: sha256Hash));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已複製 SHA-256 數位指紋。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        title: const Text('存證報告生成成功', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            // Pop back to the dashboard screen
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF9F75FF),
                size: 72,
              ),
              const SizedBox(height: 24),
              const Text(
                '數位存證報告封裝完成',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '該報告已加密存放在您的本機裝置沙盒中，全程不對外公開傳輸。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 32),
              
              // SHA-256 Panel
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF9F75FF).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🔐 SHA-256 數位指紋 (防偽驗證)',
                          style: TextStyle(color: Color(0xFFC3B0E8), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        InkWell(
                          onTap: () => _copyHash(context),
                          child: const Icon(Icons.copy, color: Color(0xFF9F75FF), size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      sha256Hash,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '※ 雜湊值不直接印在 PDF 檔案內以防二進位破壞。此指紋在檔案產出時同步計算，能保證檔案在未來作司法用途時「未經任何二進位竄改」。',
                      style: TextStyle(color: Colors.grey, fontSize: 10, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              ElevatedButton.icon(
                onPressed: () => _sharePdf(context),
                icon: const Icon(Icons.share),
                label: const Text('分享 / 儲存 PDF 存證信', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9F75FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('返回主畫面'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
