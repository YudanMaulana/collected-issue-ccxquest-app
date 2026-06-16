import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/issue.dart';
import '../repositories/issue_repository.dart';
import 'issue_form_screen.dart';

class IncompleteIssuesScreen extends StatefulWidget {
  final IssueRepository repository;

  const IncompleteIssuesScreen({super.key, required this.repository});

  @override
  State<IncompleteIssuesScreen> createState() => _IncompleteIssuesScreenState();
}

class _IncompleteIssuesScreenState extends State<IncompleteIssuesScreen> {
  bool _isLoading = true;
  List<Issue> _issues = [];
  String _selectedMissingField = 'All';

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await widget.repository.getAllIssues(incompleteOnly: true);
      setState(() {
        _issues = data.where((item) => item.isIncomplete).toList()
          ..sort((a, b) {
            final diff = b.missingFields.length.compareTo(a.missingFields.length);
            if (diff != 0) return diff;
            return b.tgl.compareTo(a.tgl);
          });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data belum lengkap: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<Issue> get _filteredIssues {
    if (_selectedMissingField == 'All') return _issues;
    return _issues.where((issue) => issue.missingFields.contains(_selectedMissingField)).toList();
  }

  int _countByField(String field) {
    return _issues.where((issue) => issue.missingFields.contains(field)).length;
  }

  Future<void> _openEdit(Issue issue) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IssueFormScreen(
          repository: widget.repository,
          issue: issue,
        ),
      ),
    );

    if (updated == true) {
      _loadIssues();
    }
  }

  Widget _buildSummaryCard(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderNavy),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(
              value.toString(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleIssues = _filteredIssues;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _loadIssues,
        color: AppTheme.accentYellow,
        backgroundColor: AppTheme.cardBg,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentYellow))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HALAMAN DATA BELUM LENGKAP',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Buka data yang masih kosong lalu lengkapi Tag Detail, Eviden, Penyebab, atau Penanganan.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildSummaryCard('Total Incomplete', _issues.length, Icons.warning_amber_rounded, AppTheme.statusPending),
                            const SizedBox(width: 10),
                            _buildSummaryCard('Tag Detail', _countByField('Tag Detail'), Icons.sell_outlined, AppTheme.accentYellow),
                            const SizedBox(width: 10),
                            _buildSummaryCard('Eviden', _countByField('Eviden'), Icons.image_outlined, Colors.lightBlueAccent),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildSummaryCard('Penyebab', _countByField('Penyebab'), Icons.help_outline, Colors.orangeAccent),
                            const SizedBox(width: 10),
                            _buildSummaryCard('Penanganan', _countByField('Penanganan'), Icons.build_outlined, Colors.greenAccent),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderNavy),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedMissingField,
                              isExpanded: true,
                              dropdownColor: AppTheme.cardBg,
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('Semua Kolom Kosong')),
                                DropdownMenuItem(value: 'Tag Detail', child: Text('Tag Detail Kosong')),
                                DropdownMenuItem(value: 'Eviden', child: Text('Eviden Kosong')),
                                DropdownMenuItem(value: 'Penyebab', child: Text('Penyebab Kosong')),
                                DropdownMenuItem(value: 'Penanganan', child: Text('Penanganan Kosong')),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedMissingField = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visibleIssues.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.check_circle_outline, color: AppTheme.statusSolved, size: 56),
                                    SizedBox(height: 12),
                                    Text(
                                      'Semua data sudah lengkap untuk filter ini.',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: visibleIssues.length,
                            itemBuilder: (context, index) {
                              final issue = visibleIssues[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _openEdit(issue),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                issue.area,
                                                style: const TextStyle(
                                                  color: AppTheme.accentYellow,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              issue.tglFormatted,
                                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          '[${issue.kodeIssue}] ${issue.issue}',
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: issue.missingFields.map((field) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: AppTheme.statusPending.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: AppTheme.statusPending.withOpacity(0.25)),
                                              ),
                                              child: Text(
                                                field,
                                                style: const TextStyle(
                                                  color: AppTheme.statusPending,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Tag Detail: ${issue.tagDetail.isEmpty ? '-' : issue.tagDetail}',
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Penyebab: ${issue.penyebab.isEmpty ? '-' : issue.penyebab}',
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Penanganan: ${issue.penanganan.isEmpty ? '-' : issue.penanganan}',
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => _openEdit(issue),
                                              icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.accentYellow),
                                              label: const Text(
                                                'Lengkapi Sekarang',
                                                style: TextStyle(
                                                  color: AppTheme.accentYellow,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
