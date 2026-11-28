import 'package:flutter_test/flutter_test.dart';

String _classifyAngle(double qibla, double heading) {
  final d = ((qibla - heading) + 540) % 360 - 180;
  if (d.abs() < 5) return 'facing';
  if (d.abs() < 20) return 'close';
  if (d > 0) return 'right';
  return 'left';
}

void main() {
  group('F48a – Qibla instruction signed wrap', () {
    test('T1: 0/360 wrap – 10 degrees away shows close', () {
      expect(_classifyAngle(5.0, 355.0), 'close');
    });

    test('T2: positive diff shows turn right', () {
      expect(_classifyAngle(90.0, 45.0), 'right');
    });

    test('T3: negative diff shows turn left', () {
      expect(_classifyAngle(45.0, 90.0), 'left');
    });

    test('T4: exact same bearing shows facing', () {
      expect(_classifyAngle(180.0, 180.0), 'facing');
    });

    test('T5: exact opposite bearing tie-breaks to left', () {
      expect(_classifyAngle(180.0, 0.0), 'left');
    });
  });
}
