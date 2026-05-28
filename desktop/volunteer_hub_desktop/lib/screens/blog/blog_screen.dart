import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
      _posts = res.data is List
          ? res.data
          : (res.data is Map ? (res.data['items'] ?? []) : []);
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
        _pageHeader(
          title: 'Blog objave',
          subtitle: 'Upravljanje objavama, nacrtima i sadrzajem za zajednicu.',
          action: ElevatedButton.icon(
            onPressed: () => _showPostDialog(null),
            icon: const Icon(Icons.add),
            label: const Text('Nova objava'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _miniStat(
              Icons.public,
              'Objavljeno: ${_posts.where((p) => p['isPublished'] == true).length}',
              Colors.green),
          _miniStat(
              Icons.edit_note,
              'Nacrt: ${_posts.where((p) => p['isPublished'] != true).length}',
              Colors.orange),
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
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          if (published && _imageUrl(p) != null)
                            IconButton(
                              icon: const Icon(Icons.image, size: 20),
                              tooltip: 'Pregled slike objave',
                              onPressed: () => _showPostImagePreview(p),
                            ),
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
                            icon: const Icon(Icons.delete,
                                size: 20, color: Colors.red),
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
    bool uploadingImage = false;
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
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Naslov je obavezan' : null,
                  ),
                  const SizedBox(height: 12),
                  _editorToolbar(content),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: content,
                    decoration: const InputDecoration(
                        labelText: 'Sadržaj *', alignLabelWithHint: true),
                    maxLines: 8,
                    maxLength: 8000,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Sadržaj je obavezan';
                      }
                      if (v.trim().length < 50) {
                        return 'Sadržaj mora imati najmanje 50 znakova';
                      }
                      if (v.trim().length > 8000) {
                        return 'Sadržaj može imati najviše 8000 znakova';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: imageUrl,
                        decoration: const InputDecoration(
                            labelText: 'Slika objave',
                            hintText: 'https://... ili /uploads/blog/...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: uploadingImage
                          ? null
                          : () async {
                              final picked =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                allowMultiple: false,
                              );
                              final path = picked?.files.single.path;
                              if (path == null) return;

                              setS(() => uploadingImage = true);
                              try {
                                final res = await _api.uploadBlogImage(path);
                                final data = res.data is Map
                                    ? res.data as Map
                                    : const {};
                                final url = data['imageUrl']?.toString();
                                if (url != null && url.isNotEmpty) {
                                  setS(() => imageUrl.text = url);
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Upload slike objave nije uspio.')),
                                  );
                                }
                              } finally {
                                setS(() => uploadingImage = false);
                              }
                            },
                      icon: uploadingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(uploadingImage ? 'Upload...' : 'Upload'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: tags,
                    decoration: const InputDecoration(
                        labelText: 'Tagovi (razdvojeni zarezom)'),
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
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Odustani')),
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
                        content: Text(isEdit
                            ? 'Objava uspješno ažurirana'
                            : 'Objava uspješno kreirana')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('Došlo je do greške. Pokušajte ponovo.')));
                  }
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_imageUrl(post) != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Image.network(_imageUrl(post)!,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              Text(post['content'] ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.6)),
              const SizedBox(height: 16),
              if (post['tags'] != null && post['tags'] != '')
                Wrap(
                  spacing: 8,
                  children: (post['tags'] as String)
                      .split(',')
                      .map((t) => Chip(label: Text(t.trim())))
                      .toList(),
                ),
              const SizedBox(height: 8),
              Text(
                  'Objavljeno: ${_fmtDate(post['publishedAt'] ?? post['createdAt'])}',
                  style: const TextStyle(color: Colors.grey)),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Zatvori'))
        ],
      ),
    );
  }

  Widget _editorToolbar(TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(children: [
        IconButton(
          tooltip: 'Bold',
          icon: const Icon(Icons.format_bold),
          onPressed: () => _wrapSelection(controller, '**', '**'),
        ),
        IconButton(
          tooltip: 'Italic',
          icon: const Icon(Icons.format_italic),
          onPressed: () => _wrapSelection(controller, '_', '_'),
        ),
        IconButton(
          tooltip: 'Naslov',
          icon: const Icon(Icons.title),
          onPressed: () => _insertPrefix(controller, '## '),
        ),
        IconButton(
          tooltip: 'Lista',
          icon: const Icon(Icons.format_list_bulleted),
          onPressed: () => _insertPrefix(controller, '- '),
        ),
        IconButton(
          tooltip: 'Citat',
          icon: const Icon(Icons.format_quote),
          onPressed: () => _insertPrefix(controller, '> '),
        ),
      ]),
    );
  }

  void _wrapSelection(
      TextEditingController controller, String before, String after) {
    final selection = controller.selection;
    final text = controller.text;
    if (!selection.isValid || selection.isCollapsed) {
      final offset = selection.isValid ? selection.baseOffset : text.length;
      controller.text = text.replaceRange(offset, offset, '$before$after');
      controller.selection =
          TextSelection.collapsed(offset: offset + before.length);
      return;
    }
    final selected = text.substring(selection.start, selection.end);
    controller.text = text.replaceRange(
        selection.start, selection.end, '$before$selected$after');
    controller.selection = TextSelection(
      baseOffset: selection.start + before.length,
      extentOffset: selection.end + before.length,
    );
  }

  void _insertPrefix(TextEditingController controller, String prefix) {
    final selection = controller.selection;
    final text = controller.text;
    final offset = selection.isValid ? selection.baseOffset : text.length;
    final lineStart = text.lastIndexOf('\n', offset - 1) + 1;
    controller.text = text.replaceRange(lineStart, lineStart, prefix);
    controller.selection =
        TextSelection.collapsed(offset: offset + prefix.length);
  }

  void _showPostImagePreview(Map<String, dynamic> post) {
    final url = _imageUrl(post);
    if (url == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(post['title'] ?? 'Pregled slike'),
        content: SizedBox(
          width: 560,
          height: 360,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Center(child: Text('Slika se ne može učitati.')),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Zatvori')),
        ],
      ),
    );
  }

  String? _imageUrl(Map<String, dynamic> post) {
    final raw = (post['imageUrl'] ?? post['featuredImageUrl'])?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    return _api.resolveFileUrl(raw);
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content: const Text('Jeste li sigurni da želite obrisati ovu objavu?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani')),
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
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Objava obrisana')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.')));
        }
      }
    }
  }

  Widget _pageHeader({
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
        action,
      ],
    );
  }

  Widget _miniStat(IconData icon, String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: c, fontWeight: FontWeight.w600, fontSize: 12)),
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
