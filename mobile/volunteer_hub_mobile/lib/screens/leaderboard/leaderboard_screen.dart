import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _api = ApiService();
  List<dynamic> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getLeaderboard(top: 50);
      if (mounted) setState(() => _entries = res.data is List ? res.data : []);
    } catch (e) {
      debugPrint('Leaderboard error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rang lista')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _entries.isEmpty
                  ? const Center(child: Text('Nema podataka'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _entries.length,
                      itemBuilder: (ctx, i) {
                        final e = _entries[i];
                        final rank = i + 1;
                        Color? rankColor;
                        IconData? medal;
                        if (rank == 1) { rankColor = Colors.amber; medal = Icons.emoji_events; }
                        else if (rank == 2) { rankColor = Colors.grey.shade400; medal = Icons.emoji_events; }
                        else if (rank == 3) { rankColor = Colors.brown.shade300; medal = Icons.emoji_events; }

                        return ListTile(
                          leading: medal != null
                              ? Icon(medal, color: rankColor, size: 32)
                              : CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey.shade200,
                                  child: Text('$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                          title: Text(e['userName'] ?? '', style: TextStyle(fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text('${e['totalEvents'] ?? 0} događaja'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${(e['totalHours'] ?? 0).toStringAsFixed(1)} h',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: rankColor ?? Colors.grey[700])),
                              Text('sati', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
