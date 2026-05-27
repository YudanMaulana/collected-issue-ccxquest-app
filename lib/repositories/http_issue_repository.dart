import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/issue.dart';
import 'issue_repository.dart';

/// A robust REST HTTP implementation of the IssueRepository interface.
/// Connects to the standalone Express & SQLite backend server.
/// Features a memory-cache layer, transparent multipart file upload, and verbose debug logging.
class HttpIssueRepository implements IssueRepository {
  // Base URL of the standalone backend server
  final String baseUrl;

  HttpIssueRepository({this.baseUrl = 'http://77.78.88.3:5001/api'}) {
    print('[HttpIssueRepository] Inisialisasi dengan Base URL: $baseUrl');
  }

  // Cache Layer variables
  List<Issue>? _cachedIssues;
  bool _isCacheDirty = true;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 2);

  // Helper to invalidate cache on mutations
  void _invalidateCache() {
    print('[HttpIssueRepository] Invalidate cache lokal (Cache ditandai kotor/dirty).');
    _isCacheDirty = true;
    _cachedIssues = null;
  }

  @override
  Future<List<Issue>> getAllIssues({String? search, String? area, String? kategori, String? status, bool? incompleteOnly}) async {
    print('[HttpIssueRepository] Memanggil getAllIssues(). Filter: search=$search, area=$area, kategori=$kategori, status=$status');
    
    // 1. Fetch dari server jika cache kotor, kosong, atau expired
    if (_isCacheDirty || 
        _cachedIssues == null || 
        _lastFetchTime == null || 
        DateTime.now().difference(_lastFetchTime!) > _cacheDuration) {
      
      final url = '$baseUrl/issues';
      print('[HttpIssueRepository] Melakukan HTTP GET ke server: $url');
      
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        print('[HttpIssueRepository] Respons diterima. Status HTTP: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body) as List<dynamic>;
          print('[HttpIssueRepository] Berhasil parse data JSON. Jumlah: ${data.length} baris.');
          _cachedIssues = data.map((jsonMap) => Issue.fromMap(jsonMap as Map<String, dynamic>)).toList();
          
          _lastFetchTime = DateTime.now();
          _isCacheDirty = false;
        } else {
          print('[HttpIssueRepository ERROR] Server mengembalikan status error: ${response.statusCode} - ${response.body}');
          throw Exception('Gagal mengambil data dari server: ${response.statusCode}');
        }
      } catch (e) {
        print('[HttpIssueRepository EXCEPTION] GAGAL MENGHUBUNGI SERVER pada $url! Error: $e');
        rethrow;
      }
    } else {
      print('[HttpIssueRepository] Menggunakan cache lokal (Usia cache: ${DateTime.now().difference(_lastFetchTime!).inSeconds} detik).');
    }

    // 2. Perform local filtering
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

    print('[HttpIssueRepository] Mengembalikan ${filtered.length} baris data setelah filter.');
    return filtered;
  }

  @override
  Future<Issue> getIssueById(int id) async {
    print('[HttpIssueRepository] Memanggil getIssueById(id: $id)');
    if (_cachedIssues != null && !_isCacheDirty) {
      try {
        final cached = _cachedIssues!.firstWhere((element) => element.id == id);
        print('[HttpIssueRepository] Detail ID $id ditemukan di cache.');
        return cached;
      } catch (_) {}
    }
    
    final url = '$baseUrl/issues/$id';
    print('[HttpIssueRepository] Melakukan HTTP GET ke detail: $url');
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        print('[HttpIssueRepository] Detail ID $id berhasil ditemukan di server.');
        return Issue.fromMap(json.decode(response.body) as Map<String, dynamic>);
      } else {
        print('[HttpIssueRepository ERROR] Detail ID $id tidak ditemukan di server.');
        throw Exception('Data kendala tidak ditemukan.');
      }
    } catch (e) {
      print('[HttpIssueRepository EXCEPTION] Gagal mengambil detail ID $id: $e');
      rethrow;
    }
  }

  @override
  Future<int> insertIssue(Issue issue) async {
    print('[HttpIssueRepository] Memanggil insertIssue() untuk issue: "${issue.issue}"');
    _invalidateCache();

    Issue finalIssue = issue;
    if (issue.kodeIssue.isEmpty) {
      final code = await generateNextIssueCode();
      finalIssue = issue.copyWith(kodeIssue: code);
    }

    final String? localPath = finalIssue.evide;

    try {
      if (localPath != null && !localPath.startsWith('http') && localPath.isNotEmpty) {
        final url = '$baseUrl/issues';
        print('[HttpIssueRepository] Mengirim Multipart POST (dengan file lokal) ke: $url');
        
        var request = http.MultipartRequest('POST', Uri.parse(url));
        
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

        print('[HttpIssueRepository] Melampirkan file gambar: $localPath');
        request.files.add(await http.MultipartFile.fromPath('evide', localPath));

        var streamedResponse = await request.send().timeout(const Duration(seconds: 15));
        var response = await http.Response.fromStream(streamedResponse);

        print('[HttpIssueRepository] Multipart respons diterima. Status: ${response.statusCode}');
        if (response.statusCode == 201) {
          final insertedJson = json.decode(response.body) as Map<String, dynamic>;
          print('[HttpIssueRepository] Sukses menyimpan data. ID baru: ${insertedJson['id']}');
          return insertedJson['id'] as int;
        } else {
          throw Exception('Gagal menyimpan data ke server: ${response.body}');
        }
      } else {
        final url = '$baseUrl/issues';
        print('[HttpIssueRepository] Mengirim JSON POST ke: $url');
        
        final bodyMap = finalIssue.toMap();
        bodyMap.remove('id');
        bodyMap['month'] = _getMonthString(finalIssue.tgl);

        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(bodyMap),
        ).timeout(const Duration(seconds: 8));

        print('[HttpIssueRepository] Respons diterima. Status: ${response.statusCode}');
        if (response.statusCode == 201) {
          final insertedJson = json.decode(response.body) as Map<String, dynamic>;
          print('[HttpIssueRepository] Sukses menyimpan data. ID baru: ${insertedJson['id']}');
          return insertedJson['id'] as int;
        } else {
          throw Exception('Gagal menyimpan data ke server: ${response.body}');
        }
      }
    } catch (e) {
      print('[HttpIssueRepository EXCEPTION] Gagal menyimpan issue baru: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateIssue(Issue issue) async {
    print('[HttpIssueRepository] Memanggil updateIssue() untuk ID: ${issue.id}');
    _invalidateCache();

    final String? localPath = issue.evide;
    final url = '$baseUrl/issues/${issue.id}';

    try {
      if (localPath != null && !localPath.startsWith('http') && localPath.isNotEmpty) {
        print('[HttpIssueRepository] Mengirim Multipart PUT (dengan file gambar baru) ke: $url');
        
        var request = http.MultipartRequest('PUT', Uri.parse(url));
        
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

        print('[HttpIssueRepository] Melampirkan file gambar baru: $localPath');
        request.files.add(await http.MultipartFile.fromPath('evide', localPath));

        var streamedResponse = await request.send().timeout(const Duration(seconds: 15));
        var response = await http.Response.fromStream(streamedResponse);

        print('[HttpIssueRepository] Multipart PUT respons diterima. Status: ${response.statusCode}');
        if (response.statusCode != 200) {
          throw Exception('Gagal memperbarui data di server: ${response.body}');
        }
      } else {
        print('[HttpIssueRepository] Mengirim JSON PUT ke: $url');
        
        final bodyMap = issue.toMap();
        bodyMap['month'] = _getMonthString(issue.tgl);

        final response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(bodyMap),
        ).timeout(const Duration(seconds: 8));

        print('[HttpIssueRepository] Respons diterima. Status: ${response.statusCode}');
        if (response.statusCode != 200) {
          throw Exception('Gagal memperbarui data di server: ${response.body}');
        }
      }
    } catch (e) {
      print('[HttpIssueRepository EXCEPTION] Gagal memperbarui data: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteIssue(int id) async {
    print('[HttpIssueRepository] Memanggil deleteIssue(id: $id)');
    _invalidateCache();

    final url = '$baseUrl/issues/$id';
    print('[HttpIssueRepository] Mengirim HTTP DELETE ke: $url');
    
    try {
      final response = await http.delete(Uri.parse(url)).timeout(const Duration(seconds: 8));
      print('[HttpIssueRepository] Respons diterima. Status: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Gagal menghapus kendala di server: ${response.body}');
      }
    } catch (e) {
      print('[HttpIssueRepository EXCEPTION] Gagal melakukan request delete: $e');
      rethrow;
    }
  }

  @override
  Future<void> importIssues(List<Issue> issues) async {
    print('[HttpIssueRepository] Memanggil importIssues() untuk ${issues.length} data.');
    _invalidateCache();
    for (var issue in issues) {
      await insertIssue(issue);
    }
  }

  @override
  Future<void> clearAllIssues() async {
    print('[HttpIssueRepository] Memanggil clearAllIssues().');
    _invalidateCache();
    final List<Issue> current = await getAllIssues();
    for (var issue in current) {
      if (issue.id != null) {
        await deleteIssue(issue.id!);
      }
    }
  }

  @override
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    print('[HttpIssueRepository] Memanggil getDashboardMetrics()');
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

  String _getMonthString(DateTime date) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    if (date.month >= 1 && date.month <= 12) {
      return months[date.month - 1];
    }
    return 'JAN';
  }
}
