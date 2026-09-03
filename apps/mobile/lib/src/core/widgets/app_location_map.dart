import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum AppLocationMapMode { fixed, live }

final class AppLocationMap extends StatefulWidget {
  AppLocationMap({
    required this.location,
    required this.mode,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    super.key,
  }) : assert(
          location.status == LocationStatus.available &&
              location.latitude != null &&
              location.longitude != null,
          'AppLocationMap requires an available location.',
        );

  final LocationCapture location;
  final AppLocationMapMode mode;
  final String tileUrl;

  @override
  State<AppLocationMap> createState() => _AppLocationMapState();
}

final class _AppLocationMapState extends State<AppLocationMap> {
  final MapController _controller = MapController();

  LatLng get _point => LatLng(
        widget.location.latitude!,
        widget.location.longitude!,
      );

  @override
  void didUpdateWidget(covariant AppLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locationChanged =
        oldWidget.location.latitude != widget.location.latitude ||
            oldWidget.location.longitude != widget.location.longitude;
    if (widget.mode == AppLocationMapMode.live && locationChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.move(_point, _controller.camera.zoom);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final point = _point;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        key: const Key('app-location-map'),
        height: 220,
        child: FlutterMap(
          mapController: _controller,
          options: MapOptions(initialCenter: point, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate: widget.tileUrl,
              userAgentPackageName: 'com.cyanzone.mobile',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 48,
                  height: 48,
                  child: DecoratedBox(
                    key: const Key('app-location-marker'),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 8,
                          color: Color(0x33000000),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.mode == AppLocationMapMode.live
                          ? Icons.my_location_rounded
                          : Icons.location_on_rounded,
                      color: colors.primary,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
            const SimpleAttributionWidget(
              key: Key('app-location-attribution'),
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
      ),
    );
  }
}
