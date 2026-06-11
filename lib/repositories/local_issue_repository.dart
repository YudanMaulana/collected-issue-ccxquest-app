import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/issue.dart';
import 'issue_repository.dart';

class LocalIssueRepository implements IssueRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'collected_issues.db');

    return await openDatabase(
      pathString,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE issues (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tgl TEXT NOT NULL,
            area TEXT NOT NULL,
            kategori TEXT NOT NULL,
            issue TEXT NOT NULL,
            penanganan TEXT NOT NULL,
            status TEXT NOT NULL,
<<<<<<< HEAD
            perulangan_masalah INTEGER NOT NULL DEFAULT 1,
=======
            perulangan_masalah INTEGER NOT NULL,
>>>>>>> 95fa6fef18d21218c8989d3c0f1b0c1496a4125e
            penyebab TEXT NOT NULL,
            evide TEXT,
            tag_issue TEXT,
            kode_issue TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE issues ADD COLUMN tag_issue TEXT');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE issues ADD COLUMN kode_issue TEXT');
          } catch (_) {}
          await _populateLegacyCodes(db);
        }
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE issues RENAME COLUMN lama_perbaikan TO perulangan_masalah');
          } catch (_) {
            try {
              await db.execute('ALTER TABLE issues ADD COLUMN perulangan_masalah INTEGER DEFAULT 1');
            } catch (_) {}
          }
        }
      },
    );
  }

  Future<void> _populateLegacyCodes(Database db) async {
    final List<Map<String, dynamic>> maps = await db.rawQuery('SELECT id, issue FROM issues ORDER BY id ASC');
    if (maps.isEmpty) return;

    final Map<String, String> issueToCode = {};
    int counter = 1;

    for (var row in maps) {
      final id = row['id'] as int;
      final issueText = (row['issue'] ?? '') as String;
      final key = issueText.trim().toLowerCase();
      if (key.isEmpty) continue;

      if (!issueToCode.containsKey(key)) {
        final codeStr = 'ISS-${counter.toString().padLeft(3, '0')}';
        issueToCode[key] = codeStr;
        counter++;
      }

      final code = issueToCode[key]!;
      await db.rawUpdate('UPDATE issues SET kode_issue = ? WHERE id = ?', [code, id]);
    }
  }

  @override
  Future<List<Issue>> getAllIssues({String? search, String? area, String? kategori, String? status, bool? incompleteOnly}) async {
    final db = await database;
    
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (search != null && search.isNotEmpty) {
      whereClauses.add('(issue LIKE ? OR penyebab LIKE ? OR penanganan LIKE ? OR kode_issue LIKE ?)');
      whereArgs.add('%$search%');
      whereArgs.add('%$search%');
      whereArgs.add('%$search%');
      whereArgs.add('%$search%');
    }

    if (area != null && area != 'All' && area.isNotEmpty) {
      whereClauses.add('area = ?');
      whereArgs.add(area);
    }

    if (kategori != null && kategori != 'All' && kategori.isNotEmpty) {
      whereClauses.add('kategori = ?');
      whereArgs.add(kategori);
    }

    if (status != null && status != 'All' && status.isNotEmpty) {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }

    if (incompleteOnly == true) {
      whereClauses.add('(evide IS NULL OR evide = "" OR penyebab = "" OR penanganan = "")');
    }

    final String whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT * FROM issues $whereString ORDER BY tgl DESC, id DESC',
      whereArgs,
    );

    return List.generate(maps.length, (i) {
      return Issue.fromMap(maps[i]);
    });
  }

  @override
  Future<Issue> getIssueById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'issues',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) {
      throw Exception('Issue not found');
    }
    return Issue.fromMap(maps.first);
  }

  @override
  Future<int> insertIssue(Issue issue) async {
    final db = await database;
    
    Issue finalIssue = issue;
    if (issue.kodeIssue.isEmpty) {
      final code = await generateNextIssueCode();
      finalIssue = issue.copyWith(kodeIssue: code);
    }

    // Auto-sync evidence photo for the same issue code
    if (finalIssue.kodeIssue.isNotEmpty) {
      if (finalIssue.evide == null || finalIssue.evide!.isEmpty) {
        final List<Map<String, dynamic>> existing = await db.query(
          'issues',
          columns: ['evide'],
          where: 'kode_issue = ? AND evide IS NOT NULL AND evide != ""',
          whereArgs: [finalIssue.kodeIssue],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          finalIssue = finalIssue.copyWith(evide: existing.first['evide'] as String?);
        }
      } else {
        await db.update(
          'issues',
          {'evide': finalIssue.evide},
          where: 'kode_issue = ?',
          whereArgs: [finalIssue.kodeIssue],
        );
      }
    }

    final id = await db.insert(
      'issues',
      finalIssue.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await recalculateDurations();
    return id;
  }

  @override
  Future<void> updateIssue(Issue issue) async {
    final db = await database;
    
    Issue finalIssue = issue;
    if (finalIssue.kodeIssue.isNotEmpty) {
      if (finalIssue.evide == null || finalIssue.evide!.isEmpty) {
        final List<Map<String, dynamic>> existing = await db.query(
          'issues',
          columns: ['evide'],
          where: 'kode_issue = ? AND evide IS NOT NULL AND evide != "" AND id != ?',
          whereArgs: [finalIssue.kodeIssue, finalIssue.id],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          finalIssue = finalIssue.copyWith(evide: existing.first['evide'] as String?);
        }
      } else {
        await db.update(
          'issues',
          {'evide': finalIssue.evide},
          where: 'kode_issue = ?',
          whereArgs: [finalIssue.kodeIssue],
        );
      }
    }

    await db.update(
      'issues',
      finalIssue.toMap(),
      where: 'id = ?',
      whereArgs: [finalIssue.id],
    );
    await recalculateDurations();
  }

  @override
  Future<void> deleteIssue(int id) async {
    final db = await database;
    await db.delete(
      'issues',
      where: 'id = ?',
      whereArgs: [id],
    );
    await recalculateDurations();
  }

  @override
  Future<void> importIssues(List<Issue> issues) async {
    final db = await database;
    final batch = db.batch();
    
    // We can fetch the highest numerical code and increment sequentially
    String nextCode = await generateNextIssueCode();
    int nextNum = int.tryParse(nextCode.replaceFirst('ISS-', '')) ?? 1;
    
    // Cache unique descriptions to map duplicate imported ones to the same code
    final Map<String, String> descToCode = {};
    
    // Fetch existing issues to map to existing codes first!
    final List<Map<String, dynamic>> existingResult = await db.rawQuery(
      'SELECT issue, kode_issue FROM issues WHERE kode_issue IS NOT NULL AND kode_issue != "" GROUP BY issue'
    );
    for (var row in existingResult) {
      final String desc = (row['issue'] ?? '') as String;
      final String code = (row['kode_issue'] ?? '') as String;
      descToCode[desc.trim().toLowerCase()] = code;
    }

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
      batch.insert('issues', finalIssue.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await recalculateDurations();
  }

  @override
  Future<String> generateNextIssueCode() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      "SELECT kode_issue FROM issues WHERE kode_issue IS NOT NULL AND kode_issue != ''"
    );
    final uniqueCodes = result
        .map((row) => (row['kode_issue'] ?? '').toString().trim().toUpperCase())
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
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT t.kode_issue, t.issue, t.kategori, t.penyebab, t.area,
             (SELECT evide FROM issues WHERE kode_issue = t.kode_issue AND evide IS NOT NULL AND evide != "" ORDER BY id DESC LIMIT 1) as evide
      FROM issues t
      WHERE t.kode_issue IS NOT NULL AND t.kode_issue != ""
      GROUP BY t.kode_issue
      ORDER BY t.kode_issue ASC
    ''');
    return result.map((row) => {
      'kode_issue': (row['kode_issue'] ?? '') as String,
      'issue': (row['issue'] ?? '') as String,
      'kategori': (row['kategori'] ?? '') as String,
      'penyebab': (row['penyebab'] ?? '') as String,
      'area': (row['area'] ?? '') as String,
      'evide': (row['evide'] ?? '') as String,
    }).toList();
  }

  @override
  Future<void> clearAllIssues() async {
    final db = await database;
    await db.delete('issues');
  }

  // Recalculates consecutive pending days for all issues
  Future<void> recalculateDurations() async {
    final db = await database;
    // Get all issues sorted chronologically
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT * FROM issues ORDER BY tgl ASC, id ASC'
    );
    
    if (maps.isEmpty) return;

    final List<Issue> allIssues = maps.map((m) => Issue.fromMap(m)).toList();
    
    // Map to keep track of the last issue seen for each composite key: "area|issue_lowercase"
    final Map<String, Issue> lastSeenPending = {};
    
    final batch = db.batch();

    for (var i = 0; i < allIssues.length; i++) {
      final issue = allIssues[i];
      final key = '${issue.area.trim().toLowerCase()}|${issue.issue.trim().toLowerCase()}';
      
      int finalDuration = 1;
      
      if (lastSeenPending.containsKey(key)) {
        final prevIssue = lastSeenPending[key]!;
        // Check if prevIssue was pending and consecutive (or same day)
        if (prevIssue.status.toLowerCase() == 'pending') {
          final diff = DateTime(issue.tgl.year, issue.tgl.month, issue.tgl.day)
              .difference(DateTime(prevIssue.tgl.year, prevIssue.tgl.month, prevIssue.tgl.day))
              .inDays;
          
          if (diff == 1) {
            // Consecutive day: increment
            finalDuration = prevIssue.perulanganMasalah + 1;
          } else if (diff == 0) {
            // Same day entry: inherits previous duration
            finalDuration = prevIssue.perulanganMasalah;
          } else {
            // Not consecutive: reset to 1
            finalDuration = 1;
          }
        }
      }

      // If status is solved, we still inherit the chain length, but it stops accumulating
      
      final updatedIssue = issue.copyWith(perulanganMasalah: finalDuration);
      
      // Update in DB
      batch.update(
        'issues',
        {'perulangan_masalah': finalDuration},
        where: 'id = ?',
        whereArgs: [issue.id],
      );

      // Save for subsequent consecutive checks
      lastSeenPending[key] = updatedIssue;
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final db = await database;

    // Total counts
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM issues');
    final total = totalResult.first['count'] as int;

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

    final solvedResult = await db.rawQuery("SELECT COUNT(*) as count FROM issues WHERE status = 'solved'");
    final solved = solvedResult.first['count'] as int;

    final pending = total - solved;

    // Issues by Area
    final areaMaps = await db.rawQuery('SELECT area, COUNT(*) as count FROM issues GROUP BY area');
    final Map<String, int> byArea = {};
    for (var m in areaMaps) {
      byArea[m['area'] as String] = m['count'] as int;
    }

    // Issues by Kategori
    final kategoriMaps = await db.rawQuery('SELECT kategori, COUNT(*) as count FROM issues GROUP BY kategori');
    final Map<String, int> byKategori = {};
    for (var m in kategoriMaps) {
      byKategori[m['kategori'] as String] = m['count'] as int;
    }

    // Issues by Penanganan
    final penangananMaps = await db.rawQuery('SELECT penanganan, COUNT(*) as count FROM issues GROUP BY penanganan');
    final Map<String, int> byPenanganan = {};
    for (var m in penangananMaps) {
      byPenanganan[m['penanganan'] as String] = m['count'] as int;
    }

    // Unique Issues (Distinct kode_issue count)
    final uniqueResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT kode_issue) as count FROM issues WHERE kode_issue IS NOT NULL AND kode_issue != ""'
    );
    final uniqueIssuesCount = uniqueResult.first['count'] as int? ?? 0;

    // Longest Pending Issues (ordered by recurrence count)
    final longestMaps = await db.rawQuery(
      "SELECT * FROM issues WHERE status = 'pending' ORDER BY perulangan_masalah DESC, tgl ASC LIMIT 5"
    );
    final longestPending = longestMaps.map((m) => Issue.fromMap(m)).toList();

    // Last Updated Issues (Top 5 sorted by date descending)
    final lastUpdatedMaps = await db.rawQuery(
      "SELECT * FROM issues ORDER BY tgl DESC, id DESC LIMIT 5"
    );
    final lastUpdated = lastUpdatedMaps.map((m) => Issue.fromMap(m)).toList();

    return {
      'total': total,
      'solved': solved,
      'pending': pending,
      'byArea': byArea,
      'byKategori': byKategori,
      'byPenanganan': byPenanganan,
      'longestPending': longestPending,
      'lastUpdated': lastUpdated,
      'uniqueIssuesCount': uniqueIssuesCount,
    };
  }

  @override
  void clearCache() {
    // SQLite local repository has no in-memory cache to clear
    print('[LocalIssueRepository] clearCache called (no-op for direct SQLite database)');
  }
}
