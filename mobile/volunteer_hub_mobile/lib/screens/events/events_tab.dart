import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class EventsTab extends StatefulWidget {
  final VoidCallback? onNavigateToShifts;
  const EventsTab({super.key, this.onNavigateToShifts});
  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final _api = ApiService();
  List<dynamic> _events = [];
  List<dynamic> _categories = [];
  List<dynamic> _cities = [];
  List<dynamic> _organizations = [];
  List<dynamic> _recommended = [];
  bool _loading = true;
  bool _recLoading = true;
  int? _selectedCategory;
  int? _selectedCityId;
  int? _selectedOrganizationId;
  DateTimeRange? _selectedDateRange;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadFilterData();
    _loadEvents();
    _loadRecommended();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await _api.getCategories();
      if (mounted) {
        setState(() => _categories = res.data is List ? res.data : []);
      }
    } catch (_) {}
  }

  Future<void> _loadFilterData() async {
    try {
      final res = await Future.wait([
        _api.getCities(),
        _api.getOrganizations(pageSize: 100),
      ]);

      final citiesData = res[0].data;
      final orgData = res[1].data;

      if (!mounted) return;
      setState(() {
        _cities = citiesData is List ? citiesData : [];
        _organizations = orgData is Map
            ? (orgData['items'] ?? [])
            : (orgData is List ? orgData : []);
      });
    } catch (_) {}
  }

  Future<void> _loadRecommended() async {
    setState(() => _recLoading = true);
    try {
      final res = await _api.getRecommendedEvents(top: 5);
      if (mounted) {
        setState(() => _recommended = res.data is List ? res.data : []);
      }
    } catch (e) {
      debugPrint('Recommendations error: $e');
    }
    if (mounted) setState(() => _recLoading = false);
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getEvents(
        pageSize: 50,
        categoryId: _selectedCategory,
        cityId: _selectedCityId,
        organizationId: _selectedOrganizationId,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
        query: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
        status: 'Published',
      );
      final d = res.data;
      _events = d is Map ? (d['items'] ?? []) : (d is List ? d : []);
    } catch (e) {
      debugPrint('Events error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Pretraži događaje...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadEvents();
                        })
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _loadEvents(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Dodatni filteri',
            onPressed: _showFilterSheet,
            icon: Icon(
              Icons.tune,
              color:
                  _hasAdditionalFilters ? Theme.of(context).primaryColor : null,
            ),
          ),
        ]),
      ),
      // Category chips
      if (_categories.isNotEmpty)
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('Sve'),
                  selected: _selectedCategory == null,
                  onSelected: (_) {
                    setState(() => _selectedCategory = null);
                    _loadEvents();
                  },
                ),
              ),
              ..._categories.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c['name'] ?? ''),
                      selected: _selectedCategory == c['id'],
                      onSelected: (_) {
                        setState(() => _selectedCategory = c['id']);
                        _loadEvents();
                      },
                    ),
                  )),
            ],
          ),
        ),

      if (_hasAdditionalFilters)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (_selectedCityId != null)
                InputChip(
                  label: Text('Grad: ${_cityName(_selectedCityId)}'),
                  onDeleted: () {
                    setState(() => _selectedCityId = null);
                    _loadEvents();
                  },
                ),
              if (_selectedOrganizationId != null)
                InputChip(
                  label: Text(
                      'Organizacija: ${_organizationName(_selectedOrganizationId)}'),
                  onDeleted: () {
                    setState(() => _selectedOrganizationId = null);
                    _loadEvents();
                  },
                ),
              if (_selectedDateRange != null)
                InputChip(
                  label: Text(
                      'Period: ${_fmtDate(_selectedDateRange!.start.toIso8601String())} - ${_fmtDate(_selectedDateRange!.end.toIso8601String())}'),
                  onDeleted: () {
                    setState(() => _selectedDateRange = null);
                    _loadEvents();
                  },
                ),
              ActionChip(
                avatar: const Icon(Icons.clear, size: 16),
                label: const Text('Očisti sve'),
                onPressed: () {
                  setState(() {
                    _selectedCityId = null;
                    _selectedOrganizationId = null;
                    _selectedDateRange = null;
                  });
                  _loadEvents();
                },
              ),
            ],
          ),
        ),

      // Recommendations carousel
      if (_recommended.isNotEmpty || _recLoading) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(children: [
            const Icon(Icons.auto_awesome, size: 18, color: Colors.amber),
            const SizedBox(width: 6),
            Text('Za tebe',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ]),
        ),
        if (_recLoading)
          const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()))
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _recommended.length,
              itemBuilder: (ctx, i) => _recommendedCard(_recommended[i]),
            ),
          ),
      ],

      // Events list
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadEvents,
                child: _events.isEmpty
                    ? const Center(child: Text('Nema pronađenih događaja'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _events.length,
                        itemBuilder: (ctx, i) => _eventCard(_events[i]),
                      ),
              ),
      ),
    ]);
  }

  Widget _recommendedCard(dynamic rec) {
    final rawEvent = rec is Map ? (rec['event'] ?? rec) : rec;
    final event = rawEvent is Map<String, dynamic>
        ? rawEvent
        : Map<String, dynamic>.from(rawEvent as Map);
    final matchPct = ((rec is Map ? (rec['score'] ?? 0) : 0) * 100).toInt();
    final reasonStr = rec is Map ? (rec['reasonTags'] as String? ?? '') : '';
    final reasons = reasonStr.isNotEmpty
        ? reasonStr
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    return GestureDetector(
      onTap: () => _showEventDetails(event),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.08),
              Theme.of(context).primaryColor.withValues(alpha: 0.02)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(event['title'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (matchPct > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$matchPct%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700)),
              ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.location_on, size: 13, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
                child: Text(event['location'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.calendar_today, size: 13, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(_fmtDate(event['startDate']),
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
          const Spacer(),
          if (reasons.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: reasons
                  .take(3)
                  .map((r) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(r,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.amber)),
                      ))
                  .toList(),
            ),
        ]),
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> e) {
    final imageUrl = e['imageUrl'] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showEventDetails(e),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl.startsWith('http')
                            ? imageUrl
                            : '${_api.baseUrl}$imageUrl',
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                        errorBuilder: (_, __, ___) => Icon(Icons.event,
                            color: Theme.of(context).primaryColor),
                      ),
                    )
                  : Icon(Icons.event, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e['title'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(e['location'] ?? '',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(_fmtDate(e['startDate']),
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ]),
                  ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }

  void _showEventDetails(Map<String, dynamic> e) async {
    // Load shifts for this event (exclude expired)
    List<dynamic> shifts = [];
    try {
      final res = await _api.getShiftsByEvent(e['id']);
      final all = res.data is List ? res.data as List : [];
      final now = DateTime.now();
      shifts = all.where((s) {
        final end = DateTime.tryParse(s['endTime'] ?? '')?.toLocal();
        return end == null || end.isAfter(now);
      }).toList();
    } catch (_) {}

    // Load user's current registrations to know which shifts they already joined
    Set<int> registeredShiftIds = {};
    List<Map<String, dynamic>> activeRegistrations = [];
    try {
      final regRes = await _api.getMyShifts();
      final data = regRes.data;
      final regs = data is Map
          ? (data['items'] as List? ?? [])
          : (data is List ? data : []);
      for (final r in regs) {
        final reg = Map<String, dynamic>.from(r as Map);
        if (!_registrationBlocksNewShift(reg)) continue;
        activeRegistrations.add(reg);
        final sid = reg['shiftId'];
        if (sid is int) registeredShiftIds.add(sid);
      }
    } catch (_) {}

    if (!mounted) return;
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => _EventDetailScreen(
        event: e,
        shifts: shifts,
        registeredShiftIds: registeredShiftIds,
        activeRegistrations: activeRegistrations,
      ),
    ));

    // If user tapped "Prijavljen" button, they want to go to shifts tab
    // We can't directly navigate tabs from here, but we signal via a callback
    if (result == 'go_shifts' && mounted) {
      if (widget.onNavigateToShifts != null) {
        widget.onNavigateToShifts!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Pogledajte vaše smjene u tab-u "Smjene"')),
        );
      }
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return iso;
    }
  }

  bool get _hasAdditionalFilters =>
      _selectedCityId != null ||
      _selectedOrganizationId != null ||
      _selectedDateRange != null;

  String _cityName(int? cityId) {
    if (cityId == null) return '-';
    final city = _cities.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['id'] == cityId,
          orElse: () => null,
        );
    return city?['name']?.toString() ?? cityId.toString();
  }

  String _organizationName(int? organizationId) {
    if (organizationId == null) return '-';
    final org = _organizations.cast<Map<String, dynamic>?>().firstWhere(
          (o) => o?['id'] == organizationId,
          orElse: () => null,
        );
    return org?['name']?.toString() ?? organizationId.toString();
  }

  Future<void> _showFilterSheet() async {
    int? tempCityId = _selectedCityId;
    int? tempOrganizationId = _selectedOrganizationId;
    DateTimeRange? tempDateRange = _selectedDateRange;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filteri događaja',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: tempCityId,
                decoration: const InputDecoration(
                    labelText: 'Lokacija (grad)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int>(
                      value: null, child: Text('Svi gradovi')),
                  ..._cities.map((c) => DropdownMenuItem<int>(
                        value: c['id'] as int?,
                        child: Text(c['name']?.toString() ?? ''),
                      )),
                ],
                onChanged: (value) => setModalState(() => tempCityId = value),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: tempOrganizationId,
                decoration: const InputDecoration(
                    labelText: 'Organizacija', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int>(
                      value: null, child: Text('Sve organizacije')),
                  ..._organizations.map((o) => DropdownMenuItem<int>(
                        value: o['id'] as int?,
                        child: Text(o['name']?.toString() ?? ''),
                      )),
                ],
                onChanged: (value) =>
                    setModalState(() => tempOrganizationId = value),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    initialDateRange: tempDateRange ??
                        DateTimeRange(
                            start: now.subtract(const Duration(days: 30)),
                            end: now),
                  );
                  if (picked != null) {
                    setModalState(() => tempDateRange = picked);
                  }
                },
                icon: const Icon(Icons.date_range),
                label: Text(
                  tempDateRange == null
                      ? 'Odaberi period'
                      : '${_fmtDate(tempDateRange!.start.toIso8601String())} - ${_fmtDate(tempDateRange!.end.toIso8601String())}',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setModalState(() {
                        tempCityId = null;
                        tempOrganizationId = null;
                        tempDateRange = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Reset'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedCityId = tempCityId;
                        _selectedOrganizationId = tempOrganizationId;
                        _selectedDateRange = tempDateRange;
                      });
                      Navigator.pop(ctx);
                      _loadEvents();
                    },
                    child: const Text('Primijeni'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _registrationBlocksNewShift(Map<String, dynamic> registration) {
    final status = registration['status']?.toString();
    return status != 'Rejected' && status != 'Cancelled' && status != 'Completed';
  }
}

class _EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final List<dynamic> shifts;
  final Set<int> registeredShiftIds;
  final List<Map<String, dynamic>> activeRegistrations;
  const _EventDetailScreen(
      {required this.event,
      required this.shifts,
      required this.registeredShiftIds,
      required this.activeRegistrations});

  @override
  State<_EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<_EventDetailScreen> {
  late Set<int> _registeredShiftIds;
  late List<Map<String, dynamic>> _activeRegistrations;
  final Set<int> _loadingShiftIds = {};

  @override
  void initState() {
    super.initState();
    _registeredShiftIds = Set.from(widget.registeredShiftIds);
    _activeRegistrations = List<Map<String, dynamic>>.from(widget.activeRegistrations);
  }

  Future<void> _register(int shiftId) async {
    final shift = _shiftById(shiftId);
    final conflict = shift == null ? null : _findOverlappingRegistration(shift);
    if (conflict != null) {
      _showShiftOverlapMessage(conflict);
      return;
    }

    setState(() => _loadingShiftIds.add(shiftId));
    try {
      await ApiService().registerForShift(shiftId);
      if (shift != null) _rememberRegistration(shift);
      _registeredShiftIds.add(shiftId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Uspješno ste se prijavili na smjenu!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Greška pri prijavi';
        final eStr = e.toString();
        if (eStr.contains('Već ste') || eStr.contains('already')) {
          msg = 'Već ste prijavljeni na ovu smjenu';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loadingShiftIds.remove(shiftId));
  }

  Map<String, dynamic>? _shiftById(int shiftId) {
    for (final shift in widget.shifts) {
      final map = Map<String, dynamic>.from(shift as Map);
      if (map['id'] == shiftId) return map;
    }
    return null;
  }

  Map<String, dynamic>? _findOverlappingRegistration(Map<String, dynamic> shift) {
    final newStart = _parseDate(shift['startTime']);
    final newEnd = _parseDate(shift['endTime']);
    final newShiftId = shift['id'];
    if (newStart == null || newEnd == null) return null;

    for (final registration in _activeRegistrations) {
      if (registration['shiftId'] == newShiftId) continue;
      final existingStart = _parseDate(registration['shiftStartTime']);
      final existingEnd = _parseDate(registration['shiftEndTime']);
      if (existingStart == null || existingEnd == null) continue;
      if (newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart)) {
        return registration;
      }
    }
    return null;
  }

  void _rememberRegistration(Map<String, dynamic> shift) {
    _activeRegistrations.add({
      'shiftId': shift['id'],
      'shiftName': shift['name'],
      'eventTitle': widget.event['title'],
      'shiftStartTime': shift['startTime'],
      'shiftEndTime': shift['endTime'],
      'status': 'Registered',
    });
  }

  void _showShiftOverlapMessage(Map<String, dynamic> conflict) {
    final name = (conflict['eventTitle'] ?? conflict['shiftName'] ?? 'postojeću smjenu').toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ne možete se prijaviti na smjenu u isto vrijeme. Prvo otkažite "$name" u sekciji Smjene.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.event['title'] ?? 'Događaj')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Hero
          Builder(builder: (ctx) {
            final imageUrl = widget.event['imageUrl'] as String?;
            if (imageUrl != null && imageUrl.isNotEmpty) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl.startsWith('http')
                      ? imageUrl
                      : '${ApiService().baseUrl}$imageUrl',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .primaryColor
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.event,
                        size: 80, color: Theme.of(context).primaryColor),
                  ),
                ),
              );
            }
            return Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.event,
                  size: 80, color: Theme.of(context).primaryColor),
            );
          }),
          const SizedBox(height: 16),
          Text(widget.event['title'] ?? '',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (widget.event['categoryName'] != null)
            Chip(
                label: Text(widget.event['categoryName']),
                backgroundColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          _infoTile(Icons.location_on, widget.event['location'] ?? '-'),
          _infoTile(Icons.calendar_today,
              '${_fmtDate(widget.event['startDate'])} - ${_fmtDate(widget.event['endDate'])}'),
          _infoTile(Icons.people,
              'Maks. ${widget.event['maxVolunteers'] ?? '-'} volontera'),
          const SizedBox(height: 16),
          Text('Opis',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(widget.event['description'] ?? 'Nema opisa',
              style: const TextStyle(height: 1.5)),
          const SizedBox(height: 24),
          Text('Dostupne smjene',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (widget.shifts.isEmpty)
            const Text('Nema dostupnih smjena')
          else
            ...widget.shifts.map((s) {
              final shiftId = s['id'] as int;
              final isRegistered = _registeredShiftIds.contains(shiftId);
              final isLoading = _loadingShiftIds.contains(shiftId);
              final currentVol = s['currentVolunteers'] ?? 0;
              final maxVol = s['maxVolunteers'] ?? 0;
              final isFull = currentVol >= maxVol;
              final isLocked = s['isLocked'] == true;
              final startTime = DateTime.tryParse(s['startTime'] ?? '');
              final endTime = DateTime.tryParse(s['endTime'] ?? '');
              final durationHours = startTime != null && endTime != null
                  ? endTime.difference(startTime).inMinutes / 60.0
                  : 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.schedule, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(s['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15))),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.access_time,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                              '${_fmtDT(s['startTime'])} — ${_fmtDT(s['endTime'])}',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[700])),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.timelapse,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text('Trajanje: ${durationHours.toStringAsFixed(1)}h',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[700])),
                          const SizedBox(width: 16),
                          Icon(Icons.people,
                              size: 16,
                              color: isFull ? Colors.red : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text('$currentVol / $maxVol',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isFull ? Colors.red : Colors.grey[700],
                                  fontWeight: isFull
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                          if (isFull) ...[
                            const SizedBox(width: 4),
                            Text('(Puno)',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.red[400])),
                          ],
                        ]),
                        const SizedBox(height: 8),
                        // Capacity bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxVol > 0
                                ? (currentVol / maxVol).clamp(0.0, 1.0)
                                : 0,
                            backgroundColor: Colors.grey.shade200,
                            color: isFull ? Colors.red : Colors.green,
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : isRegistered
                                  ? OutlinedButton.icon(
                                      onPressed: () =>
                                          Navigator.pop(context, 'go_shifts'),
                                      icon: const Icon(Icons.check_circle,
                                          size: 16),
                                      label: const Text('Prijavljen'),
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.green),
                                    )
                                  : ElevatedButton(
                                      onPressed: (isFull || isLocked)
                                          ? null
                                          : () => _register(shiftId),
                                      child: Text(isFull
                                          ? 'Popunjeno'
                                          : isLocked
                                              ? 'Zaključano'
                                              : 'Prijavi se'),
                                    ),
                        ),
                      ]),
                ),
              );
            }),
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
    } catch (_) {
      return iso;
    }
  }

  String _fmtDT(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
