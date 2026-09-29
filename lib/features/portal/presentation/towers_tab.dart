import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../data/portal_models.dart';
import 'portal_controller.dart';
import 'widgets/portal_card.dart';

class TowersTab extends StatelessWidget {
  final PortalController controller;

  const TowersTab({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isLoading && controller.towers.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final towers = controller.towers;
        if (towers.isEmpty) {
          return RefreshIndicator(
            onRefresh: controller.loadAll,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 80),
                Icon(
                  Icons.cell_tower_outlined,
                  size: 48,
                  color: AppColors.slate400,
                ),
                SizedBox(height: 12),
                Text(
                  'لا توجد أبراج متاحة حالياً.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        final first = towers.first;
        return RefreshIndicator(
          onRefresh: controller.loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const Text(
                'أبراجنا',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'مواقع الأبراج المتاحة لخدمتك.',
                style: TextStyle(color: AppColors.slate500),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(first.latitude, first.longitude),
                      initialZoom: 10,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'ly.altkamel.altkamel_app',
                      ),
                      MarkerLayer(
                        markers: towers
                            .map(
                              (tower) => Marker(
                                point: LatLng(tower.latitude, tower.longitude),
                                width: 42,
                                height: 42,
                                child: const Icon(
                                  Icons.cell_tower,
                                  color: AppColors.indigo,
                                  size: 34,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SimpleAttributionWidget(
                        source: Text('© OpenStreetMap contributors'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...towers.map((tower) => _TowerCard(tower: tower)),
            ],
          ),
        );
      },
    );
  }
}

class _TowerCard extends StatelessWidget {
  final TowerInfo tower;

  const _TowerCard({required this.tower});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PortalCard(
        child: Row(
          children: [
            const Icon(Icons.cell_tower, color: AppColors.indigo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tower.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (tower.address?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      tower.address!,
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (tower.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      tower.description!,
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
