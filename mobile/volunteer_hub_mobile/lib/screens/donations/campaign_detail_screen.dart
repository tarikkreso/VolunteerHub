import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class CampaignDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? campaign;
  final int? campaignId;
  const CampaignDetailScreen({super.key, this.campaign, this.campaignId})
      : assert(campaign != null || campaignId != null);

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  Map<String, dynamic>? _campaign;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.campaign != null) {
      _campaign = widget.campaign;
    } else {
      _fetchById();
    }
  }

  Future<void> _fetchById() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getCampaign(widget.campaignId!);
      if (mounted) setState(() => _campaign = res.data is Map ? Map<String, dynamic>.from(res.data) : null);
    } catch (e) {
      debugPrint('Campaign fetch error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_campaign?['title'] ?? 'Kampanja')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _campaign == null
              ? const Center(child: Text('Kampanja nije pronađena'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_campaign!['imageUrl'] != null && (_campaign!['imageUrl'] as String).isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          _campaign!['imageUrl'],
                          width: double.infinity, height: 180, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        ),
                      )
                    else
                      _placeholder(),
                    const SizedBox(height: 16),
                    Text(_campaign!['title'] ?? '',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildProgress(),
                    const SizedBox(height: 16),
                    Text('Opis',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_campaign!['description'] ?? 'Nema opisa', style: const TextStyle(height: 1.5)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text('${_fmtDate(_campaign!['startDate'])} — ${_fmtDate(_campaign!['endDate'])}',
                          style: TextStyle(color: Colors.grey[700])),
                    ]),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, 'donate'),
                        icon: const Icon(Icons.favorite),
                        label: const Text('Doniraj'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ]),
                ),
    );
  }

  Widget _buildProgress() {
    final goal = (_campaign!['goalAmount'] ?? 1).toDouble();
    final raised = (_campaign!['currentAmount'] ?? 0).toDouble();
    final pct = goal > 0 ? (raised / goal).clamp(0.0, 1.0) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(value: pct, minHeight: 12, color: Colors.pink),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${raised.toStringAsFixed(2)} KM prikupljeno',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
        Text('Cilj: ${goal.toStringAsFixed(2)} KM',
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ]),
    ]);
  }

  Widget _placeholder() => Container(
        height: 180, width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.pink.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.favorite, size: 80, color: Colors.pink),
      );

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) { return iso; }
  }
}
