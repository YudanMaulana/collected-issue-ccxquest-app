import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/theme.dart';
import '../models/issue.dart';
import '../repositories/issue_repository.dart';
import 'package:url_launcher/url_launcher.dart';
class IssueFormScreen extends StatefulWidget {
  final IssueRepository repository;
  final Issue? issue;
  
  const IssueFormScreen({Key? key, required this.repository, this.issue}) : super(key: key);

  @override
  State<IssueFormScreen> createState() => _IssueFormScreenState();
}

class _IssueFormScreenState extends State<IssueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late DateTime _selectedDate;
  late String _selectedArea;
  late String _selectedKategori;
  late String _selectedStatus;
  
  final _issueController = TextEditingController();
  final _penyebabController = TextEditingController();
  final _penangananController = TextEditingController();
  
  String? _evidencePath;
  bool _isSaving = false;

  // Unique Issue tracking & duplication states
  bool _isDuplicateMode = false;
  List<Map<String, String>> _uniqueIssues = [];
  String? _selectedLegacyCode;
  String _generatedCodePreview = '';
  bool _isLoadingUniqueIssues = false;
  String _currentKodeIssue = '';

  final List<String> _areas = [
    'ALL WAHANA',
    'INNOVATION STATION',
    'INNOVATION TRAIN',
    'CLEVO STATION',
    'CLEVO X-DREAMSPACE',
    'TUNNEL',
    'CHAMBER AI',
    'CHOCOLATOS BRIEFING ROOM',
    'X-GONDOLA'
  ];

  final List<String> _kategoris = ['SISTEM', 'ASSET'];
  final List<String> _statuses = ['pending', 'solved'];
  
  // Penanganan Vendor recommendations
  final List<String> _penangananRecommendations = [
    'TIM IMAJI',
    'IT SUPPORT',
    'OFFICER',
  ];

  @override
  void initState() {
    super.initState();
    _issueController.addListener(() {
      if (mounted) setState(() {});
    });
    _selectedDate = widget.issue?.tgl ?? DateTime.now();
    
    // Dynamic matching of area to prevent Dropdown crash (case-insensitive alignment)
    final String issueArea = widget.issue?.area ?? '';
    if (issueArea.isNotEmpty) {
      final match = _areas.firstWhere(
        (a) => a.trim().toLowerCase() == issueArea.trim().toLowerCase(),
        orElse: () {
          _areas.add(issueArea);
          return issueArea;
        },
      );
      _selectedArea = match;
    } else {
      _selectedArea = _areas.first;
    }

    final String issueKategori = widget.issue?.kategori ?? '';
    if (issueKategori.isNotEmpty) {
      final match = _kategoris.firstWhere(
        (k) => k.trim().toLowerCase() == issueKategori.trim().toLowerCase(),
        orElse: () {
          _kategoris.add(issueKategori);
          return issueKategori;
        },
      );
      _selectedKategori = match;
    } else {
      _selectedKategori = _kategoris.first;
    }

    final String issueStatus = widget.issue?.status ?? '';
    if (issueStatus.isNotEmpty) {
      final match = _statuses.firstWhere(
        (s) => s.trim().toLowerCase() == issueStatus.trim().toLowerCase(),
        orElse: () {
          _statuses.add(issueStatus);
          return issueStatus;
        },
      );
      _selectedStatus = match;
    } else {
      _selectedStatus = _statuses.first;
    }

    _issueController.text = widget.issue?.issue ?? '';
    _penyebabController.text = widget.issue?.penyebab ?? '';
    _penangananController.text = widget.issue?.penanganan ?? '';
    _evidencePath = widget.issue?.evide;
    _currentKodeIssue = widget.issue?.kodeIssue ?? '';

    _loadUniqueIssues();
  }

  Future<void> _loadUniqueIssues() async {
    if (widget.issue != null) return;
    setState(() {
      _isLoadingUniqueIssues = true;
    });
    try {
      final list = await widget.repository.getUniqueIssues();
      final preview = await widget.repository.generateNextIssueCode();
      setState(() {
        _uniqueIssues = list;
        _generatedCodePreview = preview;
        _currentKodeIssue = preview; // Default to new code
        _isLoadingUniqueIssues = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingUniqueIssues = false;
      });
    }
  }

  @override
  void dispose() {
    _issueController.dispose();
    _penyebabController.dispose();
    _penangananController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.accentYellow,
              onPrimary: AppTheme.primaryNavy,
              surface: AppTheme.cardBg,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
      
      if (pickedFile != null) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final fileName = 'evidence_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
        final savedFile = await File(pickedFile.path).copy('${appDocDir.path}/$fileName');
        
        setState(() {
          _evidencePath = savedFile.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.accentYellow),
                title: const Text('Ambil Foto (Camera)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.accentYellow),
                title: const Text('Pilih dari Galeri/Browser'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_evidencePath != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                  title: const Text('Hapus Eviden'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _evidencePath = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
    });

    final issue = Issue(
      id: widget.issue?.id,
      tgl: _selectedDate,
      area: _selectedArea,
      kategori: _selectedKategori,
      issue: _issueController.text.trim(),
      penanganan: _penangananController.text.trim(),
      status: _selectedStatus,
      perulanganMasalah: widget.issue?.perulanganMasalah ?? 1,
      penyebab: _penyebabController.text.trim(),
      evide: _evidencePath,
      kodeIssue: _currentKodeIssue,
    );

    try {
      if (widget.issue == null) {
        await widget.repository.insertIssue(issue);
      } else {
        await widget.repository.updateIssue(issue);
      }
      
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving issue: $e'), backgroundColor: Colors.redAccent),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.issue != null;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isEdit ? 'EDIT ISSUE' : 'ADD NEW ISSUE'),
        actions: [
          if (!_isSaving)
            IconButton(
              icon: const Icon(Icons.save, color: AppTheme.accentYellow),
              onPressed: _saveForm,
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentYellow),
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date picker
              const Text('HARI & TANGGAL', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryNavy.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderNavy),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                      ),
                      const Icon(Icons.calendar_today, color: AppTheme.accentYellow, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Area Dropdown
              const Text('AREA', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryNavy.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderNavy),
                ),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(border: InputBorder.none, filled: false),
                  value: _selectedArea,
                  items: _areas.map((a) {
                    return DropdownMenuItem(value: a, child: Text(a));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedArea = val);
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Category & Status row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('KATEGORI', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryNavy.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderNavy),
                          ),
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(border: InputBorder.none, filled: false),
                            value: _selectedKategori,
                            items: _kategoris.map((k) {
                              return DropdownMenuItem(value: k, child: Text(k));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedKategori = val);
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
                        const Text('STATUS PERBAIKAN', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryNavy.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderNavy),
                          ),
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(border: InputBorder.none, filled: false),
                            value: _selectedStatus,
                            items: _statuses.map((s) {
                              return DropdownMenuItem(value: s, child: Text(s.toUpperCase()));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedStatus = val);
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

              if (widget.issue == null) ...[
                // Premium Card for Duplication Selection
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryNavy.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderNavy),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'APAKAH KENDALA INI PERNAH TERJADI SEBELUMNYA?',
                        style: TextStyle(color: AppTheme.accentYellow, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isDuplicateMode = false;
                                  _currentKodeIssue = _generatedCodePreview;
                                  _issueController.clear();
                                  _penyebabController.clear();
                                  _selectedLegacyCode = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isDuplicateMode ? AppTheme.accentYellow : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !_isDuplicateMode ? AppTheme.accentYellow : AppTheme.borderNavy,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Belum Pernah (Baru)',
                                    style: TextStyle(
                                      color: !_isDuplicateMode ? AppTheme.primaryNavy : AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isDuplicateMode = true;
                                  _currentKodeIssue = '';
                                  _issueController.clear();
                                  _penyebabController.clear();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isDuplicateMode ? AppTheme.accentYellow : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _isDuplicateMode ? AppTheme.accentYellow : AppTheme.borderNavy,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Pernah (Duplikat)',
                                    style: TextStyle(
                                      color: _isDuplicateMode ? AppTheme.primaryNavy : AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isDuplicateMode) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'PILIH KENDALA TERDAHULU',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _isLoadingUniqueIssues
                            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentYellow))
                            : _uniqueIssues.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text('Belum ada riwayat kendala.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryNavy.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.borderNavy),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: _selectedLegacyCode,
                                        hint: const Text('Cari/pilih kendala yang sama...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                        dropdownColor: AppTheme.cardBg,
                                        items: _uniqueIssues.map((issueItem) {
                                          return DropdownMenuItem<String>(
                                            value: issueItem['kode_issue'],
                                            child: Text(
                                              '[${issueItem['kode_issue']}] ${issueItem['issue']}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            final selected = _uniqueIssues.firstWhere((item) => item['kode_issue'] == val);
                                            setState(() {
                                              _selectedLegacyCode = val;
                                              _currentKodeIssue = val;
                                              _issueController.text = selected['issue'] ?? '';
                                              _penyebabController.text = selected['penyebab'] ?? '';
                                              
                                              final String legacyKategori = selected['kategori'] ?? '';
                                              if (legacyKategori.isNotEmpty) {
                                                final match = _kategoris.firstWhere(
                                                  (k) => k.trim().toLowerCase() == legacyKategori.trim().toLowerCase(),
                                                  orElse: () => _selectedKategori,
                                                );
                                                _selectedKategori = match;
                                              }
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Kendala diduplikat dari $val. Penyebab & Kategori terisi otomatis!'),
                                                backgroundColor: AppTheme.statusSolved,
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                // If editing, display the prominent golden badge showing the Issue's code
                Row(
                  children: [
                    const Text('KODE TRACKING: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentYellow.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accentYellow),
                      ),
                      child: Text(
                        _currentKodeIssue,
                        style: const TextStyle(color: AppTheme.accentYellow, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Issue text
              const Text('ISSUE / KENDALA', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _issueController,
                maxLines: 3,
                readOnly: _isDuplicateMode,
                decoration: InputDecoration(
                  hintText: _isDuplicateMode ? 'Pilih kendala terdahulu di atas' : 'Masukkan penjelasan issue secara lengkap',
                  fillColor: _isDuplicateMode ? AppTheme.secondaryNavy.withOpacity(0.2) : null,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Mohon isi kolom issue' : null,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('Klasifikasi Otomatis (Tag): ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentYellow.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          Issue.calculateTag(_issueController.text.trim()),
                          style: const TextStyle(color: AppTheme.accentYellow, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Kode Issue: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        _currentKodeIssue.isNotEmpty ? _currentKodeIssue : 'Generating...',
                        style: const TextStyle(color: AppTheme.accentYellow, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Penanganan Vendor (Editable + Recommendations)
              const Text('PENANGANAN VENDOR', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _penangananController,
                decoration: InputDecoration(
                  hintText: 'Nama vendor / penanganan',
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.accentYellow),
                    onSelected: (val) {
                      _penangananController.text = val;
                    },
                    itemBuilder: (context) {
                      return _penangananRecommendations.map((r) {
                        return PopupMenuItem(value: r, child: Text(r));
                      }).toList();
                    },
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Mohon isi penanganan vendor' : null,
              ),
              const SizedBox(height: 20),

              // Penyebab
              const Text('PENYEBAB', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _penyebabController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Penyebab terjadinya kendala'),
              ),
              const SizedBox(height: 20),

              // Photo Evidence Capture picker
              const Text('EVIDEN FOTO', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildEvidenceDisplay(),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveForm,
                  child: Text(isEdit ? 'UPDATE ISSUE' : 'CREATE ISSUE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvidenceDisplay() {
    if (_evidencePath != null && 
        _evidencePath!.trim().isNotEmpty && 
        _evidencePath!.trim().toLowerCase() != 'null') {
      
      final isUrl = _evidencePath!.startsWith('http://') || _evidencePath!.startsWith('https://');
      final lowerPath = _evidencePath!.toLowerCase();
      
      bool isLocalFileExists = false;
      if (!isUrl) {
        try {
          final file = File(_evidencePath!);
          isLocalFileExists = file.existsSync();
        } catch (_) {
          isLocalFileExists = false;
        }
      }

      final isGoogleDrive = lowerPath.contains('drive.google.com') || lowerPath.contains('docs.google.com');

      // Check if it's a direct image file or supabase public link
      final isImage = isUrl
          ? (lowerPath.endsWith('.jpg') || 
             lowerPath.endsWith('.jpeg') || 
             lowerPath.endsWith('.png') || 
             lowerPath.endsWith('.gif') || 
             lowerPath.endsWith('.webp') || 
             lowerPath.contains('supabase.co/storage/v1/object/public') ||
             lowerPath.contains('firebasestorage.googleapis.com'))
          : isLocalFileExists;

      return Container(
        decoration: BoxDecoration(
          color: AppTheme.secondaryNavy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderNavy),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: isUrl
                  ? (!isImage
                      ? Container(
                          height: 150,
                          width: double.infinity,
                          color: AppTheme.primaryNavy,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isGoogleDrive ? Icons.insert_drive_file : Icons.link,
                                color: AppTheme.accentYellow,
                                size: 50,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isGoogleDrive ? 'Google Drive Document' : 'Attachment Web Link',
                                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  backgroundColor: AppTheme.accentYellow.withOpacity(0.2),
                                  foregroundColor: AppTheme.accentYellow,
                                  side: const BorderSide(color: AppTheme.accentYellow, width: 1),
                                ),
                                onPressed: () async {
                                  try {
                                    final url = Uri.parse(_evidencePath!);
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    }
                                  } catch (_) {}
                                },
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: Text(
                                  isGoogleDrive ? 'Open Drive Link' : 'Open Link',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Image.network(
                          _evidencePath!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200,
                            color: AppTheme.primaryNavy,
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.redAccent, size: 50),
                            ),
                          ),
                        ))
                  : (isLocalFileExists
                      ? Image.file(
                          File(_evidencePath!),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200,
                            color: AppTheme.primaryNavy,
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.redAccent, size: 50),
                            ),
                          ),
                        )
                      : Container(
                          height: 150,
                          width: double.infinity,
                          color: AppTheme.primaryNavy,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppTheme.statusPending,
                                size: 50,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'File Eviden Tidak Ditemukan',
                                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'File lokal tidak ada di perangkat ini (data impor/lama). Silakan upload ulang.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.8), fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        )),
            ),
            ListTile(
              title: Text(
                isUrl
                    ? (!isImage
                        ? (isGoogleDrive ? 'Google Drive Link' : 'Web Document Link')
                        : 'Remote Image Link')
                    : (isLocalFileExists
                        ? 'Photo Attachment'
                        : 'File Tidak Ditemukan / Legacy Path'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                !isUrl ? p.basename(_evidencePath!) : _evidencePath!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: AppTheme.accentYellow),
                onPressed: _showImageOptions,
              ),
            )
          ],
        ),
      );
    }

    return InkWell(
      onTap: _showImageOptions,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppTheme.secondaryNavy.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderNavy, style: BorderStyle.solid),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, color: AppTheme.accentYellow, size: 30),
              SizedBox(height: 8),
              Text(
                'Upload Evidence Photo',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                'Capture with Camera or select from Gallery',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
