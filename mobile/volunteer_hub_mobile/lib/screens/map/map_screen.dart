import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _api = ApiService();
  final MapController _mapController = MapController();
  List<dynamic> _events = [];
  List<Marker> _markers = [];
  bool _loading = true;
  bool _locating = false;
  String? _selectedFilter;
  LatLng? _userLocation;

  // Default center: Sarajevo
  static const _defaultCenter = LatLng(43.8563, 18.4131);

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadUserLocation();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getEvents(pageSize: 100);
      final d = res.data;
      final items = d is Map ? (d['items'] ?? []) : (d is List ? d : []);
      _events = (items as List)
          .where((e) => e['latitude'] != null && e['longitude'] != null)
          .toList();
      _buildMarkers();
    } catch (e) {
      debugPrint('Map events error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _buildMarkers() {
    final filtered = _selectedFilter == null
        ? _events
        : _events.where((e) => e['categoryName'] == _selectedFilter).toList();

    _markers = filtered.map<Marker>((e) {
      final lat = (e['latitude'] as num).toDouble();
      final lng = (e['longitude'] as num).toDouble();
      final upcoming = _isUpcoming(e);
      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showEventDetails(Map<String, dynamic>.from(e)),
          child: Icon(
            Icons.location_on,
            color: upcoming ? Colors.green : Colors.red,
            size: 40,
          ),
        ),
      );
    }).toList();

    if (_userLocation != null) {
      _markers.add(
        Marker(
          point: _userLocation!,
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _loadUserLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Lokacija nije omogućena. Koristi se podrazumijevana lokacija.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _userLocation = LatLng(position.latitude, position.longitude);
      _buildMarkers();
      _mapController.move(_userLocation!, 13);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nije moguće učitati trenutnu lokaciju.')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  List<dynamic> get _popularEvents {
    final list = List<dynamic>.from(_events);
    list.sort((a, b) {
      final aPop =
          ((a['registeredVolunteers'] ?? a['currentVolunteers'] ?? 0) as num)
              .toInt();
      final bPop =
          ((b['registeredVolunteers'] ?? b['currentVolunteers'] ?? 0) as num)
              .toInt();
      return bPop.compareTo(aPop);
    });
    return list.take(5).toList();
  }

  bool _isUpcoming(Map<String, dynamic> e) {
    final endDate = DateTime.tryParse(e['endDate'] ?? '');
    return endDate != null && endDate.isAfter(DateTime.now());
  }

  void _showEventDetails(Map<String, dynamic> e) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.event,
                  color: Theme.of(context).primaryColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e['title'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(e['location'] ?? '',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13))),
                    ]),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          if (e['description'] != null)
            Text(e['description'],
                style: TextStyle(color: Colors.grey[700], height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Text(_fmtDate(e['startDate']),
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(width: 4),
            Text('-', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(width: 4),
            Text(_fmtDate(e['endDate']),
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const Spacer(),
            if (e['categoryName'] != null)
              Chip(
                label: Text(e['categoryName'],
                    style: const TextStyle(fontSize: 11)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, e);
              },
              icon: const Icon(Icons.info_outline),
              label: const Text('Pogledaj detalje'),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _events
        .where((e) => e['categoryName'] != null)
        .map<String>((e) => e['categoryName'] as String)
        .toSet()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa događaja'),
        actions: [
          IconButton(
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            onPressed: _locating ? null : _loadUserLocation,
            tooltip: 'Pronađi moju lokaciju',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
            tooltip: 'Osvježi',
          ),
        ],
      ),
      body: Column(children: [
        // Filter chips
        if (categories.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Svi'),
                    selected: _selectedFilter == null,
                    onSelected: (_) => setState(() {
                      _selectedFilter = null;
                      _buildMarkers();
                    }),
                  ),
                ),
                ...categories.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(c),
                        selected: _selectedFilter == c,
                        onSelected: (_) => setState(() {
                          _selectedFilter = _selectedFilter == c ? null : c;
                          _buildMarkers();
                        }),
                      ),
                    )),
              ],
            ),
          ),
        // Map
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 12,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.volunteerhub.mobile',
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'center_location',
                onPressed: _userLocation == null
                    ? null
                    : () => _mapController.move(_userLocation!, 14),
                child: const Icon(Icons.gps_fixed),
              ),
            ),
          ]),
        ),
        // Event count + popular list
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_markers.length} događaj${_markers.length == 1 ? '' : 'a'} na mapi',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('Popularni događaji',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (_popularEvents.isEmpty)
                const Text('Nema dostupnih događaja',
                    style: TextStyle(color: Colors.grey))
              else
                ..._popularEvents.map((e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 20),
                      title: Text(e['title']?.toString() ?? '',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(e['location']?.toString() ?? '',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text('${(e['registeredVolunteers'] ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () =>
                          _showEventDetails(Map<String, dynamic>.from(e)),
                    )),
            ],
          ),
        ),
      ]),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
