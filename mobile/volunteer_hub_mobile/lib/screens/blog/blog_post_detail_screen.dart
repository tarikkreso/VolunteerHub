import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class BlogPostDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? post;
  final int? postId;
  const BlogPostDetailScreen({super.key, this.post, this.postId})
      : assert(post != null || postId != null);

  @override
  State<BlogPostDetailScreen> createState() => _BlogPostDetailScreenState();
}

class _BlogPostDetailScreenState extends State<BlogPostDetailScreen> {
  Map<String, dynamic>? _post;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.post != null) {
      _post = widget.post;
    } else {
      _fetchById();
    }
  }

  Future<void> _fetchById() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getBlogPost(widget.postId!);
      if (mounted) setState(() => _post = res.data is Map ? Map<String, dynamic>.from(res.data) : null);
    } catch (e) {
      debugPrint('BlogPost fetch error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_post?['title'] ?? 'Blog')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? const Center(child: Text('Objava nije pronađena'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _imageUrl!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _post!['title'] ?? '',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text('~${_post!['readingTime'] ?? 3} min čitanja',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      const SizedBox(width: 16),
                      Text(_fmtDate(_post!['publishedAt'] ?? _post!['createdAt']),
                          style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ]),
                    if (_post!['authorName'] != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(_post!['authorName'],
                            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      ]),
                    ],
                    if (_post!['tags'] != null && (_post!['tags'] as String).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: (_post!['tags'] as String)
                            .split(',')
                            .map((t) => Chip(
                                  label: Text(t.trim(), style: const TextStyle(fontSize: 12)),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ))
                            .toList(),
                      ),
                    ],
                    const Divider(height: 32),
                    SelectableText(
                      _post!['content'] ?? '',
                      style: const TextStyle(fontSize: 16, height: 1.7),
                    ),
                  ]),
                ),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return iso;
    }
  }

  String? get _imageUrl {
    final raw = (_post?['imageUrl'] ?? _post?['featuredImageUrl'])?.toString();
    if (raw == null || raw.isEmpty) return null;
    return raw.startsWith('http') ? raw : '${ApiService().baseUrl}$raw';
  }
}
