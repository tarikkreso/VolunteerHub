import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Public event detail screen — accepts either preloaded [event] data or [eventId] for API fetch.
class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? event;
  final int? eventId;
  const EventDetailScreen({super.key, this.event, this.eventId})
      : assert(event != null || eventId != null);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _event;
  List<dynamic> _shifts = [];
  Set<int> _registeredShiftIds = {};
  final Set<int> _loadingShiftIds = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _event = widget.event;
      _loadShifts(_event!['id']);
    } else {
      _fetchById();
    }
  }

  Future<void> _fetchById() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getEventById(widget.eventId!);
      if (mounted) {
        _event = res.data is Map ? Map<String, dynamic>.from(res.data) : null;
        if (_event != null) await _loadShifts(_event!['id']);
      }
    } catch (e) {
      debugPrint('Event fetch error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadShifts(int eventId) async {
    try {
      final res = await _api.getShiftsByEvent(eventId);
      final shifts = res.data is List ? res.data as List : [];
      final regRes = await _api.getMyShifts();
      final regs = regRes.data is List ? regRes.data as List : [];
      final regIds = <int>{};
      for (final r in regs) {
        final status = r['status'] as String?;
        if (status == 'Rejected' || status == 'Cancelled') continue;
        final sid = r['shiftId'];
        if (sid is int) regIds.add(sid);
      }
      final now = DateTime.now();
      final activeShifts = shifts.where((s) {
        final end = DateTime.tryParse(s['endTime'] ?? '')?.toLocal();
        return end == null || end.isAfter(now);
      }).toList();
      if (mounted) setState(() { _shifts = activeShifts; _registeredShiftIds = regIds; });
    } catch (_) {}
  }

  Future<void> _register(int shiftId) async {
    setState(() => _loadingShiftIds.add(shiftId));
    try {
      await _api.registerForShift(shiftId);
      setState(() => _registeredShiftIds.add(shiftId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uspješno ste se prijavili!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().contains('Već') ? 'Već ste prijavljeni' : 'Greška pri prijavi'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loadingShiftIds.remove(shiftId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_event?['title'] ?? 'Događaj')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _event == null
              ? const Center(child: Text('Događaj nije pronađen'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildHero(),
                    const SizedBox(height: 16),
                    Text(_event!['title'] ?? '',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_event!['categoryName'] != null)
                      Chip(
                        label: Text(_event!['categoryName']),
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      ),
                    const SizedBox(height: 16),
                    _infoTile(Icons.location_on, _event!['location'] ?? '-'),
                    _infoTile(Icons.calendar_today,
                        '${_fmtDate(_event!['startDate'])} - ${_fmtDate(_event!['endDate'])}'),
                    _infoTile(Icons.people, 'Maks. ${_event!['maxVolunteers'] ?? '-'} volontera'),
                    const SizedBox(height: 16),
                    Text('Opis',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_event!['description'] ?? 'Nema opisa', style: const TextStyle(height: 1.5)),
                    const SizedBox(height: 24),
                    Text('Dostupne smjene',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_shifts.isEmpty)
                      const Text('Nema dostupnih smjena')
                    else
                      ..._shifts.map((s) => _shiftCard(s)),
                  ]),
                ),
    );
  }

  Widget _buildHero() {
    final imageUrl = _event!['imageUrl'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          imageUrl.startsWith('http') ? imageUrl : '${_api.baseUrl}$imageUrl',
          height: 180, width: double.infinity, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _heroPlaceholder(),
        ),
      );
    }
    return _heroPlaceholder();
  }

  Widget _heroPlaceholder() => Container(
        height: 180, width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.event, size: 80, color: Theme.of(context).primaryColor),
      );

  Widget _shiftCard(dynamic s) {
    final shiftId = s['id'] as int;
    final isRegistered = _registeredShiftIds.contains(shiftId);
    final isLoading = _loadingShiftIds.contains(shiftId);
    final currentVol = s['currentVolunteers'] ?? 0;
    final maxVol = s['maxVolunteers'] ?? 0;
    final isFull = currentVol >= maxVol;
    final isLocked = s['isLocked'] == true;
    final start = DateTime.tryParse(s['startTime'] ?? '');
    final end = DateTime.tryParse(s['endTime'] ?? '');
    final durationH = start != null && end != null ? end.difference(start).inMinutes / 60.0 : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.access_time, size: 15, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text('${_fmtDT(s['startTime'])} — ${_fmtDT(s['endTime'])}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            const SizedBox(width: 12),
            Text('${durationH.toStringAsFixed(1)}h', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.people, size: 15, color: isFull ? Colors.red : Colors.grey[600]),
            const SizedBox(width: 6),
            Text('$currentVol / $maxVol',
                style: TextStyle(fontSize: 13, color: isFull ? Colors.red : Colors.grey[700])),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxVol > 0 ? (currentVol / maxVol).clamp(0.0, 1.0) : 0,
              backgroundColor: Colors.grey.shade200,
              color: isFull ? Colors.red : Colors.green,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : isRegistered
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Prijavljen'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                      )
                    : ElevatedButton(
                        onPressed: (isFull || isLocked) ? null : () => _register(shiftId),
                        child: Text(isFull ? 'Popunjeno' : isLocked ? 'Zaključano' : 'Prijavi se'),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _infoTile(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ]),
      );

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) { return iso; }
  }

  String _fmtDT(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }
}
