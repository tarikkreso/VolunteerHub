import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class BlogCategoriesScreen extends StatefulWidget {
  const BlogCategoriesScreen({super.key});

  @override
  State<BlogCategoriesScreen> createState() => _BlogCategoriesScreenState();
}

class _BlogCategoriesScreenState extends State<BlogCategoriesScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  List<dynamic> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getBlogCategories();
      _categories = res.data is List ? res.data : [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e))),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  List<dynamic> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _categories;
    return _categories.where((category) {
      return (category['name'] ?? '').toString().toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Blog kategorije',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Nova kategorija'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Pretrazi blog kategorije...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('Nema blog kategorija'))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final category = _filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    _parseColor(category['color']?.toString()),
                                child: const Icon(Icons.article,
                                    color: Colors.white),
                              ),
                              title: Text(category['name']?.toString() ?? ''),
                              subtitle: Text(
                                category['description']?.toString().isNotEmpty ==
                                        true
                                    ? category['description'].toString()
                                    : 'Bez opisa',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Uredi',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showEditor(category),
                                  ),
                                  IconButton(
                                    tooltip: 'Obrisi',
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _delete(category['id'] as int),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showEditor([Map<String, dynamic>? existing]) {
    final isEdit = existing != null;
    final nameCtrl =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final descriptionCtrl = TextEditingController(
        text: existing?['description']?.toString() ?? '');
    final colorCtrl =
        TextEditingController(text: existing?['color']?.toString() ?? '#2196F3');
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'Uredi kategoriju' : 'Nova kategorija'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Naziv *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Naziv je obavezan'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Opis'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Boja (HEX)',
                    hintText: '#2196F3',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim().toUpperCase();
                    return RegExp(r'^#[0-9A-F]{6}$').hasMatch(text)
                        ? null
                        : 'Format mora biti HEX, npr. #2196F3';
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final payload = {
                'name': nameCtrl.text.trim(),
                'description': descriptionCtrl.text.trim(),
                'color': colorCtrl.text.trim().toUpperCase(),
              };

              try {
                if (isEdit) {
                  await _api.updateBlogCategory(existing['id'] as int, payload);
                } else {
                  await _api.createBlogCategory(payload);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit
                          ? 'Blog kategorija uspjesno azurirana'
                          : 'Blog kategorija uspjesno kreirana'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_errorMessage(e))),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Spremi' : 'Kreiraj'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content: const Text('Jeste li sigurni da zelite obrisati ovu blog kategoriju?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Obrisi'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteBlogCategory(id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blog kategorija obrisana')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e))),
        );
      }
    }
  }

  Color _parseColor(String? value) {
    final text = value?.replaceFirst('#', '0xFF');
    if (text == null) return Colors.blue;
    return Color(int.tryParse(text) ?? 0xFF2196F3);
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    }
    return 'Doslo je do greske. Pokusajte ponovo.';
  }
}
