import 'package:flutter_test/flutter_test.dart';

//  Test
class AppLogicTester {
  // Battery Alert
  bool shouldSendBatteryAlert(int currentLevel, int lastAlertLevel) {
    return currentLevel <= 15 && currentLevel < lastAlertLevel;
  }

  // 25m
  bool isSignificantMovement(double distanceInMeters) {
    return distanceInMeters >= 25.0;
  }

  // 9to 6
  bool isMorningAlertWindow(int hour) {
    return hour >= 6 && hour <= 9;
  }
}

// Tests
void main() {
  group('FamilyLink Pro - Logic Validation Tests', () {
    final tester = AppLogicTester();

    // 1. Low Battery Alert Logic Tests
    test('Battery Alert logic should return true for 12% if last was 20%', () {
      expect(tester.shouldSendBatteryAlert(12, 20), true);
    });

    test('Battery Alert logic should return false for 40%', () {
      expect(tester.shouldSendBatteryAlert(40, 50), false);
    });

    // 2. Movement Logic Tests
    test('Movement should be significant if distance is 30m', () {
      expect(tester.isSignificantMovement(30.0), true);
    });

    test('Movement should be ignored if distance is only 5m', () {
      expect(tester.isSignificantMovement(5.0), false);
    });

    // 3. Time Window Logic Tests
    test('Morning window should be true at 7 AM', () {
      expect(tester.isMorningAlertWindow(7), true);
    });

    test('Morning window should be false at 11 PM', () {
      expect(tester.isMorningAlertWindow(23), false);
    });
  });
}
