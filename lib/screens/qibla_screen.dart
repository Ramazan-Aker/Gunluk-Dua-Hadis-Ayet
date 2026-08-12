import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/qibla_direction.dart';
import '../services/firebase_service.dart'
    show FirebaseService, AnalyticsEvents, AnalyticsParams;
import '../services/qibla_direction_service.dart';
import '../theme/app_theme.dart';

enum _QiblaStatus {
  intro,
  loading,
  ready,
  permissionDenied,
  permissionDeniedForever,
  locationDisabled,
  error,
}

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({
    super.key,
    this.fallbackCityName,
    this.autoStart = true,
  });

  final String? fallbackCityName;
  final bool autoStart;

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with WidgetsBindingObserver {
  _QiblaStatus _status = _QiblaStatus.intro;
  QiblaDirection? _direction;
  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _heading;
  bool _sensorUnavailable = false;
  String _locationLabel = '';
  String _source = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FirebaseService.logScreenView(screenName: AnalyticsEvents.screenQibla);
    FirebaseService.logEvent(name: AnalyticsEvents.qiblaScreenViewed);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resumeWithExistingPermission();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_status == _QiblaStatus.permissionDeniedForever ||
            _status == _QiblaStatus.locationDisabled)) {
      _resumeWithExistingPermission();
    }
  }

  Future<void> _resumeWithExistingPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      final hasPermission = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (hasPermission && await Geolocator.isLocationServiceEnabled()) {
        await _loadDeviceLocation(requestPermission: false);
      }
    } catch (_) {
      // İlk ekranda izin istemeden tanıtım görünümü korunur.
    }
  }

  Future<void> _loadDeviceLocation({bool requestPermission = true}) async {
    if (!mounted) return;
    setState(() {
      _status = _QiblaStatus.loading;
      _errorMessage = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _status = _QiblaStatus.locationDisabled);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _status = _QiblaStatus.permissionDeniedForever);
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _status = _QiblaStatus.permissionDenied);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await _applyCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        label: 'Mevcut konum',
        source: 'device',
      );
    } catch (_) {
      _showError(
          'Konum alınamadı. Tekrar deneyebilir veya şehir merkezini kullanabilirsin.');
    }
  }

  Future<void> _loadSelectedCity() async {
    final cityName = widget.fallbackCityName?.trim();
    if (cityName == null || cityName.isEmpty) {
      _showError('Önce Namaz ekranından bir şehir seçmelisin.');
      return;
    }
    setState(() {
      _status = _QiblaStatus.loading;
      _errorMessage = null;
    });
    try {
      final locations = await Geocoding(
        locale: const Locale('tr', 'TR'),
      ).locationFromAddress('$cityName, Türkiye');
      if (locations.isEmpty) {
        _showError('$cityName için yaklaşık konum bulunamadı.');
        return;
      }
      final location = locations.first;
      await _applyCoordinates(
        latitude: location.latitude,
        longitude: location.longitude,
        label: '$cityName şehir merkezi',
        source: 'city',
      );
    } catch (_) {
      _showError(
          'Şehir konumu bulunamadı. İnternet bağlantını kontrol edip tekrar dene.');
    }
  }

  Future<void> _applyCoordinates({
    required double latitude,
    required double longitude,
    required String label,
    required String source,
  }) async {
    final direction = QiblaDirectionService.calculate(
      latitude: latitude,
      longitude: longitude,
    );
    if (!mounted) return;
    setState(() {
      _direction = direction;
      _locationLabel = label;
      _source = source;
      _heading = null;
      _sensorUnavailable = false;
      _status = _QiblaStatus.ready;
    });
    _startCompass();
    FirebaseService.logEvent(
      name: AnalyticsEvents.qiblaReady,
      parameters: {AnalyticsParams.qiblaSource: source},
    );
  }

  void _startCompass() {
    _compassSubscription?.cancel();
    final events = FlutterCompass.events;
    if (events == null) {
      if (mounted) setState(() => _sensorUnavailable = true);
      return;
    }
    _compassSubscription = events.listen(
      (event) {
        if (!mounted) return;
        final heading = event.heading;
        if (heading == null) {
          setState(() => _sensorUnavailable = true);
          return;
        }
        setState(() {
          _heading = QiblaDirectionService.normalizeDegrees(heading);
          _sensorUnavailable = false;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _sensorUnavailable = true);
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _status = _QiblaStatus.error;
      _errorMessage = message;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _compassSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(title: const Text('Kıbleyi Bul')),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _QiblaStatus.loading:
        return const Center(
          key: ValueKey('qibla-loading'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Kıble yönü hazırlanıyor...'),
            ],
          ),
        );
      case _QiblaStatus.ready:
        return _buildCompassContent();
      case _QiblaStatus.permissionDenied:
        return _buildStateCard(
          icon: Icons.location_off_outlined,
          title: 'Konum izni verilmedi',
          message:
              'İzni tekrar isteyebilir veya seçili şehir merkezini kullanabilirsin.',
          primaryLabel: 'Tekrar izin iste',
          onPrimary: _loadDeviceLocation,
        );
      case _QiblaStatus.permissionDeniedForever:
        return _buildStateCard(
          icon: Icons.settings_outlined,
          title: 'Konum izni ayarlardan kapalı',
          message:
              'Kıbleyi gerçek konumuna göre göstermek için uygulama ayarlarından konum iznini açabilirsin.',
          primaryLabel: 'Uygulama ayarlarını aç',
          onPrimary: Geolocator.openAppSettings,
        );
      case _QiblaStatus.locationDisabled:
        return _buildStateCard(
          icon: Icons.location_disabled_outlined,
          title: 'Konum servisi kapalı',
          message:
              'Cihazının konum servisini açabilir veya şehir merkezini kullanabilirsin.',
          primaryLabel: 'Konum ayarlarını aç',
          onPrimary: Geolocator.openLocationSettings,
        );
      case _QiblaStatus.error:
        return _buildStateCard(
          icon: Icons.explore_off_outlined,
          title: 'Kıble yönü hazırlanamadı',
          message: _errorMessage ?? 'Beklenmeyen bir sorun oluştu.',
          primaryLabel: 'Tekrar dene',
          onPrimary: _loadDeviceLocation,
        );
      case _QiblaStatus.intro:
        return _buildIntro();
    }
  }

  Widget _buildIntro() {
    return ListView(
      key: const ValueKey('qibla-intro'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      children: [
        Container(
          width: 104,
          height: 104,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.navyContainer,
            shape: BoxShape.circle,
            boxShadow: AppTheme.ambientShadow,
          ),
          child:
              const Icon(Icons.explore_rounded, color: AppTheme.gold, size: 58),
        ),
        const SizedBox(height: 26),
        const Text(
          'Bulunduğun yerden kıble yönünü öğren',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Konum yalnızca yönü hesaplamak için cihazında kullanılır. Arka planda izlenmez ve kaydedilmez.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, height: 1.45),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _loadDeviceLocation,
          icon: const Icon(Icons.my_location_rounded),
          label: const Text('Konumumu kullan'),
        ),
        if (widget.fallbackCityName?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadSelectedCity,
            icon: const Icon(Icons.location_city_outlined),
            label: Text('${widget.fallbackCityName} merkezini kullan'),
          ),
        ],
        const SizedBox(height: 24),
        _buildPrivacyNotice(),
      ],
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    required String primaryLabel,
    required Future<dynamic> Function() onPrimary,
  }) {
    return ListView(
      key: ValueKey(title),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      children: [
        Icon(icon, color: AppTheme.gold, size: 64),
        const SizedBox(height: 20),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 21,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, height: 1.4)),
        const SizedBox(height: 24),
        FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
        if (widget.fallbackCityName?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _loadSelectedCity,
            child: Text('${widget.fallbackCityName} merkezini kullan'),
          ),
        ],
      ],
    );
  }

  Widget _buildCompassContent() {
    final direction = _direction!;
    final relativeAngle = QiblaDirectionService.relativeAngle(
      qiblaBearing: direction.bearingDegrees,
      deviceHeading: _heading ?? 0,
    );
    final aligned = !_sensorUnavailable && relativeAngle.abs() <= 5;
    return ListView(
      key: const ValueKey('qibla-ready'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.mint.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 17, color: AppTheme.emerald),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(_locationLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.emerald,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed:
                  _source == 'device' ? _loadDeviceLocation : _loadSelectedCity,
              tooltip: 'Yenile',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: _QiblaCompassDial(
            relativeAngle: relativeAngle,
            aligned: aligned,
            sensorUnavailable: _sensorUnavailable,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _directionMessage(relativeAngle, direction),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: aligned ? AppTheme.emerald : AppTheme.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _sensorUnavailable
              ? 'Telefonun pusula sensörü kullanılamıyor; dereceyi kuzeye göre takip et.'
              : 'Telefonu düz tut ve metal eşyalardan uzaklaştır.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.explore_outlined,
                label: 'Kıble açısı',
                value: '${direction.bearingDegrees.round()}°',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                icon: Icons.straighten_rounded,
                label: 'Kâbe mesafesi',
                value: '${direction.distanceKm.round()} km',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.ambientShadow,
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.screen_rotation_alt_outlined, color: AppTheme.gold),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Yön kararsız görünüyorsa telefonu havada 8 çizerek kalibre et. Manyetik kılıflar pusulayı etkileyebilir.',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildPrivacyNotice(),
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.emerald),
          const SizedBox(height: 7),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, color: AppTheme.emerald, size: 16),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Konum kaydedilmez veya paylaşılmaz',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }

  String _directionMessage(
    double relativeAngle,
    QiblaDirection direction,
  ) {
    if (_sensorUnavailable) {
      return 'Kuzeyden ${direction.bearingDegrees.round()}° • ${direction.cardinalDirection}';
    }
    if (relativeAngle.abs() <= 5) return 'Kıble yönündesin';
    final side = relativeAngle > 0 ? 'sağa' : 'sola';
    return '$side ${relativeAngle.abs().round()}° dön';
  }
}

class _QiblaCompassDial extends StatelessWidget {
  const _QiblaCompassDial({
    required this.relativeAngle,
    required this.aligned,
    required this.sensorUnavailable,
  });

  final double relativeAngle;
  final bool aligned;
  final bool sensorUnavailable;

  @override
  Widget build(BuildContext context) {
    const size = 260.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Colors.white, Color(0xFFEAF2EF)],
              ),
              border: Border.all(
                color: aligned ? AppTheme.emerald : AppTheme.navy,
                width: aligned ? 4 : 2,
              ),
              boxShadow: AppTheme.ambientShadow,
            ),
          ),
          const Positioned(
            top: 14,
            child: Text('TELEFONUN ÜSTÜ',
                style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ),
          CustomPaint(size: const Size.square(size), painter: _TickPainter()),
          Transform.rotate(
            angle: relativeAngle * math.pi / 180,
            child: SizedBox(
              width: size - 44,
              height: size - 44,
              child: Align(
                alignment: Alignment.topCenter,
                child: Icon(
                  Icons.navigation_rounded,
                  size: 48,
                  color: aligned ? AppTheme.emerald : AppTheme.gold,
                ),
              ),
            ),
          ),
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.navyContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.gold, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8),
              ],
            ),
            child:
                const Icon(Icons.mosque_rounded, color: Colors.white, size: 30),
          ),
          if (sensorUnavailable)
            Positioned(
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLow,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('Manuel yön',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    for (var index = 0; index < 72; index++) {
      final angle = index * 5 * math.pi / 180 - math.pi / 2;
      final major = index % 9 == 0;
      final outer = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final innerRadius = radius - (major ? 12 : 6);
      final inner = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = major
              ? AppTheme.navy.withValues(alpha: .55)
              : AppTheme.outline.withValues(alpha: .6)
          ..strokeWidth = major ? 2 : 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
