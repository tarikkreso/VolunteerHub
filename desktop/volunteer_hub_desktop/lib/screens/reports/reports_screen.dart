import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = ApiService();

  Map<String, dynamic> _stats = {};
  List<dynamic> _leaderboard = [];
  List<Map<String, dynamic>> _reportRows = [];

  bool _loading = true;
  DateTimeRange? _dateRange;
  String _selectedReport = 'Overview';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        _api.getDashboardStats(
          startDate: _dateRange?.start,
          endDate: _dateRange?.end,
        ),
        _api.getLeaderboard(top: 500),
      ]);

      _stats = res[0].data is Map ? res[0].data as Map<String, dynamic> : {};
      _leaderboard = res[1].data is List ? res[1].data : [];
      await _loadReportRows();
    } catch (e) {
      debugPrint('Reports load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadReportRows() async {
    if (_selectedReport == 'Overview') {
      _reportRows = _leaderboard.take(100).map((e) {
        return {
          'Volonter': e['userName'] ?? '',
          'Sati': _num(e['totalHours']).toStringAsFixed(1),
          'Dogadjaji': '${e['totalEvents'] ?? 0}',
          'Rang': '${e['rank'] ?? 0}',
        };
      }).toList();
      return;
    }

    try {
      final ResponseSelector call = switch (_selectedReport) {
        'VolunteerParticipation' => _api.getVolunteerParticipationReport,
        'HoursByVolunteer' => _api.getHoursByVolunteerReport,
        'EventAttendance' => _api.getEventAttendanceReport,
        'DonationsSummary' => _api.getDonationsSummaryReport,
        _ => _api.getVolunteerParticipationReport,
      };

      final res = await call(
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );
      final list = res.data is List ? res.data as List : <dynamic>[];
      _reportRows = list
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('Report rows load error: $e');
      _reportRows = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Izvjestaji',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range),
                label: Text(_rangeLabel),
              ),
              const SizedBox(width: 8),
              if (_dateRange != null)
                TextButton.icon(
                  onPressed: () async {
                    setState(() => _dateRange = null);
                    await _load();
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Ocisti period'),
                ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedReport,
                items: const [
                  DropdownMenuItem(value: 'Overview', child: Text('Pregled')),
                  DropdownMenuItem(
                    value: 'VolunteerParticipation',
                    child: Text('Ucesce volontera'),
                  ),
                  DropdownMenuItem(
                    value: 'HoursByVolunteer',
                    child: Text('Sati po volonteru'),
                  ),
                  DropdownMenuItem(
                    value: 'EventAttendance',
                    child: Text('Posjecenost dogadjaja'),
                  ),
                  DropdownMenuItem(
                    value: 'DonationsSummary',
                    child: Text('Donacije po kampanji'),
                  ),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _selectedReport = v);
                  await _load();
                },
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildMetrics(),
          const SizedBox(height: 20),
          _buildCharts(),
          const SizedBox(height: 20),
          _buildReportTable(),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _card('Ukupno dogadjaja', '${_stats['totalEvents'] ?? 0}', Icons.event,
            Colors.blue),
        _card('Ukupno volontera', '${_stats['totalVolunteers'] ?? 0}',
            Icons.people, Colors.green),
        _card('Ukupno smjena', '${_stats['totalShifts'] ?? 0}', Icons.schedule,
            Colors.orange),
        _card('Ukupno sati', _num(_stats['totalHours']).toStringAsFixed(1),
            Icons.timer, Colors.purple),
        _card('Aktivne kampanje', '${_stats['activeCampaigns'] ?? 0}',
            Icons.campaign, Colors.teal),
        _card(
            'Ukupne donacije',
            '${_num(_stats['totalDonations']).toStringAsFixed(2)} KM',
            Icons.monetization_on,
            Colors.amber.shade700),
      ],
    );
  }

  Widget _buildCharts() {
    final chart = _leaderboard.take(8).toList();
    if (chart.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nema dovoljno podataka za grafikone.'),
        ),
      );
    }

    final maxY = chart.fold<double>(0, (m, e) {
      final v = _num(e['totalHours']);
      return v > m ? v : m;
    });

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top volonteri po satima',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY <= 0 ? 10 : maxY * 1.2,
                        barGroups: List.generate(
                          chart.length,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: _num(chart[i]['totalHours']),
                                width: 18,
                                color: Colors.blue,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= chart.length) {
                                  return const SizedBox();
                                }
                                final name = (chart[i]['userName'] ?? '')
                                    .toString()
                                    .split(' ')
                                    .first;
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(name,
                                      style: const TextStyle(fontSize: 11)),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportTable() {
    final columns = _resolvedColumns();
    final rows = _resolvedRows(columns);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _reportTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Nema podataka za odabrani period.'),
              ),
            if (rows.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns:
                      columns.map((c) => DataColumn(label: Text(c))).toList(),
                  rows: rows.take(300).map((r) {
                    return DataRow(
                      cells: columns
                          .map((c) => DataCell(Text((r[c] ?? '').toString())))
                          .toList(),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _resolvedColumns() {
    if (_selectedReport == 'Overview') {
      return ['Volonter', 'Sati', 'Dogadjaji', 'Rang'];
    }
    if (_selectedReport == 'VolunteerParticipation') {
      return [
        'userName',
        'eventCount',
        'shiftCount',
        'totalHours',
        'approvedShifts',
        'rejectedShifts'
      ];
    }
    if (_selectedReport == 'HoursByVolunteer') {
      return [
        'userName',
        'totalApprovedHours',
        'totalShifts',
        'averageHoursPerShift'
      ];
    }
    if (_selectedReport == 'EventAttendance') {
      return [
        'eventTitle',
        'shiftCount',
        'totalRegistrations',
        'approvedRegistrations',
        'totalHours'
      ];
    }
    return [
      'campaignTitle',
      'goalAmount',
      'raisedAmount',
      'donationCount',
      'averageDonation',
      'isActive'
    ];
  }

  List<Map<String, dynamic>> _resolvedRows(List<String> columns) {
    if (_selectedReport == 'Overview') return _reportRows;
    return _reportRows.map((r) {
      final converted = <String, dynamic>{};
      for (final c in columns) {
        converted[c] = r[c];
      }
      return converted;
    }).toList();
  }

  Future<void> _exportPdf() async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final columns = _resolvedColumns();
    final rows = _resolvedRows(columns);
    final now = DateTime.now();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (_) => [
          pw.Text(
            'VolunteerHub - $_reportTitle',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generisano: ${now.day}.${now.month}.${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
          ),
          if (_dateRange != null)
            pw.Text('Period: ${_rangeLabel.replaceAll(' - ', ' do ')}'),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration:
                pw.BoxDecoration(color: PdfColor.fromHex('#1f6feb')),
            data: [
              columns,
              ...rows.take(500).map((r) {
                return columns.map((c) => (r[c] ?? '').toString()).toList();
              }),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    final fileName = 'VolunteerHub_$_selectedReport.pdf';
    final fullPath =
        '$home${Platform.pathSeparator}Downloads${Platform.pathSeparator}$fileName';
    await File(fullPath).writeAsBytes(bytes);
    await Process.run('cmd', ['/c', 'start', '', fullPath]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF sacuvan: $fullPath')),
      );
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _dateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: initial,
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      await _load();
    }
  }

  String get _reportTitle {
    return switch (_selectedReport) {
      'Overview' => 'Pregled',
      'VolunteerParticipation' => 'Ucesce volontera',
      'HoursByVolunteer' => 'Sati po volonteru',
      'EventAttendance' => 'Posjecenost dogadjaja',
      'DonationsSummary' => 'Donacije po kampanji',
      _ => 'Izvjestaj',
    };
  }

  String get _rangeLabel {
    if (_dateRange == null) return 'Odaberi period';
    final s = _dateRange!.start;
    final e = _dateRange!.end;
    return '${s.day.toString().padLeft(2, '0')}.${s.month.toString().padLeft(2, '0')}.${s.year} - ${e.day.toString().padLeft(2, '0')}.${e.month.toString().padLeft(2, '0')}.${e.year}';
  }

  double _num(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Widget _card(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

typedef ResponseSelector = Future<dynamic> Function({
  DateTime? startDate,
  DateTime? endDate,
});
