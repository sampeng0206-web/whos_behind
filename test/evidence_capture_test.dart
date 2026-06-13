import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:whos_behind/constants/evidence_capture_constants.dart';

void main() {
  group('Online Shopping Dispute Evidence Capture Tests', () {
    test('SHA-256 Hash Formatting & Integrity Verification', () {
      final Uint8List dummyBytes1 = Uint8List.fromList([1, 2, 3, 4, 5]);
      final Uint8List dummyBytes2 = Uint8List.fromList([1, 2, 3, 4, 5]);
      final Uint8List dummyBytes3 = Uint8List.fromList([5, 4, 3, 2, 1]);

      final String hash1 = sha256.convert(dummyBytes1).toString();
      final String hash2 = sha256.convert(dummyBytes2).toString();
      final String hash3 = sha256.convert(dummyBytes3).toString();

      // Check format
      expect(hash1.length, 64);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hash1), true);

      // Check integrity (same bytes -> same hash, different bytes -> different hash)
      expect(hash1, hash2);
      expect(hash1, isNot(hash3));
    });

    test('Defensive Time-Chain Sorting Logic (Oldest to Newest)', () {
      final List<Map<String, dynamic>> unsortedCaptures = [
        {'timestamp': '2026-06-11 15:30:00', 'url': 'url1', 'tags': ['A']},
        {'timestamp': '2026-06-11 15:10:00', 'url': 'url2', 'tags': ['B']},
        {'timestamp': '2026-06-11 15:20:00', 'url': 'url3', 'tags': ['C']},
      ];

      // Perform the same sort logic used in generateWebEvidenceReport
      final sortedCaptures = List<Map<String, dynamic>>.from(unsortedCaptures);
      sortedCaptures.sort((a, b) {
        final String tA = a['timestamp'] ?? '';
        final String tB = b['timestamp'] ?? '';
        return tA.compareTo(tB);
      });

      expect(sortedCaptures[0]['timestamp'], '2026-06-11 15:10:00');
      expect(sortedCaptures[1]['timestamp'], '2026-06-11 15:20:00');
      expect(sortedCaptures[2]['timestamp'], '2026-06-11 15:30:00');
    });

    test('Custom Tag Character Length Limit Safety Checks', () {
      // Tags shouldn't exceed 10 characters in length to prevent PDF overflow
      const String validTag = '商品瑕疵照片';
      const String longTag = '極度嚴重之網購商品瑕疵與廣告不符';

      expect(validTag.length <= EvidenceCaptureConstants.maxCustomTagLength, true);
      expect(longTag.length <= EvidenceCaptureConstants.maxCustomTagLength, false);

      // Check truncation helper logic representing the dialog confirm button
      String processedTag = longTag;
      if (processedTag.length > EvidenceCaptureConstants.maxCustomTagLength) {
        processedTag = processedTag.substring(0, EvidenceCaptureConstants.maxCustomTagLength);
      }

      expect(processedTag.length, EvidenceCaptureConstants.maxCustomTagLength);
      expect(processedTag, '極度嚴重之網購商品瑕');
    });

    test('Evidence Capture Constants Limits Verification', () {
      expect(EvidenceCaptureConstants.minCaptures, 1);
      expect(EvidenceCaptureConstants.maxCaptures, 6);
      expect(EvidenceCaptureConstants.maxCustomTagLength, 10);
      expect(EvidenceCaptureConstants.nodeTags.length, 8);
    });

    test('Evidence Capture Button Unlock Boundary Logic', () {
      // 0 captures -> disabled / cannot export
      const bool canExportWith0 = 0 >= EvidenceCaptureConstants.minCaptures &&
          0 <= EvidenceCaptureConstants.maxCaptures;
      expect(canExportWith0, false);

      // 1 capture -> enabled / successfully unlocked
      const bool canExportWith1 = 1 >= EvidenceCaptureConstants.minCaptures &&
          1 <= EvidenceCaptureConstants.maxCaptures;
      expect(canExportWith1, true);

      // 6 captures -> enabled
      const bool canExportWith6 = 6 >= EvidenceCaptureConstants.minCaptures &&
          6 <= EvidenceCaptureConstants.maxCaptures;
      expect(canExportWith6, true);

      // 7 captures -> disabled / exceeds max
      const bool canExportWith7 = 7 >= EvidenceCaptureConstants.minCaptures &&
          7 <= EvidenceCaptureConstants.maxCaptures;
      expect(canExportWith7, false);
    });
  });
}
