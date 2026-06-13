const fs = require('fs');

const file = 'lib/services/pdf_generator_service.dart';
let code = fs.readFileSync(file, 'utf8');

const startMarker = '  static Future<void> generateRentalRiskReport({';
const startIndex = code.indexOf(startMarker);

if (startIndex === -1) {
  console.error('Start marker not found!');
  process.exit(1);
}

// Find the end of the class (the last '}' in the file)
const classEndIndex = code.lastIndexOf('}');

const replacement = `  static Future<void> generateRentalRiskReport({
    required BuildContext context,
    required int totalScore,
    required String gradeKey,
    required String gradeTitle,
    required String gradeRange,
    required String gradeDesc,
    required String gradeAdvice,
    required int d1Score,
    required int d2Score,
    required int d3Score,
    required List<String> triggeredRedFlags,
  }) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating PDF rental risk report, please wait...')),
        );
      }

      final font = await PdfGoogleFonts.notoSansTCRegular();
      final fontBold = await PdfGoogleFonts.notoSansTCBold();

      final titleStyle = pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.green900);
      final sectionStyle = pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.green800);
      final labelStyle = pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.grey900);
      final contentStyle = pw.TextStyle(font: font, fontSize: 9.0, color: PdfColors.black, height: 1.1);
      final boldContentStyle = pw.TextStyle(font: fontBold, fontSize: 9.0, color: PdfColors.black, height: 1.1);

      final pdf = pw.Document();
      final reportId = DateTime.now().millisecondsSinceEpoch.toString();
      final timestamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');

      final Map<String, Map<String, String>> _rentalRiskGradesEn = {
        'green': {
          'title': 'Green: Low Risk (Safe to Rent)',
          'desc': 'Safe housing conditions, legally compliant contract, transparent landlord profile. Very low risk.',
          'advice': 'Proceed to sign with confidence. Double-check original ID and ownership certificate.',
        },
        'yellow': {
          'title': 'Yellow: Medium Risk (Verify First)',
          'desc': 'Minor property issues. No clear fraud signs, but terms like maintenance or taxes are vague.',
          'advice': 'Do not rush. Require explicit repair and early termination clauses in writing before signing.',
        },
        'orange': {
          'title': 'Orange: High Risk (Proceed with Caution)',
          'desc': 'Poor legal compliance, unfair clauses, or landlord evades identity verification. High risk of disputes.',
          'advice': 'Stop cash payments. Demand latest land registration transcript; search elsewhere if landlord refuses.',
        },
        'red': {
          'title': 'Red: Extreme Danger (Do Not Rent)',
          'desc': 'High correlation with fake landlord and duplicate rental scam patterns. Or severe safety hazards.',
          'advice': 'Cut off contact immediately. Never transfer money without visiting. Prepayments are 100% scams.',
        },
      };

      final gradeEn = _rentalRiskGradesEn[gradeKey]!;

      // Dynamic spacing adjustment to prevent 3 pages when red flags are present
      final bool hasFlags = triggeredRedFlags.isNotEmpty;
      final double spacing = hasFlags ? 6.0 : 8.0;
      final double innerSpacing = hasFlags ? 4.0 : 6.0;

      final cleanGradeTitle = gradeTitle.replaceAll(RegExp(r'[🟢🔴🟡🟠🚨]'), '').trim();

      PdfColor indicatorColor = PdfColors.grey;
      if (gradeKey == 'green') {
        indicatorColor = PdfColors.green;
      } else if (gradeKey == 'yellow') {
        indicatorColor = PdfColors.yellow;
      } else if (gradeKey == 'orange') {
        indicatorColor = PdfColors.orange;
      } else if (gradeKey == 'red') {
        indicatorColor = PdfColors.red;
      }

      pw.Widget buildField(String labelZh, String labelEn, String content) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$labelZh / $labelEn', style: labelStyle),
              pw.SizedBox(height: 1),
              pw.Text(content, style: contentStyle),
            ],
          ),
        );
      }

      pw.Widget buildBilingualFooter(int pageNum) {
        return pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '本報告由當事人依客觀事實勾選、經地端演算法評估產出。全程地端無涉私個資。',
                    style: pw.TextStyle(font: font, fontSize: 7.0, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Generated locally based on facts selected by the user under local algorithm. Serverless privacy guaranteed.',
                    style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Text(
                'Report ID: $reportId  |  Page $pageNum of 2',
                style: pw.TextStyle(font: font, fontSize: 7.0, color: PdfColors.grey700),
              ),
            ],
          ),
        );
      }

      // Page 1: Personal Result
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.green900,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          '誰在亂搞？ —— 租屋風險健檢報告',
                          style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Tenancy Safety Inquiry Scan Report',
                          style: pw.TextStyle(font: font, fontSize: 9.0, color: PdfColors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: spacing),

                // Red Flags Banner at the top if triggered
                if (hasFlags) ...[
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                      border: pw.Border.all(color: PdfColors.red900, width: 1.0),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Container(
                              width: 8,
                              height: 8,
                              decoration: const pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                color: PdfColors.red,
                              ),
                            ),
                            pw.SizedBox(width: 4),
                            pw.Text(
                              '重大風險警訊：本物件已觸發致命紅旗項目！',
                              style: pw.TextStyle(font: fontBold, fontSize: 9.0, color: PdfColors.red900),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Warning: Serious Risk! Critical Red Flag triggered!',
                          style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.red700),
                        ),
                        pw.SizedBox(height: 4),
                        ...triggeredRedFlags.map((flag) {
                          final cleanFlag = flag.replaceAll(RegExp(r'[🟢🔴🟡🟠🚨]'), '').trim();
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            child: pw.Text(
                              '• 已觸發 / Triggered: $cleanFlag',
                              style: pw.TextStyle(font: font, fontSize: 9.0, color: PdfColors.red900),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: spacing),
                ],

                // Report Details Columns
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('基本評估資訊 / General Info', style: sectionStyle),
                          pw.SizedBox(height: innerSpacing),
                          buildField('報告編號', 'Report ID', reportId),
                          buildField('評估時間', 'Generated Time', timestamp),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('地端演算法得分 / Algorithm Score', style: sectionStyle),
                          pw.SizedBox(height: innerSpacing),
                          if (hasFlags) ...[
                            pw.Row(
                              children: [
                                pw.Text('總評估得分: ', style: boldContentStyle),
                                pw.Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const pw.BoxDecoration(
                                    shape: pw.BoxShape.circle,
                                    color: PdfColors.red,
                                  ),
                                ),
                                pw.SizedBox(width: 4),
                                pw.Text('觸發致命紅旗 (Red Flag)', style: boldContentStyle),
                              ],
                            ),
                          ] else ...[
                            pw.Text('總評估得分: $totalScore 分 / 100 分 (Score: $totalScore / 100)', style: boldContentStyle),
                          ],
                          pw.SizedBox(height: 4),
                          pw.Row(
                            children: [
                              pw.Text('安全燈號: ', style: boldContentStyle),
                              pw.Container(
                                width: 8,
                                height: 8,
                                decoration: pw.BoxDecoration(
                                  shape: pw.BoxShape.circle,
                                  color: indicatorColor,
                                ),
                              ),
                              pw.SizedBox(width: 4),
                              pw.Text('$cleanGradeTitle (Grade: \${gradeEn['title']})', style: boldContentStyle),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('適用情境: 看房、簽約、防假房東防詐篩選', style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.black)),
                          pw.Text('Use Cases: Viewing, signing, rental fraud screening', style: pw.TextStyle(font: font, fontSize: 8.0, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: innerSpacing),
                pw.Divider(color: PdfColors.grey300, height: 1),
                pw.SizedBox(height: innerSpacing),

                // Dimension table
                pw.Text('三維度評分明細 / Three Dimensions Detailed Evaluation', style: sectionStyle),
                pw.SizedBox(height: innerSpacing),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3.5),
                    1: const pw.FlexColumnWidth(2.0),
                    2: const pw.FlexColumnWidth(4.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('評估維度 / Dimension', style: boldContentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('得分 / Score', style: boldContentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('健康度狀態 / Health Status', style: boldContentStyle),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('居住安全', style: contentStyle),
                              pw.Text('Housing Safety', style: pw.TextStyle(font: font, fontSize: 8.0, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('$d1Score / 25', style: contentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                d1Score >= 20 ? '良好：居住環境安全' : (d1Score >= 15 ? '中等：有輕微結構/安全瑕疵' : '高風險：結構/消防隱憂嚴重'),
                                style: contentStyle,
                              ),
                              pw.Text(
                                d1Score >= 20 
                                  ? 'Good: Safe living environment' 
                                  : (d1Score >= 15 ? 'Moderate: Minor structural/safety issues' : 'High Risk: Severe structural/fire hazards'),
                                style: pw.TextStyle(font: font, fontSize: 8.0, color: PdfColors.grey700, height: 1.05),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('法律與合約合規', style: contentStyle),
                              pw.Text('Legal & Contract Compliance', style: pw.TextStyle(font: font, fontSize: 8.0, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('$d2Score / 15', style: contentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                d2Score >= 12 ? '良好：合約條款公平合規' : (d2Score >= 9 ? '中等：修繕或報稅約定模糊' : '高風險：不平等條款或刁難限制'),
                                style: contentStyle,
                              ),
                              pw.Text(
                                d2Score >= 12 
                                  ? 'Good: Fair & compliant clauses' 
                                  : (d2Score >= 9 ? 'Moderate: Vague repair/tax clauses' : 'High Risk: Unfair terms or restrictions'),
                                style: pw.TextStyle(font: font, fontSize: 8.0, color: PdfColors.grey700, height: 1.05),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('詐騙風險模型', style: contentStyle),
                              pw.Text('Fraud Risk Model', style: pw.TextStyle(font: font, fontSize: 8.0, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('$d3Score / 60', style: contentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                d3Score >= 48 ? '良好：身分與行情真實透明' : (d3Score >= 36 ? '中等：資訊未完全驗證' : '高風險：高度符合詐騙特徵'),
                                style: contentStyle,
                              ),
                              pw.Text(
                                d3Score >= 48 
                                  ? 'Good: Verified identity & market price' 
                                  : (d3Score >= 36 ? 'Moderate: Information not fully verified' : 'High Risk: Matches fraud patterns'),
                                style: pw.TextStyle(font: font, fontSize: 8.0, color: PdfColors.grey700, height: 1.05),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: spacing),

                // Analysis details
                pw.Text('詳細結果說明 / Detailed Results', style: sectionStyle),
                pw.SizedBox(height: innerSpacing),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Paragraph(
                        text: gradeDesc,
                        style: pw.TextStyle(font: font, fontSize: 9.0, color: PdfColors.black, height: 1.15),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Paragraph(
                        text: gradeEn['desc'] ?? '',
                        style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700, height: 1.1),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: innerSpacing),
                
                pw.Text('防禦防範建議 / Safety Advice', style: sectionStyle),
                pw.SizedBox(height: innerSpacing),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: gradeKey == 'red' ? PdfColors.red50 : (gradeKey == 'green' ? PdfColors.green50 : PdfColors.blue50),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Paragraph(
                        text: gradeAdvice,
                        style: pw.TextStyle(font: font, fontSize: 9.0, color: gradeKey == 'red' ? PdfColors.red900 : (gradeKey == 'green' ? PdfColors.green900 : PdfColors.blue900), height: 1.15),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Paragraph(
                        text: gradeEn['advice'] ?? '',
                        style: pw.TextStyle(font: font, fontSize: 8.5, color: gradeKey == 'red' ? PdfColors.red700 : (gradeKey == 'green' ? PdfColors.green800 : PdfColors.blue800), height: 1.1),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),
                buildBilingualFooter(1),
              ],
            );
          },
        ),
      );

      // Page 2: Official Resources & Disclaimer
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            const resourcesEn = [
              {
                'title': '165 Anti-Fraud Inquiry Hotline',
                'desc': 'Listen, hang up, and verify to check if the bank transfer account has been reported as a fraud account.',
              },
              {
                'title': 'MOI Real Estate Information Platform',
                'desc': 'Free download of model residential lease agreements to crosscheck and protect your basic tenancy rights.',
              },
              {
                'title': 'Land Registration Portal & Title Transcript Request',
                'desc': 'Request electronic transcripts online (NT$20) to verify if the landlord is the actual property owner.',
              },
              {
                'title': 'Tsui Mama Foundation / Consumer Protection Officers',
                'desc': 'Provides professional legal consultations and dispute mediation channels to safeguard tenant rights.',
              },
            ];

            const String disclaimerZh =
                '1. 本報告為個人化問卷評估報告，僅作為使用者看房、簽約前之自我風險篩選防範參考。本 App 與相關服務不保證房屋交易之完全安全，亦不負擔任何交易履約與資金損失責任。\\n' +
                '2. 【全程地端安全承諾】：本功能之問卷勾選、評估計算與 PDF 報告產出，完全在使用者裝置本地端運算完成。系統全程不收集、不上傳任何涉私個人資料，不申請亦不取用任何 GPS 地理定位資訊，確保您的個人資料絕對隱私安全。\\n' +
                '3. 涉及押金、定金匯款時，請務必先透過 165 反詐騙系統或地政謄本對照所有權人姓名與銀行帳戶姓名，切勿在未見到屋主本人並查驗正本房屋權狀前匯出任何款項。';

            const String disclaimerEn =
                '1. This report is for personal risk screening reference before property visits or contract signing. It does not guarantee transaction safety or assume liability for losses.\\n' +
                '2. [On-Device Safety]: All calculations and PDF generation are done locally. No personal data or GPS location is uploaded or collected.\\n' +
                '3. Verify banking and owner names via 165 or ownership transcripts before transfer. Never transfer money without visiting.';

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.green900,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          '租屋安全官方查詢資源 & 免責聲明',
                          style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.white),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Official Tenancy Safety Resources & Disclaimer',
                          style: pw.TextStyle(font: font, fontSize: 9.0, color: PdfColors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.Text('租屋安全查證官方資源附錄 / Official Tenancy Safety Resources', style: titleStyle),
                pw.SizedBox(height: 6),

                ...List.generate(RentalRiskConstants.officialResources.length, (idx) {
                  final resZh = RentalRiskConstants.officialResources[idx];
                  final resEn = resourcesEn[idx];
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Container(
                      width: double.infinity,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(resZh['title'] ?? '', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.green800)),
                          pw.Text(resEn['title'] ?? '', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.green700)),
                          pw.SizedBox(height: 2),
                          pw.Paragraph(
                            text: resZh['desc'] ?? '',
                            style: pw.TextStyle(font: font, fontSize: 9.0, height: 1.1, color: PdfColors.black),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Paragraph(
                            text: resEn['desc'] ?? '',
                            style: pw.TextStyle(font: font, fontSize: 8.5, height: 1.05, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 6),

                pw.Text('地端演算法評估聲明 / On-Device Algorithm & Disclaimer', style: titleStyle),
                pw.SizedBox(height: 6),

                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.fromBorderSide(pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Paragraph(
                        text: disclaimerZh,
                        style: pw.TextStyle(font: font, fontSize: 9.0, height: 1.1, color: PdfColors.black),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Paragraph(
                        text: disclaimerEn,
                        style: pw.TextStyle(font: font, fontSize: 8.5, height: 1.05, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),
                buildBilingualFooter(2),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'rental_risk_report_\$reportId.pdf',
      );
    } catch (e) {
      debugPrint("PDF Generation Failed: \$e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: \$e')),
        );
      }
    }
  }
`;

const newCode = code.substring(0, startIndex) + replacement + code.substring(classEndIndex + 1);
fs.writeFileSync(file, newCode, 'utf8');
console.log('Successfully edited generateRentalRiskReport!');
