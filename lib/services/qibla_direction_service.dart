import 'dart:math' as math;

import '../models/qibla_direction.dart';

abstract final class QiblaDirectionService {
  static const double kaabaLatitude = 21.4225;
  static const double kaabaLongitude = 39.8262;
  static const double _earthRadiusKm = 6371.0088;

  static QiblaDirection calculate({
    required double latitude,
    required double longitude,
  }) {
    final latitudeRadians = _toRadians(latitude);
    final kaabaLatitudeRadians = _toRadians(kaabaLatitude);
    final longitudeDifference = _toRadians(kaabaLongitude - longitude);

    final y = math.sin(longitudeDifference) * math.cos(kaabaLatitudeRadians);
    final x = math.cos(latitudeRadians) * math.sin(kaabaLatitudeRadians) -
        math.sin(latitudeRadians) *
            math.cos(kaabaLatitudeRadians) *
            math.cos(longitudeDifference);
    final bearing = normalizeDegrees(_toDegrees(math.atan2(y, x)));

    final latitudeDifference = kaabaLatitudeRadians - latitudeRadians;
    final haversine = math.pow(math.sin(latitudeDifference / 2), 2) +
        math.cos(latitudeRadians) *
            math.cos(kaabaLatitudeRadians) *
            math.pow(math.sin(longitudeDifference / 2), 2);
    final centralAngle = 2 *
        math.atan2(
          math.sqrt(haversine.toDouble()),
          math.sqrt(1 - haversine.toDouble()),
        );

    return QiblaDirection(
      bearingDegrees: bearing,
      distanceKm: _earthRadiusKm * centralAngle,
    );
  }

  static double relativeAngle({
    required double qiblaBearing,
    required double deviceHeading,
  }) {
    final difference =
        normalizeDegrees(qiblaBearing) - normalizeDegrees(deviceHeading);
    return ((difference + 540) % 360) - 180;
  }

  static double normalizeDegrees(double value) => (value % 360 + 360) % 360;

  static double _toRadians(double degrees) => degrees * math.pi / 180;
  static double _toDegrees(double radians) => radians * 180 / math.pi;
}
