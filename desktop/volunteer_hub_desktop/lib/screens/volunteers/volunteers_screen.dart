import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class VolunteersScreen extends StatefulWidget {
  const VolunteersScreen({super.key});
  @override
  State<VolunteersScreen> createState() => _VolunteersScreenState();
}

class _VolunteersScreenState extends State<VolunteersScreen> {
  final _api = ApiService();
  List<dynamic> _users = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getUsers(query: {'search': _searchCtrl.text, 'pageSize': 100});
      final d = res.data;
        final allUsers = d is Map ? (d['items'] ?? []) : (d is List ? d : []);
        _users = (allUsers as List)
          .where((u) => (u['role'] ?? '').toString().toLowerCase() == 'volunteer')
          .toList();
    } catch (e) {
      debugPrint('Volunteers error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Search
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Pretraži po imenu ili emailu...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: _load, child: const Text('Traži')),
        ]),
        const SizedBox(height: 12),
        // Stats summary
        Row(children: [
          _miniStat(Icons.people, 'Ukupno: ${_users.length}', Colors.blueGrey),
          const SizedBox(width: 12),
          _miniStat(Icons.volunteer_activism, 'Aktivni volonteri: ${_users.length}', Colors.green),
        ]),
        const SizedBox(height: 16),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('Nema pronađenih volontera'))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (ctx, i) {
                        final u = _users[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: _userAvatar(u),
                            title: Text('${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim()),
                            subtitle: Text('${u['email'] ?? ''}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              _stat(Icons.timer, '${u['totalHours']?.toStringAsFixed(1) ?? '0'} h'),
                              const SizedBox(width: 12),
                              _stat(Icons.event, '${u['totalEvents'] ?? 0} događaja'),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.info_outline),
                                tooltip: 'Detalji',
                                onPressed: () => _showDetails(u),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _userAvatar(Map<String, dynamic> u) {
    final url = u['profileImageUrl'] as String?;
    final initials = '${_initial(u['firstName'], fallback: 'V')}${_initial(u['lastName'])}'.toUpperCase();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(url), onBackgroundImageError: (_, __) {});
    }
    return CircleAvatar(child: Text(initials));
  }

  Widget _miniStat(IconData icon, String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );

  Widget _stat(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: Colors.grey),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 13)),
    ]);
  }

  void _showDetails(Map<String, dynamic> u) async {
    List<dynamic> skills = [];
    try {
      final res = await _api.getUserSkills(u['id']);
      skills = res.data is List ? res.data : [];
    } catch (_) {}

    List<dynamic> history = [];
    try {
      final res = await _api.getUserShiftRegistrations(u['id']);
      history = res.data is List ? res.data : [];
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, _) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 760,
            height: 620,
            child: DefaultTabController(
              length: 3,
              child: Column(children: [
                // ── Profile header ──
                _detailsHeader(u),
                // ── Tabs ──
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Info'),
                    Tab(icon: Icon(Icons.star_outline, size: 18), text: 'Vještine'),
                    Tab(icon: Icon(Icons.history, size: 18), text: 'Smjene'),
                  ],
                ),
                Expanded(
                  child: TabBarView(children: [
                    // ── Info tab ──
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        _detailCard([
                          _detailTile(Icons.email_outlined, 'Email', u['email'] ?? '-'),
                          _detailTile(Icons.phone_outlined, 'Telefon', u['phone'] ?? u['phoneNumber'] ?? '-'),
                          _detailTile(Icons.location_city_outlined, 'Grad', u['cityName'] ?? '-'),
                          _detailTile(Icons.badge_outlined, 'Uloga', u['role'] ?? '-'),
                          _detailTile(Icons.calendar_today_outlined, 'Registracija', _fmtDate(u['createdAt'])),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          _statCard(Icons.timer_outlined, '${u['totalHours']?.toStringAsFixed(1) ?? '0'}h', 'Ukupno sati', Colors.blue),
                          const SizedBox(width: 12),
                          _statCard(Icons.event_outlined, '${u['totalEvents'] ?? 0}', 'Događaja', Colors.green),
                        ]),
                        if ((u['bio'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _detailCard([
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                                  const SizedBox(width: 10),
                                  Text('O volonteru', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                                ]),
                                const SizedBox(height: 8),
                                Text(u['bio'], style: const TextStyle(fontSize: 14, height: 1.5)),
                              ]),
                            ),
                          ]),
                        ],
                      ]),
                    ),
                    // ── Skills tab ──
                    skills.isEmpty
                        ? _emptyState(Icons.star_outline, 'Nema unesenih vještina')
                        : Padding(
                            padding: const EdgeInsets.all(20),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: skills.map<Widget>((s) => Chip(
                                    avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
                                    label: Text(s['skillName'] ?? s['name'] ?? ''),
                                    backgroundColor: Colors.amber.shade50,
                                  )).toList(),
                            ),
                          ),
                    // ── Shift history tab ──
                    history.isEmpty
                        ? _emptyState(Icons.history, 'Nema historije smjena')
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: history.length,
                            itemBuilder: (_, i) {
                              final h = history[i];
                              final status = h['status'] ?? '-';
                              final statusColor = status == 'Approved'
                                  ? Colors.green
                                  : status == 'Rejected'
                                      ? Colors.red
                                      : Colors.orange;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: statusColor.withValues(alpha: 0.12),
                                    child: Icon(
                                      status == 'Approved' ? Icons.check_circle_outline : status == 'Rejected' ? Icons.cancel_outlined : Icons.hourglass_empty,
                                      size: 18,
                                      color: statusColor,
                                    ),
                                  ),
                                  title: Text(h['shiftName'] ?? h['eventTitle'] ?? 'Smjena', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  subtitle: Text('${_fmtDate(h['shiftStartTime'] ?? h['createdAt'])}', style: const TextStyle(fontSize: 12)),
                                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                    if (h['hoursWorked'] != null)
                                      Text('${(h['hoursWorked'] as num).toStringAsFixed(1)}h', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                      child: Text(status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                  ]),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zatvori')),
          ],
        ),
      ),
    );
  }

  Widget _detailsHeader(Map<String, dynamic> u) {
    final imageUrl = u['profileImageUrl'] as String?;
    final initials = '${_initial(u['firstName'], fallback: 'V')}${_initial(u['lastName'])}'.toUpperCase();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Row(children: [
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
          child: CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white24,
            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
            child: (imageUrl == null || imageUrl.isEmpty)
                ? Text(initials, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))
                : null,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(u['email'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
            if ((u['cityName'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(Icons.location_on, size: 14, color: Colors.white.withValues(alpha: 0.75)),
                  const SizedBox(width: 4),
                  Text(u['cityName'], style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _detailCard(List<Widget> children) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(children: children.map((w) => w is Divider ? w : Column(children: [w, if (w != children.last) const Divider(height: 1)])).toList()),
        ),
      );

  Widget _detailTile(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ]),
      );

  Widget _statCard(IconData icon, String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
          ]),
        ),
      );

  Widget _emptyState(IconData icon, String message) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[500])),
        ]),
      );

  String _initial(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return fallback;
    return text[0];
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '-';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return DateFormat('dd.MM.yyyy HH:mm').format(d);
  }

}
