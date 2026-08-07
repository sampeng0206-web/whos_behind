import 'package:flutter/material.dart';
import '../constants/rental_risk_constants.dart';
import '../services/billing_service.dart';
import '../services/pdf_generator_service.dart';
import '../widgets/remote_ad_banner.dart';

class RentalRiskScreen extends StatefulWidget {
  const RentalRiskScreen({super.key});

  @override
  State<RentalRiskScreen> createState() => _RentalRiskScreenState();
}

class _RentalRiskScreenState extends State<RentalRiskScreen> {
  final PageController _pageController = PageController();
  final Map<int, Map<String, dynamic>> _selectedOptions = {}; // Map of question index -> selected option Map
  int _currentPage = 0;
  bool _isScanCompleted = false;

  int get _totalScore {
    return _selectedOptions.values.fold(0, (sum, option) => sum + (option['score'] as int));
  }

  bool get _hasRedFlag {
    return _selectedOptions.values.any((option) => option['isRedFlag'] == true);
  }

  List<String> get _triggeredRedFlags {
    final List<String> flags = [];
    for (int i = 0; i < RentalRiskConstants.questions.length; i++) {
      final q = RentalRiskConstants.questions[i];
      final selected = _selectedOptions[i];
      if (selected != null && selected['isRedFlag'] == true) {
        flags.add(q['dimensionName'] ?? '');
      }
    }
    return flags;
  }

  String get _gradeKey {
    if (_hasRedFlag) return 'red';
    final score = _totalScore;
    if (score >= 61) return 'green';
    if (score >= 41) return 'orange';
    if (score >= 21) return 'yellow';
    return 'red';
  }

  Map<String, double> get _dimensionScores {
    // Dimension 1: 看房現場觀察 (Q1 to Q5, max score 25)
    // Dimension 2: 法律與合約合規 (Q6 to Q10, max score 15)
    // Dimension 3: 詐騙風險模型 (Q11 to Q13, max score 60)
    int d1 = 0;
    int d2 = 0;
    int d3 = 0;

    for (int i = 0; i < 5; i++) {
      d1 += (_selectedOptions[i]?['score'] as int?) ?? 1;
    }
    for (int i = 5; i < 10; i++) {
      d2 += (_selectedOptions[i]?['score'] as int?) ?? 1;
    }
    for (int i = 10; i < 13; i++) {
      d3 += (_selectedOptions[i]?['score'] as int?) ?? 4;
    }

    return {
      '看房現場觀察': d1 / 25.0,
      '法律與合約合規': d2 / 15.0,
      '詐騙風險模型': d3 / 60.0,
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < RentalRiskConstants.questions.length - 1) {
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
      '本次查詢與報告產出之對象資料，為您本人之相關權益爭議或看房租屋所需，\n'
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
                '產生租屋健檢報告前請確認',
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
                      '我確認：這是我本人租房權益相關之資料',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    value: isChecked,
                    activeColor: Colors.greenAccent,
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
                      color: isChecked ? Colors.greenAccent : Colors.grey[600],
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
    final gradeInfo = RentalRiskConstants.resultGrades[_gradeKey]!;

    int d1Score = 0;
    int d2Score = 0;
    int d3Score = 0;

    for (int i = 0; i < 5; i++) {
      d1Score += (_selectedOptions[i]?['score'] as int?) ?? 1;
    }
    for (int i = 5; i < 10; i++) {
      d2Score += (_selectedOptions[i]?['score'] as int?) ?? 1;
    }
    for (int i = 10; i < 13; i++) {
      d3Score += (_selectedOptions[i]?['score'] as int?) ?? 4;
    }

    await PdfGeneratorService.generateRentalRiskReport(
      context: context,
      totalScore: _totalScore,
      gradeKey: _gradeKey,
      gradeTitle: gradeInfo['title'] ?? '',
      gradeRange: gradeInfo['range'] ?? '',
      gradeDesc: gradeInfo['desc'] ?? '',
      gradeAdvice: gradeInfo['advice'] ?? '',
      d1Score: d1Score,
      d2Score: d2Score,
      d3Score: d3Score,
      triggeredRedFlags: _triggeredRedFlags,
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'green':
        return Colors.greenAccent;
      case 'yellow':
        return Colors.blueAccent;
      case 'orange':
        return Colors.orangeAccent;
      case 'red':
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C100E), // Premium dark green tint theme
      appBar: AppBar(
        title: const Text('租屋風險掃描器', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
    final progress = (_currentPage + 1) / RentalRiskConstants.questions.length;
    final isOptionSelected = _selectedOptions[_currentPage] != null;
    final q = RentalRiskConstants.questions[_currentPage];
    final isRedFlagQuestion = q['isRedFlagType'] == true;

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
                '評估問題 ${_currentPage + 1} / ${RentalRiskConstants.questions.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(color: isRedFlagQuestion ? Colors.redAccent : Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(isRedFlagQuestion ? Colors.redAccent : Colors.greenAccent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 24),

          // Questionnaire body Card
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Force steps navigation
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: RentalRiskConstants.questions.length,
              itemBuilder: (context, index) {
                final currentQ = RentalRiskConstants.questions[index];
                final isCurrentRedFlag = currentQ['isRedFlagType'] == true;
                final optionsList = currentQ['options'] as List;

                return SingleChildScrollView(
                  child: Card(
                    color: isCurrentRedFlag ? const Color(0xFF241416) : const Color(0xFF131A15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isCurrentRedFlag ? Colors.redAccent.withOpacity(0.5) : Colors.greenAccent.withOpacity(0.2),
                        width: isCurrentRedFlag ? 1.5 : 1,
                      ),
                    ),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCurrentRedFlag 
                                      ? Colors.redAccent.withOpacity(0.15) 
                                      : Colors.greenAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  currentQ['dimension'] ?? '',
                                  style: TextStyle(
                                    color: isCurrentRedFlag ? Colors.redAccent : Colors.greenAccent, 
                                    fontSize: 11, 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isCurrentRedFlag) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 4),
                                const Text(
                                  '一票否決紅旗題',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentQ['question'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 12),

                          if (isCurrentRedFlag)
                            // 14-16紅旗題在畫面上以明確的「是 / 否」獨立 Radio / 卡片樣式呈現
                            Row(
                              children: List.generate(optionsList.length, (oIdx) {
                                final option = optionsList[oIdx];
                                final isSelected = _selectedOptions[index] == option;
                                final isYesOption = option['isRedFlag'] == true;

                                return Expanded(
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      left: oIdx == 0 ? 0 : 8,
                                      right: oIdx == optionsList.length - 1 ? 0 : 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? (isYesOption ? Colors.redAccent.withOpacity(0.2) : Colors.grey.withOpacity(0.2)) 
                                          : Colors.black26,
                                      border: Border.all(
                                        color: isSelected 
                                            ? (isYesOption ? Colors.redAccent : Colors.white30) 
                                            : Colors.white10,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedOptions[index] = option;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isYesOption ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                              color: isSelected 
                                                  ? (isYesOption ? Colors.redAccent : Colors.white) 
                                                  : Colors.white30,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              option['text'].split('（')[0], // 移除括號提示
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : Colors.white60,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            )
                          else
                            // 常規分值題選項呈現
                            ...List.generate(optionsList.length, (oIdx) {
                              final option = optionsList[oIdx];
                              final isSelected = _selectedOptions[index] == option;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.greenAccent.withOpacity(0.1) : Colors.black26,
                                  border: Border.all(
                                    color: isSelected ? Colors.greenAccent : Colors.white10,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onTap: () {
                                    setState(() {
                                      _selectedOptions[index] = option;
                                    });
                                  },
                                  leading: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: isSelected ? Colors.greenAccent : Colors.white12,
                                    child: isSelected 
                                        ? const Icon(Icons.check, size: 14, color: Colors.black) 
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
                    backgroundColor: isRedFlagQuestion ? Colors.redAccent : Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white10,
                    disabledForegroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _currentPage == RentalRiskConstants.questions.length - 1 ? '看評估結果' : '下一題',
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
    final gradeInfo = RentalRiskConstants.resultGrades[_gradeKey]!;
    final gradeColor = _getGradeColor(_gradeKey);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Result Title Banner
          Card(
            color: const Color(0xFF131A15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: gradeColor.withOpacity(0.5), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text('地端租屋風險分析評估完成', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (_hasRedFlag) ...[
                    const Text(
                      '🚨 觸發重大紅旗',
                      style: TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                  ] else ...[
                    Text(
                      '$_totalScore分',
                      style: TextStyle(color: gradeColor, fontSize: 48, fontWeight: FontWeight.w900),
                    ),
                  ],
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
          const SizedBox(height: 20),

          // Red Flags Section if triggered
          if (_hasRedFlag) ...[
            const Text('🚨 重大風險警訊', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              color: Colors.redAccent.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.redAccent, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _triggeredRedFlags.map((flag) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '已觸發致命紅旗：$flag',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Dimension Breakdown Title
          const Text('維度評分分析 / Dimension Analysis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Dimension breakdown list
          Card(
            color: const Color(0xFF131A15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: _dimensionScores.entries.map((entry) {
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
          const SizedBox(height: 20),

          // Action recommendations
          const Text('防禦與防範建議 / Actions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            color: gradeColor.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: gradeColor.withOpacity(0.3))),
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
            label: const Text('產出 PDF 租屋風險健檢報告', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
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
                _selectedOptions.clear();
                _currentPage = 0;
                _isScanCompleted = false;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重新進行風險評估', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
