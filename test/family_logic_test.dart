import 'package:flutter_test/flutter_test.dart';

class AppLogicTester {
  //check if battery alert should be sent (e.g., below 15% and last alert was above 15%)
  bool shouldSendBatteryAlert(int currentLevel, int lastAlertLevel) {
    return currentLevel <= 15 && currentLevel < lastAlertLevel;
  }

  //check if movement is significant enough to update location (e.g., more than 25m)
  bool isSignificantMovement(double distanceInMeters) {
    // save datata  25m
    return distanceInMeters >= 25.0;
  }

  bool isMorningAlertWindow(int hour) {
    return hour >= 6 && hour <= 9;
  }
}

void main() {
  group('FamilyLink Pro - Logic Validation Tests', () {
    final tester = AppLogicTester();

    // Low Battery Alert Logic
    test('Battery Alert logic should return true for 12% if last was 20%', () {
      expect(tester.shouldSendBatteryAlert(12, 20), true);
    });

    test('Battery Alert logic should return false for 40%', () {
      expect(tester.shouldSendBatteryAlert(40, 50), false);
    });

    // Movement Logic
    test('Movement should be significant if distance is 30m', () {
      expect(tester.isSignificantMovement(30.0), true);
    });

    test('Movement should be ignored if distance is only 5m', () {
      expect(tester.isSignificantMovement(5.0), false);
    });

    // Time Window Logic
    test('Morning window should be true at 7 AM', () {
      expect(tester.isMorningAlertWindow(7), true);
    });

    test('Morning window should be false at 11 PM', () {
      expect(tester.isMorningAlertWindow(23), false);
    });
  });
}
