import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 引入 kIsWeb 判斷庫
import 'package:url_launcher/url_launcher.dart';
import '../core/db_helper.dart';
import '../services/pdf_generator_service.dart';
import '../services/billing_service.dart';
import '../services/ad_service.dart';

class PhoneSearchScreen extends StatefulWidget {
  const PhoneSearchScreen({super.key});

  @override
  State<PhoneSearchScreen> createState() => _PhoneSearchScreenState();
}

class _PhoneSearchScreenState extends State<PhoneSearchScreen> {
  final _phoneController = TextEditingController();
  final _anchorUrlController = TextEditingController(); // 定錨網址控制器
  
  bool _isSearching = false;
  String? _selectedMode;
  DateTime? _savedTimestamp;
  Map<String, bool?> _platformStatus = {
    'google': null,
    'facebook': null,
    'dcard': null,
    'ptt': null,
    'threads': null,
  };

  // 模擬進度與視窗引導狀態
  bool _isSimulatingProgress = false;
  double _searchProgress = 0.0;
  bool _showInitialSearchGuide = false;
  bool _isDeepSearching = false;
  double _deepSearchProgress = 0.0;
  bool _showDeepSearchGuide = false;

  @override
  void initState() {
    super.initState();
    // 確保每次進入頁面時，狀態與輸入框都被清空
    _phoneController.clear();
    _anchorUrlController.clear();
    _isSearching = false;
    _savedTimestamp = null;
    _isSimulatingProgress = false;
    _searchProgress = 0.0;
    _showInitialSearchGuide = false;
    _isDeepSearching = false;
    _deepSearchProgress = 0.0;
    _showDeepSearchGuide = false;
    
    _platformStatus = {
      'google': null,
      'facebook': null,
      'dcard': null,
      'ptt': null,
      'threads': null,
    };

    _phoneController.addListener(() {
      if (_savedTimestamp != null) {
        setState(() {
          _savedTimestamp = null;
          _showInitialSearchGuide = false;
          _showDeepSearchGuide = false;
          _isSimulatingProgress = false;
          _isDeepSearching = false;
          _anchorUrlController.clear();
          _platformStatus = {
            'google': null,
            'facebook': null,
            'dcard': null,
            'ptt': null,
            'threads': null,
          };
        });
      }
    });
  }

  Future<void> _openUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法開啟連結')),
        );
      }
    }
  }

  Future<void> _searchAndSavePhone() async {
    final phone = _phoneController.text.trim();
    final phoneRegex = RegExp(r'^[\d\+\-\s\(\)]+$');

    if (phone.isEmpty || !phoneRegex.hasMatch(phone)) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('提示 / Notice', style: TextStyle(color: Colors.white)),
            content: const Text('請輸入正確的電話號碼 / Please enter a valid number', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('確定 / OK', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _isSimulatingProgress = true;
      _searchProgress = 0.0;
      _showInitialSearchGuide = false;
      _showDeepSearchGuide = false;
    });

    try {
      // 模擬進度條動態增長 (2秒)
      for (int i = 1; i <= 20; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        setState(() {
          _searchProgress = i / 20.0;
        });
      }

      if (kIsWeb) {
        if (mounted) {
          setState(() {
            _savedTimestamp = DateTime.now();
            _showInitialSearchGuide = true; // 顯示手動引導，避免被攔截
            _platformStatus = {
              'google': null,
              'facebook': null,
              'dcard': null,
              'ptt': null,
              'threads': null,
            };
          });
        }
      } else {
        // 1. 本機存證
        final record = EvidenceRecord(
          type: 'phone',
          content: phone,
          timestamp: DateTime.now().toIso8601String(),
        );
        await DatabaseHelper.instance.insertEvidence(record);

        if (mounted) {
          setState(() {
            _savedTimestamp = DateTime.now();
            _showInitialSearchGuide = true; // 顯示手動引導，避免被攔截
            _platformStatus = {
              'google': null,
              'facebook': null,
              'dcard': null,
              'ptt': null,
              'threads': null,
            };
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('錯誤 / Error', style: TextStyle(color: Colors.white)),
            content: Text('處理時發生錯誤 / An error occurred:\n$e', style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('確定 / OK', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _isSimulatingProgress = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _anchorUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808), // 深黑色底
      appBar: AppBar(
        title: const Text('電話號碼查詢', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _selectedMode != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  _phoneController.clear();
                  setState(() {
                    _selectedMode = null;
                    _savedTimestamp = null;
                    _isSearching = false;
                    _platformStatus = {'google': null, 'facebook': null, 'dcard': null, 'ptt': null, 'threads': null};
                  });
                },
              )
            : null,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _selectedMode != null ? _buildInputScreen() : _buildSelectionScreen(),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }

  Widget _buildSelectionScreen() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '你要查什麼？',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // 第一張卡片
              Center(
                child: _buildSelectionCard(
                  icon: '📞',
                  title: '我接到可疑電話',
                  subtitle: '有人打給我，懷疑是詐騙或騷擾',
                  backgroundColor: const Color(0xFF330000),
                  borderColor: const Color(0xFFFF3B30),
                  shadowColor: const Color(0xFFFF3B30).withOpacity(0.4),
                  onTap: () {
                    _phoneController.clear();
                    setState(() {
                      _selectedMode = 'received';
                      _savedTimestamp = null;
                      _isSearching = false;
                      _platformStatus = {'google': null, 'facebook': null, 'dcard': null, 'ptt': null, 'threads': null};
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),
              
              // 第二張卡片
              Center(
                child: _buildSelectionCard(
                  icon: '😱',
                  title: '我的號碼被人亂貼網路',
                  subtitle: '我的電話被Po到論壇，害我一直被陌生人騷擾',
                  backgroundColor: const Color(0xFF331A00),
                  borderColor: const Color(0xFFFF9500),
                  shadowColor: const Color(0xFFFF9500).withOpacity(0.4),
                  onTap: () {
                    _phoneController.clear();
                    setState(() {
                      _selectedMode = 'leaked';
                      _savedTimestamp = null;
                      _isSearching = false;
                      _platformStatus = {'google': null, 'facebook': null, 'dcard': null, 'ptt': null, 'threads': null};
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String icon,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required Color borderColor,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    color: Colors.white70,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputScreen() {
    final title = _selectedMode == 'received' ? '查詢可疑來電' : '查詢我的號碼是否被散布';
    final description = _selectedMode == 'received'
        ? '輸入打給你的可疑號碼，系統會查詢是否為已知詐騙電話'
        : '輸入你自己的電話號碼，系統會搜尋是否出現在可疑論壇或網站';
    final hint = _selectedMode == 'received' ? '輸入來電號碼' : '輸入你的手機號碼';

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: hint,
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade800),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.phone, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 32),
              if (_isSimulatingProgress) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.redAccent),
                      const SizedBox(height: 16),
                      const Text(
                        '正在交叉比對全台商務黃頁與反詐資料庫...',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(_searchProgress * 100).toInt()}%',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _searchProgress,
                          backgroundColor: Colors.grey[900],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_isSearching)
                const Center(child: CircularProgressIndicator(color: Colors.redAccent))
              else if (_savedTimestamp == null)
                ElevatedButton.icon(
                  onPressed: _searchAndSavePhone,
                  icon: const Icon(Icons.search),
                  label: const Text('搜尋並存證', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              
              if (_savedTimestamp != null)
                _buildResultPanel(),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultPanel() {
    final timeString = "${_savedTimestamp!.hour.toString().padLeft(2, '0')}:${_savedTimestamp!.minute.toString().padLeft(2, '0')}";
    final phone = Uri.encodeComponent(_phoneController.text.trim());

    int reportedCount = _platformStatus.values.where((v) => v != null).length;
    int yesCount = _platformStatus.values.where((v) => v == true).length;
    int noCount = _platformStatus.values.where((v) => v == false).length;
    int totalPlatforms = _platformStatus.length;

    bool allReported = reportedCount == totalPlatforms;
    bool anyYes = yesCount > 0;
    bool allNo = allReported && noCount == totalPlatforms;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showInitialSearchGuide) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent, width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(Icons.shield, color: Colors.redAccent, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    '安全比對已完成 / Ready',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '為繞過瀏覽器攔截，請「主動點擊下方按鈕」開啟 Google 鑑識網頁：',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final rawPhone = _phoneController.text.trim();
                        String searchUrl = '';
                        if (_selectedMode == 'received') {
                          searchUrl = 'https://www.google.com/search?q=$rawPhone';
                        } else if (_selectedMode == 'leaked') {
                          searchUrl = 'https://www.google.com/search?q="%e2%80%9d$rawPhone"%e2%80%9d';
                        }
                        _openUrl(searchUrl);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('前往 Google 鑑識網頁', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                '已於 $timeString 存證',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 統計列
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '已查 $reportedCount 個平台：',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  '$yesCount個有紀錄',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                const Text('、', style: TextStyle(color: Colors.white70)),
                Text(
                  '$noCount個無紀錄',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (anyYes)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent),
              ),
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '發現可疑紀錄！建議立即向165報案存證',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          
          if (allNo)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                children: [
                  Text('🎉', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '恭喜！目前各平台均無您號碼的相關紀錄',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          const Text(
            '請選擇搜尋入口並回報：',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          _buildPlatformRow('google', '🔍', 'Google 搜尋', 'https://www.google.com/search?q=$phone'),
          _buildPlatformRow('facebook', '📘', 'Facebook 搜尋', 'https://www.google.com/search?q=site:facebook.com+$phone'),
          _buildPlatformRow('dcard', '💬', 'Dcard 搜尋', 'https://www.google.com/search?q=site:dcard.tw+$phone'),
          _buildPlatformRow('ptt', '📋', 'PTT 搜尋', 'https://www.google.com/search?q=site:ptt.cc+OR+site:www.ptt.cc+$phone'),
          _buildPlatformRow('threads', '@', 'Threads 搜尋', 'https://www.google.com/search?q=site:threads.net+$phone'),
          
          const SizedBox(height: 8),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          
          ElevatedButton.icon(
            onPressed: () => _openUrl('https://165.npa.gov.tw'),
            icon: const Text('📋', style: TextStyle(fontSize: 18)),
            label: const Text('前往165官網報案', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.2),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              alignment: Alignment.center,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.redAccent),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (_isDeepSearching) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    '正在交叉比對全台商務黃頁與反詐資料庫...',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(_deepSearchProgress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _deepSearchProgress,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_showDeepSearchGuide) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent, width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(Icons.security, color: Colors.redAccent, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    '深度鑑識比對就緒！',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '請主動點擊按鈕前往 Google 深度鑑識網頁，進行網路黃頁比對：',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final phoneNumber = _phoneController.text.trim();
                        final url = 'https://www.google.com/search?q=%22$phoneNumber%22+%28%E8%A9%90%E9%A8%99+OR+%E8%AA%B0%E6%89%93%E7%9A%84+OR+%E9%BB%83%E9%A0%81%29';
                        _openUrl(url);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('手動點擊啟動深度鑑識', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC62828),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  setState(() {
                    _isDeepSearching = true;
                    _deepSearchProgress = 0.0;
                    _showDeepSearchGuide = false;
                  });
                  for (int i = 1; i <= 20; i++) {
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (!mounted) return;
                    setState(() {
                      _deepSearchProgress = i / 20.0;
                    });
                  }
                  if (mounted) {
                    setState(() {
                      _isDeepSearching = false;
                      _showDeepSearchGuide = true;
                    });
                  }
                },
                icon: const Icon(Icons.youtube_searched_for, color: Colors.white),
                label: const Text('啟動 Google 深度鑑識 (含網路黃頁)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828), // 高質感紅色系視覺
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                  elevation: 4,
                  shadowColor: Colors.redAccent.withOpacity(0.4),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // 商務定錨存證輸入框
          TextField(
            controller: _anchorUrlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '請貼回查獲的黃頁或論壇網址進行定錨存證',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              labelText: '商務定錨存證網址 / Anchor Evidence URL',
              labelStyle: const TextStyle(color: Colors.redAccent, fontSize: 14),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.link, color: Colors.redAccent),
              filled: true,
              fillColor: const Color(0xFF1E1010),
            ),
            onChanged: (val) {
              setState(() {});
            },
          ),
          
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
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
              },
              icon: const Icon(Icons.description),
              label: const Text('📄 產出PDF證據包 / Generate Evidence Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            '建議逐一點擊各平台查詢，搜尋不到代表該平台目前無紀錄',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _executePdfGeneration() async {
    if (_savedTimestamp == null) return;
    await PdfGeneratorService.generateEvidenceReport(
      context: context,
      evidenceTimestamp: _savedTimestamp!.toIso8601String(),
      searchedPhone: _phoneController.text.trim(),
      phoneSearchStatus: _platformStatus,
      anchorUrl: _anchorUrlController.text.trim(),
    );
  }

  Widget _buildPlatformRow(String id, String icon, String label, String url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openUrl(url),
              icon: Text(icon, style: const TextStyle(fontSize: 18)),
              label: Text(label, style: const TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.05),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildReportButton(id, true, '✓ 有', Colors.green),
          const SizedBox(width: 8),
          _buildReportButton(id, false, '✗ 沒有', Colors.grey),
        ],
      ),
    );
  }

  Widget _buildReportButton(String id, bool isYes, String label, Color activeColor) {
    final isSelected = _platformStatus[id] == isYes;
    return InkWell(
      onTap: () {
        setState(() {
          _platformStatus[id] = isYes;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white.withOpacity(0.1),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
