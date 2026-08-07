import 'package:flutter/material.dart';
import '../constants/trust_scan_constants.dart';
import '../services/billing_service.dart';
import '../services/pdf_generator_service.dart';
import '../widgets/remote_ad_banner.dart';

class TrustScanScreen extends StatefulWidget {
  const TrustScanScreen({super.key});

  @override
  State<TrustScanScreen> createState() => _TrustScanScreenState();
}

class _TrustScanScreenState extends State<TrustScanScreen> {
  final PageController _pageController = PageController();
  final Map<int, int> _selectedAnswers = {}; // Map of question index -> selected score
  int _currentPage = 0;
  bool _isScanCompleted = false;

  int get _totalScore {
    return _selectedAnswers.values.fold(0, (sum, score) => sum + score);
  }

  String get _gradeKey {
    final score = _totalScore;
    if (score >= 45) return 'A';
    if (score >= 38) return 'B';
    if (score >= 30) return 'C';
    if (score >= 20) return 'D';
    return 'E';
  }

  Map<String, double> get _dimensionAverages {
    // Dimension 1: 現況透明度 (Q1, Q2, Q3)
    // Dimension 2: 利益壓力測試 (Q4, Q5, Q6)
    // Dimension 3: 極限信任能力 (Q7, Q8)
    // Dimension 4: 綜合人格與直覺預警 (Q9, Q10)
    final d1 = ((_selectedAnswers[0] ?? 3) + (_selectedAnswers[1] ?? 3) + (_selectedAnswers[2] ?? 3)) / 15.0;
    final d2 = ((_selectedAnswers[3] ?? 3) + (_selectedAnswers[4] ?? 3) + (_selectedAnswers[5] ?? 3)) / 15.0;
    final d3 = ((_selectedAnswers[6] ?? 3) + (_selectedAnswers[7] ?? 3)) / 10.0;
    final d4 = ((_selectedAnswers[8] ?? 3) + (_selectedAnswers[9] ?? 3)) / 10.0;
    return {
      '現況透明度': d1,
      '利益壓力測試': d2,
      '極限信任能力': d3,
      '綜合人格預警': d4,
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < TrustScanConstants.questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() {
        _isScanCompleted = true;
      });
      // Trigger Interstitial Ad after finishing questionnaire (Removed AdMob)
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  static const String _pdfConfirmMessage =
      '為保障您與他人的權益，請確認：\n\n'
      '本次查詢與報告產出之對象資料，為您本人之相關權益爭議所需，\n'
      '並非用於查詢、騷擾或調查與本案無關之第三人。\n\n'
      '若違反前述聲明，產生之相關法律責任將由您自行承擔。';

  void _showPdfConfirmDialog(BuildContext screenContext) {
    bool isChecked = false;
    showDialog(
      context: screenContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                '產生證據報告前請確認',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    _pdfConfirmMessage,
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text(
                      '我確認：這是我本人權益相關之資料',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    value: isChecked,
                    activeColor: Colors.redAccent,
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
                          Navigator.pop(dialogContext); // Close dialog
                          
                          // Execute PDF generation with billing checks
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
                      color: isChecked ? Colors.redAccent : Colors.grey[600],
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
    final gradeInfo = TrustScanConstants.resultGrades[_gradeKey]!;
    
    // Map dimensions score into absolute points (e.g. out of 15 or 10)
    final d1Score = (_selectedAnswers[0] ?? 3) + (_selectedAnswers[1] ?? 3) + (_selectedAnswers[2] ?? 3);
    final d2Score = (_selectedAnswers[3] ?? 3) + (_selectedAnswers[4] ?? 3) + (_selectedAnswers[5] ?? 3);
    final d3Score = (_selectedAnswers[6] ?? 3) + (_selectedAnswers[7] ?? 3);
    final d4Score = (_selectedAnswers[8] ?? 3) + (_selectedAnswers[9] ?? 3);

    await PdfGeneratorService.generateTrustScanReport(
      context: context,
      totalScore: _totalScore,
      gradeTitle: gradeInfo['title'] ?? '',
      gradeRange: gradeInfo['range'] ?? '',
      gradeDesc: gradeInfo['desc'] ?? '',
      gradeAdvice: gradeInfo['advice'] ?? '',
      d1Score: d1Score,
      d2Score: d2Score,
      d3Score: d3Score,
      d4Score: d4Score,
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return Colors.greenAccent;
      case 'B':
        return Colors.blueAccent;
      case 'C':
        return Colors.amberAccent;
      case 'D':
        return Colors.orangeAccent;
      case 'E':
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0E14), // Premium dark theme
      appBar: AppBar(
        title: const Text('朋友靠譜信任度掃描', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black54,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isScanCompleted ? _buildResultPanel() : _buildQuestionnaireFlow(),
      ),
      bottomNavigationBar: FutureBuilder<bool>(
        future: BillingService.isPremiumUser(),
        builder: (context, snapshot) {
          final isPremium = snapshot.data ?? false;
          return RemoteAdBanner(shouldShow: !isPremium);
        },
      ),
    );
  }

  Widget _buildQuestionnaireFlow() {
    final progress = (_currentPage + 1) / TrustScanConstants.questions.length;
    final isOptionSelected = _selectedAnswers[_currentPage] != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '問題 ${_currentPage + 1} / ${TrustScanConstants.questions.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 32),

          // Questionnaire body Card
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Force steps
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: TrustScanConstants.questions.length,
              itemBuilder: (context, index) {
                final q = TrustScanConstants.questions[index];
                return SingleChildScrollView(
                  child: Card(
                    color: const Color(0xFF161A26),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white24, width: 1),
                    ),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              q['dimension'] ?? '',
                              style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            q['question'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 12),
                          ...List.generate((q['options'] as List).length, (oIdx) {
                            final option = q['options'][oIdx];
                            final isSelected = _selectedAnswers[index] == option['score'];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blueAccent.withOpacity(0.15) : Colors.black26,
                                border: Border.all(
                                  color: isSelected ? Colors.blueAccent : Colors.white10,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onTap: () {
                                  setState(() {
                                    _selectedAnswers[index] = option['score'];
                                  });
                                },
                                leading: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isSelected ? Colors.blueAccent : Colors.white12,
                                  child: isSelected 
                                      ? const Icon(Icons.check, size: 14, color: Colors.white) 
                                      : const SizedBox.shrink(),
                                ),
                                title: Text(
                                  option['text'],
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Stepper Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentPage > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _prevPage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('上一題', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: isOptionSelected ? _nextPage : null, // Prevent skipping
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white10,
                    disabledForegroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _currentPage == TrustScanConstants.questions.length - 1 ? '看評估結果' : '下一題',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel() {
    final gradeInfo = TrustScanConstants.resultGrades[_gradeKey]!;
    final gradeColor = _getGradeColor(_currentPage == 0 ? 'A' : _gradeKey); // Default guard

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Result Title Banner
          Card(
            color: const Color(0xFF161A26),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: gradeColor.withOpacity(0.5), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text('地端分析評估完成', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    '$_totalScore分',
                    style: TextStyle(color: gradeColor, fontSize: 48, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gradeInfo['title'] ?? '',
                    style: TextStyle(color: gradeColor, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  Text(
                    gradeInfo['desc'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Dimension Breakdown Title
          const Text('維度評分分析 / Dimension Analysis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Dimension breakdown list
          Card(
            color: const Color(0xFF161A26),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: _dimensionAverages.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            Text('${(entry.value * 100).toInt()}%', style: TextStyle(color: gradeColor, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: entry.value,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action recommendations
          const Text('地端防禦防範建議 / Actions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            color: Colors.redAccent.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.redAccent.withOpacity(0.3))),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🛡️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      gradeInfo['advice'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Action Buttons
          ElevatedButton.icon(
            onPressed: () => _showPdfConfirmDialog(context),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('產出 PDF 信任度掃描報告', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _selectedAnswers.clear();
                _currentPage = 0;
                _isScanCompleted = false;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重新進行掃描測試', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
