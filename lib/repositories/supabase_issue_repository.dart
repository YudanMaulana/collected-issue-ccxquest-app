import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/issue.dart';
import 'issue_repository.dart';

/// A robust Supabase implementation of the IssueRepository interface.
/// Handles PostgreSQL CRUD operations and Storage Bucket file uploads.
/// Features a memory-cache layer to minimize read requests to Supabase.
class SupabaseIssueRepository implements IssueRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Bucket name in Supabase Storage
  static const String _bucketName = 'evidences';

  // Cache Layer variables
  List<Issue>? _cachedIssues;
  bool _isCacheDirty = true;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5); // 5 minutes lifetime

  // Helper to invalidate cache on mutations
  void _invalidateCache() {
    _isCacheDirty = true;
    _cachedIssues = null;
  }

  @override
  Future<List<Issue>> getAllIssues({String? search, String? area, String? kategori, String? status, bool? incompleteOnly}) async {
    // 1. Fetch from Supabase only if cache is dirty, empty, or expired
    if (_isCacheDirty || 
        _cachedIssues == null || 
        _lastFetchTime == null || 
        DateTime.now().difference(_lastFetchTime!) > _cacheDuration) {
      
      final response = await _client.from('issues').select().order('tgl', ascending: false);
      final List<dynamic> data = response as List<dynamic>;
      _cachedIssues = data.map((json) => Issue.fromMap(json as Map<String, dynamic>)).toList();
      
      _lastFetchTime = DateTime.now();
      _isCacheDirty = false;
    }

    // 2. Perform local filtering on the cached list to minimize DB reads!
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
    // Check if we can find it in our cache first
    if (_cachedIssues != null && !_isCacheDirty) {
      try {
        return _cachedIssues!.firstWhere((element) => element.id == id);
      } catch (_) {}
    }
    
    final response = await _client.from('issues').select().eq('id', id).single();
    return Issue.fromMap(response as Map<String, dynamic>);
  }

  /// Uploads a local file to Supabase Storage and returns its public URL
  Future<String?> _uploadEvidence(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return null;
    if (localPath.startsWith('http')) return localPath; // Already uploaded

    final file = File(localPath);
    if (!await file.exists()) return null;

    final fileName = 'evidence_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    
    // Upload image file to Supabase storage bucket
    await _client.storage.from(_bucketName).upload(
      fileName,
      file,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
    );

    // Get Public URL
    final String publicUrl = _client.storage.from(_bucketName).getPublicUrl(fileName);
    return publicUrl;
  }

  @override
  Future<int> insertIssue(Issue issue) async {
    _invalidateCache();

    Issue finalIssue = issue;
    if (issue.kodeIssue.isEmpty) {
      final code = await generateNextIssueCode();
      finalIssue = issue.copyWith(kodeIssue: code);
    }

    // 1. Upload evidence photo if it is local
    String? onlineUrl = finalIssue.evide;
    if (finalIssue.evide != null && !finalIssue.evide!.startsWith('http')) {
      onlineUrl = await _uploadEvidence(finalIssue.evide);
    }

    final dataToInsert = finalIssue.copyWith(evide: onlineUrl).toMap();
    dataToInsert.remove('id');

    final response = await _client.from('issues').insert(dataToInsert).select('id').single();
    final newId = response['id'] as int;

    await recalculateDurations();
    return newId;
  }

  @override
  Future<void> updateIssue(Issue issue) async {
    _invalidateCache();

    // 1. Upload evidence photo if it is local
    String? onlineUrl = issue.evide;
    if (issue.evide != null && !issue.evide!.startsWith('http')) {
      onlineUrl = await _uploadEvidence(issue.evide);
    }

    final dataToUpdate = issue.copyWith(evide: onlineUrl).toMap();
    await _client.from('issues').update(dataToUpdate).eq('id', issue.id!);

    await recalculateDurations();
  }

  @override
  Future<void> deleteIssue(int id) async {
    _invalidateCache();

    try {
      final issue = await getIssueById(id);
      if (issue.evide != null && issue.evide!.contains(_bucketName)) {
        final uri = Uri.parse(issue.evide!);
        final fileName = uri.pathSegments.last;
        await _client.storage.from(_bucketName).remove([fileName]);
      }
    } catch (_) {}

    await _client.from('issues').delete().eq('id', id);
    await recalculateDurations();
  }

  @override
  Future<void> importIssues(List<Issue> issues) async {
    _invalidateCache();

    // We can fetch the highest numerical code and increment sequentially
    String nextCode = await generateNextIssueCode();
    int nextNum = int.tryParse(nextCode.replaceFirst('ISS-', '')) ?? 1;

    // Cache unique descriptions to map duplicate imported ones to the same code
    final Map<String, String> descToCode = {};

    // Fetch all current issues from cache or DB to map existing codes
    final List<Issue> currentIssues = await getAllIssues();
    for (var item in currentIssues) {
      if (item.kodeIssue.isNotEmpty) {
        descToCode[item.issue.trim().toLowerCase()] = item.kodeIssue;
      }
    }

    final List<Map<String, dynamic>> maps = [];
    for (var issue in issues) {
      Issue finalIssue = issue;
      if (finalIssue.kodeIssue.isEmpty) {
        final key = finalIssue.issue.trim().toLowerCase();
        if (descToCode.containsKey(key)) {
          finalIssue = finalIssue.copyWith(kodeIssue: descToCode[key]!);
        } else {
          final codeStr = 'ISS-${nextNum.toString().padLeft(3, '0')}';
          descToCode[key] = codeStr;
          finalIssue = finalIssue.copyWith(kodeIssue: codeStr);
          nextNum++;
        }
      }
      final m = finalIssue.toMap();
      m.remove('id');
      maps.add(m);
    }
    await _client.from('issues').insert(maps);
    await recalculateDurations();
  }

  @override
  Future<void> clearAllIssues() async {
    _invalidateCache();
    await _client.from('issues').delete().neq('id', -1);
  }

  /// Automatic recalculation of consecutive pending issue durations
  Future<void> recalculateDurations() async {
    // Fetch all issues chronologically
    final response = await _client.from('issues').select().order('tgl', ascending: true);
    final List<dynamic> data = response as List<dynamic>;
    if (data.isEmpty) return;

    final List<Issue> allIssues = data.map((m) => Issue.fromMap(m as Map<String, dynamic>)).toList();
    final Map<String, Issue> lastSeenPending = {};

    for (var i = 0; i < allIssues.length; i++) {
      final issue = allIssues[i];
      final key = '${issue.area.trim().toLowerCase()}|${issue.issue.trim().toLowerCase()}';
      int finalDuration = 1;

      if (lastSeenPending.containsKey(key)) {
        final prevIssue = lastSeenPending[key]!;
        if (prevIssue.status.toLowerCase() == 'pending') {
          final diff = DateTime(issue.tgl.year, issue.tgl.month, issue.tgl.day)
              .difference(DateTime(prevIssue.tgl.year, prevIssue.tgl.month, prevIssue.tgl.day))
              .inDays;
          if (diff == 1) {
            finalDuration = prevIssue.perulanganMasalah + 1;
          } else if (diff == 0) {
            finalDuration = prevIssue.perulanganMasalah;
          }
        }
      }

      if (issue.perulanganMasalah != finalDuration) {
        await _client.from('issues').update({'perulangan_masalah': finalDuration}).eq('id', issue.id!);
      }
      
      lastSeenPending[key] = issue.copyWith(perulanganMasalah: finalDuration);
    }
  }

  @override
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    // Reuse getAllIssues to leverage cache and avoid redundant queries!
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

    final solved = all.where((element) => element.status == 'solved').length;
    final pending = total - solved;

    final Map<String, int> byArea = {};
    final Map<String, int> byKategori = {};
    final Map<String, int> byPenanganan = {};

    for (var issue in all) {
      // Standardize area labels
      byArea[issue.area] = (byArea[issue.area] ?? 0) + 1;
      byKategori[issue.kategori] = (byKategori[issue.kategori] ?? 0) + 1;
      byPenanganan[issue.penanganan] = (byPenanganan[issue.penanganan] ?? 0) + 1;
    }

    final longestPending = all.where((element) => element.status == 'pending').toList();
    longestPending.sort((a, b) => b.perulanganMasalah.compareTo(a.perulanganMasalah));

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
      'byPenanganan': byPenanganan,
      'longestPending': longestPending.take(5).toList(),
      'lastUpdated': lastUpdated.take(5).toList(),
      'uniqueIssuesCount': uniqueIssuesCount,
    };
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
        };
      }
    }
    final sortedList = unique.values.toList();
    sortedList.sort((a, b) => a['kode_issue']!.compareTo(b['kode_issue']!));
    return sortedList;
  }

  @override
  void clearCache() {
    _invalidateCache();
  }
}
