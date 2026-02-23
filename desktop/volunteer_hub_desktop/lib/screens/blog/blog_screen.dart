import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});
  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  final _api = ApiService();
  List<dynamic> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getBlogPostsAll();
      _posts = res.data is List ? res.data : (res.data is Map ? (res.data['items'] ?? []) : []);
    } catch (e) {
      debugPrint('Blog error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Blog objave', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          _miniStat(Icons.public, 'Objavljeno: ${_posts.where((p) => p['isPublished'] == true).length}', Colors.green),
          const SizedBox(width: 12),
          _miniStat(Icons.edit_note, 'Nacrt: ${_posts.where((p) => p['isPublished'] != true).length}', Colors.orange),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showPostDialog(null),
            icon: const Icon(Icons.add),
            label: const Text('Nova objava'),
          ),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: _posts.isEmpty
              ? const Center(child: Text('Nema blog objava'))
              : ListView.builder(
                  itemCount: _posts.length,
                  itemBuilder: (ctx, i) {
                    final p = _posts[i];
                    final published = p['isPublished'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          published ? Icons.public : Icons.edit_note,
                          color: published ? Colors.green : Colors.orange,
                        ),
                        title: Text(p['title'] ?? ''),
                        subtitle: Text(
                          '${published ? 'Objavljeno' : 'Nacrt'} • ${_fmtDate(p['publishedAt'] ?? p['createdAt'])} • ~${p['readingTime'] ?? '?'} min čitanja',
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 20),
                            tooltip: 'Pregled',
                            onPressed: () => _showPreview(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: 'Uredi',
                            onPressed: () => _showPostDialog(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            tooltip: 'Obriši',
                            onPressed: () => _delete(p['id']),
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

  void _showPostDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;
    final title = TextEditingController(text: existing?['title'] ?? '');
    final content = TextEditingController(text: existing?['content'] ?? '');
    final imageUrl = TextEditingController(text: existing?['imageUrl'] ?? '');
    final tags = TextEditingController(text: existing?['tags'] ?? '');
    bool isPublished = existing?['isPublished'] ?? false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) {
        return AlertDialog(
          title: Text(isEdit ? 'Uredi objavu' : 'Nova blog objava'),
          content: SizedBox(
            width: 600,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Naslov *'),
                    validator: (v) => v == null || v.isEmpty ? 'Naslov je obavezan' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: content,
                    decoration: const InputDecoration(labelText: 'Sadržaj *', alignLabelWithHint: true),
                    maxLines: 8,
                    maxLength: 8000,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Sadržaj je obavezan';
                      if (v.trim().length < 50) return 'Sadržaj mora imati najmanje 50 znakova';
                      if (v.trim().length > 8000) return 'Sadržaj može imati najviše 8000 znakova';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: imageUrl,
                    decoration: const InputDecoration(labelText: 'URL slike (opcionalno)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: tags,
                    decoration: const InputDecoration(labelText: 'Tagovi (razdvojeni zarezom)'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Objavljeno'),
                    value: isPublished,
                    onChanged: (v) => setS(() => isPublished = v),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Odustani')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final data = {
                  'title': title.text.trim(),
                  'content': content.text.trim(),
                  'imageUrl': imageUrl.text.trim(),
                  'tags': tags.text.trim(),
                  'isPublished': isPublished,
                };
                try {
                  if (isEdit) {
                    await _api.updateBlogPost(existing['id'], data);
                  } else {
                    await _api.createBlogPost(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isEdit ? 'Objava uspješno ažurirana' : 'Objava uspješno kreirana')));
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

  void _showPreview(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(post['title'] ?? ''),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (post['imageUrl'] != null && post['imageUrl'] != '')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Image.network(post['imageUrl'], height: 200, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              Text(post['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.6)),
              const SizedBox(height: 16),
              if (post['tags'] != null && post['tags'] != '')
                Wrap(
                  spacing: 8,
                  children: (post['tags'] as String).split(',').map((t) => Chip(label: Text(t.trim()))).toList(),
                ),
              const SizedBox(height: 8),
              Text('Objavljeno: ${_fmtDate(post['publishedAt'] ?? post['createdAt'])}',
                  style: const TextStyle(color: Colors.grey)),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zatvori'))],
      ),
    );
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content: const Text('Jeste li sigurni da želite obrisati ovu objavu?'),
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
        await _api.deleteBlogPost(id);
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Objava obrisana')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.')));
      }
    }
  }

  Widget _miniStat(IconData icon, String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
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
}
