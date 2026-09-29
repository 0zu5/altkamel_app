import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';

class AntennaMapPoint {
  final double latitude;
  final double longitude;

  const AntennaMapPoint({required this.latitude, required this.longitude});
}

/// Lets a customer choose their antenna position without reading device GPS.
class AntennaLocationPicker extends StatefulWidget {
  const AntennaLocationPicker({super.key});

  @override
  State<AntennaLocationPicker> createState() => _AntennaLocationPickerState();
}

class _AntennaLocationPickerState extends State<AntennaLocationPicker> {
  static const _initialCenter = LatLng(32.8872, 13.1913);
  LatLng? _selected;

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
                'حرّك الخريطة واضغط على موقع الهوائي الفعلي. لا نستخدم موقع جهازك.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.slate700),
              ),
            ),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: 11,
                  onTap: (_, point) => setState(() => _selected = point),
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
