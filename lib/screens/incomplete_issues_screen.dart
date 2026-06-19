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
  final Map<String, bool> _draftFieldFilters = {
    'Tag Detail': false,
    'Eviden': false,
    'Penyebab': false,
    'Penanganan': false,
  };
  Set<String> _activeFieldFilters = {};
  bool _isFilterExpanded = false;

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
    if (_activeFieldFilters.isEmpty) return _issues;
    return _issues.where((issue) {
      return _activeFieldFilters.any(issue.missingFields.contains);
    }).toList();
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

  void _applyFilters() {
    setState(() {
      _activeFieldFilters = _draftFieldFilters.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toSet();
    });
  }

  void _clearFilters() {
    setState(() {
      for (final key in _draftFieldFilters.keys) {
        _draftFieldFilters[key] = false;
      }
      _activeFieldFilters = {};
    });
  }

  Widget _buildCompactFilterTile(String label, IconData icon, Color color) {
    final isSelected = _draftFieldFilters[label] ?? false;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          setState(() {
            _draftFieldFilters[label] = !isSelected;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: isSelected,
                activeColor: AppTheme.accentYellow,
                checkColor: AppTheme.primaryNavy,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (value) {
                  setState(() {
                    _draftFieldFilters[label] = value ?? false;
                  });
                },
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                '$label (${_countByField(label)})',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleIssues = _filteredIssues;

    final filterFields = [
      {'label': 'Tag Detail', 'icon': Icons.sell_outlined, 'color': AppTheme.accentYellow},
      {'label': 'Eviden', 'icon': Icons.image_outlined, 'color': Colors.lightBlueAccent},
      {'label': 'Penyebab', 'icon': Icons.help_outline, 'color': Colors.orangeAccent},
      {'label': 'Penanganan', 'icon': Icons.build_outlined, 'color': Colors.greenAccent},
    ];

    final sortedFields = List.from(filterFields)
      ..sort((a, b) {
        final countA = _countByField(a['label'] as String);
        final countB = _countByField(b['label'] as String);
        return countB.compareTo(countA);
      });

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
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderNavy),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isFilterExpanded = !_isFilterExpanded;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.filter_list_alt,
                                              color: AppTheme.accentYellow,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Filter & Ringkasan',
                                              style: TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Icon(
                                          _isFilterExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                          color: AppTheme.textSecondary,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_isFilterExpanded) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Total incomplete: ${_issues.length}',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: sortedFields.map((field) {
                                        final isLast = field == sortedFields.last;
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildCompactFilterTile(
                                              field['label'] as String,
                                              field['icon'] as IconData,
                                              field['color'] as Color,
                                            ),
                                            if (!isLast) const SizedBox(width: 8),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _clearFilters,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.textSecondary,
                                            side: const BorderSide(color: AppTheme.borderNavy),
                                          ),
                                          child: const Text('Reset'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _applyFilters,
                                          child: const Text('Terapkan'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_activeFieldFilters.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Filter aktif: ${_activeFieldFilters.join(', ')}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ] else ...[
                                  if (_activeFieldFilters.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Filter aktif: ${_activeFieldFilters.join(', ')}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Total incomplete: ${_issues.length} | Ketuk untuk memfilter',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ]
                                ]
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Menampilkan ${visibleIssues.length} hasil',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
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
