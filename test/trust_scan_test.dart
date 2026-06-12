import 'package:flutter_test/flutter_test.dart';
import 'package:whos_behind/constants/trust_scan_constants.dart';

void main() {
  group('Trust Scan Constants and Logic Tests', () {
    test('Question count should be 10', () {
      expect(TrustScanConstants.questions.length, 10);
    });

    test('Each question should have exactly 3 options', () {
      for (var q in TrustScanConstants.questions) {
        final options = q['options'] as List;
        expect(options.length, 3);
        
        final scores = options.map((opt) => opt['score'] as int).toList();
        expect(scores, containsAll([1, 3, 5]));
      }
    });

    test('Result grades should have ranges corresponding to scores', () {
      expect(TrustScanConstants.resultGrades.containsKey('A'), true);
      expect(TrustScanConstants.resultGrades.containsKey('B'), true);
      expect(TrustScanConstants.resultGrades.containsKey('C'), true);
      expect(TrustScanConstants.resultGrades.containsKey('D'), true);
      expect(TrustScanConstants.resultGrades.containsKey('E'), true);
    });

    test('Grade mapping logic validation', () {
      // Helper function matching the grade mapping logic in TrustScanScreen
      String getGradeKey(int score) {
        if (score >= 45) return 'A';
        if (score >= 38) return 'B';
        if (score >= 30) return 'C';
        if (score >= 20) return 'D';
        return 'E';
      }

      // Check all 1s (Score 10) -> Grade E
      expect(getGradeKey(10), 'E');
      expect(getGradeKey(19), 'E');

      // Check Score 20 -> Grade D
      expect(getGradeKey(20), 'D');
      expect(getGradeKey(29), 'D');

      // Check Score 30 -> Grade C
      expect(getGradeKey(30), 'C');
      expect(getGradeKey(37), 'C');

      // Check Score 38 -> Grade B
      expect(getGradeKey(38), 'B');
      expect(getGradeKey(44), 'B');

      // Check all 5s (Score 50) -> Grade A
      expect(getGradeKey(45), 'A');
      expect(getGradeKey(50), 'A');
    });

    test('Golden rules verification', () {
      expect(TrustScanConstants.goldenRules.length, 3);
      expect(TrustScanConstants.goldenRules[0]['title'], contains('鐵律'));
      expect(TrustScanConstants.goldenRules[1]['title'], contains('鐵律'));
      expect(TrustScanConstants.goldenRules[2]['title'], contains('鐵律'));
    });

    test('Rejection formula verification', () {
      expect(TrustScanConstants.rejectionFormula.isNotEmpty, true);
      expect(TrustScanConstants.rejectionFormula, contains('第三方不可抗力公式'));
    });
  });
}
