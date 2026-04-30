import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

import '../../services/api_service.dart';

class DonationsTab extends StatefulWidget {
  final int? focusCampaignId;
  final int focusVersion;

  const DonationsTab({super.key, this.focusCampaignId, this.focusVersion = 0});

  @override
  State<DonationsTab> createState() => _DonationsTabState();
}

class _DonationsTabState extends State<DonationsTab> {
  final _api = ApiService();
  final _scrollController = ScrollController();
  List<dynamic> _campaigns = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _totalCount = 0;
  int _totalDonations = 0;
  static const _pageSize = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DonationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusVersion != oldWidget.focusVersion ||
        widget.focusCampaignId != oldWidget.focusCampaignId) {
      _focusCampaign();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      _page = 1;
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await _api.getCampaigns(page: _page, pageSize: _pageSize);
      final data = res.data;
      final items =
          data is Map ? (data['items'] ?? []) : (data is List ? data : []);
      _totalCount = data is Map
          ? ((data['totalCount'] as num?)?.toInt() ?? items.length)
          : items.length;
      _campaigns = reset ? List.from(items) : [..._campaigns, ...items];
      _totalDonations = 0;
      for (final campaign in _campaigns) {
        _totalDonations += (campaign['donationCount'] as num?)?.toInt() ?? 0;
      }
      if (reset) _focusCampaign();
    } catch (e) {
      debugPrint('Campaigns error: $e');
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _campaigns.length >= _totalCount) return;
    _page += 1;
    await _load(reset: false);
  }

  void _focusCampaign() {
    final id = widget.focusCampaignId;
    if (id == null) return;
    final index = _campaigns.indexWhere((c) => c['id'] == id);
    if (index < 0) {
      if (!_loadingMore && (_totalCount == 0 || _campaigns.length < _totalCount)) {
        _loadMore().then((_) => _focusCampaign());
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = 116.0 + index * 330.0;
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: _campaigns.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 200),
                Center(
                    child: Icon(Icons.campaign_outlined,
                        size: 64, color: Colors.grey)),
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nema aktivnih kampanja'),
                  ),
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _campaigns.length + 2,
              itemBuilder: (ctx, i) {
                if (i == 0) return _buildSummaryHeader();
                if (i == _campaigns.length + 1) return _buildPagingFooter();
                return _campaignCard(_campaigns[i - 1]);
              },
            ),
    );
  }

  Widget _buildPagingFooter() {
    if (_campaigns.length >= _totalCount) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Center(
          child: Text('Prikazane su sve kampanje',
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: OutlinedButton.icon(
        onPressed: _loadingMore ? null : _loadMore,
        icon: _loadingMore
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more),
        label: Text(_loadingMore ? 'Učitavanje...' : 'Učitaj još'),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final activeCampaigns =
        _campaigns.where((c) => c['isActive'] == true).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem(Icons.campaign, '$activeCampaigns', 'Aktivne'),
          _summaryItem(
              Icons.volunteer_activism, '$_totalDonations', 'Donacije'),
          _summaryItem(Icons.category, '${_campaigns.length}', 'Ukupno'),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _campaignCard(Map<String, dynamic> c) {
    final goal = (c['goalAmount'] ?? 1).toDouble();
    final raised = (c['currentAmount'] ?? c['raisedAmount'] ?? 0).toDouble();
    final pct = goal > 0 ? (raised / goal).clamp(0.0, 1.0) : 0.0;
    final donationCount = c['donationCount'] ?? 0;
    final imageUrl = _imageUrl(c);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 58,
                    height: 58,
                    color: Colors.pink.withValues(alpha: 0.08),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.favorite,
                                color: Colors.pink,
                                size: 28),
                          )
                        : const Icon(Icons.favorite,
                            color: Colors.pink, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['title'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      if (donationCount > 0)
                        Text(
                          '$donationCount donacija',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
                if (c['isFeatured'] == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Featured',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (c['description'] != null)
              Text(
                c['description'],
                style: TextStyle(color: Colors.grey[600], height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                color:
                    pct >= 1.0 ? Colors.green : Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${raised.toStringAsFixed(2)} KM',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  ' / ${goal.toStringAsFixed(2)} KM',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: pct >= 1.0
                        ? Colors.green
                        : Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed:
                    c['isActive'] == true ? () => _showDonateDialog(c) : null,
                icon: const Icon(Icons.volunteer_activism),
                label: Text(
                    c['isActive'] == true ? 'Doniraj' : 'Kampanja zatvorena'),
              ),
            ),
            const SizedBox(height: 8),
            if (donationCount > 0)
              TextButton.icon(
                onPressed: () => _showRecentDonors(c['id'], c['title'] ?? ''),
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('Pogledaj nedavne donatore'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
          ],
        ),
      ),
    );
  }

  String? _imageUrl(Map<String, dynamic> item) {
    final raw = item['imageUrl']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return raw.startsWith('http') ? raw : '${_api.baseUrl}$raw';
  }

  Future<void> _showRecentDonors(int campaignId, String campaignTitle) async {
    List<dynamic> donors = [];
    try {
      final res = await _api.getDonationsByCampaign(campaignId);
      final data = res.data;
      if (data is Map && data['items'] != null) {
        donors = data['items'] as List;
      } else if (data is List) {
        donors = data;
      }
    } catch (e) {
      debugPrint('Recent donors error: $e');
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Donatori: $campaignTitle',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          if (donors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Nema donacija za ovu kampanju'),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.4),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: donors.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final d = donors[i];
                  final isAnon = d['isAnonymous'] == true;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      child: Icon(isAnon ? Icons.person_off : Icons.person,
                          color: Colors.green, size: 20),
                    ),
                    title: Text(
                      isAnon ? 'Anonimni donor' : (d['donorName'] ?? 'Donor'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: d['message'] != null &&
                            d['message'].toString().isNotEmpty
                        ? Text(
                            d['message'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                    trailing: Text(
                      '${(d['amount'] ?? 0).toStringAsFixed(2)} KM',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _showDonateDialog(Map<String, dynamic> campaign) async {
    final didDonate = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DonationCheckoutSheet(
        api: _api,
        campaign: campaign,
      ),
    );

    if (didDonate == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donacija je uspješno obrađena. Hvala na podršci!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class DonationCheckoutSheet extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> campaign;

  const DonationCheckoutSheet({
    super.key,
    required this.api,
    required this.campaign,
  });

  @override
  State<DonationCheckoutSheet> createState() => _DonationCheckoutSheetState();
}

class _DonationCheckoutSheetState extends State<DonationCheckoutSheet> {
  static const List<double> _presetAmounts = [5, 10, 25, 50, 100];

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();

  bool _anonymous = false;
  bool _processing = false;
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _normalizeAmount(String value) => value.trim().replaceAll(',', '.');

  String _newIdempotencyKey(double amount) {
    final campaignId = widget.campaign['id'];
    final cents = (amount * 100).round();
    return '$campaignId-$cents-${DateTime.now().microsecondsSinceEpoch}';
  }

  double? _parseAmount(String value) {
    final normalized = _normalizeAmount(value);
    return double.tryParse(normalized);
  }

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseAmount(_amountController.text);
    if (amount == null) {
      setState(() => _errorText = 'Unesite ispravan iznos donacije.');
      return;
    }

    final donorName = _anonymous
        ? null
        : _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim();
    final message = _messageController.text.trim();

    setState(() {
      _processing = true;
      _errorText = null;
    });

    try {
      final response = await widget.api.createPaymentIntent({
        'amount': amount,
        'campaignId': widget.campaign['id'],
        'isAnonymous': _anonymous,
        'donorName': donorName,
        'message': message.isEmpty ? null : message,
        'idempotencyKey': _newIdempotencyKey(amount),
      });
      final data = response.data;
      final clientSecret =
          data is Map ? data['clientSecret']?.toString() : null;
      final paymentIntentId =
          data is Map ? data['paymentIntentId']?.toString() : null;
      final publishableKey =
          data is Map ? data['publishableKey']?.toString() ?? '' : '';
      final demoMode = data is Map && data['demoMode'] == true;

      if (!demoMode) {
        if (publishableKey.isEmpty) {
          throw StateError(
              'Stripe publishable key nije konfigurisan na serveru.');
        }
        if (clientSecret == null || clientSecret.isEmpty) {
          throw StateError('Stripe client secret nije vraćen sa servera.');
        }

        Stripe.publishableKey = publishableKey;
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'VolunteerHub',
          ),
        );
        await Stripe.instance.presentPaymentSheet();
      }

      if (paymentIntentId != null && paymentIntentId.isNotEmpty) {
        await _waitForServerDonation(paymentIntentId);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Plaćanje je otkazano: ${e.error.localizedMessage ?? 'Greška'}'),
          backgroundColor: Colors.orange,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _errorText =
            e.response?.data is Map && e.response?.data['message'] != null
                ? e.response!.data['message'].toString()
                : 'Greška pri obradi donacije. Pokušajte ponovo.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _errorText = e is StateError
            ? e.message
            : 'Greška pri donaciji. Pokušajte ponovo.';
      });
    }
  }

  Future<void> _waitForServerDonation(String paymentIntentId) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        await Future<void>.delayed(const Duration(seconds: 2));
        await widget.api.getDonationByPaymentIntent(paymentIntentId);
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) {
          rethrow;
        }
      }
    }

    throw StateError(
      'Plaćanje je završeno, ali server još nije evidentirao donaciju. Provjerite Stripe webhook i pokušajte osvježiti kampanju.',
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon,
      {String? helperText}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campaignTitle = widget.campaign['title'] ?? 'kampanju';

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Doniraj za "$campaignTitle"',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Stripe Checkout će se otvoriti nakon potvrde iznosa.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetAmounts
                    .map(
                      (amount) => ActionChip(
                        label: Text('${amount.toInt()} KM'),
                        onPressed: _processing
                            ? null
                            : () => setState(() => _amountController.text =
                                amount.toStringAsFixed(0)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: _fieldDecoration(
                  'Iznos (KM) *',
                  Icons.monetization_on,
                  helperText: 'Dozvoljen je decimalni unos, npr. 10 ili 10.50',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
                ],
                enabled: !_processing,
                validator: (value) {
                  final raw = value?.trim() ?? '';
                  if (raw.isEmpty) {
                    return 'Unesite iznos donacije.';
                  }
                  final parsed = _parseAmount(raw);
                  if (parsed == null) {
                    return 'Unesite validan broj, npr. 10 ili 10.50.';
                  }
                  if (parsed <= 0) {
                    return 'Iznos mora biti veći od nule.';
                  }
                  if (parsed < 0.5) {
                    return 'Minimalan iznos donacije je 0.50 KM.';
                  }
                  if (parsed > 1000000) {
                    return 'Maksimalan iznos je 1.000.000 KM.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Anonimna donacija'),
                subtitle: const Text(
                  'Vaše ime neće biti prikazano u listi donatora.',
                  style: TextStyle(fontSize: 12),
                ),
                value: _anonymous,
                onChanged: _processing
                    ? null
                    : (value) => setState(() => _anonymous = value),
                contentPadding: EdgeInsets.zero,
              ),
              if (!_anonymous) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: _fieldDecoration(
                    'Vaše ime (opcionalno)',
                    Icons.person,
                    helperText: 'Ako ga unesete, prikazat će se uz donaciju.',
                  ),
                  enabled: !_processing,
                  maxLength: 200,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    if (text.length > 200) {
                      return 'Ime može imati najviše 200 znakova.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _messageController,
                decoration: _fieldDecoration(
                  'Poruka (opcionalno)',
                  Icons.message,
                  helperText: 'Poruka za organizaciju, najviše 500 znakova.',
                ),
                enabled: !_processing,
                maxLength: 500,
                maxLines: 3,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  if (text.length > 500) {
                    return 'Poruka može imati najviše 500 znakova.';
                  }
                  return null;
                },
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 4),
                Text(
                  _errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _processing ? null : _submitDonation,
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.volunteer_activism),
                  label: Text(
                    _processing ? 'Obrađuje se...' : 'Potvrdi donaciju',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
