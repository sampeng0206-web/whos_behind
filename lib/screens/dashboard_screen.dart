import 'package:flutter/material.dart';
import 'dart:math';
import 'search_screen.dart';
import 'phone_search_screen.dart';
import 'eula_consent_screen.dart';
import 'trust_scan_screen.dart';
import 'rental_risk_screen.dart';
import 'evidence_capture_screen.dart';
import '../services/ad_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _searchCardKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showRecordsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.security, color: Colors.greenAccent, size: 48),
            SizedBox(height: 16),
            Text(
              'Cloud Storage Secured.\n雲端存證紀錄已受 Google Firebase 加密保護，目前尚無歷史紀錄。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, height: 1.5, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉 / Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showLegalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('法律救濟權益 / Legal Rights', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '• 肖像權侵害 (Right of Portrait):\n未經同意於 Facebook, Instagram, Threads, PTT 等平台使用照片已侵害民法第18、195條肖像權。\n\n'
                '• 個資法違反 (PDPA Violation):\n於 Facebook, Instagram, Threads, PTT 等平台散布聯絡方式等屬違反個人資料保護法。\n\n'
                '• 損害賠償責任 (Liability for Damages):\n被害人得請求移除內容並請求精神慰撫金。\n\n'
                '• 2年請求權時效 (Statute of Limitations):\n侵權行為損害賠償請求權，自請求權人知有損害及賠償義務人時起，二年間不行使而消滅。',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                '※ 技術搜尋範圍重要提示（Important Technical Notice）',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, height: 1.5),
              ),
              SizedBox(height: 8),
              Text(
                '【查詢範圍聲明 / Search Scope Notice】\n'
                '本工具之自動化搜圖技術基於全球公開網路（Public Web）之大數據比對。查詢範圍不包括通訊媒體之私密領域（如 LINE 私密群組、WeChat 封閉對話）以及社群媒體之非公開數據（如 Facebook 封閉型社團、Instagram/Threads 隱私不公開帳號/限時動態）。\n\n'
                'This automated verification tool scans publicly indexed web data only. The search scope does not cover private communication channels (e.g., private LINE/WeChat groups) or closed social media sectors (e.g., Facebook Closed Groups, Instagram/Threads Private Accounts/Stories).',
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EulaConsentScreen(isReadOnlyMode: true),
                ),
              );
            },
            child: const Text('服務條款與免責聲明 (EULA)', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了 / Got it', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // 生成隨機的暗紅色星點粒子
    final particles = List.generate(100, (index) {
      final random = Random(index);
      final double dotSize = random.nextDouble() * 4 + 1.5;
      return Positioned(
        left: random.nextDouble() * size.width,
        top: random.nextDouble() * size.height,
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(random.nextDouble() * 0.6 + 0.3),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.6),
                blurRadius: 4,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFF080808), // 深黑色底
      body: Stack(
        children: [
          // 暗紅色星點粒子散布效果
          ...particles,
          
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: max(0, constraints.maxHeight - 64),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                  const SizedBox(height: 40), // 往下移，上方留 40 間距
                  // 頂部區域
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF3B30), Color(0xFF8B0000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text('🕵️', style: TextStyle(fontSize: 36)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '誰在亂搞？',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '數位鑑識・存證保護・反詐騙工具',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 朋友靠譜信任度掃描卡片
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _buildFeatureCard(
                      context: context,
                      icon: '🤝',
                      title: '朋友靠譜信任度掃描',
                      subtitle: '交往、借錢、合夥創業必備工具',
                      backgroundColor: const Color(0xFF0D1E3D), // 深藍色背景
                      borderColor: const Color(0xFF007AFF), // 藍色發光邊框
                      shadowColor: const Color(0xFF007AFF).withOpacity(0.4),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TrustScanScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 租屋風險掃描器卡片
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _buildFeatureCard(
                      context: context,
                      icon: '🏠',
                      title: '租屋風險掃描器',
                      subtitle: '看房、簽約、防假房東詐騙必備工具',
                      backgroundColor: const Color(0xFF0B2818), // 深綠色背景
                      borderColor: const Color(0xFF34C759), // 綠色發光邊框
                      shadowColor: const Color(0xFF34C759).withOpacity(0.4),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RentalRiskScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 網購糾紛數位存證卡片
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _buildFeatureCard(
                      context: context,
                      icon: '🛍️',
                      title: '網購糾紛數位存證',
                      subtitle: '網購商品、貼文與對話存證工具',
                      backgroundColor: const Color(0xFF2E1A47), // 深專用紫色背景
                      borderColor: const Color(0xFF9F75FF), // 紫色發光邊框
                      shadowColor: const Color(0xFF9F75FF).withOpacity(0.4),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EvidenceCaptureScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 第一張功能卡片
                  ConstrainedBox(
                    key: _searchCardKey,
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _buildFeatureCard(
                      context: context,
                      icon: '📸',
                      title: '查圖片是否被盜用？',
                      subtitle: '上傳圖片・AI 鑑識・立即存證',
                      backgroundColor: const Color(0xFF330000), // 深紅色背景
                      borderColor: const Color(0xFFFF3B30), // 紅色發光邊框
                      shadowColor: const Color(0xFFFF3B30).withOpacity(0.4),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SearchScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 第二張功能卡片
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _buildFeatureCard(
                      context: context,
                      icon: '📱',
                      title: '查號碼是否被惡意散布？',
                      subtitle: '輸入號碼・查詢風險・立即存證',
                      backgroundColor: const Color(0xFF331A00), // 深橘褐色背景
                      borderColor: const Color(0xFFFF9500), // 橘色邊框
                      shadowColor: const Color(0xFFFF9500).withOpacity(0.4),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PhoneSearchScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 查詢範圍聲明
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      '【查詢範圍聲明 / Search Scope Notice】\n'
                      '本工具之自動化搜圖技術基於全球公開網路（Public Web）之大數據比對。查詢範圍不包括通訊媒體之私密領域（如 LINE 私密群組、WeChat 封閉對話）以及社群媒體之非公開數據（如 Facebook 封閉型社團、Instagram/Threads 隱私不公開帳號/限時動態）。\n\n'
                      'This automated verification tool scans publicly indexed web data only. The search scope does not cover private communication channels (e.g., private LINE/WeChat groups) or closed social media sectors (e.g., Facebook Closed Groups, Instagram/Threads Private Accounts/Stories).',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 底部安全文字
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        '所有查詢僅在您的裝置上進行・台灣165反詐騙',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40), // 為 FAB 留白
                ],
              ),
            ),
          );
        },
      ),
    ),
  ],
      ),
      // 右下角浮動按鈕
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24.0, right: 8.0), // 確保完整顯示在右下角
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A), // 深灰色圓角正方形
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6), // 輕微陰影
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchScreen(autoOpenImagePicker: true),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('📸', style: TextStyle(fontSize: 24)),
                    SizedBox(height: 4),
                    Text(
                      '快速存證',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // 底部 Tab Bar
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdBannerWidget(),
          Container(
            color: const Color(0xFF1A1A1A), // 深灰色背景
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabItem(
                      icon: '🔍', 
                      label: '即時查詢', 
                      isSelected: false,
                      onTap: () {
                        if (_searchCardKey.currentContext != null) {
                          Scrollable.ensureVisible(
                            _searchCardKey.currentContext!,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            alignment: 0.1, // 稍微在畫面上方
                          );
                        }
                      },
                    ),
                    _buildTabItem(
                      icon: '📁', 
                      label: '存證紀錄', 
                      isSelected: false,
                      onTap: _showRecordsDialog,
                    ),
                    _buildLegalTabItem(
                      isSelected: true, // 此項目為選中狀態（白色高亮）
                      onTap: _showLegalDialog,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String icon,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required Color borderColor,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: shadowColor, // 輕微的外發光
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
                          fontSize: 22, // 標題加大
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14, // 副標加大
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward, // 右側→箭頭
                  color: Colors.white70,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({required String icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalTabItem({required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛡', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              '法律工具',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '165 通報',
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.grey,
                fontSize: 10,
              ),
            ),
            Text(
              '產生 PDF',
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
