import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class EulaConsentScreen extends StatefulWidget {
  final bool isReadOnlyMode;

  const EulaConsentScreen({
    super.key,
    this.isReadOnlyMode = false,
  });

  @override
  State<EulaConsentScreen> createState() => _EulaConsentScreenState();
}

class _EulaConsentScreenState extends State<EulaConsentScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _isChecked = false;

  @override
  void initState() {
    super.initState();
    if (widget.isReadOnlyMode) {
      _hasScrolledToBottom = true;
    } else {
      _scrollController.addListener(_scrollListener);
      // Wait for layout to check if scrolling is needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          if (maxScroll <= 0) {
            setState(() {
              _hasScrolledToBottom = true;
            });
          }
        }
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll <= 0 || currentScroll >= maxScroll * 0.9) {
        if (!_hasScrolledToBottom) {
          setState(() {
            _hasScrolledToBottom = true;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _acceptEula() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasAcceptedEULA', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          '服務條款與免責聲明',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: widget.isReadOnlyMode,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '誰在亂搞？App 服務條款與免責聲明',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '歡迎使用「誰在亂搞？」（以下稱「本工具」）。在開始使用前，請詳細閱讀以下條款。當您勾選同意並開始使用，即表示您已閱讀、理解並同意接受本條款之全部內容。',
                        style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '一、服務性質',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '本工具提供圖片反向搜尋、電話號碼查詢、證據保存與 PDF 報告產出等功能，目的為協助使用者進行自我權益防護之初步調查與證據整理，並非具有公權力之鑑定、偵查或司法調查工具。',
                        style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '二、使用範圍與限制',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '本工具僅供個人自身權益防護之鑑識使用，若用戶冒用他人資料進行查詢，須自行承擔相關法律責任。\n\n'
                        '使用者應確保所輸入、上傳之圖片、電話號碼、文字內容等資料，皆與使用者本身之權益爭議直接相關，不得用於騷擾、跟蹤、侵犯他人隱私或其他違法目的。',
                        style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '三、查詢結果之限制',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '本工具透過第三方公開資料來源（如 Google、Bing、TinEye 等圖片搜尋引擎及公開資料庫）進行查詢，所呈現之結果僅供參考，本工具及其開發者不保證查詢結果之即時性、完整性或正確性。',
                        style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '四、PDF 證據報告之性質',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '本工具產出之 PDF 證據報告，係依使用者操作當下所擷取之公開資料、GPS 定位、時間戳記等資訊整理而成，僅作為使用者自行保存證據、提交相關單位（如警察機關、法院、消費者保護單位）參考之用，不具有法律上鑑定報告之效力，最終是否採信仍由受理單位自行判斷。',
                        style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '五、免責聲明',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '本工具開發者已盡力確保功能正常運作，惟對於：\n'
                        '1. 因第三方服務（如圖片搜尋引擎、電信業者資料庫）異動或中斷所造成之查詢結果誤差或無法使用；\n'
                        '2. 使用者依據查詢結果所做出之任何決定或行動；\n'
                        '3. 因使用者自行輸入錯誤資料所導致之任何損失或爭議；\n'
                        '開發者均不負擔任何法律責任。',
                        style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '六、隱私權保護',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '本工具重視使用者隱私，相關資料蒐集、使用與保護方式，請參閱本工具之隱私權政策。',
                        style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '七、條款修訂',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '開發者保留隨時修訂本服務條款之權利，修訂後將於 App 內公告，使用者持續使用本工具即視為同意修訂後之條款。',
                        style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '八、準據法與管轄',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '本條款之解釋與適用，以及與本條款有關之爭議，均應依照中華民國法律予以處理，並以台灣台北地方法院為第一審管轄法院。',
                        style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!widget.isReadOnlyMode) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                color: Colors.black26,
                child: CheckboxListTile(
                  title: const Text(
                    '我已閱讀並同意上述 EULA 服務條款與免責聲明',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                  subtitle: !_hasScrolledToBottom
                      ? const Text(
                          '請先捲動閱讀完整內容',
                          style: TextStyle(fontSize: 11, color: Colors.redAccent),
                        )
                      : null,
                  value: _isChecked,
                  activeColor: Colors.red,
                  onChanged: _hasScrolledToBottom
                      ? (val) {
                          setState(() {
                            _isChecked = val ?? false;
                          });
                        }
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isChecked ? Colors.red : Colors.grey[800],
                      foregroundColor: _isChecked ? Colors.white : Colors.white30,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: _isChecked ? 4 : 0,
                    ),
                    onPressed: _isChecked ? _acceptEula : null,
                    child: const Text(
                      '同意並開始使用',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '關閉',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
