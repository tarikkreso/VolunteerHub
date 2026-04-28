import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ShiftsTab extends StatefulWidget {
  final ValueNotifier<int>? refreshTrigger;
  const ShiftsTab({super.key, this.refreshTrigger});
  @override
  State<ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<ShiftsTab> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;
  List<dynamic> _shifts = [];
  bool _loading = true;
  bool _actionLoading = false;

  DateTime? _filterDate;

  Timer? _timer;
  int? _activeShiftId;
  DateTime? _checkInTime;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
    widget.refreshTrigger?.addListener(_onRefreshTrigger);
  }

  void _onRefreshTrigger() => _load();

  @override
  void dispose() {
    widget.refreshTrigger?.removeListener(_onRefreshTrigger);
    _tabCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getMyShifts();
      final data = res.data;
      _shifts = data is Map
          ? (data['items'] as List? ?? [])
          : (data is List ? data : []);
      _activeShiftId = null;
      _checkInTime = null;
      for (final s in _shifts) {
        if (s['checkInTime'] != null && s['checkOutTime'] == null) {
          _activeShiftId = s['shiftId'];
          _checkInTime = DateTime.tryParse(s['checkInTime'] ?? '')?.toLocal();
          _startTimer();
          break;
        }
      }
    } catch (e) {
      debugPrint('My shifts error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  String _elapsed() {
    if (_checkInTime == null) return '00:00:00';
    final diff = DateTime.now().difference(_checkInTime!);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  bool _matchesDateFilter(dynamic s) {
    if (_filterDate == null) return true;
    final start = DateTime.tryParse(s['shiftStartTime'] ?? '')?.toLocal();
    if (start == null) return false;
    return start.year == _filterDate!.year &&
        start.month == _filterDate!.month &&
        start.day == _filterDate!.day;
  }

  List<dynamic> get _upcoming {
    final now = DateTime.now();
    final list = _shifts.where((s) {
      final status = s['status'] ?? '';
      final endTime = DateTime.tryParse(s['shiftEndTime'] ?? '')?.toLocal();
      final isActive = s['checkInTime'] != null && s['checkOutTime'] == null;
      if (isActive) return _matchesDateFilter(s);
      if (status != 'Registered' && status != 'Pending' && status != 'Approved') return false;
      if (endTime != null && endTime.isBefore(now)) return false;
      return _matchesDateFilter(s);
    }).toList();
    list.sort((a, b) {
      final aTime = DateTime.tryParse(a['shiftStartTime'] ?? '') ?? DateTime(2099);
      final bTime = DateTime.tryParse(b['shiftStartTime'] ?? '') ?? DateTime(2099);
      return aTime.compareTo(bTime);
    });
    return list;
  }

  List<dynamic> get _completed {
    final list = _shifts.where((s) {
      final status = s['status'] ?? '';
      final isCompleted = status == 'Completed' || status == 'Rejected' ||
          (s['checkInTime'] != null && s['checkOutTime'] != null && status != 'Registered');
      if (!isCompleted) return false;
      return _matchesDateFilter(s);
    }).toList();
    list.sort((a, b) {
      final aTime = DateTime.tryParse(a['shiftStartTime'] ?? '') ?? DateTime(2099);
      final bTime = DateTime.tryParse(b['shiftStartTime'] ?? '') ?? DateTime(2099);
      return bTime.compareTo(aTime);
    });
    return list;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _filterDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(children: [
      // Active shift timer
      if (_activeShiftId != null) _buildActiveTimer(),

      // Date filter
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(children: [
          FilterChip(
            avatar: Icon(Icons.calendar_today, size: 16,
                color: _filterDate != null ? Colors.white : Theme.of(context).primaryColor),
            label: Text(_filterDate != null
                ? '${_filterDate!.day.toString().padLeft(2, '0')}.${_filterDate!.month.toString().padLeft(2, '0')}.${_filterDate!.year}'
                : 'Filtriraj po datumu'),
            selected: _filterDate != null,
            onSelected: (_) => _pickDate(),
            selectedColor: Theme.of(context).primaryColor,
            labelStyle: TextStyle(color: _filterDate != null ? Colors.white : null),
          ),
          if (_filterDate != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: 'Ukloni filter',
              onPressed: () => setState(() => _filterDate = null),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ]),
      ),

      // Tabs
      TabBar(controller: _tabCtrl, tabs: [
        Tab(text: 'Nadolazeće (${_upcoming.length})'),
        Tab(text: 'Završene (${_completed.length})'),
      ]),
      Expanded(
        child: TabBarView(controller: _tabCtrl, children: [
          _buildList(_upcoming, isUpcoming: true),
          _buildList(_completed, isUpcoming: false),
        ]),
      ),
    ]);
  }

  Widget _buildActiveTimer() {
    final active = _shifts.firstWhere(
      (s) => s['shiftId'] == _activeShiftId,
      orElse: () => <String, dynamic>{},
    );
    final shiftName = active['shiftName'] ?? '';
    final eventTitle = active['eventTitle'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade700]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Aktivna smjena', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        if (eventTitle.isNotEmpty || shiftName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            eventTitle.isNotEmpty ? '$eventTitle • $shiftName' : shiftName,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 8),
        Text(_elapsed(), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red),
          onPressed: _actionLoading ? null : () => _checkOut(_activeShiftId!),
          icon: _actionLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.stop_circle),
          label: const Text('Check-out'),
        ),
      ]),
    );
  }

  Widget _buildList(List<dynamic> items, {required bool isUpcoming}) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isUpcoming ? Icons.event_available : Icons.history, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            isUpcoming ? 'Nemate nadolazećih smjena' : 'Nema završenih smjena',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _buildShiftCard(items[i], isUpcoming: isUpcoming),
      ),
    );
  }

  Widget _buildShiftCard(dynamic s, {required bool isUpcoming}) {
    final status = s['status'] ?? '';
    final shiftId = s['shiftId'] as int? ?? 0;
    final canCheckIn = isUpcoming && s['checkInTime'] == null && (status == 'Registered' || status == 'Pending');
    final isActive = s['checkInTime'] != null && s['checkOutTime'] == null;
    final startTime = DateTime.tryParse(s['shiftStartTime'] ?? '');
    final endTime = DateTime.tryParse(s['shiftEndTime'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header: event title + status badge
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['eventTitle'] ?? 'Događaj', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (s['shiftName'] != null)
                  Text(s['shiftName'], style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(fontSize: 12, color: _statusColor(status), fontWeight: FontWeight.w600),
              ),
            ),
          ]),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Date row
          Row(children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(_fmtFullDate(startTime), style: const TextStyle(fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          // Time row
          Row(children: [
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text('${_fmtTime(startTime)} — ${_fmtTime(endTime)}', style: const TextStyle(fontSize: 13)),
            if (startTime != null && endTime != null) ...[
              const SizedBox(width: 8),
              Text(
                '(${endTime.difference(startTime).inHours}h ${endTime.difference(startTime).inMinutes % 60}min)',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ]),

          // Check-in/out times
          if (s['checkInTime'] != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.login, size: 16, color: Colors.green[700]),
              const SizedBox(width: 6),
              Text('Check-in: ${_fmtDateTime(s['checkInTime'])}', style: TextStyle(fontSize: 12, color: Colors.green[700])),
            ]),
          ],
          if (s['checkOutTime'] != null) ...[
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.logout, size: 16, color: Colors.red[700]),
              const SizedBox(width: 6),
              Text('Check-out: ${_fmtDateTime(s['checkOutTime'])}', style: TextStyle(fontSize: 12, color: Colors.red[700])),
            ]),
          ],

          // Hours worked
          if (s['hoursWorked'] != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.timelapse, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text('Odrađeno: ${(s['hoursWorked'] as num?)?.toStringAsFixed(1) ?? '0.0'} sati',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
          ],

          // Action buttons
          if (canCheckIn || isActive) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (canCheckIn)
                ElevatedButton.icon(
                  onPressed: _actionLoading ? null : () => _checkIn(shiftId),
                  icon: _actionLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Check-in'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (isActive)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer, color: Colors.green, size: 20),
                  const SizedBox(width: 6),
                  Text(_elapsed(), style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ]),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _checkIn(int shiftId) async {
    setState(() => _actionLoading = true);
    try {
      await _api.checkIn(shiftId);
      _activeShiftId = shiftId;
      _checkInTime = DateTime.now();
      _startTimer();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in uspješan!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) {
        String msg = 'Greška pri check-in-u';
        final eStr = e.toString();
        if (eStr.contains('Već ste')) {
          msg = 'Već ste se prijavili na ovu smjenu';
        } else if (eStr.contains('zaključana')) {
          msg = 'Smjena je zaključana';
        } else if (eStr.contains('Check-in nije moguć') || eStr.contains('prije početka')) {
          msg = 'Check-in nije moguć prije početka smjene (najranije 15 min prije)';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  Future<void> _checkOut(int shiftId) async {
    setState(() => _actionLoading = true);
    try {
      await _api.checkOut(shiftId);
      _timer?.cancel();
      _activeShiftId = null;
      _checkInTime = null;
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-out uspješan! Sati zabilježeni.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Greška pri check-out-u. Pokušajte ponovo.'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  // ── Formatting helpers ──

  String _statusLabel(String status) => switch (status) {
        'Approved' => 'Odobreno',
        'Completed' => 'Završeno',
        'Rejected' => 'Odbijeno',
        'Registered' => 'Prijavljeno',
        'Pending' => 'Čeka se odobrenje',
        'Cancelled' => 'Otkazano',
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'Approved' => Colors.green,
        'Completed' => Colors.blue,
        'Rejected' => Colors.red,
        'Cancelled' => Colors.red.shade300,
        'Registered' || 'Pending' => Colors.orange,
        _ => Colors.grey,
      };

  static const _dayNames = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];

  /// Formats a DateTime as "Pon, 23.02.2026"
  String _fmtFullDate(DateTime? d) {
    if (d == null) return '-';
    final dayName = _dayNames[d.weekday - 1];
    return '$dayName, ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  /// Formats a DateTime as "08:00"
  String _fmtTime(DateTime? d) {
    if (d == null) return '-';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// Formats an ISO string as "23.02.2026 08:00"
  String _fmtDateTime(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
