import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../shifts/shift_detail_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;
  List<dynamic> _leaderboard = [];
  List<dynamic> _mySkills = [];
  List<dynamic> _allSkills = [];
  List<dynamic> _myShifts = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  // Leaderboard pagination
  final ScrollController _lbScroll = ScrollController();
  int _lbPage = 1;
  bool _lbHasMore = true;
  bool _lbLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _lbScroll.addListener(_onLbScroll);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _lbScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final futures = await Future.wait([
        _api.getLeaderboardPaged(page: 1, pageSize: 20),
        _api.getUserSkills(),
        _api.getSkills(),
        _api.getMyStats(),
        _api.getMyShifts(),
      ]);
      final lbData = futures[0].data;
      _leaderboard = lbData is Map ? (lbData['items'] as List? ?? []) : (lbData is List ? lbData : []);
      _lbPage = 1;
      _lbHasMore = lbData is Map && (_lbPage < (lbData['totalPages'] ?? 1));
      _mySkills = futures[1].data is List ? futures[1].data : [];
      _allSkills = futures[2].data is List ? futures[2].data : [];
      _stats = futures[3].data is Map ? futures[3].data as Map<String, dynamic> : {};
      final shiftsData = futures[4].data;
      _myShifts = shiftsData is Map
          ? (shiftsData['items'] as List? ?? [])
          : (shiftsData is List ? shiftsData : []);
    } catch (e) {
      debugPrint('Profile load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onLbScroll() {
    if (_lbScroll.position.pixels >= _lbScroll.position.maxScrollExtent - 200) {
      _loadMoreLeaderboard();
    }
  }

  Future<void> _loadMoreLeaderboard() async {
    if (_lbLoadingMore || !_lbHasMore) return;
    _lbLoadingMore = true;
    try {
      final res = await _api.getLeaderboardPaged(page: _lbPage + 1, pageSize: 20);
      final data = res.data;
      if (data is Map) {
        final items = data['items'] as List? ?? [];
        if (items.isNotEmpty) {
          _lbPage++;
          _leaderboard.addAll(items);
          _lbHasMore = _lbPage < (data['totalPages'] ?? 1);
        } else {
          _lbHasMore = false;
        }
      }
    } catch (e) {
      debugPrint('Leaderboard load more error: $e');
    } finally {
      _lbLoadingMore = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Column(children: [
      // Profile header (always visible)
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          _buildAvatar(user, radius: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(user?['email'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _showEditProfileDialog(user),
            tooltip: 'Uredi profil',
          ),
        ]),
      ),

      // Stats row
      if (!_loading)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            _miniStatCard('${(_stats['totalHours'] ?? 0).toStringAsFixed(1)}h', 'Sati', Colors.blue),
            const SizedBox(width: 8),
            _miniStatCard('${_stats['totalEvents'] ?? 0}', 'Dogadaji', Colors.green),
            const SizedBox(width: 8),
            _miniStatCard('${_stats['upcomingShifts'] ?? 0}', 'Nadolazece', Colors.orange),
            const SizedBox(width: 8),
            _miniStatCard('#${_stats['rank'] ?? '-'}', 'Rang', Colors.amber.shade700),
          ]),
        ),

      // Tab bar
      TabBar(
        controller: _tabCtrl,
        tabs: const [
          Tab(icon: Icon(Icons.person, size: 18), text: 'Profil'),
          Tab(icon: Icon(Icons.history, size: 18), text: 'Moje smjene'),
          Tab(icon: Icon(Icons.leaderboard, size: 18), text: 'Rang lista'),
        ],
      ),

      // Tab views
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(controller: _tabCtrl, children: [
                _buildProfileTab(auth, user),
                _buildShiftsTab(),
                _buildLeaderboardTab(user),
              ]),
      ),
    ]);
  }

  Widget _miniStatCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ]),
      ),
    );
  }

  // --- PROFILE TAB ---
  Widget _buildProfileTab(AuthProvider auth, Map<String, dynamic>? user) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // User info
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _infoRow(Icons.email, 'Email', user?['email'] ?? '-'),
                const Divider(),
                _infoRow(Icons.phone, 'Telefon', user?['phone'] ?? user?['phoneNumber'] ?? '-'),
                const Divider(),
                _infoRow(Icons.badge, 'Uloga', user?['role'] ?? '-'),
                if ((user?['bio'] ?? '').toString().isNotEmpty) ...[
                  const Divider(),
                  _infoRow(Icons.info_outline, 'O meni', user?['bio'] ?? ''),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Skills
          Row(children: [
            const Icon(Icons.star, size: 20, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Moje vještine', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: _showAddSkillDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Dodaj'),
            ),
          ]),
          const SizedBox(height: 8),
          if (_mySkills.isEmpty)
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(child: Text('Dodajte vještine za bolje preporuke dogadaja!')),
                ]),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _mySkills.map((s) => Chip(
                    label: Text(s['skillName'] ?? s['name'] ?? ''),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeSkill(s['skillId']),
                  )).toList(),
            ),
          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () {
                auth.logout();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Odjava'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            softWrap: true,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }

  // --- MY SHIFTS TAB ---
  Widget _buildShiftsTab() {
    if (_myShifts.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.history, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Nema podataka o smjenama', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ]),
      );
    }

    final completed = _myShifts.where((s) {
      final st = s['status'] ?? '';
      return st == 'Completed' || st == 'Approved' || st == 'Rejected';
    }).toList();
    final pending = _myShifts.where((s) {
      final st = s['status'] ?? '';
      return st == 'Registered' || st == 'Pending';
    }).toList();

    final completedHours = completed.fold(0.0, (sum, s) => sum + (s['hoursWorked'] as num? ?? 0).toDouble());
    final completedCount = completed.where((s) => s['status'] == 'Completed').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Summary row
          Row(children: [
            _miniStatCard('${completedHours.toStringAsFixed(1)}h', 'Odradeno', Colors.blue),
            const SizedBox(width: 8),
            _miniStatCard('$completedCount', 'Završene', Colors.green),
            const SizedBox(width: 8),
            _miniStatCard('${pending.length}', 'Nadolazece', Colors.orange),
            const SizedBox(width: 8),
            _miniStatCard('${completed.where((s) => s['status'] == 'Rejected').length}', 'Odbijene', Colors.red),
          ]),
          const SizedBox(height: 16),
          if (pending.isNotEmpty) ...[
            Text('Aktivne/Nadolazece (${pending.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...pending.map((s) => _shiftHistoryCard(s)),
            const SizedBox(height: 16),
          ],
          if (completed.isNotEmpty) ...[
            Text('Povijest (${completed.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...completed.map((s) => _shiftHistoryCard(s)),
          ],
        ],
      ),
    );
  }

  Widget _shiftHistoryCard(dynamic s) {
    final status = s['status'] ?? '';
    final hours = s['hoursWorked'] as num?;
    final isSuspicious = s['isSuspicious'] == true;
    final shiftId = _readInt(s['shiftId']);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: shiftId == null ? null : () => _openShiftDetail(Map<String, dynamic>.from(s as Map)),
        child: ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: _statusColor(status).withValues(alpha: 0.15),
            child: Icon(_statusIcon(status), color: _statusColor(status), size: 18),
          ),
          title: Text(s['eventTitle'] ?? s['shiftName'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (s['shiftName'] != null) Text(s['shiftName'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(_fmtDT(s['shiftStartTime']), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (hours != null) Text('${hours.toStringAsFixed(1)}h', style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, color: _statusColor(status), fontWeight: FontWeight.w600)),
              ),
              if (isSuspicious) ...[
                const SizedBox(width: 4),
                const Icon(Icons.warning_amber, size: 14, color: Colors.orange),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade500),
            ]),
          ]),
        ),
      ),
    );
  }

  // --- LEADERBOARD TAB ---
  Widget _buildLeaderboardTab(Map<String, dynamic>? user) {
    if (_leaderboard.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.leaderboard, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Rang lista je prazna', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _lbScroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _leaderboard.length + (_lbHasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= _leaderboard.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final e = _leaderboard[i];
          final isMe = user != null && e['userId'] == user['id'];

          return Card(
            color: isMe ? Theme.of(context).primaryColor.withValues(alpha: 0.2) : null,
            shape: isMe
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  )
                : null,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: i < 3
                    ? [Colors.amber, Colors.grey.shade400, Colors.brown.shade300][i]
                    : Colors.grey.shade200,
                child: i < 3
                    ? Icon([Icons.looks_one, Icons.looks_two, Icons.looks_3][i], color: Colors.white, size: 20)
                    : Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              title: Text(
                '${e['userName'] ?? ''}${isMe ? ' (Ti)' : ''}',
                style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
              ),
              subtitle: Text('${e['totalEvents'] ?? 0} dogadaja • ${e['points'] ?? 0} bodova', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              trailing: Text('${(e['totalHours'] ?? 0).toStringAsFixed(1)}h',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: i < 3 ? Colors.amber.shade700 : null)),
            ),
          );
        },
      ),
    );
  }

  // --- HELPERS ---
  Widget _buildAvatar(Map<String, dynamic>? user, {double radius = 24}) {
    final url = user?['profileImageUrl'] as String?;
    final firstName = (user?['firstName'] ?? 'V').toString();
    final lastName = (user?['lastName'] ?? '').toString();
    final initials =
        '${firstName.isNotEmpty ? firstName[0] : 'V'}${lastName.isNotEmpty ? lastName[0] : ''}'
            .toUpperCase();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(_api.resolveFileUrl(url)),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
      child: Text(initials, style: TextStyle(fontSize: radius * 0.67, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'Approved' => Colors.green,
        'Completed' => Colors.blue,
        'Rejected' => Colors.red,
        'Registered' || 'Pending' => Colors.orange,
        _ => Colors.grey,
      };

  IconData _statusIcon(String status) => switch (status) {
        'Approved' => Icons.check_circle,
        'Completed' => Icons.task_alt,
        'Rejected' => Icons.cancel,
        'Registered' || 'Pending' => Icons.hourglass_empty,
        _ => Icons.schedule,
      };

  String _statusLabel(String status) => switch (status) {
        'Approved' => 'Odobreno',
        'Completed' => 'Završeno',
        'Rejected' => 'Odbijeno',
        'Registered' => 'Prijavljeno',
        'Pending' => 'Ceka se odobrenje',
        _ => status,
      };

  String _fmtDT(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _openShiftDetail(Map<String, dynamic> shift) async {
    final shiftId = _readInt(shift['shiftId']);
    if (shiftId == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShiftDetailScreen(
          shiftId: shiftId,
          initialRegistration: shift,
        ),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  void _showEditProfileDialog(Map<String, dynamic>? user) {
    if (user == null) return;
    final firstNameCtrl = TextEditingController(text: user['firstName'] ?? '');
    final lastNameCtrl = TextEditingController(text: user['lastName'] ?? '');
    final emailCtrl = TextEditingController(text: user['email'] ?? '');
    final phoneCtrl = TextEditingController(text: user['phone'] ?? user['phoneNumber'] ?? '');
    final imageUrlCtrl = TextEditingController(text: user['profileImageUrl'] ?? '');
    final bioCtrl = TextEditingController(text: user['bio'] ?? '');
    bool changePassword = false;
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Uredi profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              TextFormField(
                controller: firstNameCtrl,
                decoration: const InputDecoration(labelText: 'Ime *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Unesite ime' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: lastNameCtrl,
                decoration: const InputDecoration(labelText: 'Prezime *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Unesite prezime' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Unesite email';
                  final emailRe = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                  if (!emailRe.hasMatch(v.trim())) return 'Nevažeci format emaila';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final phoneRe = RegExp(r'^\+?[0-9\s\-\(\)]{6,20}$');
                  if (!phoneRe.hasMatch(v.trim())) return 'Nevažeci format broja telefona';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: imageUrlCtrl,
                decoration: const InputDecoration(labelText: 'URL slike profila', border: OutlineInputBorder(), prefixIcon: Icon(Icons.image_outlined), hintText: 'https://...'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: bioCtrl,
                decoration: const InputDecoration(labelText: 'O meni', border: OutlineInputBorder(), prefixIcon: Icon(Icons.info_outline)),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Promijeni lozinku'),
                value: changePassword,
                onChanged: (v) => setS(() => changePassword = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (changePassword) ...[
                TextFormField(
                  controller: oldPassCtrl,
                  decoration: const InputDecoration(labelText: 'Trenutna lozinka *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                  obscureText: true,
                  validator: (v) => changePassword && (v == null || v.isEmpty) ? 'Unesite trenutnu lozinku' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPassCtrl,
                  decoration: const InputDecoration(labelText: 'Nova lozinka *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                  obscureText: true,
                  validator: (v) {
                    if (!changePassword) return null;
                    if (v == null || v.isEmpty) return 'Unesite novu lozinku';
                    if (v.length < 6) return 'Lozinka mora imati najmanje 6 znakova';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setS(() => saving = true);
                          try {
                            final data = {
                              'firstName': firstNameCtrl.text.trim(),
                              'lastName': lastNameCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'phoneNumber': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                              'profileImageUrl': imageUrlCtrl.text.trim().isEmpty ? null : imageUrlCtrl.text.trim(),
                              'bio': bioCtrl.text.trim().isEmpty ? null : bioCtrl.text.trim(),
                            };
                            if (changePassword) {
                              data['oldPassword'] = oldPassCtrl.text;
                              data['newPassword'] = newPassCtrl.text;
                            }
                            await _api.updateProfile(data);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (!mounted) return;
                            final auth = context.read<AuthProvider>();
                            auth.updateUser({
                              ...user,
                              'firstName': data['firstName'],
                              'lastName': data['lastName'],
                              'email': data['email'],
                              'phone': data['phoneNumber'],
                              'profileImageUrl': data['profileImageUrl'],
                              'bio': data['bio'],
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profil uspješno ažuriran'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            setS(() => saving = false);
                            if (mounted) {
                              String msg = 'Greška pri ažuriranju profila. Provjerite unos i pokušajte ponovo.';
                              if (e is DioException) {
                                final data = e.response?.data;
                                final apiMsg = data is Map ? (data['message'] ?? data['title']) : null;
                                if (apiMsg != null) {
                                  msg = apiMsg.toString();
                                } else if (e.response?.statusCode == 401) {
                                  msg = 'Trenutna lozinka je neispravna.';
                                } else if (e.response?.statusCode == 409) {
                                  msg = 'Email adresa je vec u upotrebi.';
                                }
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  icon: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(saving ? 'Sprema...' : 'Spremi'),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  void _showAddSkillDialog() {
    final available = _allSkills.where((s) => !_mySkills.any((ms) => ms['skillId'] == s['id'])).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Dodaj vještinu', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (available.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Sve vještine su vec dodane!'))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: available.map((s) => ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(s['name'] ?? ''),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addSkill(s['id']);
                    },
                  )).toList(),
            ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Future<void> _addSkill(int skillId) async {
    try {
      await _api.addUserSkill(skillId);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vještina dodana'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.'), backgroundColor: Colors.red));
    }
  }

  Future<void> _removeSkill(int id) async {
    try {
      await _api.removeUserSkill(id);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vještina uklonjena'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.'), backgroundColor: Colors.red));
    }
  }
}

