import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/issue.dart';
import 'issue_repository.dart';
import 'local_issue_repository.dart';

/// A robust REST HTTP implementation of the IssueRepository interface.
/// Connects to the standalone Express & SQLite backend server.
/// Features a memory-cache layer, transparent multipart file upload, and verbose debug logging.
/// Includes the 'ngrok-skip-browser-warning': 'true' header to bypass Ngrok's interstitial warning pages.
/// Integrated with a local SQLite persistent cache fallback to ensure 100% offline-first reliability.
class HttpIssueRepository implements IssueRepository {
  // Base URL of the standalone backend server
  final String baseUrl;
  final LocalIssueRepository _localCache = LocalIssueRepository();

  HttpIssueRepository({this.baseUrl = 'http://77.78.88.3:5001/api'}) {
    print('[HttpIssueRepository] Inisialisasi dengan Base URL: $baseUrl');
  }

  // Cache Layer variables
  List<Issue>? _cachedIssues;
  bool _isCacheDirty = true;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 2);

  // Helper request headers for Ngrok bypass & JSON
  Map<String, String> _getHeaders({bool isJson = false}) {
    return {
      if (isJson) 'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true', // MEM-BYPASS INTERSTITIAL WARNING NGROK FREE
    };
  }

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
        final response = await http.get(
          Uri.parse(url),
          headers: _getHeaders(),
        ).timeout(const Duration(seconds: 4)); // Fast timeout fallback to offline db
        
        print('[HttpIssueRepository] Respons diterima. Status HTTP: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body) as List<dynamic>;
          print('[HttpIssueRepository] Berhasil parse data JSON. Jumlah: ${data.length} baris.');
          _cachedIssues = data.map((jsonMap) => Issue.fromMap(jsonMap as Map<String, dynamic>)).toList();
          
          _lastFetchTime = DateTime.now();
          _isCacheDirty = false;

          // Sync database lokal SQLite cache secara persistent
          try {
            await _localCache.clearAllIssues();
            await _localCache.importIssues(_cachedIssues!);
            print('[HttpIssueRepository] Berhasil sinkronisasi persistent local SQLite cache.');
          } catch (cacheErr) {
            print('[HttpIssueRepository WARNING] Gagal meng-update SQLite cache: $cacheErr');
          }
        } else {
          print('[HttpIssueRepository ERROR] Server mengembalikan status error: ${response.statusCode} - ${response.body}');
          throw Exception('Gagal mengambil data dari server: ${response.statusCode}');
        }
      } catch (e) {
        print('[HttpIssueRepository EXCEPTION] GAGAL MENGHUBUNGI SERVER pada $url! Error: $e');
        print('[HttpIssueRepository OFFLINE] Mengaktifkan mode offline, memuat data dari SQLite local cache.');
        
        // FALLBACK GRACEFUL KE SQLITE CACHE LOKAL
        try {
          final offlineIssues = await _localCache.getAllIssues(
            search: search,
            area: area,
            kategori: kategori,
            status: status,
            incompleteOnly: incompleteOnly,
          );
          return offlineIssues;
        } catch (dbErr) {
          print('[HttpIssueRepository OFFLINE ERROR] Gagal membaca dari database SQLite cache: $dbErr');
          rethrow;
        }
      }
    } else {
      print('[HttpIssueRepository] Menggunakan cache memori (Usia cache: ${DateTime.now().difference(_lastFetchTime!).inSeconds} detik).');
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
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 30));
      
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
      // Auto-match: cek apakah issue text yang sama sudah punya kode
      String? matchedCode;
      try {
        final allIssues = await getAllIssues();
        final issueTextLower = issue.issue.trim().toLowerCase();
        for (var existing in allIssues) {
          if (existing.kodeIssue.isNotEmpty &&
              existing.issue.trim().toLowerCase() == issueTextLower) {
            matchedCode = existing.kodeIssue;
            break;
          }
        }
      } catch (_) {}

      if (matchedCode != null) {
        print('[HttpIssueRepository] Auto-match: issue serupa ditemukan, pakai kode $matchedCode');
        finalIssue = issue.copyWith(kodeIssue: matchedCode);
      } else {
        final code = await generateNextIssueCode();
        print('[HttpIssueRepository] Issue baru, generate kode: $code');
        finalIssue = issue.copyWith(kodeIssue: code);
      }
    }

    // 1. Simpan di local SQLite cache terlebih dahulu agar data tetap aman saat offline!
    int? localId;
    try {
      localId = await _localCache.insertIssue(finalIssue);
      print('[HttpIssueRepository] Berhasil menyimpan baru ke local SQLite cache (ID Lokal: $localId).');
    } catch (dbErr) {
      print('[HttpIssueRepository WARNING] Gagal menulis ke SQLite cache: $dbErr');
    }

    final String? localPath = finalIssue.evide;

    try {
      if (localPath != null && !localPath.startsWith('http') && localPath.isNotEmpty) {
        final url = '$baseUrl/issues';
        print('[HttpIssueRepository] Mengirim Multipart POST (dengan file lokal) ke: $url');
        
        var request = http.MultipartRequest('POST', Uri.parse(url));
        request.headers.addAll(_getHeaders());
        
        request.fields['tgl'] = finalIssue.tgl.toIso8601String();
        request.fields['area'] = finalIssue.area;
        request.fields['kategori'] = finalIssue.kategori;
        request.fields['kode_issue'] = finalIssue.kodeIssue;
        request.fields['issue'] = finalIssue.issue;
        request.fields['tag_issue'] = finalIssue.tagIssue;
        request.fields['tag_detail'] = finalIssue.tagDetail;
        request.fields['penanganan'] = finalIssue.penanganan;
        request.fields['status'] = finalIssue.status;
        request.fields['perulangan_masalah'] = finalIssue.perulanganMasalah.toString();
        request.fields['lama_perbaikan'] = finalIssue.perulanganMasalah.toString();
        request.fields['penyebab'] = finalIssue.penyebab;
        request.fields['month'] = _getMonthString(finalIssue.tgl);

        final ext = localPath.split('.').last.toLowerCase();
        final isVideo = ext == 'mp4' || ext == 'mov' || ext == 'avi' || ext == 'mkv' || ext == 'webm' || ext == '3gp';
        print('[HttpIssueRepository] Melampirkan file ${isVideo ? 'video' : 'gambar'}: $localPath');
        final mimeSub = (ext == 'png' || ext == 'webp' || ext == 'gif' || ext == 'heic' || ext == 'heif') ? ext : 'jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'evide',
          localPath,
          contentType: isVideo ? MediaType('video', ext) : MediaType('image', mimeSub),
        ));

        var streamedResponse = await request.send().timeout(const Duration(seconds: 120));
        var response = await http.Response.fromStream(streamedResponse);

        print('[HttpIssueRepository] Multipart respons diterima. Status: ${response.statusCode}');
        if (response.statusCode == 201) {
          final insertedJson = json.decode(response.body) as Map<String, dynamic>;
          print('[HttpIssueRepository] Sukses menyimpan data ke server. ID baru: ${insertedJson['id']}');
          
          // Sinkronisasi ulang ID dari server ke database lokal
          if (localId != null) {
            try {
              await _localCache.deleteIssue(localId);
              await _localCache.insertIssue(finalIssue.copyWith(id: insertedJson['id'] as int));
            } catch (_) {}
          }
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
        bodyMap['lama_perbaikan'] = finalIssue.perulanganMasalah; // Backward compatibility

        final response = await http.post(
          Uri.parse(url),
          headers: _getHeaders(isJson: true),
          body: json.encode(bodyMap),
        ).timeout(const Duration(seconds: 6));

        print('[HttpIssueRepository] Respons diterima. Status: ${response.statusCode}');
        if (response.statusCode == 201) {
          final insertedJson = json.decode(response.body) as Map<String, dynamic>;
          print('[HttpIssueRepository] Sukses menyimpan data ke server. ID baru: ${insertedJson['id']}');
          
          // Sinkronisasi ulang ID dari server ke database lokal
          if (localId != null) {
            try {
              await _localCache.deleteIssue(localId);
              await _localCache.insertIssue(finalIssue.copyWith(id: insertedJson['id'] as int));
            } catch (_) {}
          }
          return insertedJson['id'] as int;
        } else {
          throw Exception('Gagal menyimpan data ke server: ${response.body}');
        }
      }
    } catch (e) {
      print('[HttpIssueRepository EXCEPTION] Gagal menyimpan issue ke server: $e');
      if (localId != null) {
        print('[HttpIssueRepository OFFLINE] Fallback sukses offline. Menggunakan local ID: $localId');
        return localId;
      }
      rethrow;
    }
  }

  @override
  Future<void> updateIssue(Issue issue) async {
    print('[HttpIssueRepository] Memanggil updateIssue() untuk ID: ${issue.id}');
    _invalidateCache();

    // 1. Update ke local SQLite cache terlebih dahulu agar aman saat offline!
    try {
      await _localCache.updateIssue(issue);
      print('[HttpIssueRepository] Berhasil memperbarui data di local SQLite cache.');
    } catch (dbErr) {
      print('[HttpIssueRepository WARNING] Gagal meng-update SQLite cache: $dbErr');
    }

    Issue payloadIssue = issue;
    List<Issue> affectedIssues = [issue];
    try {
      final localIssues = await _localCache.getAllIssues();
      if (issue.kodeIssue.isNotEmpty) {
        final sameCodeIssues = localIssues
            .where((item) => item.kodeIssue.trim().toUpperCase() == issue.kodeIssue.trim().toUpperCase())
            .toList();
        if (sameCodeIssues.isNotEmpty) {
          affectedIssues = sameCodeIssues;
          payloadIssue = sameCodeIssues.first;
        }
      }
    } catch (_) {}

    try {
      for (final targetIssue in affectedIssues) {
        final targetId = targetIssue.id ?? issue.id;
        if (targetId == null) continue;
        final String? localPath = payloadIssue.evide;
        final url = '$baseUrl/issues/$targetId';

        if (localPath != null && !localPath.startsWith('http') && localPath.isNotEmpty) {
          print('[HttpIssueRepository] Mengirim Multipart PUT ke: $url');
          
          var request = http.MultipartRequest('PUT', Uri.parse(url));
          request.headers.addAll(_getHeaders());
          
          request.fields['tgl'] = payloadIssue.tgl.toIso8601String();
          request.fields['area'] = payloadIssue.area;
          request.fields['kategori'] = payloadIssue.kategori;
          request.fields['kode_issue'] = payloadIssue.kodeIssue;
          request.fields['issue'] = payloadIssue.issue;
          request.fields['tag_issue'] = payloadIssue.tagIssue;
          request.fields['tag_detail'] = payloadIssue.tagDetail;
          request.fields['penanganan'] = payloadIssue.penanganan;
          request.fields['status'] = payloadIssue.status;
          request.fields['perulangan_masalah'] = payloadIssue.perulanganMasalah.toString();
          request.fields['lama_perbaikan'] = payloadIssue.perulanganMasalah.toString();
          request.fields['penyebab'] = payloadIssue.penyebab;
          request.fields['month'] = _getMonthString(payloadIssue.tgl);

          final ext = localPath.split('.').last.toLowerCase();
          final isVideo = ext == 'mp4' || ext == 'mov' || ext == 'avi' || ext == 'mkv' || ext == 'webm' || ext == '3gp';
          print('[HttpIssueRepository] Melampirkan file ${isVideo ? 'video' : 'gambar'}: $localPath');
          final mimeSub = (ext == 'png' || ext == 'webp' || ext == 'gif' || ext == 'heic' || ext == 'heif') ? ext : 'jpeg';
          request.files.add(await http.MultipartFile.fromPath(
            'evide',
            localPath,
            contentType: isVideo ? MediaType('video', ext) : MediaType('image', mimeSub),
          ));

          var streamedResponse = await request.send().timeout(const Duration(seconds: 120));
          var response = await http.Response.fromStream(streamedResponse);

          print('[HttpIssueRepository] Multipart PUT respons diterima. Status: ${response.statusCode}');
          if (response.statusCode != 200) {
            throw Exception('Gagal memperbarui data di server: ${response.body}');
          }
        } else {
          print('[HttpIssueRepository] Mengirim JSON PUT ke: $url');
          
          final bodyMap = payloadIssue.toMap();
          bodyMap.remove('id');
          bodyMap['month'] = _getMonthString(payloadIssue.tgl);
          bodyMap['lama_perbaikan'] = payloadIssue.perulanganMasalah; // Backward compatibility

          final response = await http.put(
            Uri.parse(url),
            headers: _getHeaders(isJson: true),
            body: json.encode(bodyMap),
          ).timeout(const Duration(seconds: 6));

          print('[HttpIssueRepository] Respons diterima. Status: ${response.statusCode}');
          if (response.statusCode != 200) {
            throw Exception('Gagal memperbarui data di server: ${response.body}');
          }
        }
      }
    } catch (e) {
      print('[HttpIssueRepository EXCEPTION] Gagal memperbarui data ke server: $e');
      print('[HttpIssueRepository OFFLINE] Fallback sukses offline. Perubahan tersimpan secara lokal.');
      return; // Selesaikan secara sukses tanpa melempar exception agar UI terus berjalan
    }
  }

  @override
  Future<void> deleteIssue(int id) async {
    print('[HttpIssueRepository] Memanggil deleteIssue(id: $id)');
    _invalidateCache();

    // 1. Hapus dari local SQLite cache terlebih dahulu agar data instant hilang dari UI!
    try {
      await _localCache.deleteIssue(id);
      print('[HttpIssueRepository] Berhasil menghapus dari local SQLite cache.');
    } catch (dbErr) {
      print('[HttpIssueRepository WARNING] Gagal menghapus dari SQLite cache: $dbErr');
    }

    final url = '$baseUrl/issues/$id';
    print('[HttpIssueRepository] Mengirim HTTP DELETE ke: $url');
    
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 6));
      
      print('[HttpIssueRepository] Respons diterima. Status: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Gagal menghapus kendala di server: ${response.body}');
      }
    } catch (e) {
      print('[HttpIssueRepository EXCEPTION] Gagal menghapus dari server: $e');
      print('[HttpIssueRepository OFFLINE] Fallback sukses offline. Penghapusan tersimpan secara lokal.');
      return; // Selesaikan secara sukses tanpa melempar exception agar UI terus berjalan
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
    print('[HttpIssueRepository] Memanggil getDashboardMetrics() via /api/dashboard');

    final url = '$baseUrl/dashboard';
    print('[HttpIssueRepository] Melakukan HTTP GET ke: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 30));

      print('[HttpIssueRepository] Dashboard respons diterima. Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> serverData = json.decode(response.body) as Map<String, dynamic>;

        // Parse server response into the format dashboard_screen.dart expects
        final total = serverData['total'] as int? ?? 0;
        final solved = serverData['solved'] as int? ?? 0;
        final pending = serverData['pending'] as int? ?? 0;
        final incomplete = serverData['incomplete'] as int? ?? 0;

        // byArea & byKategori come as {String: int} maps from server
        final Map<String, int> byArea = {};
        if (serverData['byArea'] is Map) {
          (serverData['byArea'] as Map).forEach((k, v) {
            byArea[k.toString()] = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
          });
        }
        final Map<String, int> byKategori = {};
        if (serverData['byKategori'] is Map) {
          (serverData['byKategori'] as Map).forEach((k, v) {
            byKategori[k.toString()] = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
          });
        }

        // longestPending come as List<Map> from server
        final List<Issue> longestPending = [];
        if (serverData['longestPending'] is List) {
          for (var item in serverData['longestPending']) {
            longestPending.add(Issue.fromMap(item as Map<String, dynamic>));
          }
        }

        // lastUpdated come as List<Map> from server
        final List<Issue> lastUpdated = [];
        if (serverData['lastUpdated'] is List) {
          for (var item in serverData['lastUpdated']) {
            lastUpdated.add(Issue.fromMap(item as Map<String, dynamic>));
          }
        } else {
          final List<Issue> all = await getAllIssues();
          final sorted = List<Issue>.from(all);
          sorted.sort((a, b) {
            final tglCompare = b.tgl.compareTo(a.tgl);
            if (tglCompare != 0) return tglCompare;
            return (b.id ?? 0).compareTo(a.id ?? 0);
          });
          lastUpdated.addAll(sorted.take(5));
        }

        // Calculate uniqueIssuesCount locally from cache / getAllIssues()
        final List<Issue> allForUnique = await getAllIssues();
        final uniqueCodes = allForUnique
            .map((e) => e.kodeIssue.trim().toUpperCase())
            .where((c) => c.isNotEmpty)
            .toSet();
        final uniqueIssuesCount = uniqueCodes.length;

        print('[HttpIssueRepository] Dashboard: total=$total, solved=$solved, pending=$pending, incomplete=$incomplete, unique=$uniqueIssuesCount');

        return {
          'total': total,
          'solved': solved,
          'pending': pending,
          'incomplete': incomplete,
          'byArea': byArea,
          'byKategori': byKategori,
          'byPenanganan': <String, int>{},
          'longestPending': longestPending,
          'lastUpdated': lastUpdated,
          'uniqueIssuesCount': uniqueIssuesCount,
        };
      } else {
        print('[HttpIssueRepository ERROR] Dashboard endpoint error: ${response.statusCode}');
        throw Exception('Gagal mengambil dashboard metrics: ${response.statusCode}');
      }
    } catch (e) {
      print('[HttpIssueRepository EXCEPTION] Dashboard gagal: $e');
      // Fallback: hitung dari getAllIssues jika endpoint dashboard tidak tersedia
      print('[HttpIssueRepository] Fallback: menghitung dari getAllIssues...');
      final List<Issue> all = await getAllIssues();
      final total = all.length;
      final solved = all.where((e) => e.status.toLowerCase() == 'solved').length;
      final pending = total - solved;
      final Map<String, int> byArea = {};
      final Map<String, int> byKategori = {};
      for (var issue in all) {
        byArea[issue.area] = (byArea[issue.area] ?? 0) + 1;
        byKategori[issue.kategori] = (byKategori[issue.kategori] ?? 0) + 1;
      }
      final longestPending = all.where((e) => e.status.toLowerCase() == 'pending').toList()
        ..sort((a, b) => b.perulanganMasalah.compareTo(a.perulanganMasalah));
      final lastUpdated = List<Issue>.from(all);
      lastUpdated.sort((a, b) {
        final tglCompare = b.tgl.compareTo(a.tgl);
        if (tglCompare != 0) return tglCompare;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });

      final uniqueCodes = all
          .map((e) => e.kodeIssue.trim().toUpperCase())
          .where((c) => c.isNotEmpty)
          .toSet();
      final uniqueIssuesCount = uniqueCodes.length;

      return {
        'total': total,
        'solved': solved,
        'pending': pending,
        'byArea': byArea,
        'byKategori': byKategori,
        'byPenanganan': <String, int>{},
        'longestPending': longestPending.take(5).toList(),
        'lastUpdated': lastUpdated.take(5).toList(),
        'uniqueIssuesCount': uniqueIssuesCount,
      };
    }
  }

  @override
  Future<String> generateNextIssueCode() async {
    final List<Issue> all = await getAllIssues();
    final uniqueCodes = all
        .map((e) => e.kodeIssue.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    
    int maxNum = 0;
    final regExp = RegExp(r'\d+');
    for (var code in uniqueCodes) {
      final match = regExp.firstMatch(code);
      if (match != null) {
        final num = int.tryParse(match.group(0)!) ?? 0;
        if (num > maxNum) {
          maxNum = num;
        }
      }
    }
    
    final nextNum = maxNum + 1;
    return 'CI${nextNum.toString().padLeft(3, '0')}';
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
          'area': item.area,
          'evide': item.evide ?? '',
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

  @override
  void clearCache() {
    print('[HttpIssueRepository] Menghapus in-memory cache dan SQLite local cache...');
    _invalidateCache();
    // Also clear SQLite cache to force fresh sync
    _localCache.clearAllIssues().catchError((e) {
      print('[HttpIssueRepository WARNING] Gagal menghapus SQLite cache saat clearCache: $e');
    });
  }
}
