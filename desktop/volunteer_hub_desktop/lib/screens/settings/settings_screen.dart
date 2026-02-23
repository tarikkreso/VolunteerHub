import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _userStats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getMyStats();
      _userStats = res.data is Map ? res.data as Map<String, dynamic> : null;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final role = (user?['role'] ?? '').toString().toLowerCase();
    final isVolunteer = role == 'volunteer';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Postavke', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),

        // Profile section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Profil korisnika', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
              const SizedBox(height: 8),
              Row(children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    '${_initial(user?['firstName'], fallback: 'U')}${_initial(user?['lastName'])}'.toUpperCase(),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(user?['email'] ?? '', style: const TextStyle(color: Colors.grey)),
                    ]),
                    if ((user?['phone'] ?? user?['phoneNumber']) != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text((user?['phone'] ?? user?['phoneNumber'] ?? '').toString(), style: const TextStyle(color: Colors.grey)),
                      ]),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(user?['role'] ?? 'Korisnik',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: user == null ? null : () => _showEditProfileDialog(auth, user),
                    icon: const Icon(Icons.edit),
                    label: const Text('Uredi profil'),
                  ),
                ],
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Stats
        if (isVolunteer && !_loading && _userStats != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Statistika', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(),
                Wrap(spacing: 16, runSpacing: 16, children: [
                  _statTile('Ukupno sati', '${(_userStats!['totalHours'] ?? 0).toStringAsFixed(1)}', Icons.access_time, Colors.purple),
                  _statTile('Događaji', '${_userStats!['totalEvents'] ?? 0}', Icons.event, Colors.blue),
                  _statTile('Nadolazeće smjene', '${_userStats!['upcomingShifts'] ?? 0}', Icons.schedule, Colors.green),
                  _statTile('Rang', '#${_userStats!['rank'] ?? '-'}', Icons.leaderboard, Colors.amber),
                ]),
              ]),
            ),
          ),
        const SizedBox(height: 16),

        // System info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sistemske informacije', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
              const SizedBox(height: 8),
              _infoRow('Platforma', 'VolunteerHub Desktop Admin'),
              _infoRow('Verzija', '1.0.0'),
              _infoRow('Korisnička uloga', user?['role']?.toString() ?? 'N/A'),
              _infoRow('API konekcija', 'Aktivna'),
              _infoRow('Posljednje osvježenje', _formatNow()),
              const SizedBox(height: 12),
              const Text(
                'Administratorski panel za upravljanje događajima, smjenama, volonterima, donacijama i izvještajima.',
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Danger zone
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Akcije', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Odjava'),
                        content: const Text('Jeste li sigurni da se želite odjaviti?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Odustani')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () {
                              Navigator.pop(ctx);
                              auth.logout();
                              Navigator.of(context).pushReplacementNamed('/login');
                            },
                            child: const Text('Odjavi se'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Odjavi se'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  void _showEditProfileDialog(AuthProvider auth, Map<String, dynamic> user) {
    final firstNameCtrl = TextEditingController(text: (user['firstName'] ?? '').toString());
    final lastNameCtrl = TextEditingController(text: (user['lastName'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (user['phone'] ?? user['phoneNumber'] ?? '').toString());
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    bool changePassword = false;
    bool saving = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Uredi profil'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: firstNameCtrl,
                    decoration: const InputDecoration(labelText: 'Ime *'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Unesite ime' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lastNameCtrl,
                    decoration: const InputDecoration(labelText: 'Prezime *'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Unesite prezime' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      final text = (v ?? '').trim();
                      if (text.isEmpty) return null;
                      final ok = RegExp(r'^\+?[0-9\-\s]{6,20}$').hasMatch(text);
                      return ok ? null : 'Unesite ispravan broj telefona';
                    },
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
                      decoration: const InputDecoration(labelText: 'Trenutna lozinka *'),
                      obscureText: true,
                      validator: (v) {
                        if (!changePassword) return null;
                        if (v == null || v.isEmpty) return 'Unesite trenutnu lozinku';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPassCtrl,
                      decoration: const InputDecoration(labelText: 'Nova lozinka *'),
                      obscureText: true,
                      validator: (v) {
                        if (!changePassword) return null;
                        if (v == null || v.isEmpty) return 'Unesite novu lozinku';
                        if (v.length < 6) return 'Lozinka mora imati najmanje 6 znakova';
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Odustani')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => saving = true);
                      try {
                        final data = <String, dynamic>{
                          'firstName': firstNameCtrl.text.trim(),
                          'lastName': lastNameCtrl.text.trim(),
                          'phoneNumber': phoneCtrl.text.trim(),
                        };
                        if (changePassword) {
                          data['oldPassword'] = oldPassCtrl.text;
                          data['newPassword'] = newPassCtrl.text;
                        }

                        final res = await _api.updateProfile(data);
                        final updated = res.data is Map<String, dynamic>
                            ? res.data as Map<String, dynamic>
                            : (res.data as Map).cast<String, dynamic>();
                        auth.updateUser({...?auth.user, ...updated});
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profil uspješno ažuriran')),
                          );
                        }
                      } on DioException catch (e) {
                        setS(() => saving = false);
                        String msg = 'Došlo je do greške. Pokušajte ponovo.';
                        if (e.response?.data is Map && (e.response?.data['message']?.toString().isNotEmpty ?? false)) {
                          msg = e.response?.data['message'].toString() ?? msg;
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                        }
                      } catch (_) {
                        setS(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.')),
                          );
                        }
                      }
                    },
              child: Text(saving ? 'Spremanje...' : 'Spremi promjene'),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return fallback;
    return text[0];
  }

  String _formatNow() {
    final now = DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yyyy = now.year.toString();
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 180,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 160, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
