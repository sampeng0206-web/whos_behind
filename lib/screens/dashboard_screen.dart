import 'package:flutter/material.dart';
import 'dart:math';
import 'search_screen.dart';
import 'phone_search_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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

                  // 第一張功能卡片
                  ConstrainedBox(
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
                  const SizedBox(height: 64),

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
                // 快速存證 action
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
      bottomNavigationBar: Container(
        color: const Color(0xFF1A1A1A), // 深灰色背景
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTabItem(icon: '🔍', label: '即時查詢', isSelected: false),
                _buildTabItem(icon: '📁', label: '存證紀錄', isSelected: false),
                _buildLegalTabItem(isSelected: true), // 此項目為選中狀態（白色高亮）
              ],
            ),
          ),
        ),
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

  Widget _buildTabItem({required String icon, required String label, required bool isSelected}) {
    return Column(
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
    );
  }

  Widget _buildLegalTabItem({required bool isSelected}) {
    return Column(
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
    );
  }
}
