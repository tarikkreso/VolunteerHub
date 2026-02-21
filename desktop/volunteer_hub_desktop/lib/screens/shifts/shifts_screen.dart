import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});
  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final _api = ApiService();
  List<dynamic> _events = [];
  List<dynamic> _shifts = [];
  bool _loading = true;
  int? _selectedEventId;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getEvents(query: {'pageSize': 100});
      final ed = res.data;
      _events = ed is Map ? (ed['items'] ?? []) : (ed is List ? ed : []);
      if (_events.isNotEmpty && _selectedEventId == null) {
        _selectedEventId = _events.first['id'];
        await _loadShifts();
      }
    } catch (e) {
      debugPrint('Shifts load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadShifts() async {
    if (_selectedEventId == null) return;
    try {
      final res = await _api.getShifts(eventId: _selectedEventId);
      _shifts = res.data is List ? res.data : [];
    } catch (e) {
      _shifts = [];
      debugPrint('Shifts error: $e');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Event selector
        Row(children: [
          const Text('Događaj: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<int>(
              value: _selectedEventId,
              isExpanded: true,
              items: _events.map<DropdownMenuItem<int>>((e) =>
                  DropdownMenuItem(value: e['id'] as int, child: Text(e['title'] ?? ''))).toList(),
              onChanged: (v) {
                setState(() => _selectedEventId = v);
                _loadShifts();
              },
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _selectedEventId == null ? null : () => _showShiftDialog(null),
            icon: const Icon(Icons.add),
            label: const Text('Nova smjena'),
          ),
        ]),
        const SizedBox(height: 16),
        // Shifts list
        Expanded(
          child: _shifts.isEmpty
              ? const Center(child: Text('Nema smjena za odabrani događaj'))
              : ListView.builder(
                  itemCount: _shifts.length,
                  itemBuilder: (ctx, i) {
                    final s = _shifts[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: Icon(
                          s['isLocked'] == true ? Icons.lock : Icons.schedule,
                          color: s['isLocked'] == true ? Colors.red : Colors.blue,
                        ),
                        title: Text(s['name'] ?? ''),
                        subtitle: Text(
                            '${_fmtDT(s['startTime'])} - ${_fmtDT(s['endTime'])} • ${s['currentVolunteers'] ?? 0}/${s['maxVolunteers'] ?? 0} volontera'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (s['isLocked'] != true) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Uredi',
                              onPressed: () => _showShiftDialog(s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              tooltip: 'Obriši',
                              onPressed: () => _deleteShift(s['id']),
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.people, size: 20),
                            tooltip: 'Upravljaj volonterima',
                            onPressed: () => _showRegistrationsDialog(s),
                          ),
                        ]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Opis: ${s['description'] ?? 'Nema opisa'}'),
                              const SizedBox(height: 8),
                              Row(children: [
                                Icon(s['isLocked'] == true ? Icons.lock : Icons.lock_open,
                                    size: 16, color: s['isLocked'] == true ? Colors.red : Colors.green),
                                const SizedBox(width: 6),
                                Text('Status: ${s['isLocked'] == true ? 'Zaključano (finalno odobreno)' : 'Otvoreno'}'),
                              ]),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.people, size: 16, color: Colors.blue),
                                const SizedBox(width: 6),
                                Text('Popunjenost: ${s['currentVolunteers'] ?? 0} / ${s['maxVolunteers'] ?? 0}'),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 120,
                                  child: LinearProgressIndicator(
                                    value: ((s['currentVolunteers'] ?? 0) / (s['maxVolunteers'] ?? 1)).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                    backgroundColor: Colors.grey.shade200,
                                  ),
                                ),
                              ]),
                            ]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  void _showShiftDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;
    final name = TextEditingController(text: existing?['name'] ?? '');
    final desc = TextEditingController(text: existing?['description'] ?? '');
    final maxVol = TextEditingController(text: '${existing?['maxVolunteers'] ?? 10}');
    DateTime start = existing != null
        ? DateTime.tryParse(existing['startTime'] ?? '') ?? DateTime.now()
        : DateTime.now().add(const Duration(days: 7));
    DateTime end = existing != null
        ? DateTime.tryParse(existing['endTime'] ?? '') ?? start.add(const Duration(hours: 4))
        : start.add(const Duration(hours: 4));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: Text(isEdit ? 'Uredi smjenu' : 'Nova smjena'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Naziv smjene *'),
                  validator: (v) => v == null || v.isEmpty ? 'Naziv je obavezan' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Opis'), maxLines: 2),
                const SizedBox(height: 12),
                TextFormField(
                  controller: maxVol,
                  decoration: const InputDecoration(labelText: 'Maks. volontera *'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty || (int.tryParse(v) ?? 0) < 1 ? 'Unesite pozitivan broj' : null,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ListTile(
                      title: Text('Početak: ${_fmtDT2(start)}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final d = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime(2024), lastDate: DateTime(2030));
                        if (d != null) {
                          final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(start));
                          setS(() => start = DateTime(d.year, d.month, d.day, t?.hour ?? 8, t?.minute ?? 0));
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text('Kraj: ${_fmtDT2(end)}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final d = await showDatePicker(context: ctx, initialDate: end, firstDate: DateTime(2024), lastDate: DateTime(2030));
                        if (d != null) {
                          final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(end));
                          setS(() => end = DateTime(d.year, d.month, d.day, t?.hour ?? 16, t?.minute ?? 0));
                        }
                      },
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Odustani')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final data = {
                  'name': name.text.trim(),
                  'description': desc.text.trim(),
                  'startTime': start.toUtc().toIso8601String(),
                  'endTime': end.toUtc().toIso8601String(),
                  'maxVolunteers': int.parse(maxVol.text.trim()),
                  'eventId': _selectedEventId,
                };
                try {
                  if (isEdit) {
                    await _api.updateShift(existing['id'], data);
                  } else {
                    await _api.createShift(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadShifts();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isEdit ? 'Smjena uspješno ažurirana' : 'Smjena uspješno kreirana')));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.')));
                }
              },
              child: Text(isEdit ? 'Spremi' : 'Kreiraj'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _deleteShift(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content: const Text('Jeste li sigurni da želite obrisati ovu smjenu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Odustani')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _api.deleteShift(id);
        _loadShifts();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Smjena uspješno obrisana')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.')));
      }
    }
  }

  void _showRegistrationsDialog(Map<String, dynamic> shift) async {
    List<dynamic> regs = [];
    bool loading = true;
    final isLocked = shift['isLocked'] == true;
    final shiftStart = DateTime.tryParse(shift['startTime']?.toString() ?? '');
    final shiftEnd = DateTime.tryParse(shift['endTime']?.toString() ?? '');
    final now = DateTime.now().toUtc();
    final canApproveAll = !isLocked && shiftStart != null && !now.isBefore(shiftStart.toUtc());
    final canFinalApprove = !isLocked && shiftEnd != null && !now.isBefore(shiftEnd.toUtc());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (loading) {
          _api.getShiftRegistrations(shift['id']).then((res) {
            setS(() {
              regs = res.data is List ? res.data : [];
              loading = false;
            });
          }).catchError((e) {
            setS(() => loading = false);
          });
        }

        // Stats
        final approved = regs.where((r) => r['status'] == 'Approved').length;
        final pending = regs.where((r) => r['status'] == 'Pending' || r['status'] == 'Registered').length;
        final suspicious = regs.where((r) => r['isSuspicious'] == true).length;

        return AlertDialog(
          title: Row(children: [
            Icon(isLocked ? Icons.lock : Icons.people, color: isLocked ? Colors.red : Colors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text('Volonteri — ${shift['name']}')),
            if (isLocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Text('ZAKLJUČANO', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ]),
          content: SizedBox(
            width: 900,
            height: 500,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    // Stats summary
                    Row(children: [
                      _regStat('Ukupno', '${regs.length}', Colors.blueGrey),
                      const SizedBox(width: 12),
                      _regStat('Odobreno', '$approved', Colors.green),
                      const SizedBox(width: 12),
                      _regStat('Na čekanju', '$pending', Colors.orange),
                      const SizedBox(width: 12),
                      if (suspicious > 0) _regStat('Sumnjivo', '$suspicious', Colors.red),
                    ]),
                    const SizedBox(height: 16),
                    // DataTable
                    Expanded(
                      child: regs.isEmpty
                          ? const Center(child: Text('Nema prijavljenih volontera'))
                          : SingleChildScrollView(
                              child: DataTable(
                                columnSpacing: 16,
                                headingRowColor: WidgetStateColor.resolveWith((_) => Colors.grey.shade100),
                                columns: const [
                                  DataColumn(label: Text('Volonter', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Check-in', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Check-out', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Sati', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                  DataColumn(label: Text('Anomalija', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Akcije', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: regs.map<DataRow>((r) {
                                  final isSuspicious = r['isSuspicious'] == true;
                                  return DataRow(
                                    color: isSuspicious
                                        ? WidgetStateColor.resolveWith((_) => Colors.red.withOpacity(0.06))
                                        : null,
                                    cells: [
                                      DataCell(Text(r['userName'] ?? 'Volonter #${r['userId']}')),
                                      DataCell(_statusBadge(r['status'])),
                                      DataCell(Text(_fmtDT(r['checkInTime']))),
                                      DataCell(Text(_fmtDT(r['checkOutTime']))),
                                      DataCell(Text(r['hoursWorked']?.toStringAsFixed(1) ?? '-')),
                                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                        if (isSuspicious) ...[
                                          const Tooltip(message: 'Sumnjivi sati', child: Icon(Icons.warning_amber, color: Colors.red, size: 18)),
                                          const SizedBox(width: 4),
                                        ],
                                        if (r['adminNotes'] != null && r['adminNotes'] != '')
                                          Tooltip(message: r['adminNotes'], child: const Icon(Icons.comment, size: 16, color: Colors.grey)),
                                      ])),
                                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                        if (!isLocked && (r['status'] == 'Pending' || r['status'] == 'Registered' || r['status'] == 'Completed'))
                                          IconButton(
                                            icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                            tooltip: 'Odobri',
                                            onPressed: () async {
                                              if (shiftStart != null && now.isBefore(shiftStart.toUtc())) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Nije moguće odobriti sate prije početka smjene.')),
                                                  );
                                                }
                                                return;
                                              }
                                              try {
                                                await _api.approveRegistration(r['id'], hours: r['hoursWorked']?.toDouble());
                                                final res2 = await _api.getShiftRegistrations(shift['id']);
                                                setS(() => regs = res2.data is List ? res2.data : []);
                                              } catch (e) {
                                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.')));
                                              }
                                            },
                                          ),
                                        if (!isLocked && r['status'] != 'Rejected' && r['status'] != 'Approved')
                                          IconButton(
                                            icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                            tooltip: 'Odbij',
                                            onPressed: () async {
                                              try {
                                                await _api.rejectRegistration(r['id'], reason: 'Odbijeno od strane admina');
                                                final res2 = await _api.getShiftRegistrations(shift['id']);
                                                setS(() => regs = res2.data is List ? res2.data : []);
                                              } catch (e) {
                                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.')));
                                              }
                                            },
                                          ),
                                      ])),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ]),
          ),
          actions: [
            if (!isLocked) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.done_all, size: 18),
                onPressed: canApproveAll
                    ? () async {
                        try {
                          await _api.approveAll(shift['id']);
                          final res2 = await _api.getShiftRegistrations(shift['id']);
                          setS(() => regs = res2.data is List ? res2.data : []);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sve prijave odobrene')));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.')));
                          }
                        }
                      }
                    : null,
                label: const Text('Odobri sve'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.lock, size: 18),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                onPressed: canFinalApprove
                    ? () async {
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (c2) => AlertDialog(
                            title: const Text('Konačno odobrenje'),
                            content: const Text('Zaključavanje smjene je nepovratna radnja. Svi sati će biti finalno odobreni i neće se moći mijenjati. Nastaviti?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('Odustani')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                onPressed: () => Navigator.pop(c2, true),
                                child: const Text('Zaključaj'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          try {
                            await _api.finalApproval(shift['id']);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadShifts();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Smjena zaključana — konačno odobrenje')));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.')));
                            }
                          }
                        }
                      }
                    : null,
                label: const Text('Konačno odobrenje'),
              ),
            ],
            if (!isLocked && !canApproveAll)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('Odobravanje je moguće tek nakon početka smjene.', style: TextStyle(fontSize: 12, color: Colors.orange)),
              ),
            if (!isLocked && !canFinalApprove)
              const Text('Konačno odobrenje je moguće tek nakon završetka smjene.', style: TextStyle(fontSize: 12, color: Colors.orange)),
            const SizedBox(width: 8),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zatvori')),
          ],
        );
      }),
    );
  }

  Widget _regStat(String label, String value, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 18)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: c, fontSize: 13)),
        ]),
      );

  Widget _statusBadge(String? status) {
    Color c;
    String label;
    switch (status) {
      case 'Approved': c = Colors.green; label = 'Odobreno'; break;
      case 'Rejected': c = Colors.red; label = 'Odbijeno'; break;
      case 'Completed': c = Colors.blue; label = 'Završeno'; break;
      case 'Cancelled': c = Colors.grey; label = 'Otkazano'; break;
      case 'Registered': c = Colors.teal; label = 'Registrovan'; break;
      default: c = Colors.orange; label = status ?? 'Na čekanju'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
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

  String _fmtDT2(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
