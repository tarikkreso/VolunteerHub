import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../events/event_detail_screen.dart';
import '../../services/api_service.dart';

class ShiftDetailScreen extends StatefulWidget {
  final int shiftId;
  final Map<String, dynamic>? initialRegistration;

  const ShiftDetailScreen({
    super.key,
    required this.shiftId,
    this.initialRegistration,
  });

  @override
  State<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends State<ShiftDetailScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _shift;
  Map<String, dynamic>? _event;
  Map<String, dynamic>? _registration;
  bool _loading = true;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _registration = widget.initialRegistration == null
        ? null
        : Map<String, dynamic>.from(widget.initialRegistration!);
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final shiftRes = await _api.getShiftById(widget.shiftId);
      final shiftData = shiftRes.data;
      _shift = shiftData is Map ? Map<String, dynamic>.from(shiftData) : null;

      final eventId = _readInt(_shift?['eventId']);
      if (eventId != null) {
        final eventRes = await _api.getEventById(eventId);
        final eventData = eventRes.data;
        _event = eventData is Map ? Map<String, dynamic>.from(eventData) : null;
      }

      if (_registration == null || _readInt(_registration?['shiftId']) != widget.shiftId) {
        final regsRes = await _api.getMyShifts();
        final regsData = regsRes.data;
        final items = regsData is Map
            ? (regsData['items'] as List? ?? [])
            : (regsData is List ? regsData : []);
        for (final item in items) {
          if (_readInt(item['shiftId']) == widget.shiftId) {
            _registration = Map<String, dynamic>.from(item as Map);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Shift detail load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = _shift?['name']?.toString() ??
        _registration?['shiftName']?.toString() ??
        'Smjena';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Otvori događaj',
            onPressed: _event == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailScreen(event: _event),
                      ),
                    );
                  },
            icon: const Icon(Icons.event_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _shift == null
              ? const Center(child: Text('Smjena nije pronađena'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHero(),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _registration?['eventTitle']?.toString() ??
                            _event?['title']?.toString() ??
                            '',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _summaryCard(),
                      const SizedBox(height: 16),
                      _detailsCard(),
                      const SizedBox(height: 16),
                      if (_registration != null) _registrationCard(),
                      const SizedBox(height: 20),
                      _actionRow(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHero() {
    final imageUrl = _event?['imageUrl'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          imageUrl.startsWith('http') ? imageUrl : '${_api.baseUrl}$imageUrl',
          height: 190,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _heroPlaceholder(),
        ),
      );
    }
    return _heroPlaceholder();
  }

  Widget _heroPlaceholder() => Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.schedule,
          size: 72,
          color: Theme.of(context).primaryColor,
        ),
      );

  Widget _summaryCard() {
    final shift = _shift!;
    final eventTitle = _event?['title']?.toString() ??
        _registration?['eventTitle']?.toString() ??
        '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    eventTitle.isEmpty ? 'Događaj' : eventTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _statusChip(_statusText()),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.calendar_today, _fmtRange(shift['startTime'], shift['endTime'])),
            _infoRow(Icons.people, 'Popunjeno: ${shift['currentVolunteers'] ?? 0} / ${shift['maxVolunteers'] ?? 0}'),
            if (shift['isLocked'] == true)
              _infoRow(Icons.lock, 'Smjena je zaključana'),
            if (shift['description'] != null && shift['description'].toString().isNotEmpty)
              _infoRow(Icons.description, shift['description'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard() {
    final shift = _shift!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalji smjene',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.access_time, _fmtSingle(shift['startTime'], shift['endTime'])),
            _infoRow(Icons.timelapse, _durationText(shift['startTime'], shift['endTime'])),
            _infoRow(Icons.group_outlined, 'Maksimalno volontera: ${shift['maxVolunteers'] ?? '-'}'),
            _infoRow(Icons.pin_drop_outlined, _event?['location']?.toString() ?? _event?['locationName']?.toString() ?? '-'),
            if (_event?['categoryName'] != null)
              _infoRow(Icons.label_outline, _event!['categoryName'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _registrationCard() {
    final reg = _registration!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Moja prijava',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.badge_outlined, _statusText()),
            if (reg['checkInTime'] != null)
              _infoRow(Icons.login, 'Check-in: ${_fmtDateTime(reg['checkInTime'])}'),
            if (reg['checkOutTime'] != null)
              _infoRow(Icons.logout, 'Check-out: ${_fmtDateTime(reg['checkOutTime'])}'),
            if (reg['hoursWorked'] != null)
              _infoRow(Icons.hourglass_bottom, 'Odrađeno: ${_readNum(reg['hoursWorked'])!.toStringAsFixed(1)} sati'),
            if (reg['notes'] != null && reg['notes'].toString().isNotEmpty)
              _infoRow(Icons.notes, reg['notes'].toString()),
            if (reg['adminNotes'] != null && reg['adminNotes'].toString().isNotEmpty)
              _infoRow(Icons.fact_check, reg['adminNotes'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _actionRow() {
    final canCheckIn = _canCheckIn();
    final canCheckOut = _isActive();
    final canCancel = _canCancel();

    if (!canCheckIn && !canCheckOut && !canCancel) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (canCancel)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _actionLoading ? null : _cancelRegistration,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Otkaži'),
            ),
          ),
        if (canCancel && (canCheckIn || canCheckOut)) const SizedBox(width: 8),
        if (canCheckIn)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _actionLoading ? null : _checkIn,
              icon: _actionLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('Check-in'),
            ),
          ),
        if (canCheckIn && canCheckOut) const SizedBox(width: 8),
        if (canCheckOut)
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _actionLoading ? null : _checkOut,
              icon: _actionLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.stop_circle),
              label: const Text('Check-out'),
            ),
          ),
      ],
    );
  }

  Future<void> _checkIn() async {
    final shiftId = widget.shiftId;
    setState(() => _actionLoading = true);
    try {
      await _api.checkIn(shiftId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in uspješan.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showError(e, 'Greška pri check-in-u.');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _checkOut() async {
    final shiftId = widget.shiftId;
    setState(() => _actionLoading = true);
    try {
      await _api.checkOut(shiftId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-out uspješan. Sati su poslani na odobravanje.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError(e, 'Greška pri check-out-u.');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _cancelRegistration() async {
    final registrationId = _readInt(_registration?['id']);
    if (registrationId == null) return;
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Otkaži smjenu'),
        content: TextField(
          controller: reasonController,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Razlog otkazivanja',
            helperText: 'Obavezno unesite razlog.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ne')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Da, otkaži')),
        ],
      ),
    );
    if (confirm != true) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (reason.isEmpty) {
      _showError(StateError('Razlog otkazivanja je obavezan.'), 'Razlog otkazivanja je obavezan.');
      return;
    }

    setState(() => _actionLoading = true);
    try {
      await _api.cancelShiftRegistration(registrationId, reason);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prijava na smjenu je otkazana.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showError(e, 'Nije moguće otkazati smjenu.');
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _showError(Object error, String fallback) {
    var message = fallback;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        message = data['message'].toString();
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Widget _statusChip(String label) {
    final color = _statusColor(_registration?['status']?.toString() ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  bool _canCheckIn() {
    final status = _registration?['status']?.toString();
    return status == 'Registered' && _registration?['checkInTime'] == null;
  }

  bool _isActive() {
    return _registration?['checkInTime'] != null && _registration?['checkOutTime'] == null;
  }

  bool _canCancel() {
    final status = _registration?['status']?.toString();
    return _registration?['checkInTime'] == null &&
        (status == 'Registered' || status == 'Pending');
  }

  String _statusText() {
    final status = _registration?['status']?.toString() ?? '-';
    return switch (status) {
      'Registered' => 'Prijavljena',
      'Pending' => 'Čeka odobrenje',
      'Approved' => 'Odobrena',
      'Completed' => 'Završena',
      'Rejected' => 'Odbijena',
      'Cancelled' => 'Otkazana',
      _ => status,
    };
  }

  Color _statusColor(String status) => switch (status) {
        'Approved' => Colors.green,
        'Completed' => Colors.blue,
        'Rejected' => Colors.red,
        'Cancelled' => Colors.redAccent,
        'Registered' => Colors.orange,
        'Pending' => Colors.orange,
        _ => Colors.grey,
      };

  String _fmtRange(dynamic start, dynamic end) {
    final s = _parseDate(start);
    final e = _parseDate(end);
    if (s == null || e == null) return '-';
    return '${_fmtDate(s)} • ${_fmtTime(s)} - ${_fmtTime(e)}';
  }

  String _fmtSingle(dynamic start, dynamic end) {
    final s = _parseDate(start);
    final e = _parseDate(end);
    if (s == null || e == null) return '-';
    return '${_fmtDate(s)} • ${_fmtTime(s)} - ${_fmtTime(e)}';
  }

  String _durationText(dynamic start, dynamic end) {
    final s = _parseDate(start);
    final e = _parseDate(end);
    if (s == null || e == null) return '-';
    final diff = e.difference(s);
    return 'Trajanje: ${diff.inHours}h ${diff.inMinutes % 60}min';
  }

  String _fmtDateTime(dynamic value) {
    final d = _parseDate(value);
    if (d == null) return '-';
    return '${_fmtDate(d)} ${_fmtTime(d)}';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  num? _readNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }
}
