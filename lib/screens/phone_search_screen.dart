import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/db_helper.dart';

class PhoneSearchScreen extends StatefulWidget {
  const PhoneSearchScreen({super.key});

  @override
  State<PhoneSearchScreen> createState() => _PhoneSearchScreenState();
}

class _PhoneSearchScreenState extends State<PhoneSearchScreen> {
  final _phoneController = TextEditingController();
  bool _isSearching = false;
  String? _selectedMode;
  DateTime? _savedTimestamp;
  Map<String, bool?> _platformStatus = {
    'google': null,
    'facebook': null,
    'dcard': null,
    'ptt': null,
  };

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      if (_savedTimestamp != null) {
        setState(() {
          _savedTimestamp = null;
          _platformStatus = {
            'google': null,
            'facebook': null,
            'dcard': null,
            'ptt': null,
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
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入電話號碼')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // 1. 存證
      final record = EvidenceRecord(
        type: 'phone',
        content: phone,
        timestamp: DateTime.now().toIso8601String(),
      );
      await DatabaseHelper.instance.insertEvidence(record);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('電話號碼已自動存入清單作為證據。請選擇搜尋入口。')),
        );
        setState(() {
          _savedTimestamp = DateTime.now();
          _platformStatus = {
            'google': null,
            'facebook': null,
            'dcard': null,
            'ptt': null,
          };
        });
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
          _isSearching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
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
                  setState(() {
                    _selectedMode = null;
                  });
                },
              )
            : null,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _selectedMode != null ? _buildInputScreen() : _buildSelectionScreen(),
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
                    setState(() {
                      _selectedMode = 'received';
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
                    setState(() {
                      _selectedMode = 'leaked';
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
              if (_isSearching)
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
          _buildPlatformRow('facebook', '📘', 'Facebook 搜尋', 'https://www.facebook.com/search/top?q=$phone'),
          _buildPlatformRow('dcard', '💬', 'Dcard 搜尋', 'https://www.dcard.tw/search?q=$phone'),
          _buildPlatformRow('ptt', '📋', 'PTT 搜尋', 'https://www.google.com/search?q=site:ptt.cc+$phone'),
          
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
          const Text(
            '建議逐一點擊各平台查詢，搜尋不到代表該平台目前無紀錄',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
