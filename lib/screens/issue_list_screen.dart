import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  DateTime? _selectedFilterDate;
  String _selectedKodeIssue = 'All';
  List<String> _uniqueKodeIssues = ['All'];
  
  // Calendar states
  bool _showCalendar = false;
  DateTime _focusedMonth = DateTime.now();
  Set<DateTime> _datesWithIssues = {};

  final List<String> _areas = [
    'All',
    'All Wahana',
    'Innovation Station',
    'Innovation Train',
    'Clevo Station',
    'Clevo X-DREAMFARM',
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

    List<String> uniqueCodesList = ['All'];
    try {
      final allUnfiltered = await widget.repository.getAllIssues();
      final codes = allUnfiltered
          .map((e) => e.kodeIssue.trim().toUpperCase())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      uniqueCodesList = ['All', ...codes];
    } catch (e) {
      print('Gagal mengambil list unique kode issue: $e');
    }
    
    var data = await widget.repository.getAllIssues(
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
      area: _selectedArea != 'All' ? _selectedArea : null,
      kategori: _selectedKategori != 'All' ? _selectedKategori : null,
      status: _selectedStatus != 'All' ? _selectedStatus : null,
      incompleteOnly: _incompleteOnly ? true : null,
    );

    if (_selectedKodeIssue != 'All') {
      data = data.where((issue) => issue.kodeIssue.trim().toUpperCase() == _selectedKodeIssue.toUpperCase()).toList();
    }

    // Compute dates with issues based on current filters (before date filter is applied)
    final Set<DateTime> issueDates = data.map((e) {
      final local = e.tgl.toLocal();
      return DateTime(local.year, local.month, local.day);
    }).toSet();

    if (_selectedFilterDate != null) {
      data = data.where((issue) {
        final local = issue.tgl.toLocal();
        return local.year == _selectedFilterDate!.year &&
               local.month == _selectedFilterDate!.month &&
               local.day == _selectedFilterDate!.day;
      }).toList();
    }

    // Sort strictly by date descending, then by ID descending to keep backdated/old issues in their correct date positions
    data.sort((a, b) {
      final tglCompare = b.tgl.compareTo(a.tgl);
      if (tglCompare != 0) return tglCompare;
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });

    setState(() {
      _issues = data;
      _datesWithIssues = issueDates;
      _uniqueKodeIssues = uniqueCodesList;
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
        const SnackBar(content: Text('Tidak ada data issue untuk diekspor!'), backgroundColor: AppTheme.statusPending),
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

      // Show customized success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppTheme.statusSolved, size: 28),
                SizedBox(width: 10),
                Text('Ekspor Berhasil', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'File Excel analisis kendala berhasil disimpan secara lokal tanpa share sheet!',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Lokasi Penyimpanan:',
                  style: TextStyle(color: AppTheme.accentYellow, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryNavy.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderNavy),
                  ),
                  child: Text(
                    path,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('TUTUP', style: TextStyle(color: AppTheme.accentYellow, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor file: $e'), backgroundColor: Colors.redAccent),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCopyWhatsApp() async {
    if (_selectedFilterDate == null) return;
    if (_issues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data issue untuk disalin pada tanggal ini!'),
          backgroundColor: AppTheme.statusPending,
        ),
      );
      return;
    }

    try {
      final String formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(_selectedFilterDate!.toLocal());
      
      final totalIssues = _issues.length;
      final solvedCount = _issues.where((e) => e.status.toLowerCase() == 'solved').length;
      final pendingCount = _issues.where((e) => e.status.toLowerCase() == 'pending').length;

      final buffer = StringBuffer();
      buffer.writeln('*COLLECTED ISSUE - $formattedDate*');
      buffer.writeln('Total Issue: $totalIssues');
      buffer.writeln('Solved: $solvedCount');
      buffer.writeln('Pending: $pendingCount');
      buffer.writeln();

      for (int i = 0; i < _issues.length; i++) {
        final issue = _issues[i];
        final noUrut = i + 1;
        final area = issue.area.toUpperCase();
        final kendala = issue.issue;
        final penyebab = issue.penyebab.isNotEmpty ? issue.penyebab : '-';
        final status = issue.status.toLowerCase() == 'solved' ? 'SOLVED ✅' : 'PENDING ⏳';

        buffer.writeln('$noUrut. *Area:* $area');
        buffer.writeln('   *Issue/Kendala:* $kendala');
        buffer.writeln('   *Penyebab:* $penyebab');
        buffer.writeln('   *Status Perbaikan:* $status');
        if (i < _issues.length - 1) {
          buffer.writeln();
        }
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Laporan berhasil disalin ke clipboard!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: Color(0xFF25D366),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyalin ke clipboard: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _addNewIssue() async {
    List<Issue> latestIssues = [];
    DateTime? latestDate;
    final targetDate = _selectedFilterDate ?? DateTime.now();

    try {
      final all = await widget.repository.getAllIssues();
      if (all.isNotEmpty) {
        final sorted = List<Issue>.from(all)
          ..sort((a, b) => b.tgl.compareTo(a.tgl));

        // Find issues strictly before the targetDate
        final beforeTarget = sorted.where((e) {
          final local = e.tgl.toLocal();
          final localTarget = targetDate.toLocal();
          final d = DateTime(local.year, local.month, local.day);
          final t = DateTime(localTarget.year, localTarget.month, localTarget.day);
          return d.isBefore(t);
        }).toList();

        if (beforeTarget.isNotEmpty) {
          final tempLatest = beforeTarget.first.tgl.toLocal();
          latestDate = DateTime(tempLatest.year, tempLatest.month, tempLatest.day);

          // Get all issues on this exact date
          latestIssues = sorted.where((e) {
            final d = e.tgl.toLocal();
            return d.year == latestDate!.year &&
                   d.month == latestDate!.month &&
                   d.day == latestDate!.day;
          }).toList();
        }
      }
    } catch (e) {
      print('Gagal mengambil data terakhir untuk disalin: $e');
    }

    Issue? duplicateFrom;
    if (latestIssues.isNotEmpty && latestDate != null && mounted) {
      final String formattedDate = DateFormat('dd MMMM yyyy').format(latestDate);
      
      duplicateFrom = await showDialog<Issue?>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.copy, color: AppTheme.accentYellow, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Salin Data ($formattedDate)',
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih salah satu issue dari tanggal terakhir di bawah ini untuk disalin, atau pilih "Mulai Baru":',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    if (latestIssues.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Semua data telah dihapus.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: latestIssues.length,
                          itemBuilder: (context, index) {
                            final item = latestIssues[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: AppTheme.secondaryNavy.withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: AppTheme.borderNavy),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => Navigator.pop(context, item),
                                            child: Text(
                                              '#${index + 1} - ${item.area}',
                                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          item.kategori,
                                          style: TextStyle(
                                            color: item.kategori.toUpperCase() == 'ASSET' ? Colors.orangeAccent : Colors.lightBlueAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                backgroundColor: AppTheme.cardBg,
                                                title: const Text('Hapus Issue?'),
                                                content: const Text('Apakah Anda yakin ingin menghapus data issue ini secara permanen?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, false),
                                                    child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text('Hapus'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true && item.id != null) {
                                              await widget.repository.deleteIssue(item.id!);
                                              setDialogState(() {
                                                latestIssues.removeAt(index);
                                              });
                                              _loadIssues();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => Navigator.pop(context, item),
                                      child: Text(
                                        'Issue: ${item.issue}',
                                        style: const TextStyle(color: AppTheme.accentYellow, fontSize: 11),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('MULAI BARU (KOSONG)', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            );
          },
        ),
      );
    }

    if (!mounted) return;
    final added = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IssueFormScreen(
          repository: widget.repository,
          initialDate: _selectedFilterDate,
          duplicateFrom: duplicateFrom,
        ),
      ),
    );
    if (added == true) {
      _loadIssues();
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
            return SingleChildScrollView(
              child: Padding(
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
                              _selectedKodeIssue = 'All';
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

                    // Kode Issue Filter
                    const Text('Kode Issue', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
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
                        value: _selectedKodeIssue,
                        items: _uniqueKodeIssues.map((k) {
                          return DropdownMenuItem(value: k, child: Text(k));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => _selectedKodeIssue = val);
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
              ),
            );
          },
        );
      },
    );
  }

  List<DateTime?> _generateCalendarDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    int prefixDays = firstDay.weekday % 7; 
    final totalDays = DateTime(month.year, month.month + 1, 0).day;

    final List<DateTime?> days = [];
    for (int i = 0; i < prefixDays; i++) {
      days.add(null);
    }
    for (int i = 1; i <= totalDays; i++) {
      days.add(DateTime(month.year, month.month, i));
    }
    return days;
  }

  Widget _buildCustomCalendarGrid() {
    final List<DateTime?> days = _generateCalendarDays(_focusedMonth);
    final monthName = DateFormat('MMMM yyyy').format(_focusedMonth);
    final weekdays = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderNavy),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppTheme.accentYellow),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  });
                },
              ),
              Text(
                monthName.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppTheme.accentYellow),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((day) {
              return SizedBox(
                width: 36,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(color: AppTheme.borderNavy, height: 16),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              if (day == null) return const SizedBox.shrink();

              final isSelected = _selectedFilterDate != null &&
                  _selectedFilterDate!.year == day.year &&
                  _selectedFilterDate!.month == day.month &&
                  _selectedFilterDate!.day == day.day;

              final hasIssues = _datesWithIssues.any((d) =>
                  d.year == day.year && d.month == day.month && d.day == day.day);

              final isToday = DateTime.now().year == day.year &&
                  DateTime.now().month == day.month &&
                  DateTime.now().day == day.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedFilterDate = null;
                    } else {
                      _selectedFilterDate = day;
                    }
                  });
                  _loadIssues();
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accentYellow
                        : isToday
                            ? AppTheme.secondaryNavy
                            : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(color: AppTheme.accentYellow.withOpacity(0.5))
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryNavy
                              : isToday
                                  ? AppTheme.accentYellow
                                  : AppTheme.textPrimary,
                          fontWeight:
                              isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      if (hasIssues && !isSelected)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppTheme.accentYellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showCalendar = !_showCalendar;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _showCalendar || _selectedFilterDate != null
                          ? AppTheme.accentYellow.withOpacity(0.2)
                          : AppTheme.secondaryNavy,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showCalendar || _selectedFilterDate != null
                            ? AppTheme.accentYellow
                            : AppTheme.borderNavy,
                      ),
                    ),
                    child: Icon(
                      Icons.calendar_month,
                      color: _showCalendar || _selectedFilterDate != null
                          ? AppTheme.accentYellow
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showCalendar) _buildCustomCalendarGrid(),
          if (_selectedFilterDate != null || _selectedKodeIssue != 'All')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (_selectedFilterDate != null)
                      Theme(
                        data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
                        child: InputChip(
                          backgroundColor: AppTheme.secondaryNavy,
                          side: const BorderSide(color: AppTheme.borderNavy),
                          label: Text(
                            'Tanggal: ${DateFormat('dd MMMM yyyy').format(_selectedFilterDate!)}',
                            style: const TextStyle(color: AppTheme.accentYellow, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.statusPending),
                          onDeleted: () {
                            setState(() {
                              _selectedFilterDate = null;
                            });
                            _loadIssues();
                          },
                        ),
                      ),
                    if (_selectedKodeIssue != 'All')
                      Theme(
                        data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
                        child: InputChip(
                          backgroundColor: AppTheme.secondaryNavy,
                          side: const BorderSide(color: AppTheme.borderNavy),
                          label: Text(
                            'Kode: $_selectedKodeIssue',
                            style: const TextStyle(color: AppTheme.accentYellow, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.statusPending),
                          onDeleted: () {
                            setState(() {
                              _selectedKodeIssue = 'All';
                            });
                            _loadIssues();
                          },
                        ),
                      ),
                  ],
                ),
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
          if (_selectedFilterDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                onPressed: _handleCopyWhatsApp,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text(
                  'Salin Laporan (WhatsApp)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
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
        onPressed: _addNewIssue,
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
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryNavy,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderNavy),
                      ),
                      child: Text(
                        issue.area,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.accentYellow,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
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
                  if (issue.tagDetail.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentYellow.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.accentYellow.withOpacity(0.3)),
                      ),
                      child: Text(
                        issue.tagDetail,
                        style: const TextStyle(
                          color: AppTheme.accentYellow,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),

                  // Duration Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${issue.perulanganMasalah} Kali',
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
            if (_selectedFilterDate != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _addNewIssue,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('TAMBAH ISSUE DI TANGGAL INI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
