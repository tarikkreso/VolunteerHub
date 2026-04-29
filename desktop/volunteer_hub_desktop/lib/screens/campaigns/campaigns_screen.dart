import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});
  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final _api = ApiService();
  List<dynamic> _campaigns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCampaigns();
      final items = res.data is List
          ? res.data
          : (res.data is Map ? (res.data['items'] ?? []) : []);
      _campaigns = (items as List)
          .map((e) => <String, dynamic>{
                ...(e as Map),
                'isActive': _toBool(e['isActive'])
              })
          .toList();
    } catch (e) {
      debugPrint('Campaigns error: $e');
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
          title: 'Kampanje',
          subtitle: 'Pregled aktivnih inicijativa, ciljeva i donacija.',
          action: ElevatedButton.icon(
            onPressed: () => _showCampaignDialog(null),
            icon: const Icon(Icons.add),
            label: const Text('Nova kampanja'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _miniStat(
              Icons.campaign,
              'Aktivne: ${_campaigns.where((c) => _toBool(c['isActive'])).length}',
              Colors.green),
          _miniStat(
              Icons.monetization_on,
              'Prikupljeno: ${_totalRaised().toStringAsFixed(0)} KM',
              Colors.amber.shade800),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: _campaigns.isEmpty
              ? const Center(child: Text('Nema kampanja'))
              : ListView.builder(
                  itemCount: _campaigns.length,
                  itemBuilder: (ctx, i) {
                    final c = _campaigns[i];
                    final goal = (c['goalAmount'] ?? 1).toDouble();
                    final raised = (c['currentAmount'] ?? 0).toDouble();
                    final pct =
                        goal > 0 ? (raised / goal).clamp(0.0, 1.0) : 0.0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: Icon(
                          _toBool(c['isActive'])
                              ? Icons.campaign
                              : Icons.campaign_outlined,
                          color: _toBool(c['isActive'])
                              ? Colors.green
                              : Colors.grey,
                        ),
                        title: Text(
                          c['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4)),
                              const SizedBox(height: 4),
                              Text(
                                  '${raised.toStringAsFixed(2)} / ${goal.toStringAsFixed(2)} KM (${(pct * 100).toStringAsFixed(0)}%)'),
                            ]),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showCampaignDialog(c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 20, color: Colors.red),
                            onPressed: () => _delete(c['id']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.monetization_on, size: 20),
                            tooltip: 'Donacije',
                            onPressed: () => _showDonationsDialog(c),
                          ),
                        ]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['description'] ?? 'Nema opisa',
                                    style: const TextStyle(height: 1.45),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Status: ${_toBool(c['isActive']) ? 'Aktivna' : 'Neaktivna'}'),
                                  if (c['startDate'] != null)
                                    Text(
                                        'Početak: ${_fmtDate(c['startDate'])}'),
                                  if (c['endDate'] != null)
                                    Text('Kraj: ${_fmtDate(c['endDate'])}'),
                                ]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  void _showCampaignDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;
    final title = TextEditingController(text: existing?['title'] ?? '');
    final desc = TextEditingController(text: existing?['description'] ?? '');
    final goal =
        TextEditingController(text: '${existing?['goalAmount'] ?? ''}');
    bool isActive = _toBool(existing?['isActive'], fallback: true);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) {
        return AlertDialog(
          title: Text(isEdit ? 'Uredi kampanju' : 'Nova kampanja'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Naziv *'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Naziv je obavezan' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: desc,
                    decoration: const InputDecoration(labelText: 'Opis'),
                    maxLines: 3),
                const SizedBox(height: 12),
                TextFormField(
                  controller: goal,
                  decoration: const InputDecoration(labelText: 'Cilj (KM) *'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty || (double.tryParse(v) ?? 0) <= 0
                          ? 'Unesite pozitivan iznos'
                          : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Aktivna'),
                  value: isActive,
                  onChanged: (v) => setS(() => isActive = v),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Odustani')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final now = DateTime.now().toUtc();
                final defaultEnd =
                    now.add(const Duration(days: 30)).toIso8601String();
                final data = {
                  'title': title.text.trim(),
                  'description': desc.text.trim(),
                  'goalAmount': double.parse(goal.text.trim()),
                  'startDate': _normalizeCampaignDate(
                      existing?['startDate'], now.toIso8601String()),
                  'endDate':
                      _normalizeCampaignDate(existing?['endDate'], defaultEnd),
                  'imageUrl': existing?['imageUrl'],
                  'isActive': isActive,
                };
                try {
                  if (isEdit) {
                    await _api.updateCampaign(
                        (existing['id'] as num).toInt(), data);
                  } else {
                    await _api.createCampaign(data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isEdit
                            ? 'Kampanja uspješno ažurirana'
                            : 'Kampanja uspješno kreirana')));
                  }
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_extractErrorMessage(e))));
                }
              },
              child: Text(isEdit ? 'Spremi' : 'Kreiraj'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content:
            const Text('Jeste li sigurni da želite obrisati ovu kampanju?'),
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
        await _api.deleteCampaign(id);
        _load();
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Kampanja obrisana')));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Došlo je do greške. Pokušajte ponovo.')));
      }
    }
  }

  void _showDonationsDialog(Map<String, dynamic> campaign) async {
    List<dynamic> donations = [];
    bool loadError = false;
    try {
      final res = await _api.getDonations(campaignId: campaign['id']);
      donations = res.data is List
          ? res.data
          : (res.data is Map ? (res.data['items'] ?? []) : []);
    } catch (e) {
      debugPrint('Donations load error: $e');
      loadError = true;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Donacije — ${campaign['title']}'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: loadError
              ? const Center(child: Text('Greška pri učitavanju donacija'))
              : donations.isEmpty
                  ? const Center(child: Text('Nema donacija'))
                  : ListView.builder(
                      itemCount: donations.length,
                      itemBuilder: (c2, i) {
                        final d = donations[i];
                        return ListTile(
                          leading: Icon(d['isAnonymous'] == true
                              ? Icons.person_off
                              : Icons.person),
                          title: Text(d['isAnonymous'] == true
                              ? 'Anonimno'
                              : d['donorName'] ?? 'Anonimni donator'),
                          subtitle: Text(
                              '${(d['amount'] as num?)?.toStringAsFixed(2) ?? '0'} KM • ${_fmtDate(d['createdAt'])}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (d['message'] != null && d['message'] != '')
                                Tooltip(
                                    message: d['message'],
                                    child: const Icon(Icons.chat_bubble_outline,
                                        size: 18)),
                              IconButton(
                                tooltip: 'Refundiraj donaciju',
                                icon: const Icon(Icons.undo, size: 18),
                                onPressed: d['status'] == 'Refunded'
                                    ? null
                                    : () => _refundDonation(ctx, d),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Zatvori'))
        ],
      ),
    );
  }

  Future<void> _refundDonation(
      BuildContext dialogContext, Map<String, dynamic> donation) async {
    final amount = (donation['amount'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refundacija donacije'),
        content: Text('Refundirati donaciju u iznosu od $amount KM?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Odustani')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Refundiraj')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.refundDonation((donation['id'] as num).toInt());
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donacija je refundirana.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractErrorMessage(e))),
        );
      }
    }
  }

  double _totalRaised() => _campaigns.fold(
      0.0, (sum, c) => sum + ((c['currentAmount'] ?? 0) as num).toDouble());

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

  bool _toBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = (value ?? '').toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }

  String _normalizeCampaignDate(dynamic value, String fallbackIso) {
    if (value == null) return fallbackIso;
    final text = value.toString().trim();
    if (text.isEmpty || text.startsWith('0001-01-01')) return fallbackIso;
    return text;
  }

  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message'] ?? data['title'] ?? data['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
      if (statusCode == 401)
        return 'Sesija je istekla. Molimo prijavite se ponovo.';
      if (statusCode == 403) return 'Nemate dozvolu za ovu akciju.';
      if (statusCode != null)
        return 'Greška servera ($statusCode). Pokušajte ponovo.';
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Nije moguće povezati se sa serverom.';
      }
    }
    return 'Došlo je do greške. Pokušajte ponovo.';
  }
}
