import 'package:flutter_test/flutter_test.dart';
import 'package:whos_behind/constants/rental_risk_constants.dart';

void main() {
  group('Rental Risk Scanner Score & Grade Mapping Tests', () {
    test('Question count should be exactly 16', () {
      expect(RentalRiskConstants.questions.length, 16);
    });

    test('Regular questions (1-13) and Red Flag questions (14-16) validation', () {
      for (int i = 0; i < 13; i++) {
        expect(RentalRiskConstants.questions[i]['isRedFlagType'], false);
      }
      for (int i = 13; i < 16; i++) {
        expect(RentalRiskConstants.questions[i]['isRedFlagType'], true);
      }
    });

    // Helper functions representing rating logic
    String getGradeKey(int score, bool hasRedFlag) {
      if (hasRedFlag) return 'red';
      if (score >= 61) return 'green';
      if (score >= 41) return 'orange';
      if (score >= 21) return 'yellow';
      return 'red';
    }

    test('Boundary Test 1: Regular questions all highest score, Red flags all NO -> 100 points -> Green', () {
      int score = 0;
      bool hasRedFlag = false;

      // Select highest options for Q1-Q13
      for (int i = 0; i < 13; i++) {
        final q = RentalRiskConstants.questions[i];
        final options = q['options'] as List;
        // The last option has the highest score
        final highestOpt = options.last;
        score += highestOpt['score'] as int;
      }

      // Red flags selected as NO (option index 1)
      for (int i = 13; i < 16; i++) {
        final q = RentalRiskConstants.questions[i];
        final options = q['options'] as List;
        final noOpt = options[1];
        if (noOpt['isRedFlag'] == true) {
          hasRedFlag = true;
        }
      }

      expect(score, 100);
      expect(hasRedFlag, false);
      expect(getGradeKey(score, hasRedFlag), 'green');
    });

    test('Boundary Test 2: Regular questions all lowest score, Red flags all NO -> 22 points -> Yellow', () {
      int score = 0;
      bool hasRedFlag = false;

      // Select lowest options for Q1-Q13
      for (int i = 0; i < 13; i++) {
        final q = RentalRiskConstants.questions[i];
        final options = q['options'] as List;
        // The first option has the lowest score
        final lowestOpt = options.first;
        score += lowestOpt['score'] as int;
      }

      // Red flags selected as NO (option index 1)
      for (int i = 13; i < 16; i++) {
        final q = RentalRiskConstants.questions[i];
        final options = q['options'] as List;
        final noOpt = options[1];
        if (noOpt['isRedFlag'] == true) {
          hasRedFlag = true;
        }
      }

      expect(score, 22);
      expect(hasRedFlag, false);
      expect(getGradeKey(score, hasRedFlag), 'yellow');
    });

    test('Boundary Test 3: Red flag Q14 is YES -> Directly Red Grade (Red Flag triggered)', () {
      int score = 100; // Even if regular questions get max score of 100
      bool hasRedFlag = false;

      // Q14 (index 13) is YES (index 0)
      final q14 = RentalRiskConstants.questions[13];
      final options14 = q14['options'] as List;
      final yesOpt = options14[0];
      if (yesOpt['isRedFlag'] == true) {
        hasRedFlag = true;
      }

      expect(hasRedFlag, true);
      expect(getGradeKey(score, hasRedFlag), 'red');
    });

    test('Boundary Test 4: Red flag Q15 is YES -> Directly Red Grade (Red Flag triggered)', () {
      int score = 100;
      bool hasRedFlag = false;

      // Q15 (index 14) is YES
      final q15 = RentalRiskConstants.questions[14];
      final options15 = q15['options'] as List;
      final yesOpt = options15[0];
      if (yesOpt['isRedFlag'] == true) {
        hasRedFlag = true;
      }

      expect(hasRedFlag, true);
      expect(getGradeKey(score, hasRedFlag), 'red');
    });

    test('Boundary Test 5: Red flag Q16 is YES -> Directly Red Grade (Red Flag triggered)', () {
      int score = 100;
      bool hasRedFlag = false;

      // Q16 (index 15) is YES
      final q16 = RentalRiskConstants.questions[15];
      final options16 = q16['options'] as List;
      final yesOpt = options16[0];
      if (yesOpt['isRedFlag'] == true) {
        hasRedFlag = true;
      }

      expect(hasRedFlag, true);
      expect(getGradeKey(score, hasRedFlag), 'red');
    });

    test('Official resources check', () {
      expect(RentalRiskConstants.officialResources.length, 4);
      expect(RentalRiskConstants.officialResources[0]['title'], '165反詐騙諮詢專線');
    });
  });
}
