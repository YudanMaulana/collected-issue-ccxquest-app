import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/issue.dart';
import '../repositories/issue_repository.dart';

class DashboardScreen extends StatefulWidget {
  final IssueRepository repository;
  const DashboardScreen({Key? key, required this.repository}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _metrics = {};
  bool _isLoading = true;
  int _incompleteCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await widget.repository.getDashboardMetrics();
      
      // Use pre-computed incomplete count from server if available
      final incompleteFromServer = data['incomplete'] as int?;
      
      int incompleteCount = 0;
      if (incompleteFromServer != null) {
        incompleteCount = incompleteFromServer;
      } else {
        // Fallback: fetch incomplete list the old way
        final incompleteList = await widget.repository.getAllIssues(incompleteOnly: true);
        incompleteCount = incompleteList.length;
      }
      
      setState(() {
        _metrics = data;
        _incompleteCount = incompleteCount;
        _isLoading = false;
      });
    } catch (e) {
      print('[DashboardScreen] Error loading dashboard: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat dashboard: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentYellow)),
      );
    }

    final total = _metrics['total'] as int? ?? 0;
    final solved = _metrics['solved'] as int? ?? 0;
    final pending = _metrics['pending'] as int? ?? 0;
    final byArea = _metrics['byArea'] as Map<String, int>? ?? {};
    final byKategori = _metrics['byKategori'] as Map<String, int>? ?? {};
    final longestPending = _metrics['longestPending'] as List<Issue>? ?? [];
    final lastUpdated = _metrics['lastUpdated'] as List<Issue>? ?? [];

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: AppTheme.accentYellow,
      backgroundColor: AppTheme.cardBg,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Banner for Incomplete Data
            if (_incompleteCount > 0) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.statusPending.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.statusPending.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.statusPending, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data Belum Lengkap!',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ditemukan $_incompleteCount data yang belum diisi Eviden, Penyebab, atau Penanganan.',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Issues',
                    value: total.toString(),
                    icon: Icons.list_alt,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Jumlah Kode Issue',
                    value: (_metrics['uniqueIssuesCount'] ?? 0).toString(),
                    icon: Icons.settings_suggest,
                    color: AppTheme.accentYellow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Solved',
                    value: solved.toString(),
                    icon: Icons.check_circle_outline,
                    color: AppTheme.statusSolved,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Pending',
                    value: pending.toString(),
                    icon: Icons.pending_actions_outlined,
                    color: AppTheme.statusPending,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Charts Section
            if (total > 0) ...[
              const Text(
                'KATEGORI ANALYSIS',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _buildKategoriPieChart(byKategori),
              const SizedBox(height: 28),

              const Text(
                'ISSUES BY AREA',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _buildAreaBarChart(byArea),
              const SizedBox(height: 28),
            ],

            // Collapsible LAST UPDATED ISSUES Section
            if (lastUpdated.isNotEmpty) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        const Icon(Icons.history, color: AppTheme.accentYellow, size: 20),
                        const SizedBox(width: 10),
                        const Text(
                          'LAST UPDATED ISSUES',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${lastUpdated.length} Kendala Terakhir Tercatat',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: lastUpdated.map((issue) => _buildMiniIssueItem(issue, isPendingType: false)).toList(),
                  ),
                ),
              ),
            ],

            // Collapsible LONGEST PENDING ISSUES Section
            if (longestPending.isNotEmpty) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 24),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        const Icon(Icons.access_time_filled, color: AppTheme.statusPending, size: 20),
                        const SizedBox(width: 10),
                        const Text(
                          'LONGEST PENDING ISSUES',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${longestPending.length} Kendala Tertunda Terlama',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: longestPending.map((issue) => _buildMiniIssueItem(issue, isPendingType: true)).toList(),
                  ),
                ),
              ),
            ] else if (total == 0) ...[
              _buildEmptyState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderNavy),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKategoriPieChart(Map<String, int> data) {
    final sistemVal = (data['SISTEM'] ?? 0).toDouble();
    final assetVal = (data['ASSET'] ?? 0).toDouble();
    final total = sistemVal + assetVal;

    if (total == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: SizedBox(
                height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 35,
                    sections: [
                      PieChartSectionData(
                        color: Colors.cyanAccent,
                        value: sistemVal,
                        title: '${(sistemVal / total * 100).toStringAsFixed(0)}%',
                        radius: 40,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                      PieChartSectionData(
                        color: AppTheme.accentYellow,
                        value: assetVal,
                        title: '${(assetVal / total * 100).toStringAsFixed(0)}%',
                        radius: 40,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem(color: Colors.cyanAccent, title: 'SISTEM', value: '${sistemVal.toInt()} Issues'),
                  const SizedBox(height: 12),
                  _buildLegendItem(color: AppTheme.accentYellow, title: 'ASSET', value: '${assetVal.toInt()} Issues'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String title, required String value}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        )
      ],
    );
  }

  Widget _buildAreaBarChart(Map<String, int> byArea) {
    final sortedAreas = byArea.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Take top 6 areas for display to fit nicely
    final displayedAreas = sortedAreas.take(6).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: displayedAreas.isEmpty 
                  ? 10 
                  : (displayedAreas.first.value * 1.2).ceilToDouble(),
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final int index = value.toInt();
                      if (index < 0 || index >= displayedAreas.length) return const SizedBox.shrink();
                      
                      final areaName = displayedAreas[index].key;
                      // Abbreviate long names
                      String label = areaName;
                      if (label.length > 8) {
                        label = '${label.substring(0, 7)}.';
                      }

                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          label,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: List.generate(displayedAreas.length, (index) {
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: displayedAreas[index].value.toDouble(),
                      color: AppTheme.accentYellow,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: displayedAreas.isEmpty ? 10 : displayedAreas.first.value * 1.2,
                        color: AppTheme.borderNavy,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(Icons.dashboard_outlined, size: 80, color: AppTheme.borderNavy),
            const SizedBox(height: 16),
            const Text(
              'No issues found in database',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Import data from an Excel spreadsheet or add an issue manually to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniIssueItem(Issue issue, {required bool isPendingType}) {
    final bool isSolved = issue.status == 'solved';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.secondaryNavy.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderNavy),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentYellow.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  issue.area,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.accentYellow,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              issue.kategori,
                              style: TextStyle(
                                color: issue.kategori == 'SISTEM' ? Colors.cyanAccent : Colors.tealAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM yyyy').format(issue.tgl),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    issue.issue,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (issue.penyebab.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Penyebab: ${issue.penyebab}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isPendingType)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.statusPending.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.statusPending.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      '${issue.perulanganMasalah}',
                      style: const TextStyle(
                        color: AppTheme.statusPending,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Kali',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSolved ? AppTheme.statusSolved.withOpacity(0.1) : AppTheme.statusPending.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSolved ? AppTheme.statusSolved : AppTheme.statusPending,
                    width: 1,
                  ),
                ),
                child: Text(
                  issue.status.toUpperCase(),
                  style: TextStyle(
                    color: isSolved ? AppTheme.statusSolved : AppTheme.statusPending,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
