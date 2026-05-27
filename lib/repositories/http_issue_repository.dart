import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/issue.dart';
import 'issue_repository.dart';

/// A robust REST HTTP implementation of the IssueRepository interface.
/// Connects to the standalone Express & SQLite backend server.
/// Features a memory-cache layer and transparent multipart file upload.
class HttpIssueRepository implements IssueRepository {
  // Base URL of the standalone backend server
  // Bound to the local network IP address by default
  final String baseUrl;

  HttpIssueRepository({this.baseUrl = 'http://77.78.88.3:5001/api'});

  // Cache Layer variables
  List<Issue>? _cachedIssues;
  bool _isCacheDirty = true;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 2); // 2 minutes lifetime

  // Helper to invalidate cache on mutations
  void _invalidateCache() {
    _isCacheDirty = true;
    _cachedIssues = null;
  }

  @override
  Future<List<Issue>> getAllIssues({String? search, String? area, String? kategori, String? status, bool? incompleteOnly}) async {
    // 1. Fetch from Express server only if cache is dirty, empty, or expired
    if (_isCacheDirty || 
        _cachedIssues == null || 
        _lastFetchTime == null || 
        DateTime.now().difference(_lastFetchTime!) > _cacheDuration) {
      
      final response = await http.get(Uri.parse('$baseUrl/issues'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        _cachedIssues = data.map((jsonMap) => Issue.fromMap(jsonMap as Map<String, dynamic>)).toList();
        
        _lastFetchTime = DateTime.now();
        _isCacheDirty = false;
      } else {
        throw Exception('Gagal mengambil data kendala dari server: ${response.statusCode}');
      }
    }

    // 2. Perform local filtering on the cached list (identical to Supabase implementation)
    List<Issue> filtered = List.from(_cachedIssues!);

    if (incompleteOnly == true) {
      filtered = filtered.where((item) => 
        item.evide == null || item.evide!.isEmpty ||
        item.penyebab.isEmpty ||
        item.penanganan.isEmpty
      ).toList();
    }

    if (area != null && area != 'All') {
      filtered = filtered.where((item) => item.area.trim().toLowerCase() == area.trim().toLowerCase()).toList();
    }
    if (kategori != null && kategori != 'All') {
      filtered = filtered.where((item) => item.kategori.trim().toUpperCase() == kategori.trim().toUpperCase()).toList();
    }
    if (status != null && status != 'All') {
      filtered = filtered.where((item) => item.status.trim().toLowerCase() == status.trim().toLowerCase()).toList();
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      filtered = filtered.where((item) => 
        item.issue.toLowerCase().contains(s) || 
        item.penyebab.toLowerCase().contains(s) || 
        item.penanganan.toLowerCase().contains(s)
      ).toList();
    }

    return filtered;
  }

  @override
  Future<Issue> getIssueById(int id) async {
    // Check cache first
    if (_cachedIssues != null && !_isCacheDirty) {
      try {
        return _cachedIssues!.firstWhere((element) => element.id == id);
      } catch (_) {}
    }
    
    final response = await http.get(Uri.parse('$baseUrl/issues/$id'));
    if (response.statusCode == 200) {
      return Issue.fromMap(json.decode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Data kendala tidak ditemukan.');
    }
  }

  @override
  Future<int> insertIssue(Issue issue) async {
    _invalidateCache();

    Issue finalIssue = issue;
    if (issue.kodeIssue.isEmpty) {
      final code = await generateNextIssueCode();
      finalIssue = issue.copyWith(kodeIssue: code);
    }

    final String? localPath = finalIssue.evide;

    // Jika eviden berisi file lokal, lakukan upload via Multipart
    if (localPath != null && !localPath.startsWith('http') && localPath.isNotEmpty) {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/issues'));
      
      request.fields['tgl'] = finalIssue.tgl.toIso8601String();
      request.fields['area'] = finalIssue.area;
      request.fields['kategori'] = finalIssue.kategori;
      request.fields['kode_issue'] = finalIssue.kodeIssue;
      request.fields['issue'] = finalIssue.issue;
      request.fields['tag_issue'] = finalIssue.tagIssue;
      request.fields['penanganan'] = finalIssue.penanganan;
      request.fields['status'] = finalIssue.status;
      request.fields['lama_perbaikan'] = finalIssue.lamaPerbaikan.toString();
      request.fields['penyebab'] = finalIssue.penyebab;
      request.fields['month'] = _getMonthString(finalIssue.tgl);

      request.files.add(await http.MultipartFile.fromPath('evide', localPath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final insertedJson = json.decode(response.body) as Map<String, dynamic>;
        return insertedJson['id'] as int;
      } else {
        throw Exception('Gagal menambahkan kendala dengan upload gambar.');
      }
    } else {
      // Kirim POST JSON biasa jika tidak ada file lokal baru
      final bodyMap = finalIssue.toMap();
      bodyMap.remove('id');
      bodyMap['month'] = _getMonthString(finalIssue.tgl);

      final response = await http.post(
        Uri.parse('$baseUrl/issues'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bodyMap),
      );

      if (response.statusCode == 201) {
        final insertedJson = json.decode(response.body) as Map<String, dynamic>;
        return insertedJson['id'] as int;
      } else {
        throw Exception('Gagal menambahkan kendala.');
      }
    }
  }

  @override
  Future<void> updateIssue(Issue issue) async {
    _invalidateCache();

    final String? localPath = issue.evide;

    // Jika eviden berisi file lokal baru, lakukan upload via Multipart PUT
    if (localPath != null && !localPath.startsWith('http') && localPath.isNotEmpty) {
      var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/issues/${issue.id}'));
      
      request.fields['tgl'] = issue.tgl.toIso8601String();
      request.fields['area'] = issue.area;
      request.fields['kategori'] = issue.kategori;
      request.fields['kode_issue'] = issue.kodeIssue;
      request.fields['issue'] = issue.issue;
      request.fields['tag_issue'] = issue.tagIssue;
      request.fields['penanganan'] = issue.penanganan;
      request.fields['status'] = issue.status;
      request.fields['lama_perbaikan'] = issue.lamaPerbaikan.toString();
      request.fields['penyebab'] = issue.penyebab;
      request.fields['month'] = _getMonthString(issue.tgl);

      request.files.add(await http.MultipartFile.fromPath('evide', localPath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Gagal memperbarui kendala dengan gambar baru.');
      }
    } else {
      // Kirim PUT JSON biasa
      final bodyMap = issue.toMap();
      bodyMap['month'] = _getMonthString(issue.tgl);

      final response = await http.put(
        Uri.parse('$baseUrl/issues/${issue.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bodyMap),
      );

      if (response.statusCode != 200) {
        throw Exception('Gagal memperbarui kendala.');
      }
    }
  }

  @override
  Future<void> deleteIssue(int id) async {
    _invalidateCache();

    final response = await http.delete(Uri.parse('$baseUrl/issues/$id'));
    if (response.statusCode != 200) {
      throw Exception('Gagal menghapus kendala.');
    }
  }

  @override
  Future<void> importIssues(List<Issue> issues) async {
    _invalidateCache();
    
    // Kirim secara sequential/loop
    for (var issue in issues) {
      await insertIssue(issue);
    }
  }

  @override
  Future<void> clearAllIssues() async {
    _invalidateCache();
    // Di SQLite server, cara paling gampang hapus satu persatu atau buat custom endpoint.
    // Demi kehandalan, panggil endpoint delete untuk semua item.
    final List<Issue> current = await getAllIssues();
    for (var issue in current) {
      if (issue.id != null) {
        await deleteIssue(issue.id!);
      }
    }
  }

  @override
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final List<Issue> all = await getAllIssues();
    
    final total = all.length;
    if (total == 0) {
      return {
        'total': 0,
        'solved': 0,
        'pending': 0,
        'byArea': <String, int>{},
        'byKategori': <String, int>{},
        'byPenanganan': <String, int>{},
        'longestPending': <Issue>[],
      };
    }

    final solved = all.where((element) => element.status.toLowerCase() == 'solved').length;
    final pending = total - solved;

    final Map<String, int> byArea = {};
    final Map<String, int> byKategori = {};
    final Map<String, int> byPenanganan = {};

    for (var issue in all) {
      byArea[issue.area] = (byArea[issue.area] ?? 0) + 1;
      byKategori[issue.kategori] = (byKategori[issue.kategori] ?? 0) + 1;
      byPenanganan[issue.penanganan] = (byPenanganan[issue.penanganan] ?? 0) + 1;
    }

    final longestPending = all.where((element) => element.status.toLowerCase() == 'pending').toList();
    longestPending.sort((a, b) => b.lamaPerbaikan.compareTo(a.lamaPerbaikan));

    return {
      'total': total,
      'solved': solved,
      'pending': pending,
      'byArea': byArea,
      'byKategori': byKategori,
      'byPenanganan': byPenanganan,
      'longestPending': longestPending.take(5).toList(),
    };
  }

  @override
  Future<String> generateNextIssueCode() async {
    final List<Issue> all = await getAllIssues();
    int maxNum = 0;
    for (var item in all) {
      final String code = item.kodeIssue;
      if (code.startsWith('ISS-')) {
        final String numStr = code.replaceFirst('ISS-', '');
        final int? num = int.tryParse(numStr);
        if (num != null && num > maxNum) {
          maxNum = num;
        }
      }
    }
    return 'ISS-${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  @override
  Future<List<Map<String, String>>> getUniqueIssues() async {
    final List<Issue> all = await getAllIssues();
    final Map<String, Map<String, String>> unique = {};
    for (var item in all) {
      if (item.kodeIssue.isNotEmpty) {
        unique[item.kodeIssue] = {
          'kode_issue': item.kodeIssue,
          'issue': item.issue,
          'kategori': item.kategori,
          'penyebab': item.penyebab,
        };
      }
    }
    final sortedList = unique.values.toList();
    sortedList.sort((a, b) => a['kode_issue']!.compareTo(b['kode_issue']!));
    return sortedList;
  }

  // Helper untuk mendapatkan nama bulan dari DateTime
  String _getMonthString(DateTime date) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    if (date.month >= 1 && date.month <= 12) {
      return months[date.month - 1];
    }
    return 'JAN';
  }
}
