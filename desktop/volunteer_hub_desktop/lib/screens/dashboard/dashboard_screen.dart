import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../events/events_screen.dart';
import '../shifts/shifts_screen.dart';
import '../volunteers/volunteers_screen.dart';
import '../campaigns/campaigns_screen.dart';
import '../blog/blog_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../skills/skills_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final ApiService _api = ApiService();

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.event, label: 'Događaji'),
    _NavItem(icon: Icons.schedule, label: 'Smjene'),
    _NavItem(icon: Icons.people, label: 'Volonteri'),
    _NavItem(icon: Icons.campaign, label: 'Kampanje'),
    _NavItem(icon: Icons.article, label: 'Blog'),
    _NavItem(icon: Icons.bar_chart, label: 'Izvještaji'),
    _NavItem(icon: Icons.psychology, label: 'Vještine'),
    _NavItem(icon: Icons.settings, label: 'Postavke'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 250,
            color: const Color(0xFF1E1E2D),
            child: Column(
              children: [
                Container(
                  height: 80,
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    children: [
                      Icon(Icons.volunteer_activism, color: Colors.white, size: 32),
                      SizedBox(width: 12),
                      Text('VolunteerHub',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _navItems.length,
                    itemBuilder: (context, index) {
                      final item = _navItems[index];
                      final sel = _selectedIndex == index;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: sel ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.transparent,
                        ),
                        child: ListTile(
                          leading: Icon(item.icon, color: sel ? Theme.of(context).primaryColor : Colors.white70),
                          title: Text(item.label,
                              style: TextStyle(
                                  color: sel ? Theme.of(context).primaryColor : Colors.white70,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                          onTap: () => setState(() => _selectedIndex = index),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text('${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}',
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(user?['role'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white54),
                    tooltip: 'Odjavi se',
                    onPressed: () {
                      auth.logout();
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(children: [
                    Text(_navItems[_selectedIndex].label,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                  ]),
                ),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: return _DashboardHome(api: _api, onNavigate: (i) => setState(() => _selectedIndex = i));
      case 1: return const EventsScreen();
      case 2: return const ShiftsScreen();
      case 3: return const VolunteersScreen();
      case 4: return const CampaignsScreen();
      case 5: return const BlogScreen();
      case 6: return const ReportsScreen();
      case 7: return const SkillsScreen();
      case 8: return const SettingsScreen();
      default: return const SizedBox();
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}

class _DashboardHome extends StatefulWidget {
  final ApiService api;
  final void Function(int index) onNavigate;
  const _DashboardHome({required this.api, required this.onNavigate});
  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  Map<String, dynamic>? _stats;
  List<dynamic> _events = [];
  List<dynamic> _leaderboard = [];
  bool _loading = true;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        widget.api.getDashboardStats(
          startDate: _dateRange?.start,
          endDate: _dateRange?.end,
        ),
        widget.api.getEvents(query: {'page': 1, 'pageSize': 5}),
        widget.api.getLeaderboard(top: 5),
      ]);
      _stats = res[0].data;
      final ed = res[1].data;
      _events = ed is Map ? (ed['items'] ?? []) : (ed is List ? ed : []);
      _leaderboard = res[2].data is List ? res[2].data : [];
    } catch (e) {
      debugPrint('Dashboard error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range),
            label: Text(_rangeLabel),
          ),
          const SizedBox(width: 8),
          if (_dateRange != null)
            TextButton.icon(
              onPressed: () {
                setState(() => _dateRange = null);
                _load();
              },
              icon: const Icon(Icons.clear),
              label: const Text('Očisti period'),
            ),
          const Spacer(),
          IconButton(
            onPressed: _load,
            tooltip: 'Osvježi',
            icon: const Icon(Icons.refresh),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _stat('Događaji', '${_stats?['totalEvents'] ?? 0}', Icons.event, Colors.blue),
          const SizedBox(width: 16),
          _stat('Smjene', '${_stats?['totalShifts'] ?? 0}', Icons.schedule, Colors.orange),
          const SizedBox(width: 16),
          _stat('Volonteri', '${_stats?['totalVolunteers'] ?? 0}', Icons.people, Colors.green),
          const SizedBox(width: 16),
          _stat('Sati', _stats?['totalHours'] != null ? (_stats!['totalHours'] as num).toStringAsFixed(0) : '0', Icons.access_time, Colors.purple),
          const SizedBox(width: 16),
          _stat('Kampanje', '${_stats?['activeCampaigns'] ?? 0}', Icons.campaign, Colors.teal),
          const SizedBox(width: 16),
          _stat('Donacije', _stats?['totalDonations'] != null ? '${(_stats!['totalDonations'] as num).toStringAsFixed(0)} KM' : '0 KM', Icons.monetization_on, Colors.amber),
        ]),
        const SizedBox(height: 24),
        // Quick Actions
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Brze akcije', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _actionBtn(Icons.add_circle, 'Kreiraj događaj', Colors.blue, () => widget.onNavigate(1)),
                _actionBtn(Icons.schedule, 'Upravljaj smjenama', Colors.orange, () => widget.onNavigate(2)),
                _actionBtn(Icons.people, 'Pregled volontera', Colors.green, () => widget.onNavigate(3)),
                _actionBtn(Icons.campaign, 'Kampanje', Colors.teal, () => widget.onNavigate(4)),
                _actionBtn(Icons.article, 'Blog objave', Colors.indigo, () => widget.onNavigate(5)),
                _actionBtn(Icons.bar_chart, 'Izvještaji', Colors.purple, () => widget.onNavigate(6)),
                _actionBtn(Icons.psychology, 'Vještine', Colors.deepPurple, () => widget.onNavigate(7)),
                _actionBtn(Icons.settings, 'Postavke', Colors.blueGrey, () => widget.onNavigate(8)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 2,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Nadolazeći događaji', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_events.isEmpty) const Text('Nema nadolazećih događaja', style: TextStyle(color: Colors.grey)),
                  ..._events.map((e) => ListTile(
                        leading: const Icon(Icons.event, color: Colors.blue),
                        title: Text(e['title'] ?? ''),
                        subtitle: Text(e['location'] ?? ''),
                        trailing: Text(_fmt(e['startDate']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      )),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Top volonteri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ..._leaderboard.asMap().entries.map((en) {
                    final i = en.key;
                    final v = en.value;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: i == 0 ? Colors.amber : i == 1 ? Colors.grey : i == 2 ? Colors.brown.shade300 : Colors.blue.shade100,
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(v['userName'] ?? ''),
                      trailing: Text('${_numFmt(v['totalHours'])}h', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: color.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color c) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: c, size: 28),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ]),
          ),
        ),
      );

  String _fmt(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return iso;
    }
  }

  String _numFmt(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toStringAsFixed(1);
    return v.toString();
  }

  String get _rangeLabel {
    if (_dateRange == null) return 'Odaberi period';
    final s = _dateRange!.start;
    final e = _dateRange!.end;
    return '${s.day.toString().padLeft(2, '0')}.${s.month.toString().padLeft(2, '0')}.${s.year} - ${e.day.toString().padLeft(2, '0')}.${e.month.toString().padLeft(2, '0')}.${e.year}';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _dateRange ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: initial,
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      await _load();
    }
  }
}
