import '../models/issue.dart';
import 'issue_repository.dart';

/// A skeleton repository ready for Firebase Firestore integration.
/// Simply replace the stubs with active Firestore calls when the backend credentials are provided.
class FirebaseIssueRepository implements IssueRepository {
  // Mock internal list for development/fallback when Firebase isn't initialized yet
  final List<Issue> _mockFirebaseStorage = [];

  @override
  Future<List<Issue>> getAllIssues({String? search, String? area, String? kategori, String? status, bool? incompleteOnly}) async {
    // Firestore example:
    // Query query = FirebaseFirestore.instance.collection('issues');
    // if (area != null) query = query.where('area', isEqualTo: area);
    // ...
    // QuerySnapshot snapshot = await query.get();
    // return snapshot.docs.map((doc) => Issue.fromMap(doc.data())).toList();

    List<Issue> results = List.from(_mockFirebaseStorage);
    if (incompleteOnly == true) {
      results = results.where((item) => 
        item.evide == null || item.evide!.isEmpty ||
        item.penyebab.isEmpty ||
        item.penanganan.isEmpty
      ).toList();
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      results = results.where((item) => 
        item.issue.toLowerCase().contains(s) || 
        item.penyebab.toLowerCase().contains(s) ||
        item.penanganan.toLowerCase().contains(s)
      ).toList();
    }
    if (area != null && area != 'All') {
      results = results.where((item) => item.area == area).toList();
    }
    if (kategori != null && kategori != 'All') {
      results = results.where((item) => item.kategori == kategori).toList();
    }
    if (status != null && status != 'All') {
      results = results.where((item) => item.status == status).toList();
    }
    results.sort((a, b) => b.tgl.compareTo(a.tgl));
    return results;
  }

  @override
  Future<Issue> getIssueById(int id) async {
    return _mockFirebaseStorage.firstWhere((element) => element.id == id);
  }

  @override
  Future<int> insertIssue(Issue issue) async {
    Issue finalIssue = issue;
    if (issue.kodeIssue.isEmpty) {
      final code = await generateNextIssueCode();
      finalIssue = issue.copyWith(kodeIssue: code);
    }
    final newId = _mockFirebaseStorage.length + 1;
    final newIssue = finalIssue.copyWith(id: newId);
    _mockFirebaseStorage.add(newIssue);
    await recalculateDurations();
    return newId;
  }

  @override
  Future<void> updateIssue(Issue issue) async {
    if (issue.kodeIssue.isNotEmpty) {
      for (var i = 0; i < _mockFirebaseStorage.length; i++) {
        if (_mockFirebaseStorage[i].kodeIssue == issue.kodeIssue) {
          _mockFirebaseStorage[i] = issue.copyWith(id: _mockFirebaseStorage[i].id);
        }
      }
      await recalculateDurations();
      return;
    }

    final index = _mockFirebaseStorage.indexWhere((element) => element.id == issue.id);
    if (index != -1) {
      _mockFirebaseStorage[index] = issue;
      await recalculateDurations();
    }
  }

  @override
  Future<void> deleteIssue(int id) async {
    _mockFirebaseStorage.removeWhere((element) => element.id == id);
    await recalculateDurations();
  }

  @override
  Future<void> importIssues(List<Issue> issues) async {
    String nextCode = await generateNextIssueCode();
    int nextNum = int.tryParse(nextCode.replaceFirst('ISS-', '')) ?? 1;
    final Map<String, String> descToCode = {};
    for (var item in _mockFirebaseStorage) {
      if (item.kodeIssue.isNotEmpty) {
        descToCode[item.issue.trim().toLowerCase()] = item.kodeIssue;
      }
    }

    int currentId = _mockFirebaseStorage.length;
    for (var issue in issues) {
      currentId++;
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
      _mockFirebaseStorage.add(finalIssue.copyWith(id: currentId));
    }
    await recalculateDurations();
  }

  @override
  Future<void> clearAllIssues() async {
    _mockFirebaseStorage.clear();
  }

  Future<void> recalculateDurations() async {
    _mockFirebaseStorage.sort((a, b) => a.tgl.compareTo(b.tgl));
    final Map<String, Issue> lastSeenPending = {};

    for (var i = 0; i < _mockFirebaseStorage.length; i++) {
      final issue = _mockFirebaseStorage[i];
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

      _mockFirebaseStorage[i] = issue.copyWith(perulanganMasalah: finalDuration);
      lastSeenPending[key] = _mockFirebaseStorage[i];
    }
  }

  @override
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final total = _mockFirebaseStorage.length;
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

    final solved = _mockFirebaseStorage.where((element) => element.status == 'solved').length;
    final pending = total - solved;

    final Map<String, int> byArea = {};
    final Map<String, int> byKategori = {};
    final Map<String, int> byPenanganan = {};

    for (var issue in _mockFirebaseStorage) {
      byArea[issue.area] = (byArea[issue.area] ?? 0) + 1;
      byKategori[issue.kategori] = (byKategori[issue.kategori] ?? 0) + 1;
      byPenanganan[issue.penanganan] = (byPenanganan[issue.penanganan] ?? 0) + 1;
    }

    final longestPending = _mockFirebaseStorage
        .where((element) => element.status == 'pending')
        .toList();
    longestPending.sort((a, b) => b.perulanganMasalah.compareTo(a.perulanganMasalah));

    final uniqueCodes = _mockFirebaseStorage
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
      'uniqueIssuesCount': uniqueIssuesCount,
    };
  }

  @override
  Future<String> generateNextIssueCode() async {
    final uniqueCodes = _mockFirebaseStorage
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
    final Map<String, Map<String, String>> unique = {};
    for (var item in _mockFirebaseStorage) {
      if (item.kodeIssue.isNotEmpty) {
        unique[item.kodeIssue] = {
          'kode_issue': item.kodeIssue,
          'issue': item.issue,
          'kategori': item.kategori,
          'penyebab': item.penyebab,
          'area': item.area,
          'tag_detail': item.tagDetail,
        };
      }
    }
    final sortedList = unique.values.toList();
    sortedList.sort((a, b) => a['kode_issue']!.compareTo(b['kode_issue']!));
    return sortedList;
  }

  @override
  void clearCache() {
    print('[FirebaseIssueRepository] clearCache called (no-op for mock firebase storage)');
  }
}
