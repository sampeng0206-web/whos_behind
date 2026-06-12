import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../constants/trust_scan_constants.dart';
import '../constants/rental_risk_constants.dart';
import '../constants/evidence_capture_constants.dart';

class PdfGeneratorService {
  static Future<void> generateEvidenceReport({
    required BuildContext context,
    XFile? selectedImage,
    required String evidenceTimestamp,
    String? uploadedImageUrl,
    String? selectedObservation,
    String? otherObservation,
    String? searchedPhone,
    Map<String, bool?>? phoneSearchStatus,
    String? anchorUrl,
  }) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating PDF, please wait...')),
        );
      }

      Position? pos;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
        }
      } catch (e) {
        debugPrint("Location access failed or was skipped: $e");
      }

      pw.MemoryImage? pdfImage;
      if (selectedImage != null) {
        final bytes = await selectedImage.readAsBytes();
        pdfImage = pw.MemoryImage(bytes);
      }
      final font = await PdfGoogleFonts.notoSansTCRegular();
      final fontBold = await PdfGoogleFonts.notoSansTCBold();
      
      final titleStyle = pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.red900);
      final subtitleStyle = pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black);
      final labelStyle = pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey900);
      final contentStyle = pw.TextStyle(font: font, fontSize: 10, color: PdfColors.black);
      
      final pdf = pw.Document();
      final reportId = DateTime.now().millisecondsSinceEpoch.toString();

      // GPS Strings
      String gpsZh = "用戶未提供";
      String gpsEn = "Not provided";
      if (pos != null) {
        gpsZh = "經度: ${pos.longitude}\n緯度: ${pos.latitude}\n精準度: ${pos.accuracy.toStringAsFixed(1)}公尺";
        gpsEn = "Longitude: ${pos.longitude}\nLatitude: ${pos.latitude}\nAccuracy: ${pos.accuracy.toStringAsFixed(1)}m";
      }

      // Incident Type
      String incidentTypeZh = searchedPhone != null ? "可疑電話號碼散布 / 詐騙防範" : "肖像權侵害 / 圖片遭盜用鑑定";
      String incidentTypeEn = searchedPhone != null ? "Suspicious Phone Number Distribution / Anti-Scam Lookup" : "Right of Portrait Infringement / Image Misuse Verification";

      // Platforms
      String platformZh = searchedPhone != null 
          ? "公開網路搜尋（Google, Facebook, Dcard, PTT, Threads）"
          : "公開網路以圖搜圖（Google Lens, TinEye, Bing Visual Search, Google Images）";
      String platformEn = searchedPhone != null
          ? "Public Web Search (Google, Facebook, Dcard, PTT, Threads)"
          : "Public Web Image Search (Google Lens, TinEye, Bing Visual Search, Google Images)";

      // Image Search Result
      String imageSearchZh = "無（本案為電話號碼查詢）";
      String imageSearchEn = "N/A (This report is for Phone Number Lookup)";
      if (selectedImage != null) {
        final observation = selectedObservation == '其他 / Other' ? (otherObservation ?? '') : (selectedObservation ?? '');
        imageSearchZh = "查核結果: $observation\n雲端存證連結: ${uploadedImageUrl ?? '無雲端連結'}";
        imageSearchEn = "Observation: $observation\nSecure Image URL: ${uploadedImageUrl ?? 'N/A'}";
      }

      // Phone Lookup Result
      String phoneLookupZh = "無（本案為圖片盜用查詢）";
      String phoneLookupEn = "N/A (This report is for Image Misuse Verification)";
      if (searchedPhone != null) {
        final yesCount = phoneSearchStatus?.values.where((v) => v == true).length ?? 0;
        final noCount = phoneSearchStatus?.values.where((v) => v == false).length ?? 0;
        phoneLookupZh = "查詢號碼: $searchedPhone\n有紀錄平台數: $yesCount\n無紀錄平台數: $noCount";
        phoneLookupEn = "Searched Number: $searchedPhone\nFound on: $yesCount platforms\nNo record on: $noCount platforms";
      }

      // 165 Report Status
      String scamReportZh = searchedPhone != null
          ? "已提供官方 165 檢舉入口指引；若比對有紀錄，建議儘速舉報。"
          : "已提供官方 165 檢舉及社群平台（FB/IG/Threads）申訴指引。";
      String scamReportEn = searchedPhone != null
          ? "Official 165 Anti-Scam report guide provided; immediate reporting recommended if records found."
          : "Official 165 Anti-Scam and social media (FB/IG/Threads) take-down guides provided.";

      // Legal Notice
      String legalNoticeZh = "本文件由「誰在亂搞？」App 自動產出。時間與定位資訊為技術性存證，供司法機關參考。本工具之查詢範圍僅限於公開網頁，不包括私密通訊或非公開社群數據。";
      String legalNoticeEn = "This report is generated by Who's Behind? App. The timestamp and GPS coordinates are technical evidence for legal reference. The search scope is limited to publicly indexed web pages and does not cover private communications or closed social networks.";

      // Helper for clean rendering of fields
      pw.Widget buildField(String label, String content) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: labelStyle),
              pw.SizedBox(height: 1),
              pw.Text(content, style: contentStyle),
            ],
          ),
        );
      }

      pw.Widget buildUrlLink(String prefix, String url, {double fontSize = 9}) {
        String safeUrl = url.replaceAll('？', '?').replaceAll('，', ',');
        String displayUrl = safeUrl
            .replaceAll('/', '/ ')
            .replaceAll('=', '= ')
            .replaceAll('?', '? ')
            .replaceAll('&', '& ')
            .replaceAll(',', ', ');

        return pw.Wrap(
          children: [
            if (prefix.isNotEmpty)
              pw.Text(prefix, style: pw.TextStyle(font: font, fontSize: fontSize, color: PdfColors.black)),
            pw.UrlLink(
              destination: safeUrl,
              child: pw.Text(displayUrl, style: pw.TextStyle(font: font, fontSize: fontSize, color: PdfColors.blue)),
            ),
          ],
        );
      }

      // Reusable Bilingual Footer
      pw.Widget buildBilingualFooter() {
        return pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 15),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '本文件由「誰在亂搞？」App 自動產出，具法律參考效力\nGenerated by Who\'s Behind? App for legal reference',
                style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
              ),
              pw.Text(
                'Report ID: $reportId',
                style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        );
      }

      // Reusable Core Message Banner
      pw.Widget buildCoreMessageBanner() {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(
            color: PdfColors.red50,
            border: pw.Border.all(color: PdfColors.red200, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                '你有證據，才有正義   |   Evidence is the foundation of justice',
                style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.red900),
              ),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (pw.Context context) => buildBilingualFooter(),
          build: (pw.Context context) {
            return [
              // Header banner
              buildCoreMessageBanner(),
              pw.SizedBox(height: 16),
              
              // Side-by-side Columns
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left Column: zh-TW
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('技術存證報告 (Technical Evidence)', style: titleStyle),
                        pw.SizedBox(height: 10),
                        buildField('報告編號', reportId),
                        buildField('產出時間', evidenceTimestamp),
                        buildField('GPS 位置（選填）', gpsZh),
                        buildField('事件類型', incidentTypeZh),
                        buildField('涉及平台', platformZh),
                        buildField('反向搜圖結果', imageSearchZh),
                        buildField('電話查詢結果', phoneLookupZh),
                        buildField('165 通報狀態', scamReportZh),
                        buildField('法律聲明', legalNoticeZh),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Right Column: en-US
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Forensic Evidence Report', style: titleStyle),
                        pw.SizedBox(height: 10),
                        buildField('Report ID', reportId),
                        buildField('Date Generated', evidenceTimestamp),
                        buildField('GPS Location (Optional)', gpsEn),
                        buildField('Incident Type', incidentTypeEn),
                        buildField('Platform Involved', platformEn),
                        buildField('Reverse Image Search Result', imageSearchEn),
                        buildField('Phone Number Lookup Result', phoneLookupEn),
                        buildField('165 Anti-Scam Report Status', scamReportEn),
                        buildField('Legal Notice', legalNoticeEn),
                      ],
                    ),
                  ),
                ],
              ),
              
              if (pos != null) ...[
                pw.SizedBox(height: 12),
                pw.Text('定位地圖連結 / Google Maps Link:', style: labelStyle),
                pw.SizedBox(height: 2),
                buildUrlLink('', 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}', fontSize: 10),
              ],
              
              if (pdfImage != null) ...[
                pw.SizedBox(height: 16),
                pw.Text('存證圖片證據 / Image Evidence:', style: labelStyle),
                pw.SizedBox(height: 8),
                pw.Container(
                  height: 160,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                ),
              ],
            ];
          },
        ),
      );

      // Page 2: Legal Assessment & Action Guide
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (pw.Context context) => buildBilingualFooter(),
          build: (pw.Context context) {
            return [
              buildCoreMessageBanner(),
              pw.SizedBox(height: 16),
              
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left Column: zh-TW
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('法律救濟評估與行動指南', style: titleStyle),
                        pw.SizedBox(height: 12),
                        
                        pw.Text('法律依據 / Legal Basis:', style: subtitleStyle),
                        pw.SizedBox(height: 6),
                        buildField('• 肖像權侵害 (民法第18、195條)', '未經授權公開散布或使用他人照片即構成肖像權侵害，被害人得請求移除內容並請求精神慰撫金之損害賠償。'),
                        buildField('• 隱私權與個資保護 (個資法違反)', '惡意於公開網路平台散布私人聯絡方式（如電話號碼）屬違反個人資料保護法，應負擔民刑事賠償責任。'),
                        buildField('• 2年請求權時效 (民法第197條)', '自主張權利人知悉損害及賠償義務人起，二年間不行使而消滅。'),
                        
                        pw.SizedBox(height: 10),
                        pw.Text('緊急行動清單 / Action Checklist:', style: subtitleStyle),
                        pw.SizedBox(height: 6),
                        buildField('1. 平台檢舉要求下架', '立即前往 Facebook, Instagram, Threads 等官方侵權投訴頁面，要求移除被盜用照片。'),
                        buildField('2. 寄送存證信函', '利用本報告檢附之警告信草稿（第三頁）填寫資訊寄送，表明您的法律立場。'),
                        buildField('3. 保存技術證據', '妥善保管本報告，其隨附之 Report ID、GPS 定位與時間戳記均可作為司法機關偵辦參考。'),
                        buildField('4. 警政單位舉報', '若懷疑遭遇網絡詐騙、貼圖威脅，應撥打 165 反詐騙專線，或攜帶本報告至派出所報案。'),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Right Column: en-US
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Legal Assessment & Action Guide', style: titleStyle),
                        pw.SizedBox(height: 12),
                        
                        pw.Text('Legal Basis:', style: subtitleStyle),
                        pw.SizedBox(height: 6),
                        buildField('• Right of Portrait (Civil Code §18, 195)', 'Unauthorized distribution or usage of personal photos constitutes a civil infringement. Victims may demand content removal and claim mental agony damages.'),
                        buildField('• Privacy & Personal Data (PDPA Violation)', 'Maliciously distributing private contact details (e.g. mobile numbers) on public websites violates the Personal Data Protection Act, carrying civil and criminal liabilities.'),
                        buildField('• 2-Year Statute of Limitations (Civil Code §197)', 'Claims for civil damages must be initiated within two years from discovery of the infringement.'),
                        
                        pw.SizedBox(height: 10),
                        pw.Text('Action Checklist:', style: subtitleStyle),
                        pw.SizedBox(height: 6),
                        buildField('1. Platform Takedown Requests', 'Immediately submit take-down complaints to Facebook, Instagram, or Threads to remove unauthorized contents.'),
                        buildField('2. Send Legal Notice', 'Draft and send the Cease and Desist warning notice (on Page 3) to formalize your legal rights.'),
                        buildField('3. Preserve Technical Evidence', 'Retain this PDF report. The included Report ID, timestamp, and GPS logs serve as authentic evidence for law enforcement.'),
                        buildField('4. Report to Law Enforcement', 'Contact the official 165 Anti-Scam Hotline or visit local police station with this report to initiate official investigation.'),
                      ],
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // Page 3: Cease and Desist Draft (Chinese warning letter)
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (pw.Context context) => buildBilingualFooter(),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('法律通知書 / 警告信草稿', style: titleStyle),
              ),
              pw.SizedBox(height: 16),
              pw.Text('存證編號 / Report ID: $reportId', style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.Text('存證時間: $evidenceTimestamp', style: pw.TextStyle(font: font, fontSize: 11)),
              pw.Text('GPS 經緯度座標: ${pos != null ? "${pos.latitude}, ${pos.longitude}" : "使用者未提供"}', style: pw.TextStyle(font: font, fontSize: 11)),
              pw.SizedBox(height: 20),
              
              pw.Text('致 侵權人 / 相關主體 (To the Infringer / Target Entity):', style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.SizedBox(height: 10),
              pw.Text(
                '於上述存證時間，本系統已正式記錄並證實，您在未經授權或同意的情況下，於公開網路平台（包括但不限於 Facebook、Instagram、Threads、PTT 或其他網站）散布且/或冒用、盜用他人之肖像照片且/或私人聯絡資訊（如電話號碼）。',
                style: pw.TextStyle(font: font, fontSize: 10.5, color: PdfColors.black),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                '此未經授權之侵權行為已違反中華民國民法第 18 條、第 184 條、第 195 條關於人格權與肖像權之規定，以及個人資料保護法（個資法）中對於個人資料保護之相關規定，並應負擔民刑事賠償責任。',
                style: pw.TextStyle(font: font, fontSize: 10.5, color: PdfColors.black),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                '特此通知您，請於收到本通知起七（7）日內完成下列要求：',
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.red900),
              ),
              pw.SizedBox(height: 8),
              pw.Bullet(text: '立即從所有平台移除所有未經授權的個人頭像、貼文內容、聯絡電話及其他相關侵權資料。', style: pw.TextStyle(font: font, fontSize: 10.5)),
              pw.Bullet(text: '提供正式的書面確認信，承諾停止一切目前進行中及未來的侵權行為。', style: pw.TextStyle(font: font, fontSize: 10.5)),
              pw.Bullet(text: '針對您所造成的精神痛苦及隱私權侵害，提出合理的和解賠償方案。', style: pw.TextStyle(font: font, fontSize: 10.5)),
              pw.SizedBox(height: 12),
              pw.Text(
                '若您未能在指定期限內履行上述要求，本案將立即移交司法機關依法追究刑事責任，並提起民事訴訟要求損害賠償。屆時因此產生的所有法律訴訟費用（包含律師費及鑑識費用）均將由您全額承擔。',
                style: pw.TextStyle(font: font, fontSize: 10.5),
              ),
              pw.SizedBox(height: 30),
              
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  '重要提示：本法律文件草稿係由「誰在亂搞？」App 依據技術存證紀錄自動產生。若欲進行正式法庭訴訟或寄送郵局存證信函，強烈建議諮詢執業律師以取得專業法律協助。',
                  style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ];
          },
        ),
      );

      // Page 4: Cease and Desist Draft (English warning letter)
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (pw.Context context) => buildBilingualFooter(),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Legal Notice / Cease and Desist Draft', style: titleStyle),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Evidence ID / Report ID: $reportId', style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.Text('Evidence Timestamp: $evidenceTimestamp', style: pw.TextStyle(font: font, fontSize: 11)),
              pw.Text('GPS Coordinates: ${pos != null ? "${pos.latitude}, ${pos.longitude}" : "Not provided by user"}', style: pw.TextStyle(font: font, fontSize: 11)),
              pw.SizedBox(height: 20),
              
              pw.Text('To the Infringer / Target Entity:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.SizedBox(height: 10),
              pw.Text(
                'It has been officially documented and authenticated on the above date that you have, without prior authorization or consent, publicly distributed and/or misused personal portrait photos and/or private contact information on public online platforms (including but not limited to Facebook, Instagram, Threads, PTT, or other websites).',
                style: pw.TextStyle(font: font, fontSize: 10.5, color: PdfColors.black),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'This unauthorized action violates civil rights regarding portrait rights under Civil Code Articles 18, 184, 195, and personal data protections under the Personal Data Protection Act (PDPA) of Taiwan (R.O.C.).',
                style: pw.TextStyle(font: font, fontSize: 10.5, color: PdfColors.black),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'YOU ARE HEREBY NOTIFIED to complete the following demands within seven (7) days of this notice:',
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.red900),
              ),
              pw.SizedBox(height: 8),
              pw.Bullet(text: 'Immediately REMOVE all unauthorized profile photos, text posts, contact numbers, and other associated content from all platforms.', style: pw.TextStyle(font: font, fontSize: 10.5)),
              pw.Bullet(text: 'Provide a formal written confirmation to cease all ongoing and future infringements.', style: pw.TextStyle(font: font, fontSize: 10.5)),
              pw.Bullet(text: 'Propose a reasonable settlement compensation for the mental agony and privacy violations incurred.', style: pw.TextStyle(font: font, fontSize: 10.5)),
              pw.SizedBox(height: 12),
              pw.Text(
                'Failure to comply with these demands within the specified timeline will result in immediate civil actions and criminal reporting to local law enforcement. All legal expenses, including attorney fees and forensic costs, will be sought at your expense.',
                style: pw.TextStyle(font: font, fontSize: 10.5),
              ),
              pw.SizedBox(height: 30),
              
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'Important Notice: This legal draft is auto-generated by Who\'s Behind? App based on technical logs. For formal court proceedings or legal mailing, it is highly recommended to consult a licensed attorney.',
                  style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      await Printing.sharePdf(
          bytes: pdfBytes, filename: 'evidence_report_$reportId.pdf');
    } catch (e) {
      debugPrint("PDF Generation Failed: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  static Future<Map<String, dynamic>?> generateWebEvidenceReport({
    required BuildContext context,
    required List<Map<String, dynamic>> captures,
    required String evidenceTimestamp,
  }) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating PDF report, please wait...')),
        );
      }

      // Defensive time-chain sorting (oldest to newest)
      final sortedCaptures = List<Map<String, dynamic>>.from(captures);
      sortedCaptures.sort((a, b) {
        final String tA = a['timestamp'] ?? '';
        final String tB = b['timestamp'] ?? '';
        return tA.compareTo(tB);
      });

      final font = await PdfGoogleFonts.notoSansTCRegular();
      final fontBold = await PdfGoogleFonts.notoSansTCBold();

      final titleStyle = pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.purple900);
      final subtitleStyle = pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black);
      final labelStyle = pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey900);
      final contentStyle = pw.TextStyle(font: font, fontSize: 9, color: PdfColors.black);
      final boldContentStyle = pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black);

      final pdf = pw.Document();
      final reportId = DateTime.now().millisecondsSinceEpoch.toString();

      pw.Widget buildField(String label, String content) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: labelStyle),
              pw.SizedBox(height: 1),
              pw.Text(content, style: contentStyle),
            ],
          ),
        );
      }

      pw.Widget buildUrlLink(String prefix, String url, {double fontSize = 8}) {
        String safeUrl = url.replaceAll('？', '?').replaceAll('，', ',');
        String displayUrl = safeUrl
            .replaceAll('/', '/ ')
            .replaceAll('=', '= ')
            .replaceAll('?', '? ')
            .replaceAll('&', '& ')
            .replaceAll(',', ', ');

        return pw.Wrap(
          children: [
            if (prefix.isNotEmpty)
              pw.Text(prefix, style: pw.TextStyle(font: font, fontSize: fontSize, color: PdfColors.black)),
            pw.UrlLink(
              destination: safeUrl,
              child: pw.Text(displayUrl, style: pw.TextStyle(font: font, fontSize: fontSize, color: PdfColors.blue)),
            ),
          ],
        );
      }

      pw.Widget buildBilingualFooter(int pageNum) {
        return pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 15),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '本文件由「誰在亂搞？」App 自動產出，具法律參考效力\nGenerated by Who\'s Behind? App for legal reference',
                style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700),
              ),
              pw.Text(
                'Report ID: $reportId  |  第 $pageNum 頁',
                style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700),
              ),
            ],
          ),
        );
      }

      pw.Widget buildCoreMessageBanner() {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: PdfColors.purple50,
            border: pw.Border.all(color: PdfColors.purple200, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                '你有證據，才有正義   |   Evidence is the foundation of justice',
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.purple900),
              ),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (pw.Context context) => buildBilingualFooter(context.pageNumber),
          build: (pw.Context context) {
            return [
              // Page 1: Cover and Summary
              buildCoreMessageBanner(),
              pw.SizedBox(height: 14),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left Column: zh-TW
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('網購糾紛數位存證報告', style: titleStyle),
                        pw.SizedBox(height: 8),
                        buildField('報告編號', reportId),
                        buildField('產出時間', evidenceTimestamp),
                        buildField('事件類型', '網購商品 / 貼文 / 對話紀錄即時存證'),
                        buildField('法律聲明', EvidenceCaptureConstants.pdfLegalStatement),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // Right Column: en-US
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Online Purchase Dispute Evidence', style: titleStyle),
                        pw.SizedBox(height: 8),
                        buildField('Report ID', reportId),
                        buildField('Date Generated', evidenceTimestamp),
                        buildField('Incident Type', 'Online Purchase / Post / Dialog Capture'),
                        buildField('Legal Notice', 
                          'This report is generated by Who\'s Behind? App. The viewport screenshots, source URLs, and timestamps are captured in real-time. The SHA-256 digital fingerprint verifies that this PDF file has not been altered since generation.'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey300, height: 1),
              pw.SizedBox(height: 12),

              // Timeline Table
              pw.Text('事件時間軸摘要 / Event Timeline Summary', style: subtitleStyle),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.2),
                  1: const pw.FlexColumnWidth(2.3),
                  2: const pw.FlexColumnWidth(4.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('存證時間 / Time', style: boldContentStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('事件節點 / Node Tag', style: boldContentStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('來源網址 / Source URL', style: boldContentStyle),
                      ),
                    ],
                  ),
                  ...sortedCaptures.map((cap) {
                    final tagsList = cap['tags'] as List<dynamic>? ?? [];
                    final tagsStr = tagsList.join(', ');
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(cap['timestamp'] ?? '', style: contentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(tagsStr, style: contentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(cap['url'] ?? '', style: pw.TextStyle(font: font, fontSize: 7.5)),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.NewPage(),

              // Page 2+: Captured Screen Details
              pw.Text('存證畫面詳情 / Captured Screen Details', style: titleStyle),
              pw.SizedBox(height: 10),

              ...sortedCaptures.asMap().entries.map((entry) {
                final int idx = entry.key;
                final cap = entry.value;
                final tagsList = cap['tags'] as List<dynamic>? ?? [];
                final tagsStr = tagsList.join(', ');
                final imageBytes = cap['imageBytes'] as Uint8List;
                final pdfImg = pw.MemoryImage(imageBytes);

                return pw.Inseparable(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 16),
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('[#${idx + 1}] 節點 (Node): $tagsStr', style: boldContentStyle),
                            pw.Text(cap['timestamp'] ?? '', style: contentStyle),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        buildUrlLink('網址 (URL): ', cap['url'] ?? '', fontSize: 7.5),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          height: 160,
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Image(pdfImg, fit: pw.BoxFit.contain),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final sha256Val = sha256.convert(pdfBytes).toString();

      return {
        'bytes': pdfBytes,
        'sha256': sha256Val,
      };
    } catch (e) {
      debugPrint("Web Evidence PDF Generation Failed: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
      return null;
    }
  }

  static Future<void> generateTrustScanReport({
    required BuildContext context,
    required int totalScore,
    required String gradeTitle,
    required String gradeRange,
    required String gradeDesc,
    required String gradeAdvice,
    required int d1Score,
    required int d2Score,
    required int d3Score,
    required int d4Score,
  }) async {
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating PDF scan report, please wait...')),
        );
      }

      final font = await PdfGoogleFonts.notoSansTCRegular();
      final fontBold = await PdfGoogleFonts.notoSansTCBold();

      final titleStyle = pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900);
      final sectionStyle = pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.blue800);
      final labelStyle = pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey900);
      final contentStyle = pw.TextStyle(font: font, fontSize: 10, color: PdfColors.black);
      final boldContentStyle = pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black);

      final pdf = pw.Document();
      final reportId = DateTime.now().millisecondsSinceEpoch.toString();
      final timestamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');

      pw.Widget buildField(String label, String content) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: labelStyle),
              pw.SizedBox(height: 1),
              pw.Text(content, style: contentStyle),
            ],
          ),
        );
      }

      pw.Widget buildBilingualFooter(int pageNum) {
        return pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 15),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '本報告由當事人依客觀事實勾選、經地端演算法評估產出。',
                style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700),
              ),
              pw.Text(
                'Report ID: $reportId  |  第 $pageNum 頁，共 2 頁',
                style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700),
              ),
            ],
          ),
        );
      }

      // Page 1: Personal Result
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blue900,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '誰在亂搞？ —— 陌生朋友靠譜度掃描報告',
                      style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.white),
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),

                // Report Details Columns
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('基本評估資訊', style: sectionStyle),
                          pw.SizedBox(height: 8),
                          buildField('報告編號 (Report ID)', reportId),
                          buildField('評估時間 (Generated Time)', timestamp),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('地端演算法得分', style: sectionStyle),
                          pw.SizedBox(height: 8),
                          pw.Text('總評估得分: $totalScore 分 / 50 分', style: boldContentStyle),
                          pw.SizedBox(height: 4),
                          pw.Text('靠譜等級: $gradeTitle', style: boldContentStyle),
                          pw.SizedBox(height: 4),
                          pw.Text('適用情境: 交往、借錢、合夥創業安全篩選', style: contentStyle),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey300, height: 1),
                pw.SizedBox(height: 12),

                // Dimension table
                pw.Text('四大維度細項評估', style: sectionStyle),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('評估維度', style: boldContentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('得分 / 滿分', style: boldContentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('健康度狀態', style: boldContentStyle),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('現況透明度', style: contentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('$d1Score / 15', style: contentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(d1Score >= 12 ? '良好：背景財務透明' : (d1Score >= 9 ? '中等：稍有隱瞞或不夠深入' : '高風險：極度不透明，不可信'), style: contentStyle),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('利益壓力測試', style: contentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('$d2Score / 15', style: contentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(d2Score >= 12 ? '良好：履約意願高，尊重拒絕' : (d2Score >= 9 ? '中等：偶有情緒性催促' : '高風險：用情感或話術利益施壓'), style: contentStyle),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('極限信任能力', style: contentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('$d3Score / 10', style: contentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(d3Score >= 8 ? '良好：無成癮，資產託付度高' : (d3Score >= 6 ? '中等：存在某些風險未知數' : '高風險：有成癮或財務黑洞傾向'), style: contentStyle),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('綜合人格與直覺預警', style: contentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('$d4Score / 10', style: contentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(d4Score >= 8 ? '良好：人格正面，無異樣感' : (d4Score >= 6 ? '中等：偶有令人存疑之處' : '高風險：直覺不安全，嚴防背叛'), style: contentStyle),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // Analysis details
                pw.Text('詳細結果說明', style: sectionStyle),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Paragraph(
                    text: gradeDesc,
                    style: pw.TextStyle(font: font, fontSize: 9.5, color: PdfColors.black, height: 1.4),
                  ),
                ),
                pw.SizedBox(height: 12),
                
                pw.Text('地端防禦防範建議', style: sectionStyle),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Paragraph(
                    text: gradeAdvice,
                    style: pw.TextStyle(font: font, fontSize: 9.5, color: PdfColors.blue900, height: 1.4),
                  ),
                ),

                pw.Spacer(),
                buildBilingualFooter(1),
              ],
            );
          },
        ),
      );

      // Page 2: Golden Rules and Rejection Formula
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blue900,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '防熟人詐騙三大鐵律 & 終極拒絕公式',
                      style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.white),
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),

                pw.Text('防熟人詐騙三大鐵律', style: titleStyle),
                pw.SizedBox(height: 10),

                ...TrustScanConstants.goldenRules.map((rule) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Container(
                      width: double.infinity,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(rule['title'] ?? '', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.red900)),
                          pw.SizedBox(height: 3),
                          pw.Paragraph(
                            text: rule['desc'] ?? '',
                            style: pw.TextStyle(font: font, fontSize: 9.5, height: 1.4, color: PdfColors.black),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 10),

                pw.Text('終極拒絕公式 & 實戰範本', style: titleStyle),
                pw.SizedBox(height: 8),

                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.fromBorderSide(pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                  child: pw.Paragraph(
                    text: TrustScanConstants.rejectionFormula,
                    style: pw.TextStyle(font: font, fontSize: 9.5, height: 1.4, color: PdfColors.black),
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
        filename: 'trust_scan_report_$reportId.pdf',
      );
    } catch (e) {
      debugPrint("PDF Generation Failed: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  static Future<void> generateRentalRiskReport({
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

      final titleStyle = pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.green900);
      final sectionStyle = pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.green800);
      final labelStyle = pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey900);
      final contentStyle = pw.TextStyle(font: font, fontSize: 10, color: PdfColors.black);
      final boldContentStyle = pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black);

      final pdf = pw.Document();
      final reportId = DateTime.now().millisecondsSinceEpoch.toString();
      final timestamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');

      // Dynamic spacing adjustment to prevent 3 pages when red flags are present
      final bool hasFlags = triggeredRedFlags.isNotEmpty;
      final double spacing = hasFlags ? 8.0 : 16.0;
      final double innerSpacing = hasFlags ? 4.0 : 8.0;

      pw.Widget buildField(String label, String content) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: labelStyle),
              pw.SizedBox(height: 1),
              pw.Text(content, style: contentStyle),
            ],
          ),
        );
      }

      pw.Widget buildBilingualFooter(int pageNum) {
        return pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 15),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '本報告由當事人依客觀事實勾選、經地端演算法評估產出。全程地端無涉私個資。',
                style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700),
              ),
              pw.Text(
                'Report ID: $reportId  |  第 $pageNum 頁，共 2 頁',
                style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700),
              ),
            ],
          ),
        );
      }

      // Page 1: Personal Result
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.green900,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '誰在亂搞？ —— 租屋風險健檢報告',
                      style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.white),
                    ),
                  ),
                ),
                pw.SizedBox(height: spacing),

                // Red Flags Banner at the top if triggered
                if (hasFlags) ...[
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.red100,
                      border: pw.Border.all(color: PdfColors.red900, width: 1.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '🚨 重大風險警訊：本物件已觸發致命紅旗項目！',
                          style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.red900),
                        ),
                        pw.SizedBox(height: 4),
                        ...triggeredRedFlags.map((flag) => pw.Text(
                          '• 已觸發：$flag (高度懷疑為假房東或人頭詐騙行為)',
                          style: pw.TextStyle(font: font, fontSize: 9.5, color: PdfColors.red900),
                        )),
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
                          pw.Text('基本評估資訊', style: sectionStyle),
                          pw.SizedBox(height: innerSpacing),
                          buildField('報告編號 (Report ID)', reportId),
                          buildField('評估時間 (Generated Time)', timestamp),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('地端演算法得分', style: sectionStyle),
                          pw.SizedBox(height: innerSpacing),
                          if (hasFlags) ...[
                            pw.Text('總評估得分: 🔴 觸發致命紅旗', style: boldContentStyle),
                          ] else ...[
                            pw.Text('總評估得分: $totalScore 分 / 100 分', style: boldContentStyle),
                          ],
                          pw.SizedBox(height: 4),
                          pw.Text('安全燈號: $gradeTitle', style: boldContentStyle),
                          pw.SizedBox(height: 4),
                          pw.Text('適用情境: 看房、簽約、防假房東防詐篩選', style: contentStyle),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: innerSpacing),
                pw.Divider(color: PdfColors.grey300, height: 1),
                pw.SizedBox(height: innerSpacing),

                // Dimension table
                pw.Text('三維度評分明細', style: sectionStyle),
                pw.SizedBox(height: innerSpacing),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('評估維度', style: boldContentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('得分 / 滿分', style: boldContentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('健康度狀態', style: boldContentStyle),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('看房現場觀察', style: contentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('$d1Score / 25', style: contentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(d1Score >= 20 ? '良好：居住環境安全' : (d1Score >= 15 ? '中等：有輕微結構/安全瑕疵' : '高風險：結構/消防隱憂嚴重'), style: contentStyle),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('法律與合約合規', style: contentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('$d2Score / 15', style: contentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(d2Score >= 12 ? '良好：合約條款公平合規' : (d2Score >= 9 ? '中等：修繕或報稅約定模糊' : '高風險：不平等條款或刁難限制'), style: contentStyle),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('詐騙風險模型', style: contentStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('$d3Score / 60', style: contentStyle, textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(d3Score >= 48 ? '良好：身分與行情真實透明' : (d3Score >= 36 ? '中等：資訊未完全驗證' : '高風險：高度符合詐騙特徵'), style: contentStyle),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: spacing),

                // Analysis details
                pw.Text('詳細結果說明', style: sectionStyle),
                pw.SizedBox(height: innerSpacing),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Paragraph(
                    text: gradeDesc,
                    style: pw.TextStyle(font: font, fontSize: 9.5, color: PdfColors.black, height: 1.4),
                  ),
                ),
                pw.SizedBox(height: innerSpacing),
                
                pw.Text('防禦防範建議', style: sectionStyle),
                pw.SizedBox(height: innerSpacing),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: gradeKey == 'red' ? PdfColors.red50 : (gradeKey == 'green' ? PdfColors.green50 : PdfColors.blue50),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Paragraph(
                    text: gradeAdvice,
                    style: pw.TextStyle(font: font, fontSize: 9.5, color: gradeKey == 'red' ? PdfColors.red900 : (gradeKey == 'green' ? PdfColors.green900 : PdfColors.blue900), height: 1.4),
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
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.green900,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '租屋安全官方查詢資源 & 免責聲明',
                      style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.white),
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),

                pw.Text('租屋安全查證官方資源附錄', style: titleStyle),
                pw.SizedBox(height: 10),

                ...RentalRiskConstants.officialResources.map((resource) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Container(
                      width: double.infinity,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(resource['title'] ?? '', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.green800)),
                          pw.SizedBox(height: 3),
                          pw.Paragraph(
                            text: resource['desc'] ?? '',
                            style: pw.TextStyle(font: font, fontSize: 9.5, height: 1.4, color: PdfColors.black),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 10),

                pw.Text('地端演算法評估聲明', style: titleStyle),
                pw.SizedBox(height: 8),

                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.fromBorderSide(pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                  child: pw.Paragraph(
                    text: '1. 本報告為個人化問卷評估報告，僅作為使用者看房、簽約前之自我風險篩選防範參考。本 App 與相關服務不保證房屋交易之完全安全，亦不負擔任何交易履約與資金損失責任。\n'
                          '2. 【全程地端安全承諾】：本功能之問卷勾選、評估計算與 PDF 報告產出，完全在使用者裝置本地端運算完成。系統全程不收集、不上傳任何涉私個人資料，不申請亦不取用任何 GPS 地理定位資訊，確保您的個人資料絕對隱私安全。\n'
                          '3. 涉及押金、定金匯款時，請務必先透過 165 反詐騙系統或地政謄本對照所有權人姓名與銀行帳戶姓名，切勿在未見到屋主本人並查驗正本房屋權狀前匯出任何款項。',
                    style: pw.TextStyle(font: font, fontSize: 9.5, height: 1.4, color: PdfColors.black),
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
        filename: 'rental_risk_report_$reportId.pdf',
      );
    } catch (e) {
      debugPrint("PDF Generation Failed: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }
}
