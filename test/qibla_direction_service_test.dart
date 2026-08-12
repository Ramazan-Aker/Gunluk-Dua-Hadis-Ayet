import 'package:daily_dua_hadith/services/qibla_direction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('İstanbul için kıble yönü güneydoğudur', () {
    final direction = QiblaDirectionService.calculate(
      latitude: 41.0082,
      longitude: 28.9784,
    );

    expect(direction.bearingDegrees, closeTo(151.6, 0.8));
    expect(direction.distanceKm, inInclusiveRange(2350, 2450));
    expect(direction.cardinalDirection, 'Güneydoğu');
  });

  test('cihaz başlığı kıbleyle aynıysa göreli açı sıfırdır', () {
    final angle = QiblaDirectionService.relativeAngle(
      qiblaBearing: 151.6,
      deviceHeading: 151.6,
    );
    expect(angle, closeTo(0, 0.001));
  });

  test('göreli açı -180 ile 180 arasında normalize edilir', () {
    expect(
      QiblaDirectionService.relativeAngle(
        qiblaBearing: 10,
        deviceHeading: 350,
      ),
      closeTo(20, 0.001),
    );
    expect(
      QiblaDirectionService.relativeAngle(
        qiblaBearing: 350,
        deviceHeading: 10,
      ),
      closeTo(-20, 0.001),
    );
  });
}
