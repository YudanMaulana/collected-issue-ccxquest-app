import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';
import '../models/issue.dart';
import '../repositories/issue_repository.dart';
import '../helpers/excel_helper.dart';
import 'issue_form_screen.dart';

class IssueListScreen extends StatefulWidget {
  final IssueRepository repository;
  const IssueListScreen({Key? key, required this.repository}) : super(key: key);

  @override
  State<IssueListScreen> createState() => _IssueListScreenState();
}

class _IssueListScreenState extends State<IssueListScreen> {
  List<Issue> _issues = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  // Filters
  String _selectedArea = 'All';
  String _selectedKategori = 'All';
  String _selectedStatus = 'All';
  bool _incompleteOnly = false;

  final List<String> _areas = [
    'All',
    'All Wahana',
    'Innovation Station',
    'Innovation Train',
    'Clevo Station',
    'Clevo X-DREAMSPACE',
    'Tunnel',
    'Chamber Ai',
    'Chocolatos Briefing Room',
    'X-Gondola'
  ];

  final List<String> _kategoris = ['All', 'SISTEM', 'ASSET'];
  final List<String> _statuses = ['All', 'pending', 'solved'];

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() {
      _isLoading = true;
    });
    
    final data = await widget.repository.getAllIssues(
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      area: _selectedArea != 'All' ? _selectedArea : null,
      kategori: _selectedKategori != 'All' ? _selectedKategori : null,
      status: _selectedStatus != 'All' ? _selectedStatus : null,
      incompleteOnly: _incompleteOnly ? true : null,
    );

    setState(() {
      _issues = data;
      _isLoading = false;
    });
  }

  Future<void> _handleDelete(Issue issue) async {
    if (issue.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this issue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.repository.deleteIssue(issue.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue deleted successfully'), backgroundColor: Colors.redAccent),
      );
      _loadIssues();
    }
  }

  Future<void> _handleImport() async {
    try {
      final list = await ExcelHelper.importIssues();
      if (list.isEmpty) return;

      setState(() {
        _isLoading = true;
      });

      await widget.repository.importIssues(list);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported ${list.length} issues!'),
          backgroundColor: AppTheme.statusSolved,
        ),
      );
      _loadIssues();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing file: $e'), backgroundColor: Colors.redAccent),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleExport() async {
    if (_issues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No issues to export!'), backgroundColor: AppTheme.statusPending),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });
      final path = await ExcelHelper.exportIssues(_issues);
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported Excel successfully!'), backgroundColor: AppTheme.statusSolved),
      );
      
      // Open Share Sheet
      await Share.shareXFiles([XFile(path)], text: 'Exported Technical Issues');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting file: $e'), backgroundColor: Colors.redAccent),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Issues',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedArea = 'All';
                            _selectedKategori = 'All';
                            _selectedStatus = 'All';
                            _incompleteOnly = false;
                          });
                        },
                        child: const Text('Reset', style: TextStyle(color: AppTheme.accentYellow)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Area Filter
                  const Text('Area', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryNavy,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      underline: const SizedBox(),
                      value: _selectedArea,
                      items: _areas.map((a) {
                        return DropdownMenuItem(value: a, child: Text(a));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _selectedArea = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Row for Category & Status
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Kategori', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryNavy,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButton<String>(
                                isExpanded: true,
                                underline: const SizedBox(),
                                value: _selectedKategori,
                                items: _kategoris.map((k) {
                                  return DropdownMenuItem(value: k, child: Text(k));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => _selectedKategori = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryNavy,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButton<String>(
                                isExpanded: true,
                                underline: const SizedBox(),
                                value: _selectedStatus,
                                items: _statuses.map((s) {
                                  return DropdownMenuItem(value: s, child: Text(s));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => _selectedStatus = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Incomplete Data Switch Filter
                  SwitchListTile(
                    title: const Text(
                      'Hanya Data Belum Lengkap',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    subtitle: const Text(
                      'Tampilkan issue tanpa eviden, penyebab, atau penanganan',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    value: _incompleteOnly,
                    activeColor: AppTheme.accentYellow,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setModalState(() {
                        _incompleteOnly = val;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _loadIssues();
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Dynamic Search and Filters Action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search issue, vendor, cause...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                      _loadIssues();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _showFilterBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryNavy,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderNavy),
                    ),
                    child: const Icon(Icons.filter_list, color: AppTheme.accentYellow),
                  ),
                ),
              ],
            ),
          ),

          // Import & Export buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentYellow,
                      side: const BorderSide(color: AppTheme.borderNavy),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _handleImport,
                    icon: const Icon(Icons.file_download, size: 18),
                    label: const Text('Import XLSX', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentYellow,
                      side: const BorderSide(color: AppTheme.borderNavy),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _handleExport,
                    icon: const Icon(Icons.file_upload, size: 18),
                    label: const Text('Export XLSX', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // Catalog Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentYellow))
                : _issues.isEmpty
                    ? _buildEmptyCatalog()
                    : RefreshIndicator(
                        onRefresh: _loadIssues,
                        color: AppTheme.accentYellow,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          itemCount: _issues.length,
                          itemBuilder: (context, index) {
                            final issue = _issues[index];
                            return Dismissible(
                              key: Key(issue.id.toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white, size: 28),
                              ),
                              confirmDismiss: (dir) async {
                                await _handleDelete(issue);
                                return false; // Handled separately
                              },
                              child: _buildIssueItemCard(issue),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IssueFormScreen(repository: widget.repository),
            ),
          );
          if (added == true) {
            _loadIssues();
          }
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildIssueItemCard(Issue issue) {
    final bool isSolved = issue.status == 'solved';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
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
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header line: Area + Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryNavy,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderNavy),
                    ),
                    child: Text(
                      issue.area,
                      style: const TextStyle(
                        color: AppTheme.accentYellow,
                        fontSize: 11,
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
              const SizedBox(height: 12),

              // Title: Issue Description
              Text(
                issue.issue,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (issue.penyebab.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Penyebab: ${issue.penyebab}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],

              // Incomplete warnings indicator
              () {
                final List<String> missingFields = [];
                if (issue.evide == null || issue.evide!.isEmpty) missingFields.add('Eviden');
                if (issue.penyebab.isEmpty) missingFields.add('Penyebab');
                if (issue.penanganan.isEmpty) missingFields.add('Penanganan');
                
                if (missingFields.isEmpty) return const SizedBox.shrink();
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.statusPending.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.statusPending.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.statusPending, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Data belum lengkap: ${missingFields.join(', ')}',
                            style: const TextStyle(color: AppTheme.statusPending, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }(),

              const SizedBox(height: 12),
              const Divider(color: AppTheme.borderNavy, height: 1),
              const SizedBox(height: 12),

              // Bottom Line: Badges + Action Buttons
              Row(
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: issue.kategori == 'SISTEM' ? Colors.cyan.withOpacity(0.1) : Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      issue.kategori,
                      style: TextStyle(
                        color: issue.kategori == 'SISTEM' ? Colors.cyanAccent : Colors.tealAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tag Issue Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentYellow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      issue.tagIssue,
                      style: const TextStyle(
                        color: AppTheme.accentYellow,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Duration Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${issue.lamaPerbaikan} Hari',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSolved ? AppTheme.statusSolved.withOpacity(0.1) : AppTheme.statusPending.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSolved ? AppTheme.statusSolved : AppTheme.statusPending,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSolved ? Icons.check : Icons.access_time,
                          size: 11,
                          color: isSolved ? AppTheme.statusSolved : AppTheme.statusPending,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          issue.status.toUpperCase(),
                          style: TextStyle(
                            color: isSolved ? AppTheme.statusSolved : AppTheme.statusPending,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCatalog() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty, size: 70, color: AppTheme.borderNavy),
            const SizedBox(height: 16),
            const Text(
              'No issues found matching filters',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try clearing your search query or modifying filters in the list.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
