import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});
  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final _api = ApiService();
  List<dynamic> _skills = [];
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
      final res = await _api.getSkills();
      _skills = res.data is List ? res.data : [];
    } catch (e) {
      debugPrint('Skills error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _skills;
    return _skills.where((s) => (s['name'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final filtered = _filtered;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Upravljanje vještinama', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star, size: 16, color: Colors.blue),
              const SizedBox(width: 6),
              Text('Ukupno: ${_skills.length}',
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 12)),
            ]),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showDialog(null),
            icon: const Icon(Icons.add),
            label: const Text('Nova vještina'),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Pretraži vještine...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Nema vještina'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final s = filtered[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _parseColor(s['color']),
                          child: Icon(
                            s['iconUrl'] != null ? Icons.star : Icons.star_border,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(s['name'] ?? ''),
                        subtitle: Text(s['description'] ?? 'Bez opisa'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: 'Uredi',
                            onPressed: () => _showDialog(s),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            tooltip: 'Obriši',
                            onPressed: () => _delete(s['id']),
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

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blue;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }

  void _showDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final desc = TextEditingController(text: existing?['description']?.toString() ?? '');
    final color = TextEditingController(text: _toHexFromAny(existing?['color']));
    final formKey = GlobalKey<FormState>();
    const presetColors = [
      '#2196F3',
      '#4CAF50',
      '#FF9800',
      '#E91E63',
      '#9C27B0',
      '#00BCD4',
      '#607D8B',
      '#795548',
      '#F44336',
      '#8BC34A',
    ];
    String selectedHex = _normalizeHex(color.text);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
        title: Text(isEdit ? 'Uredi vještinu' : 'Nova vještina'),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Naziv *'),
                validator: (v) => v == null || v.isEmpty ? 'Naziv je obavezan' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'Opis'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presetColors.map((hex) {
                  final selected = selectedHex == hex;
                  return InkWell(
                    onTap: () {
                      setS(() {
                        selectedHex = hex;
                        color.value = TextEditingValue(text: hex);
                      });
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _parseColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.black : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: color,
                decoration: const InputDecoration(labelText: 'Boja (HEX)', hintText: '#2196F3'),
                onChanged: (v) => setS(() => selectedHex = _normalizeHex(v)),
                validator: (v) {
                  final n = _normalizeHex(v ?? '');
                  final isValidHex = RegExp(r'^#[0-9A-F]{6}$').hasMatch(n);
                  if (!isValidHex) return 'Format mora biti HEX, npr. #2196F3';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Pregled boje:'),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _parseColor(selectedHex),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(selectedHex, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Odustani')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final Map<String, dynamic> data = {
                'name': name.text.trim(),
                'description': desc.text.trim(),
                'iconUrl': existing?['iconUrl'],
                'color': selectedHex,
              };
              try {
                if (isEdit) {
                  await _api.updateSkill(existing['id'] as int, data);
                } else {
                  await _api.createSkill(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isEdit ? 'Vještina uspješno ažurirana' : 'Vještina uspješno kreirana')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_extractErrorMessage(e))));
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

  String _normalizeHex(String value) {
    var hex = value.trim().toUpperCase();
    if (hex.isEmpty) return '#2196F3';
    if (!hex.startsWith('#')) hex = '#$hex';
    if (hex.length == 4) {
      final r = hex[1];
      final g = hex[2];
      final b = hex[3];
      return '#$r$r$g$g$b$b';
    }
    if (hex.length != 7) return '#2196F3';
    if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(hex)) return '#2196F3';
    return hex;
  }

  String _toHexFromAny(dynamic color) {
    if (color == null) return '#2196F3';
    if (color is int) {
      final rgb = color & 0x00FFFFFF;
      return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
    return _normalizeHex(color.toString());
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content: const Text('Jeste li sigurni da želite obrisati ovu vještinu? Ovo može utjecati na ML preporuke.'),
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
        await _api.deleteSkill(id);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vještina obrisana')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.')));
        }
      }
    }
  }

  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message'] ?? data['title'] ?? data['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    }
    return 'Došlo je do greške. Pokušajte ponovo.';
  }
}
