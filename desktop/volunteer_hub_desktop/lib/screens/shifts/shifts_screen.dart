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
      final data = res.data;
      _events =
          data is Map ? (data['items'] ?? []) : (data is List ? data : []);
      if (_events.isNotEmpty && _selectedEventId == null) {
        _selectedEventId = _events.first['id'] as int?;
      }
      await _loadShifts();
    } catch (e) {
      debugPrint('Shifts load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadShifts() async {
    if (_selectedEventId == null) {
      _shifts = [];
      return;
    }
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

    final open = _shifts.where((s) => s['isLocked'] != true).length;
    final locked = _shifts.where((s) => s['isLocked'] == true).length;
    final totalVolunteers = _shifts.fold<int>(
      0,
      (sum, s) => sum + ((s['currentVolunteers'] as num?)?.toInt() ?? 0),
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'Upravljanje smjenama i odobrenje sati',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Upravljajte smjenama, pregledajte sate volontera i finalno zaključajte odobrene podatke.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ]),
          ),
          SizedBox(
            width: 320,
            child: DropdownButtonFormField<int>(
              initialValue: _selectedEventId,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.event),
                labelText: 'Događaj',
              ),
              items: _events
                  .map<DropdownMenuItem<int>>(
                    (e) => DropdownMenuItem(
                      value: e['id'] as int,
                      child: Text(e['title'] ?? ''),
                    ),
                  )
                  .toList(),
              onChanged: (v) async {
                setState(() => _selectedEventId = v);
                await _loadShifts();
              },
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed:
                _selectedEventId == null ? null : () => _showShiftDialog(null),
            icon: const Icon(Icons.add),
            label: const Text('Nova smjena'),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _summaryCard(
              Icons.pending_actions, '$open', 'Otvorene smjene', Colors.orange),
          const SizedBox(width: 12),
          _summaryCard(Icons.people_alt_outlined, '$totalVolunteers',
              'Prijavljeni volonteri', Colors.blue),
          const SizedBox(width: 12),
          _summaryCard(Icons.verified_outlined, '$locked', 'Finalno zakljucane',
              Colors.green),
          const SizedBox(width: 12),
          _summaryCard(Icons.event_available, '${_shifts.length}',
              'Ukupno smjena', Colors.blueGrey),
        ]),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 18, runSpacing: 10, children: [
              _legendDot(Colors.blue, 'Nadolazeca'),
              _legendDot(Colors.orange, 'Ceka pregled sati'),
              _legendDot(Colors.green, 'Finalno odobrena'),
              _legendDot(Colors.red, 'Anomalije za pregled'),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _shifts.isEmpty
              ? const Center(child: Text('Nema smjena za odabrani dogadjaj'))
              : ListView.builder(
                  itemCount: _shifts.length,
                  itemBuilder: (ctx, index) {
                    final shift = _shifts[index];
                    final color = _shiftStatusColor(shift);
                    final isLocked = shift['isLocked'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(isLocked ? Icons.lock : Icons.schedule,
                              color: color),
                        ),
                        title: Text(shift['name'] ?? 'Smjena'),
                        subtitle: Text(
                          '${_timeRange(shift)}  -  ${shift['currentVolunteers'] ?? 0}/${shift['maxVolunteers'] ?? 0} volontera',
                        ),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          _pill(_shiftStatusLabel(shift), color),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _showRegistrationsDialog(shift),
                            icon:
                                const Icon(Icons.fact_check_outlined, size: 18),
                            label: const Text('Upravljaj satima'),
                          ),
                          const SizedBox(width: 8),
                          if (!isLocked) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              tooltip: 'Uredi',
                              onPressed: () => _showShiftDialog(shift),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  size: 20, color: Colors.red),
                              tooltip: 'Obrisi',
                              onPressed: () => _deleteShift(shift['id']),
                            ),
                          ],
                        ]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Opis: ${shift['description'] ?? 'Nema opisa'}'),
                                  const SizedBox(height: 12),
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    _infoChip(
                                      isLocked ? Icons.lock : Icons.lock_open,
                                      isLocked
                                          ? 'Zakljucano'
                                          : 'Otvoreno za pregled',
                                      isLocked ? Colors.red : Colors.green,
                                    ),
                                    _infoChip(
                                      Icons.people,
                                      'Popunjenost: ${shift['currentVolunteers'] ?? 0}/${shift['maxVolunteers'] ?? 0}',
                                      Colors.blue,
                                    ),
                                    _infoChip(Icons.access_time,
                                        _timeRange(shift), Colors.blueGrey),
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
    final maxVol =
        TextEditingController(text: '${existing?['maxVolunteers'] ?? 10}');
    DateTime start = existing != null
        ? DateTime.tryParse(existing['startTime'] ?? '') ?? DateTime.now()
        : DateTime.now().add(const Duration(days: 7));
    DateTime end = existing != null
        ? DateTime.tryParse(existing['endTime'] ?? '') ??
            start.add(const Duration(hours: 4))
        : start.add(const Duration(hours: 4));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: _dialogTitle(
            icon: Icons.schedule,
            title: isEdit ? 'Uredi smjenu' : 'Nova smjena',
            subtitle: 'Raspored i kapacitet za odabrani dogadjaj',
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _dialogSection('Detalji smjene'),
                TextFormField(
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'Naziv smjene *'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Naziv je obavezan' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: desc,
                    decoration: const InputDecoration(labelText: 'Opis'),
                    maxLines: 2),
                const SizedBox(height: 12),
                TextFormField(
                  controller: maxVol,
                  decoration:
                      const InputDecoration(labelText: 'Maks. volontera *'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty || (int.tryParse(v) ?? 0) < 1
                          ? 'Unesite pozitivan broj'
                          : null,
                ),
                const SizedBox(height: 16),
                _dialogSection('Vrijeme smjene'),
                Row(children: [
                  Expanded(
                    child: ListTile(
                      title: Text('Pocetak: ${_fmtDT2(start)}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final d = await showDatePicker(
                            context: ctx,
                            initialDate: start,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030));
                        if (d != null) {
                          if (!ctx.mounted) return;
                          final t = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(start));
                          setS(() => start = DateTime(d.year, d.month, d.day,
                              t?.hour ?? 8, t?.minute ?? 0));
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text('Kraj: ${_fmtDT2(end)}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final d = await showDatePicker(
                            context: ctx,
                            initialDate: end,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030));
                        if (d != null) {
                          if (!ctx.mounted) return;
                          final t = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(end));
                          setS(() => end = DateTime(d.year, d.month, d.day,
                              t?.hour ?? 16, t?.minute ?? 0));
                        }
                      },
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Odustani')),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(isEdit
                              ? 'Smjena uspjesno azurirana'
                              : 'Smjena uspjesno kreirana')),
                    );
                  }
                } catch (e) {
                  _showError();
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
        content: const Text('Jeste li sigurni da zelite obrisati ovu smjenu?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obrisi'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.deleteShift(id);
      await _loadShifts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Smjena uspjesno obrisana')));
      }
    } catch (e) {
      _showError();
    }
  }

  void _showRegistrationsDialog(Map<String, dynamic> shift) {
    List<dynamic> regs = [];
    bool loading = true;
    bool requested = false;
    final approvedControllers = <int, TextEditingController>{};
    final isLocked = shift['isLocked'] == true;
    final shiftStart = DateTime.tryParse(shift['startTime']?.toString() ?? '');
    final shiftEnd = DateTime.tryParse(shift['endTime']?.toString() ?? '');
    final now = DateTime.now().toUtc();
    final canApproveAll =
        !isLocked && shiftStart != null && !now.isBefore(shiftStart.toUtc());
    final canFinalApprove =
        !isLocked && shiftEnd != null && !now.isBefore(shiftEnd.toUtc());

    Future<void> refresh(StateSetter setS) async {
      final res = await _api.getShiftRegistrations(shift['id']);
      regs = res.data is List ? res.data : [];
      for (final r in regs) {
        final id = (r['id'] as num).toInt();
        approvedControllers.putIfAbsent(
          id,
          () => TextEditingController(text: _initialApprovedHours(r)),
        );
      }
      setS(() => loading = false);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (ctx, setS) {
        if (!requested) {
          requested = true;
          refresh(setS).catchError((_) => setS(() => loading = false));
        }

        final flagged =
            regs.where((r) => _flagsFor(r, shift).isNotEmpty).length;
        final pending = regs
            .where((r) =>
                r['status'] == 'Pending' ||
                r['status'] == 'Completed' ||
                r['status'] == 'Registered')
            .length;

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(children: [
            Icon(isLocked ? Icons.lock : Icons.fact_check_outlined,
                color: isLocked ? Colors.red : Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            Expanded(child: Text('Upravljanje smjenom: ${_timeRange(shift)}')),
            IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close)),
          ]),
          content: SizedBox(
            width: 1000,
            height: 620,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(children: [
                            Expanded(
                                child:
                                    _metaBlock('Događaj', _selectedEventTitle)),
                            Expanded(
                                child:
                                    _metaBlock('Vrijeme', _timeRange(shift))),
                            Expanded(
                                child: _metaBlock('Kapacitet',
                                    '${shift['currentVolunteers'] ?? 0}/${shift['maxVolunteers'] ?? 0}')),
                            _pill('$flagged za provjeru',
                                flagged > 0 ? Colors.red : Colors.green),
                            const SizedBox(width: 8),
                            _pill('$pending na čekanju', Colors.orange),
                            if (isLocked) ...[
                              const SizedBox(width: 8),
                              _pill('Zaključano', Colors.red),
                            ],
                          ]),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Text('Volonteri (${regs.length})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          if (flagged > 0)
                            Text('$flagged volontera za provjeru',
                                style: const TextStyle(color: Colors.red)),
                        ]),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 1240,
                            child: _approvalHeader(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: regs.isEmpty
                              ? const Center(
                                  child: Text('Nema prijavljenih volontera'))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: 1240,
                                    child: ListView.separated(
                                      itemCount: regs.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (_, index) {
                                        final reg = regs[index];
                                        final id = (reg['id'] as num).toInt();
                                        final flags = _flagsFor(reg, shift);
                                        final controller =
                                            approvedControllers[id]!;
                                        return _approvalRow(
                                          registration: reg,
                                          shift: shift,
                                          flags: flags,
                                          controller: controller,
                                          locked: isLocked,
                                          onApprove: () async {
                                            final hours = double.tryParse(
                                                controller.text
                                                    .trim()
                                                    .replaceAll(',', '.'));
                                            final notes = flags.isEmpty
                                                ? null
                                                : await _askAdminNote(
                                                    dialogContext);
                                            if (flags.isNotEmpty &&
                                                (notes == null ||
                                                    notes.trim().isEmpty)) {
                                              return;
                                            }
                                            try {
                                              await _api.approveRegistration(id,
                                                  hours: hours, notes: notes);
                                              await refresh(setS);
                                            } catch (e) {
                                              _showError();
                                            }
                                          },
                                          onReject: () async {
                                            final reason =
                                                await _askRejectReason(
                                                    dialogContext);
                                            if (reason == null) return;
                                            try {
                                              await _api.rejectRegistration(id,
                                                  reason: reason);
                                              await refresh(setS);
                                            } catch (e) {
                                              _showError();
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          if (flagged > 0)
                            const Text(
                                'Sati označeni za provjeru traže admin napomenu prije odobrenja.',
                                style: TextStyle(color: Colors.red)),
                          const Spacer(),
                          OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Odustani')),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.done_all, size: 18),
                            onPressed: canApproveAll
                                ? () async {
                                    try {
                                      await _api.approveAll(shift['id']);
                                      await refresh(setS);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Sve prijave odobrene')));
                                      }
                                    } catch (e) {
                                      _showError();
                                    }
                                  }
                                : null,
                            label: const Text('Odobri uredne'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.lock, size: 18),
                            onPressed: canFinalApprove
                                ? () async {
                                    final ok =
                                        await _confirmFinalLock(dialogContext);
                                    if (ok != true) return;
                                    try {
                                      await _api.finalApproval(shift['id']);
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                      await _loadShifts();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Smjena finalno zakljucana')));
                                      }
                                    } catch (e) {
                                      _showError();
                                    }
                                  }
                                : null,
                            label: const Text('Finalno odobri'),
                          ),
                        ]),
                      ]),
          ),
        );
      }),
    );
  }

  Widget _approvalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(children: [
        Expanded(
            flex: 2,
            child: Text('Volonter',
                style: TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
            flex: 2,
            child:
                Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
            flex: 2,
            child: Text('Prijava / odjava',
                style: TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
            child: Text('Prijavljeno',
                style: TextStyle(fontWeight: FontWeight.w700))),
        SizedBox(
            width: 112,
            child: Text('Odobreno',
                style: TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
            flex: 2,
            child: Text('Provjere',
                style: TextStyle(fontWeight: FontWeight.w700))),
        SizedBox(
            width: 150,
            child:
                Text('Akcije', style: TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _approvalRow({
    required Map<String, dynamic> registration,
    required Map<String, dynamic> shift,
    required List<_HourFlag> flags,
    required TextEditingController controller,
    required bool locked,
    required Future<void> Function() onApprove,
    required Future<void> Function() onReject,
  }) {
    final status = (registration['status'] ?? '').toString();
    final canEdit = !locked;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Row(children: [
            const Icon(Icons.person_outline, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(registration['userName'] ?? 'Nepoznat volonter',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                        registration['userEmail']?.toString() ??
                            'Email nije dostupan',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                  ]),
            ),
          ]),
        ),
        Expanded(flex: 2, child: _statusBadge(status)),
        Expanded(flex: 2, child: Text(_checkRange(registration))),
        Expanded(
            child: Text(
                '${_hours(registration['hoursWorked']).toStringAsFixed(1)} h')),
        SizedBox(
          width: 112,
          child: TextField(
              enabled: !locked,
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true, suffixText: 'h'),
          ),
        ),
        Expanded(
          flex: 2,
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            if (flags.isEmpty) _pill('Uredno', Colors.blueGrey),
            ...flags.map((f) => _pill(f.label, f.color, icon: f.icon)),
          ]),
        ),
        SizedBox(
          width: 150,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(
              onPressed: canEdit ? onApprove : null,
              tooltip: 'Odobri sate',
              icon: const Icon(Icons.check_circle, color: Colors.green),
            ),
            IconButton(
              onPressed: canEdit ? onReject : null,
              tooltip: 'Odbij sate',
              icon: const Icon(Icons.cancel, color: Colors.red),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _summaryCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: TextStyle(color: Colors.grey.shade700)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
      ]);

  Widget _pill(String label, Color color, {IconData? icon}) => Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _infoChip(IconData icon, String label, Color color) =>
      _pill(label, color, icon: icon);

  Widget _metaBlock(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]);
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

  Widget _statusBadge(String status) {
    final color = _registrationStatusColor(status);
    return _pill(_registrationStatusLabel(status), color);
  }

  Future<String?> _askAdminNote(BuildContext context) async {
    final note = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potrebna je admin napomena'),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Razlog odobrenja označenih sati'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, note.text.trim()),
              child: const Text('Spremi napomenu')),
        ],
      ),
    );
  }

  Future<String?> _askRejectReason(BuildContext context) async {
    final reason = TextEditingController(text: 'Odbijeno od strane admina');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odbij sate'),
        content: TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Razlog'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, reason.text.trim()),
              child: const Text('Odbij')),
        ],
      ),
    );
  }

  Future<bool?> _confirmFinalLock(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalno odobrenje'),
        content: const Text(
            'Nakon finalnog odobrenja sati volontera se više ne mogu mijenjati. Nastaviti?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Zaključaj smjenu')),
        ],
      ),
    );
  }

  List<_HourFlag> _flagsFor(
      Map<String, dynamic> registration, Map<String, dynamic> shift) {
    final flags = <_HourFlag>[];
    if (registration['isSuspicious'] == true) {
      flags.add(const _HourFlag(
          'Sistemska provjera', Icons.warning_amber, Colors.red));
    }
    final reported = _hours(registration['hoursWorked']);
    final shiftHours = _shiftHours(shift);
    if (reported <= 0 && registration['checkInTime'] != null) {
      flags.add(
          const _HourFlag('Nedostaju sati', Icons.error_outline, Colors.red));
    }
    if (shiftHours > 0 && reported > shiftHours + 0.5) {
      flags.add(
          const _HourFlag('Previše sati', Icons.priority_high, Colors.red));
    }
    final actual = _actualHours(registration);
    if (actual != null && (reported - actual).abs() > 0.25) {
      flags.add(const _HourFlag(
          'Vrijeme se ne slaže', Icons.sync_problem, Colors.orange));
    }
    return flags;
  }

  Color _shiftStatusColor(Map<String, dynamic> shift) {
    if (shift['isLocked'] == true) return Colors.green;
    final start = DateTime.tryParse(shift['startTime']?.toString() ?? '');
    final end = DateTime.tryParse(shift['endTime']?.toString() ?? '');
    final now = DateTime.now().toUtc();
    if (end != null && now.isAfter(end.toUtc())) return Colors.orange;
    if (start != null && now.isAfter(start.toUtc())) return Colors.orange;
    return Colors.blue;
  }

  String _shiftStatusLabel(Map<String, dynamic> shift) {
    if (shift['isLocked'] == true) return 'Finalno odobrena';
    final end = DateTime.tryParse(shift['endTime']?.toString() ?? '');
    if (end != null && DateTime.now().toUtc().isAfter(end.toUtc())) {
      return 'Čeka sate';
    }
    return 'Nadolazeća';
  }

  Color _registrationStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Completed':
        return Colors.blue;
      case 'Registered':
        return Colors.teal;
      case 'Cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _registrationStatusLabel(String status) {
    switch (status) {
      case 'Approved':
        return 'Odobreno';
      case 'Rejected':
        return 'Odbijeno';
      case 'Completed':
        return 'Čeka odobrenje';
      case 'Registered':
        return 'Registrovan';
      case 'Cancelled':
        return 'Otkazano';
      default:
        return status.isEmpty ? 'Na čekanju' : status;
    }
  }

  String get _selectedEventTitle {
    final event = _events
        .where((e) => e['id'] == _selectedEventId)
        .cast<Map?>()
        .firstOrNull;
    return event?['title']?.toString() ?? '-';
  }

  String _initialApprovedHours(Map<String, dynamic> registration) {
    final value =
        registration['approvedHours'] ?? registration['hoursWorked'] ?? 0;
    return _hours(value).toStringAsFixed(1);
  }

  String _checkRange(Map<String, dynamic> registration) {
    final checkIn = _fmtTime(registration['checkInTime']);
    final checkOut = _fmtTime(registration['checkOutTime']);
    if (checkIn == '-' && checkOut == '-') return 'Nije prijavljen';
    return '$checkIn - $checkOut';
  }

  String _timeRange(Map<String, dynamic> shift) =>
      '${_fmtTime(shift['startTime'])} - ${_fmtTime(shift['endTime'])}';

  double _shiftHours(Map<String, dynamic> shift) {
    final start = DateTime.tryParse(shift['startTime']?.toString() ?? '');
    final end = DateTime.tryParse(shift['endTime']?.toString() ?? '');
    if (start == null || end == null) return 0;
    return end.difference(start).inMinutes / 60;
  }

  double? _actualHours(Map<String, dynamic> registration) {
    final checkIn =
        DateTime.tryParse(registration['checkInTime']?.toString() ?? '');
    final checkOut =
        DateTime.tryParse(registration['checkOutTime']?.toString() ?? '');
    if (checkIn == null || checkOut == null) return null;
    return checkOut.difference(checkIn).inMinutes / 60;
  }

  double _hours(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  String _fmtTime(dynamic iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.toString();
    }
  }

  String _fmtDT2(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Doslo je do greske. Pokusajte ponovo.')),
    );
  }
}

class _HourFlag {
  final String label;
  final IconData icon;
  final Color color;

  const _HourFlag(this.label, this.icon, this.color);
}
