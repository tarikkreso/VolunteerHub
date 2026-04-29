import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'blog_post_detail_screen.dart';

class BlogTab extends StatefulWidget {
  const BlogTab({super.key});
  @override
  State<BlogTab> createState() => _BlogTabState();
}

class _BlogTabState extends State<BlogTab> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  List<dynamic> _posts = [];
  List<dynamic> _filtered = [];
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
      final res = await _api.getBlogPosts(pageSize: 50);
      final d = res.data;
      _posts = d is Map ? (d['items'] ?? []) : (d is List ? d : []);
      _applyFilter();
    } catch (e) {
      debugPrint('Blog error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_posts)
        : _posts.where((p) {
            final title = (p['title'] ?? '').toString().toLowerCase();
            final content = (p['content'] ?? '').toString().toLowerCase();
            final tags = (p['tags'] ?? '').toString().toLowerCase();
            return title.contains(q) || content.contains(q) || tags.contains(q);
          }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      // Search
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Pretraži blogove...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(() => _applyFilter()); })
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          onChanged: (_) => setState(() => _applyFilter()),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _filtered.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 120),
                  Center(child: Icon(Icons.article_outlined, size: 64, color: Colors.grey[300])),
                  const SizedBox(height: 16),
                  Center(child: Text(_searchCtrl.text.isNotEmpty ? 'Nema rezultata za pretragu' : 'Nema blog objava', style: TextStyle(color: Colors.grey[500], fontSize: 16))),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final p = _filtered[i];
                    final isFirst = i == 0;
                    return isFirst ? _featuredCard(p) : _compactCard(p);
                  },
                ),
        ),
      ),
    ]);
  }

  /// Featured card for the first (latest) blog post — larger image and prominent styling 
  Widget _featuredCard(Map<String, dynamic> p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showPost(p),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.purple.shade300, Colors.deepPurple.shade400]),
            ),
            child: _imageUrl(p) != null
                ? Image.network(_imageUrl(p)!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(child: Icon(Icons.auto_stories, size: 56, color: Colors.white.withValues(alpha: 0.7))))
                : Center(child: Icon(Icons.auto_stories, size: 56, color: Colors.white.withValues(alpha: 0.7))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
                child: const Text('Najnovije', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple)),
              ),
              const SizedBox(height: 8),
              Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(
                _excerpt(p['content'], 200),
                style: TextStyle(color: Colors.grey[600], height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _postMeta(p),
            ]),
          ),
        ]),
      ),
    );
  }

  /// Compact card for non-featured blog posts  
  Widget _compactCard(Map<String, dynamic> p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPost(p),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Thumbnail
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.purple.shade50,
              ),
              clipBehavior: Clip.antiAlias,
              child: _imageUrl(p) != null
                  ? Image.network(_imageUrl(p)!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.article, color: Colors.purple, size: 32)))
                  : const Center(child: Icon(Icons.article, color: Colors.purple, size: 32)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(_excerpt(p['content'], 80), style: TextStyle(color: Colors.grey[500], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text('~${p['readingTime'] ?? 3} min', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  const SizedBox(width: 12),
                  Text(_fmtDate(p['publishedAt'] ?? p['createdAt']), style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ]),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _postMeta(Map<String, dynamic> p) {
    return Row(children: [
      Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Text('~${p['readingTime'] ?? 3} min čitanja', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      const Spacer(),
      if (p['authorName'] != null) ...[
        Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(p['authorName'], style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(width: 12),
      ],
      Text(_fmtDate(p['publishedAt'] ?? p['createdAt']), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
    ]);
  }

  void _showPost(Map<String, dynamic> p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlogPostDetailScreen(post: p),
    ));
  }

  String _excerpt(String? content, [int length = 150]) {
    if (content == null) return '';
    return content.length > length ? '${content.substring(0, length)}...' : content;
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

  String? _imageUrl(Map<String, dynamic> post) {
    final raw = (post['imageUrl'] ?? post['featuredImageUrl'])?.toString();
    if (raw == null || raw.isEmpty) return null;
    return raw.startsWith('http') ? raw : '${_api.baseUrl}$raw';
  }
}
