import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';

class AntennaMapPoint {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  const AntennaMapPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });
}

/// Lets a customer choose an antenna position manually, with an optional
/// foreground-only current-location shortcut.
class AntennaLocationPicker extends StatefulWidget {
  const AntennaLocationPicker({super.key});

  @override
  State<AntennaLocationPicker> createState() => _AntennaLocationPickerState();
}

class _AntennaLocationPickerState extends State<AntennaLocationPicker> {
  static const _initialCenter = LatLng(32.8872, 13.1913);
  final _mapController = MapController();
  LatLng? _selected;
  double? _selectedAccuracyMeters;
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('خدمات الموقع غير مفعلة على جهازك.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw StateError(
          'لم تمنح إذن استخدام الموقع. يمكنك اختيار الموقع يدوياً.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw StateError(
          'إذن الموقع محظور. فعّله من إعدادات التطبيق أو اختر الموقع يدوياً.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _selected = point;
        _selectedAccuracyMeters = position.accuracy;
      });
      _mapController.move(point, 16);
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خدمات الموقع غير مفعلة على جهازك.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تحديد موقعك الآن. اختر الموقع يدوياً أو حاول مرة أخرى.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختر موقع الهوائي')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'حرّك الخريطة واضغط على موقع الهوائي الفعلي. يمكنك استخدام موقعك الحالي كاختصار اختياري إذا كنت بالقرب من الهوائي.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.slate700),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_outlined),
                label: Text(
                  _locating ? 'جارٍ تحديد موقعك…' : 'استخدام موقعي الحالي',
                ),
              ),
            ),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: 11,
                  onTap: (_, point) => setState(() {
                    _selected = point;
                    _selectedAccuracyMeters = null;
                  }),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ly.altkamel.altkamel_app',
                  ),
                  if (_selected != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selected!,
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_pin,
                            color: AppColors.indigo,
                            size: 48,
                          ),
                        ),
                      ],
                    ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.of(context).pop(
                          AntennaMapPoint(
                            latitude: _selected!.latitude,
                            longitude: _selected!.longitude,
                            accuracyMeters: _selectedAccuracyMeters,
                          ),
                        ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('حفظ موقع الهوائي المختار'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
