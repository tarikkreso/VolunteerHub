import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../blog/blog_post_detail_screen.dart';
import '../blog/blog_tab.dart';
import '../donations/donations_tab.dart';
import '../events/event_detail_screen.dart';
import '../events/events_tab.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_tab.dart';
import '../shifts/shifts_tab.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  final int? initialCampaignId;

  const HomeScreen({super.key, this.initialTab = 0, this.initialCampaignId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  final _shiftsRefreshTrigger = ValueNotifier<int>(0);
  int? _focusedCampaignId;
  int _donationsFocusVersion = 0;
  Timer? _notificationTimer;
  int _unreadNotifications = 0;

  final _titles = ['Početna', 'Događaji', 'Smjene', 'Donacije', 'Profil'];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _focusedCampaignId = widget.initialCampaignId;
    if (_focusedCampaignId != null) _donationsFocusVersion = 1;
    _loadUnreadNotifications();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _loadUnreadNotifications(),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _shiftsRefreshTrigger.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final res = await ApiService().getNotifications();
      final items = res.data is List ? res.data as List : const [];
      final unread = items.where((n) => n is Map && n['isRead'] != true).length;
      if (mounted) setState(() => _unreadNotifications = unread);
    } catch (_) {
      // Polling failure should not interrupt the main mobile workflow.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          if (_currentIndex == 0)
            TextButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Blog')),
                    body: const BlogTab()))),
              icon: const Icon(Icons.article_outlined),
              label: const Text('Blog'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => _showNotifications(),
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _unreadNotifications > 9
                          ? '9+'
                          : _unreadNotifications.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(
            onNav: (i) => setState(() => _currentIndex = i),
            onOpenCampaign: (campaignId) => setState(() {
              _focusedCampaignId = campaignId;
              _donationsFocusVersion++;
              _currentIndex = 3;
            }),
            onOpenBlog: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Blog')),
                  body: const BlogTab()))),
          ),
          EventsTab(onNavigateToShifts: () { setState(() => _currentIndex = 2); _shiftsRefreshTrigger.value++; }),
          ShiftsTab(refreshTrigger: _shiftsRefreshTrigger),
          DonationsTab(
            focusCampaignId: _focusedCampaignId,
            focusVersion: _donationsFocusVersion,
          ),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          if (i == 2) _shiftsRefreshTrigger.value++;
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Početna'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Događaji'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Smjene'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Donacije'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  void _showNotifications() async {
    final api = ApiService();
    List<dynamic> notifs = [];
    try {
      final res = await api.getNotifications();
      notifs = res.data is List ? res.data : [];
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Obavijesti nije moguce ucitati.')),
        );
      }
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx2, scrollCtrl) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('Obavijesti', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (notifs.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        try {
                          await api.put('/notifications/read-all');
                          await _loadUnreadNotifications();
                        } catch (_) {}
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Označi sve'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: notifs.isEmpty
                  ? const Center(child: Text('Nema obavijesti'))
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notifs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (_, i) {
                        final n = notifs[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: n['isRead'] == true
                                ? Colors.grey.shade200
                                : Theme.of(context).primaryColor.withValues(alpha: 0.15),
                            child: Icon(
                              n['isRead'] == true ? Icons.mark_email_read : Icons.mark_email_unread,
                              color: n['isRead'] == true ? Colors.grey : Theme.of(context).primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            n['title'] ?? '',
                            style: TextStyle(
                              fontWeight: n['isRead'] == true ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            n['message'] ?? '',
                            style: const TextStyle(fontSize: 13, height: 1.3),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          onTap: () async {
                            if (n['isRead'] != true) {
                              try {
                                await api.markNotificationRead(n['id']);
                                await _loadUnreadNotifications();
                              } catch (_) {}
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final void Function(int) onNav;
  final void Function(int campaignId) onOpenCampaign;
  final VoidCallback onOpenBlog;
  const _HomeTab({
    required this.onNav,
    required this.onOpenCampaign,
    required this.onOpenBlog,
  });
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _api = ApiService();
  List<dynamic> _events = [];
  List<dynamic> _recommended = [];
  List<dynamic> _campaigns = [];
  List<dynamic> _blogPosts = [];
  List<dynamic> _leaderboard = [];
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
      final futures = await Future.wait([
        _api.getEvents(pageSize: 5),
        _api.getCampaigns(pageSize: 5),
        _api.getBlogPosts(pageSize: 3),
        _api.getLeaderboard(top: 5),
        _api.getMyStats(),
        _api.getRecommendedEvents(),
      ]);
      final evData = futures[0].data;
      _events = evData is Map ? (evData['items'] ?? []) : (evData is List ? evData : []);
      final cData = futures[1].data;
      _campaigns = cData is Map ? (cData['items'] ?? []) : (cData is List ? cData : []);
      final bData = futures[2].data;
      _blogPosts = bData is Map ? (bData['items'] ?? []) : (bData is List ? bData : []);
      _leaderboard = futures[3].data is List ? futures[3].data : [];
      _userStats = futures[4].data is Map ? futures[4].data as Map<String, dynamic> : null;
      _recommended = futures[5].data is List ? futures[5].data : [];
    } catch (e) {
      debugPrint('Home load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Welcome
          Consumer<AuthProvider>(
            builder: (ctx, auth, _) => Text(
              'Dobrodošli, ${auth.user?['firstName'] ?? 'Volonter'}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Text('Pronađite svoj sljedeći volonterski događaj', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 20),

          // Quick actions
          Row(children: [
            _quickAction(Icons.event, 'Događaji', Colors.blue, () => widget.onNav(1)),
            const SizedBox(width: 8),
            _quickAction(Icons.map, 'Mapa', Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen()))),
            const SizedBox(width: 8),
            _quickAction(Icons.schedule, 'Smjene', Colors.green, () => widget.onNav(2)),
            const SizedBox(width: 8),
            _quickAction(Icons.favorite, 'Donacije', Colors.pink, () => widget.onNav(3)),
            const SizedBox(width: 8),
            _quickAction(Icons.article, 'Blog', Colors.purple, widget.onOpenBlog),
          ]),
          const SizedBox(height: 24),

          if (_loading) const Center(child: CircularProgressIndicator()) else ...[
            // User stats
            if (_userStats != null) ...[
              Row(children: [
                _statCard('Sati', '${(_userStats!['totalHours'] ?? 0).toStringAsFixed(1)}', Icons.access_time, Colors.purple),
                const SizedBox(width: 8),
                _statCard('Događaji', '${_userStats!['totalEvents'] ?? 0}', Icons.event_available, Colors.blue),
                const SizedBox(width: 8),
                _statCard('Smjene', '${_userStats!['upcomingShifts'] ?? 0}', Icons.calendar_today, Colors.green),
                const SizedBox(width: 8),
                _statCard('Rang', '#${_userStats!['rank'] ?? '-'}', Icons.leaderboard, Colors.amber),
              ]),
              const SizedBox(height: 24),
            ],

            // AI Recommended events (For You)
            if (_recommended.isNotEmpty) ...[
              _sectionHeader('Za tebe', () => widget.onNav(1)),
              const SizedBox(height: 4),
              Text('Na osnovu tvojih vještina', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recommended.length,
                  itemBuilder: (ctx, i) => _recommendedCard(_recommended[i]),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Featured events
            _sectionHeader('Istaknuti događaji', () => widget.onNav(1)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: _events.isEmpty
                  ? const Center(child: Text('Nema događaja'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _events.length,
                      itemBuilder: (ctx, i) => _eventCard(_events[i]),
                    ),
            ),
            const SizedBox(height: 24),

            // Campaigns carousel
            _sectionHeader('Podrži inicijativu', () => widget.onNav(3)),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: _campaigns.isEmpty
                  ? const Center(child: Text('Nema kampanja'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _campaigns.length,
                      itemBuilder: (ctx, i) => _campaignCard(_campaigns[i]),
                    ),
            ),
            const SizedBox(height: 24),

            // Blog preview - prominent section
            _sectionHeader('Najnovije objave', widget.onOpenBlog),
            const SizedBox(height: 12),
            if (_blogPosts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.article_outlined, size: 40, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('Nema blog objava', style: TextStyle(color: Colors.grey[500])),
                    ]),
                  ),
                ),
              )
            else
              ..._blogPosts.take(2).map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: _blogThumb(p is Map<String, dynamic>
                          ? p
                          : Map<String, dynamic>.from(p as Map)),
                      title: Text(p['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('~${p['readingTime'] ?? 3} min čitanja', style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => BlogPostDetailScreen(post: p is Map<String, dynamic> ? p : Map<String, dynamic>.from(p as Map)),
                      )),
                    ),
                  )),
            const SizedBox(height: 24),

            // Mini leaderboard
            if (_leaderboard.isNotEmpty) ...[
              _sectionHeader('Top volonteri', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()))),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: List.generate(_leaderboard.length, (i) {
                    final e = _leaderboard[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: i < 3 ? [Colors.amber, Colors.grey.shade400, Colors.brown.shade300][i] : Colors.grey.shade200,
                        child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(e['userName'] ?? ''),
                      trailing: Text('${(e['totalHours'] ?? 0).toStringAsFixed(1)} h',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      dense: true,
                    );
                  }),
                ),
              ),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, VoidCallback? onViewAll) {
    return Row(children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const Spacer(),
      if (onViewAll != null) TextButton(onPressed: onViewAll, child: const Text('Vidi sve')),
    ]);
  }

  Widget _eventCard(dynamic e) {
    final imageUrl = e['imageUrl'] as String?;
    final eventMap = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: eventMap))),
      child: Container(
      width: 240,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 80,
            width: double.infinity,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl.startsWith('http') ? imageUrl : '${ApiService().baseUrl}$imageUrl',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => Center(child: Icon(Icons.event, size: 36, color: Theme.of(context).primaryColor)),
                  )
                : Center(child: Icon(Icons.event, size: 36, color: Theme.of(context).primaryColor)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(child: Text(e['location'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              if (e['categoryName'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(e['categoryName'], style: TextStyle(fontSize: 10, color: Theme.of(context).primaryColor)),
                ),
            ]),
          ),
        ]),
      ),
    ),
    );
  }

  Widget _campaignCard(dynamic c) {
    final goal = (c['goalAmount'] ?? 1).toDouble();
    final raised = (c['currentAmount'] ?? c['raisedAmount'] ?? 0).toDouble();
    final pct = goal > 0 ? (raised / goal).clamp(0.0, 1.0) : 0.0;
    final campaignMap = c is Map<String, dynamic> ? c : Map<String, dynamic>.from(c as Map);
    final imageUrl = _imageUrl(campaignMap);
    return GestureDetector(
      onTap: () {
        final id = campaignMap['id'];
        if (id is num) widget.onOpenCampaign(id.toInt());
      },
      child: Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 42,
                  height: 42,
                  color: Colors.pink.withValues(alpha: 0.1),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.favorite, color: Colors.pink),
                        )
                      : const Icon(Icons.favorite, color: Colors.pink),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(c['title'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: pct, minHeight: 6),
            ),
            const SizedBox(height: 4),
            Text('${(pct * 100).toStringAsFixed(0)}% od ${goal.toStringAsFixed(0)} KM',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ]),
        ),
      ),
    ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ]),
        ),
      ),
    );
  }

  Widget _recommendedCard(dynamic r) {
    final event = r['event'] ?? r;
    final reason = r['reasonTags'] ?? '';
    final score = r['score'] ?? 0;
    final eventMap = event is Map<String, dynamic>
        ? event
        : Map<String, dynamic>.from(event as Map);
    final imageUrl = _imageUrl(eventMap);
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => EventDetailScreen(
            event: eventMap,
          ),
        ));
      },
      child: Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 70,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withValues(alpha: 0.6)],
              ),
            ),
            child: Stack(children: [
              if (imageUrl != null)
                Positioned.fill(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (imageUrl != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              Positioned(right: 8, top: 8, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
                child: Text('${(score * 100).toStringAsFixed(0)}% podudaranje',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              )),
              Positioned(left: 12, bottom: 8, child: Text(event['title'] ?? '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(child: Text(event['location'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              if (event['categoryName'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(event['categoryName'], style: TextStyle(fontSize: 10, color: Theme.of(context).primaryColor)),
                ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.auto_awesome, size: 12, color: Colors.amber[700]),
                  const SizedBox(width: 4),
                  Expanded(child: Text(reason, style: TextStyle(fontSize: 11, color: Colors.amber[800], fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    ),
    );
  }

  Widget _blogThumb(Map<String, dynamic> post) {
    final imageUrl = _imageUrl(post);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        color: Colors.purple.withValues(alpha: 0.1),
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.article, color: Colors.purple),
              )
            : const Icon(Icons.article, color: Colors.purple),
      ),
    );
  }

  String? _imageUrl(Map<String, dynamic> item) {
    final raw = (item['imageUrl'] ??
            item['featuredImageUrl'] ??
            item['eventImageUrl'] ??
            item['campaignImageUrl'])
        ?.toString();
    if (raw == null || raw.isEmpty) return null;
    return raw.startsWith('http') ? raw : '${ApiService().baseUrl}$raw';
  }
}

