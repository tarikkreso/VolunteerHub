import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';

class EventsScreen extends StatefulWidget {
  final int? focusEventId;
  const EventsScreen({super.key, this.focusEventId});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _api = ApiService();

  List<dynamic> _events = [];
  List<dynamic> _categories = [];
  List<dynamic> _cities = [];
  final Map<int, List<dynamic>> _eventShifts = {};
  final Set<int> _expandedEvents = {};
  final Set<int> _loadingShiftsForEvent = {};

  bool _loading = true;
  String _search = '';
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        _api.getEvents(query: {'pageSize': 100}),
        _api.getCategories(),
        _api.getCities(),
      ]);

      final eventsRaw = res[0].data;
      _events = eventsRaw is Map
          ? (eventsRaw['items'] ?? [])
          : (eventsRaw is List ? eventsRaw : []);
      _categories = res[1].data is List ? res[1].data : [];
      _cities = res[2].data is List ? res[2].data : [];
      final focusId = widget.focusEventId;
      if (focusId != null && _events.any((e) => e['id'] == focusId)) {
        _expandedEvents
          ..clear()
          ..add(focusId);
        await _loadShiftsForEvent(focusId);
      }
    } catch (e) {
      debugPrint('Events load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadShiftsForEvent(int eventId) async {
    if (_loadingShiftsForEvent.contains(eventId)) return;
    _loadingShiftsForEvent.add(eventId);
    setState(() {});
    try {
      final res = await _api.getShifts(eventId: eventId);
      _eventShifts[eventId] = res.data is List ? res.data : [];
    } catch (e) {
      _eventShifts[eventId] = [];
      debugPrint('Shift load error for event $eventId: $e');
    }
    _loadingShiftsForEvent.remove(eventId);
    if (mounted) setState(() {});
  }

  List<dynamic> get _filteredEvents {
    var list = _events;
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((e) {
        final title = (e['title'] ?? '').toString().toLowerCase();
        final location = (e['location'] ?? '').toString().toLowerCase();
        final category = (e['categoryName'] ?? '').toString().toLowerCase();
        return title.contains(q) ||
            location.contains(q) ||
            category.contains(q);
      }).toList();
    }
    if (_filterStatus != null) {
      list = list.where((e) => e['status'] == _filterStatus).toList();
    }
    return list;
  }

  int _countByStatus(String status) =>
      _events.where((e) => e['status'] == status).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Pretrazi dogadjaje, lokacije ili kategorije...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showEventDialog(null),
                icon: const Icon(Icons.add),
                label: const Text('Novi dogadjaj'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(null, 'Svi (${_events.length})', Colors.blueGrey),
              _statusChip(
                'Published',
                'Objavljeno (${_countByStatus('Published')})',
                Colors.green,
              ),
              _statusChip(
                'Draft',
                'Nacrt (${_countByStatus('Draft')})',
                Colors.grey,
              ),
              _statusChip(
                'Completed',
                'Zavrseno (${_countByStatus('Completed')})',
                Colors.blue,
              ),
              _statusChip(
                'Cancelled',
                'Otkazano (${_countByStatus('Cancelled')})',
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredEvents.isEmpty
                ? const Center(child: Text('Nema dogadjaja'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = _filteredEvents[index];
                      final eventId = event['id'] as int;
                      final shifts = _eventShifts[eventId] ?? const [];
                      final isExpanded = _expandedEvents.contains(eventId);
                      final shiftsLoading =
                          _loadingShiftsForEvent.contains(eventId);
                      final lockedShifts =
                          shifts.where((s) => s['isLocked'] == true).length;
                      final totalSlots = shifts.fold<int>(
                        0,
                        (sum, s) =>
                            sum + ((s['maxVolunteers'] as num?)?.toInt() ?? 0),
                      );
                      final filledSlots = shifts.fold<int>(
                        0,
                        (sum, s) =>
                            sum +
                            ((s['currentVolunteers'] as num?)?.toInt() ?? 0),
                      );

                      return Card(
                        key: ValueKey(eventId),
                        margin: const EdgeInsets.only(bottom: 12),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          initiallyExpanded: isExpanded,
                          onExpansionChanged: (expanded) async {
                            setState(() {
                              if (expanded) {
                                _expandedEvents.add(eventId);
                              } else {
                                _expandedEvents.remove(eventId);
                              }
                            });
                            if (expanded &&
                                !_eventShifts.containsKey(eventId)) {
                              await _loadShiftsForEvent(eventId);
                            }
                          },
                          leading: Icon(
                            Icons.event,
                            color: _statusColor(event['status']),
                          ),
                          title: Text(event['title'] ?? ''),
                          subtitle: Text(
                            '${event['location'] ?? ''} • ${event['categoryName'] ?? ''} • ${_fmtDate(event['startDate'])}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(event['status'])
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _statusLabel(event['status']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _statusColor(event['status']),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                tooltip: 'Uredi dogadjaj',
                                onPressed: () => _showEventDialog(event),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                tooltip: 'Obrisi dogadjaj',
                                onPressed: () => _deleteEvent(eventId),
                              ),
                            ],
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              color: Colors.grey.shade50,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _summaryChip(
                                        Icons.schedule,
                                        'Smjene: ${shifts.length}',
                                        Colors.blue,
                                      ),
                                      _summaryChip(
                                        Icons.lock,
                                        'Zakljucane: $lockedShifts',
                                        Colors.deepOrange,
                                      ),
                                      _summaryChip(
                                        Icons.people,
                                        'Popunjenost: $filledSlots/$totalSlots',
                                        Colors.teal,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _showShiftDialog(eventId, null),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Nova smjena'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _loadShiftsForEvent(
                                          eventId,
                                        ),
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Osvjezi smjene'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (shiftsLoading)
                                    const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(),
                                    ),
                                  if (!shiftsLoading && shifts.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Text(
                                        'Nema smjena za ovaj dogadjaj.',
                                      ),
                                    ),
                                  if (!shiftsLoading && shifts.isNotEmpty)
                                    Column(
                                      children: shifts.map<Widget>((shift) {
                                        final shiftId = shift['id'] as int;
                                        final isLocked =
                                            shift['isLocked'] == true;
                                        return Card(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                            leading: Icon(
                                              isLocked
                                                  ? Icons.lock
                                                  : Icons.schedule,
                                              color: isLocked
                                                  ? Colors.red
                                                  : Colors.blue,
                                            ),
                                            title: Text(shift['name'] ?? ''),
                                            subtitle: Text(
                                              '${_fmtDateTime(shift['startTime'])} - ${_fmtDateTime(shift['endTime'])} • '
                                              '${shift['currentVolunteers'] ?? 0}/${shift['maxVolunteers'] ?? 0} volontera',
                                            ),
                                            trailing: Wrap(
                                              spacing: 4,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showShiftApprovalsDialog(
                                                    shift,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.fact_check,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    'Odobrenja',
                                                  ),
                                                ),
                                                if (!isLocked)
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                    ),
                                                    tooltip: 'Uredi smjenu',
                                                    onPressed: () =>
                                                        _showShiftDialog(
                                                      eventId,
                                                      shift,
                                                    ),
                                                  ),
                                                if (!isLocked)
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                    tooltip: 'Obrisi smjenu',
                                                    onPressed: () =>
                                                        _deleteShift(
                                                      eventId,
                                                      shiftId,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content: const Text(
          'Jeste li sigurni da zelite obrisati ovaj dogadjaj?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obrisi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _api.deleteEvent(id);
      _eventShifts.remove(id);
      _expandedEvents.remove(id);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dogadjaj uspjesno obrisan.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Došlo je do greške. Pokušajte ponovo.')),
        );
      }
    }
  }

  Future<void> _deleteShift(int eventId, int shiftId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda brisanja smjene'),
        content: const Text(
          'Jeste li sigurni da zelite obrisati ovu smjenu?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obrisi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _api.deleteShift(shiftId);
      await _loadShiftsForEvent(eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Smjena uspjesno obrisana.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Došlo je do greške. Pokušajte ponovo.')),
        );
      }
    }
  }

  void _showShiftDialog(int eventId, Map<String, dynamic>? existing) {
    final isEdit = existing != null;
    final name = TextEditingController(text: existing?['name'] ?? '');
    final description =
        TextEditingController(text: existing?['description'] ?? '');
    final maxVolunteers = TextEditingController(
      text: '${existing?['maxVolunteers'] ?? 10}',
    );
    DateTime start = existing != null
        ? DateTime.tryParse(existing['startTime']?.toString() ?? '') ??
            DateTime.now().add(const Duration(days: 1))
        : DateTime.now().add(const Duration(days: 1));
    DateTime end = existing != null
        ? DateTime.tryParse(existing['endTime']?.toString() ?? '') ??
            start.add(const Duration(hours: 4))
        : start.add(const Duration(hours: 4));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: _dialogTitle(
            icon: Icons.schedule,
            title: isEdit ? 'Uredi smjenu' : 'Nova smjena',
            subtitle: 'Raspored, kapacitet i osnovne informacije',
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogSection('Detalji smjene'),
                    TextFormField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Naziv smjene *'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Naziv smjene je obavezan.';
                        }
                        if (v.trim().length < 3) {
                          return 'Naziv smjene mora imati najmanje 3 znaka.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'Opis'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: maxVolunteers,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Maksimalno volontera *'),
                      validator: (v) {
                        final parsed = int.tryParse(v ?? '');
                        if (parsed == null || parsed < 1 || parsed > 1000) {
                          return 'Unesite broj izmedju 1 i 1000.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _dialogSection('Vrijeme smjene'),
                    ListTile(
                      title: Text('Pocetak: ${_fmtDateTimeValue(start)}'),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: start,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (date != null) {
                          if (!ctx.mounted) return;
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(start),
                          );
                          setS(() {
                            start = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time?.hour ?? 8,
                              time?.minute ?? 0,
                            );
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text('Kraj: ${_fmtDateTimeValue(end)}'),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: end,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (date != null) {
                          if (!ctx.mounted) return;
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(end),
                          );
                          setS(() {
                            end = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time?.hour ?? 12,
                              time?.minute ?? 0,
                            );
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (!end.isAfter(start)) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kraj smjene mora biti nakon pocetka.'),
                      ),
                    );
                  }
                  return;
                }

                final payload = {
                  'name': name.text.trim(),
                  'description': description.text.trim(),
                  'startTime': start.toUtc().toIso8601String(),
                  'endTime': end.toUtc().toIso8601String(),
                  'maxVolunteers': int.parse(maxVolunteers.text.trim()),
                  'eventId': eventId,
                };

                try {
                  if (isEdit) {
                    await _api.updateShift(existing['id'], payload);
                  } else {
                    await _api.createShift(payload);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadShiftsForEvent(eventId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? 'Smjena uspjesno azurirana.'
                              : 'Smjena uspjesno kreirana.',
                        ),
                      ),
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Došlo je do greške. Pokušajte ponovo.'),
                      ),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Spremi' : 'Kreiraj'),
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftApprovalsDialog(Map<String, dynamic> shift) {
    List<dynamic> registrations = [];
    bool loading = true;
    final isLocked = shift['isLocked'] == true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> loadRegistrations() async {
            try {
              final res = await _api.getShiftRegistrations(shift['id'] as int);
              setS(() {
                registrations = res.data is List ? res.data : [];
                loading = false;
              });
            } catch (_) {
              setS(() => loading = false);
            }
          }

          if (loading) {
            loadRegistrations();
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: _dialogTitle(
              icon: Icons.fact_check,
              title: 'Odobravanje prijava',
              subtitle: (shift['name'] ?? '').toString(),
            ),
            content: SizedBox(
              width: 760,
              height: 460,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : registrations.isEmpty
                      ? const Center(
                          child: Text('Nema prijavljenih volontera.'))
                      : SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 24,
                            columns: const [
                              DataColumn(label: Text('Volonter')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Napomena')),
                              DataColumn(label: Text('Akcije')),
                            ],
                            rows: registrations.map<DataRow>((r) {
                              final status = (r['status'] ?? '').toString();
                              final canReview = !isLocked &&
                                  (status == 'Pending' ||
                                      status == 'Rejected' ||
                                      status == 'Registered');
                              final isAlreadyApproved = status == 'Registered';

                              return DataRow(
                                cells: [
                                  DataCell(Text(r['userName'] ?? 'Volonter')),
                                  DataCell(_statusBadge(status)),
                                  DataCell(
                                    Text(
                                      isAlreadyApproved
                                          ? 'Prijava je odobrena'
                                          : status == 'Rejected'
                                              ? 'Moze se ponovo odobriti'
                                              : 'Ceka odobrenje admina',
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (canReview)
                                          IconButton(
                                            icon: const Icon(Icons.check_circle,
                                                color: Colors.green),
                                            tooltip: isAlreadyApproved
                                                ? 'Ponovo potvrdi prijavu'
                                                : 'Odobri prijavu',
                                            onPressed: () async {
                                              try {
                                                await _api.approveRegistration(
                                                  r['id'] as int,
                                                  hours: 0,
                                                  notes:
                                                      'Prijava odobrena iz modala dogadjaja.',
                                                );
                                                loading = true;
                                                setS(() {});
                                              } catch (_) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Došlo je do greške. Pokušajte ponovo.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                        if (canReview)
                                          IconButton(
                                            icon: const Icon(Icons.cancel,
                                                color: Colors.red),
                                            tooltip: 'Odbij prijavu',
                                            onPressed: () async {
                                              try {
                                                await _api.rejectRegistration(
                                                  r['id'] as int,
                                                  reason:
                                                      'Prijava odbijena od strane administratora.',
                                                );
                                                loading = true;
                                                setS(() {});
                                              } catch (_) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Došlo je do greške. Pokušajte ponovo.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Zatvori'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEventDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;
    final title = TextEditingController(text: existing?['title'] ?? '');
    final description =
        TextEditingController(text: existing?['description'] ?? '');
    final location = TextEditingController(text: existing?['location'] ?? '');
    final maxVolunteers = TextEditingController(
      text: '${existing?['maxVolunteers'] ?? 20}',
    );
    final formKey = GlobalKey<FormState>();

    DateTime startDate = existing != null
        ? DateTime.tryParse(existing['startDate'] ?? '') ??
            DateTime.now().add(const Duration(days: 7))
        : DateTime.now().add(const Duration(days: 7));
    DateTime endDate = existing != null
        ? DateTime.tryParse(existing['endDate'] ?? '') ??
            startDate.add(const Duration(hours: 6))
        : startDate.add(const Duration(hours: 6));
    double? latitude = _toDouble(existing?['latitude']);
    double? longitude = _toDouble(existing?['longitude']);
    int? categoryId = existing?['categoryId'];
    int? cityId = existing?['cityId'];
    String status = existing?['status'] ?? 'Draft';
    bool featured = existing?['isFeatured'] ?? false;

    if (categoryId == null && existing?['categoryName'] != null) {
      final category = _categories.firstWhere(
        (c) => c['name'] == existing!['categoryName'],
        orElse: () => null,
      );
      if (category != null) {
        categoryId = category['id'];
      }
    }

    if (cityId == null && existing?['cityName'] != null) {
      final matches =
          _cities.where((c) => c['name'] == existing!['cityName']).toList();
      if (matches.isNotEmpty) {
        cityId = matches.first['id'] as int?;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: _dialogTitle(
            icon: Icons.event,
            title: isEdit ? 'Uredi dogadjaj' : 'Novi dogadjaj',
            subtitle: 'Podaci, lokacija, kategorija i vrijeme',
          ),
          content: SizedBox(
            width: 640,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogSection('Osnovni podaci'),
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Naziv *'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Naziv je obavezan.';
                        }
                        if (v.trim().length < 3) {
                          return 'Naziv mora imati najmanje 3 znaka.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'Opis *'),
                      maxLines: 3,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Opis je obavezan.';
                        }
                        if (v.trim().length < 20) {
                          return 'Opis mora imati najmanje 20 znakova.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _dialogSection('Lokacija'),
                    TextFormField(
                      controller: location,
                      decoration:
                          const InputDecoration(labelText: 'Lokacija *'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Lokacija je obavezna.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            latitude != null && longitude != null
                                ? 'Koordinate: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
                                : 'Koordinate nisu odabrane',
                            style: TextStyle(
                              color: latitude != null && longitude != null
                                  ? Colors.green
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await _showMapPicker(
                              initial: latitude != null && longitude != null
                                  ? LatLng(latitude!, longitude!)
                                  : null,
                            );
                            if (picked != null) {
                              setS(() {
                                latitude = picked.latitude;
                                longitude = picked.longitude;
                                if ((picked.displayName ?? '')
                                    .trim()
                                    .isNotEmpty) {
                                  location.text = picked.displayName!.trim();
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.map),
                          label: const Text('Odaberi na mapi'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _dialogSection('Kategorija i kapacitet'),
                    DropdownButtonFormField<int>(
                      initialValue: categoryId,
                      decoration:
                          const InputDecoration(labelText: 'Kategorija *'),
                      items: _categories
                          .map<DropdownMenuItem<int>>(
                            (c) => DropdownMenuItem<int>(
                              value: c['id'] as int,
                              child: Text(c['name'] ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setS(() => categoryId = v),
                      validator: (v) =>
                          v == null ? 'Odaberite kategoriju.' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: cityId,
                      decoration: const InputDecoration(labelText: 'Grad'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Bez grada'),
                        ),
                        ..._cities.map<DropdownMenuItem<int?>>(
                          (c) => DropdownMenuItem<int?>(
                            value: c['id'] as int?,
                            child: Text((c['name'] ?? '').toString()),
                          ),
                        ),
                      ],
                      onChanged: (v) => setS(() => cityId = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: maxVolunteers,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Maksimalno volontera *'),
                            validator: (v) {
                              final parsed = int.tryParse(v ?? '');
                              if (parsed == null ||
                                  parsed < 1 ||
                                  parsed > 1000) {
                                return 'Unesite broj izmedju 1 i 1000.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (isEdit)
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: status,
                              decoration:
                                  const InputDecoration(labelText: 'Status'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Draft', child: Text('Draft')),
                                DropdownMenuItem(
                                    value: 'Published',
                                    child: Text('Published')),
                                DropdownMenuItem(
                                    value: 'Cancelled',
                                    child: Text('Cancelled')),
                                DropdownMenuItem(
                                    value: 'Completed',
                                    child: Text('Completed')),
                              ],
                              onChanged: (v) =>
                                  setS(() => status = v ?? status),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dialogSection('Vrijeme dogadjaja'),
                    ListTile(
                      title: Text('Pocetak: ${_fmtDateTimeValue(startDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: startDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (date != null) {
                          if (!ctx.mounted) return;
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(startDate),
                          );
                          setS(() {
                            startDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time?.hour ?? 8,
                              time?.minute ?? 0,
                            );
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text('Kraj: ${_fmtDateTimeValue(endDate)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: endDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (date != null) {
                          if (!ctx.mounted) return;
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(endDate),
                          );
                          setS(() {
                            endDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time?.hour ?? 12,
                              time?.minute ?? 0,
                            );
                          });
                        }
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: featured,
                      title: const Text('Istaknuti dogadjaj'),
                      onChanged: (v) => setS(() => featured = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (!endDate.isAfter(startDate)) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Kraj mora biti nakon pocetka dogadjaja.'),
                      ),
                    );
                  }
                  return;
                }

                final payload = {
                  'title': title.text.trim(),
                  'description': description.text.trim(),
                  'location': location.text.trim(),
                  'startDate': startDate.toUtc().toIso8601String(),
                  'endDate': endDate.toUtc().toIso8601String(),
                  'maxVolunteers': int.parse(maxVolunteers.text.trim()),
                  'categoryId': categoryId,
                  if (cityId != null) 'cityId': cityId,
                  if (latitude != null) 'latitude': latitude,
                  if (longitude != null) 'longitude': longitude,
                  if (isEdit) 'status': status,
                  'isFeatured': featured,
                };

                try {
                  if (isEdit) {
                    await _api.updateEvent(existing['id'], payload);
                  } else {
                    final res = await _api.createEvent(payload);
                    final created = res.data is Map ? res.data as Map : null;
                    final createdId = created?['id'];
                    if (createdId is num) {
                      _expandedEvents
                        ..clear()
                        ..add(createdId.toInt());
                      await _loadShiftsForEvent(createdId.toInt());
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? 'Dogadjaj uspjesno azuriran.'
                              : 'Dogadjaj uspjesno kreiran.',
                        ),
                      ),
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Došlo je do greške. Pokušajte ponovo.'),
                      ),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Spremi' : 'Kreiraj'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_PickedLocation?> _showMapPicker({LatLng? initial}) async {
    LatLng selected = initial ?? const LatLng(43.8563, 18.4131);
    final mapController = MapController();
    final searchCtrl = TextEditingController();
    final geocoder = Dio(
      BaseOptions(
        baseUrl: 'https://nominatim.openstreetmap.org',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'VolunteerHubDesktop/1.0',
        },
      ),
    );

    List<Map<String, dynamic>> searchResults = [];
    bool searching = false;
    String? searchError;
    String? selectedDisplayName;

    Future<void> runSearch(void Function(void Function()) setS) async {
      final query = searchCtrl.text.trim();
      if (query.length < 2) return;
      setS(() {
        searching = true;
        searchError = null;
      });

      try {
        final res = await geocoder.get(
          '/search',
          queryParameters: {
            'q': query,
            'format': 'jsonv2',
            'addressdetails': 1,
            'limit': 6,
          },
        );
        final data = res.data is List ? res.data as List : <dynamic>[];
        final parsed = data
            .map<Map<String, dynamic>>((item) => {
                  'displayName': item['display_name']?.toString() ?? '',
                  'lat': double.tryParse(item['lat']?.toString() ?? ''),
                  'lon': double.tryParse(item['lon']?.toString() ?? ''),
                })
            .where((e) => e['lat'] != null && e['lon'] != null)
            .toList();

        setS(() {
          searching = false;
          searchResults = parsed;
          if (parsed.isEmpty) {
            searchError = 'Nema rezultata za trazeni pojam.';
          }
        });
      } catch (_) {
        setS(() {
          searching = false;
          searchError = 'Pretraga trenutno nije dostupna.';
        });
      }
    }

    return showDialog<_PickedLocation>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Odabir lokacije na mapi'),
          content: SizedBox(
            width: 760,
            height: 520,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Pretraga adrese ili grada',
                          hintText: 'npr. Sarajevo, Mostar',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => runSearch(setS),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: searching ? null : () => runSearch(setS),
                      child: searching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Trazi'),
                    ),
                  ],
                ),
                if (searchError != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      searchError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
                if (searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      itemCount: searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final result = searchResults[i];
                        return ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.place_outlined, size: 18),
                          title: Text(
                            result['displayName']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            final lat = result['lat'] as double;
                            final lon = result['lon'] as double;
                            setS(() {
                              selected = LatLng(lat, lon);
                              selectedDisplayName =
                                  result['displayName']?.toString();
                            });
                            mapController.move(selected, 14);
                          },
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: selected,
                        initialZoom: 13,
                        onTap: (_, point) async {
                          setS(() {
                            selected = point;
                            selectedDisplayName = null;
                          });
                          final resolved =
                              await _reverseGeocode(geocoder, point);
                          if (resolved != null && mounted) {
                            setS(() => selectedDisplayName = resolved);
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'volunteer_hub_desktop',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: selected,
                              width: 42,
                              height: 42,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Odabrano: ${selected.latitude.toStringAsFixed(5)}, ${selected.longitude.toStringAsFixed(5)}',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                ctx,
                _PickedLocation(
                  latitude: selected.latitude,
                  longitude: selected.longitude,
                  displayName: selectedDisplayName,
                ),
              ),
              child: const Text('Odaberi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _reverseGeocode(Dio geocoder, LatLng point) async {
    try {
      final res = await geocoder.get(
        '/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lon': point.longitude,
          'format': 'jsonv2',
          'addressdetails': 1,
        },
      );
      final data = res.data;
      if (data is Map) {
        final displayName = data['display_name']?.toString().trim();
        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }
    } catch (_) {}
    return null;
  }

  Widget _dialogTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
      ),
    ]);
  }

  Widget _dialogSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _summaryChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _statusChip(String? status, String label, Color color) {
    final selected = _filterStatus == status;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(color: selected ? Colors.white : color),
      ),
      selected: selected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.12),
      onSelected: (_) => setState(() => _filterStatus = status),
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'Published':
        return 'Objavljeno';
      case 'Draft':
        return 'Nacrt';
      case 'Completed':
        return 'Zavrseno';
      case 'Cancelled':
        return 'Otkazano';
      case 'Approved':
        return 'Odobreno';
      case 'Rejected':
        return 'Odbijeno';
      case 'Registered':
        return 'Registrovan';
      case 'Pending':
        return 'Na cekanju';
      default:
        return status ?? '-';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'Published':
      case 'Approved':
        return Colors.green;
      case 'Draft':
        return Colors.grey;
      case 'Completed':
        return Colors.blue;
      case 'Cancelled':
      case 'Rejected':
        return Colors.red;
      case 'Registered':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return iso;
    }
  }

  String _fmtDateTime(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _fmtDateTimeValue(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class _PickedLocation {
  final double latitude;
  final double longitude;
  final String? displayName;

  const _PickedLocation({
    required this.latitude,
    required this.longitude,
    this.displayName,
  });
}
