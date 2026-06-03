import 'package:intl/intl.dart';

class Issue {
  final int? id;
  final DateTime tgl;
  final String area;
  final String kategori;
  final String issue;
  final String penanganan;
  final String status; // 'pending' or 'solved'
  final int perulanganMasalah;
  final String penyebab;
  final String? evide; // URL or local path
  final String tagIssue; // Auto-calculated tag
  final String kodeIssue; // Unique tracking code

  Issue({
    this.id,
    required this.tgl,
    required this.area,
    required this.kategori,
    required this.issue,
    required this.penanganan,
    required this.status,
    required this.perulanganMasalah,
    required this.penyebab,
    this.evide,
    String? tagIssue,
    String? kodeIssue,
  }) : this.tagIssue = tagIssue ?? calculateTag(issue),
       this.kodeIssue = kodeIssue ?? '';

  // Dynamic regex tagging algorithm translated from the user's Excel formula
  static String calculateTag(String issueDesc) {
    if (issueDesc.isEmpty) return 'Lain-lain';
    final desc = issueDesc.toLowerCase();
    
    // 1. Koneksi Jaringan
    if (RegExp(r'wifi|internet|\bip\b|connect|koneksi|\blan\b|\bwol\b|delay|web|\bcctv\b|lokal|unregist|guide\s+app|sinkron').hasMatch(desc)) {
      return "Koneksi Jaringan";
    }
    // 2. Asset Display
    if (RegExp(r'videotron|led|monitor|\btv\b|sinkron|tampil|layar|blank|mirror|hologram').hasMatch(desc)) {
      return "Asset Display";
    }
    // 3. Bug Konten
    if (RegExp(r'konten|audio|sound|\bdata\b|score|skor|dengung|gambar|\bvideo\b|admin\s+app|guide\s+app|\bbug\b').hasMatch(desc)) {
      return "Bug Konten";
    }
    // 4. Lampu Penerangan
    if (RegExp(r'lampu|strap|laser|astronot').hasMatch(desc)) {
      return "Lampu Penerangan";
    }
    // 5. Sensor Input
    if (RegExp(r'scan|sensory|checkin|scanner|tap|band|tombol|sensor').hasMatch(desc)) {
      return "Sensor Input";
    }
    // 6. Software Aplikasi
    if (RegExp(r'auto\s+on|auto\s+run|hang|startup|bios|firmware|freeze|windows').hasMatch(desc)) {
      return "Software Aplikasi";
    }
    // 7. Mekanik Efek
    if (RegExp(r'maju|air|asap|gondola|train|lift|getaran|stuck|mundur|pengerjaan|pengunci|kipas|tirai').hasMatch(desc)) {
      return "Mekanik Efek";
    }
    // 8. Kerusakan Fasilitas
    if (RegExp(r'bingkai|copot|pintu|seatbelt|lepas|dinding|bocor|defect|deffect|longgar|bawah|atas|retak|akrilik|tangga|handle|toilet').hasMatch(desc)) {
      return "Kerusakan Fasilitas";
    }
    // 9. Listrik AC
    if (RegExp(r'ac|power|kabel|listrik|ups|panel|daya|psu').hasMatch(desc)) {
      return "Listrik AC";
    }
    
    return "Lain-lain";
  }

  // Check if dates are consecutive days
  static bool isConsecutiveDay(DateTime day1, DateTime day2) {
    final d1 = DateTime(day1.year, day1.month, day1.day);
    final d2 = DateTime(day2.year, day2.month, day2.day);
    return d2.difference(d1).inDays == 1;
  }

  // Parse TGL string to DateTime
  static DateTime parseTgl(String tglStr) {
    try {
      // monday, 08 December 2025 or Tuesday, 9 December 2025
      final cleaned = tglStr.replaceAll(RegExp(r'\s+'), ' ').trim();
      return DateFormat('EEEE, dd MMMM yyyy').parse(cleaned);
    } catch (e) {
      try {
        final cleaned = tglStr.replaceAll(RegExp(r'\s+'), ' ').trim();
        return DateFormat('EEEE, d MMMM yyyy').parse(cleaned);
      } catch (_) {
        try {
          return DateTime.parse(tglStr);
        } catch (_) {
          return DateTime.now();
        }
      }
    }
  }

  // Format DateTime to TGL string
  String get tglFormatted {
    return DateFormat('EEEE, dd MMMM yyyy').format(tgl);
  }

  Issue copyWith({
    int? id,
    DateTime? tgl,
    String? area,
    String? kategori,
    String? issue,
    String? penanganan,
    String? status,
    int? perulanganMasalah,
    String? penyebab,
    String? evide,
    String? tagIssue,
    String? kodeIssue,
  }) {
    return Issue(
      id: id ?? this.id,
      tgl: tgl ?? this.tgl,
      area: area ?? this.area,
      kategori: kategori ?? this.kategori,
      issue: issue ?? this.issue,
      penanganan: penanganan ?? this.penanganan,
      status: status ?? this.status,
      perulanganMasalah: perulanganMasalah ?? this.perulanganMasalah,
      penyebab: penyebab ?? this.penyebab,
      evide: evide ?? this.evide,
      tagIssue: tagIssue ?? this.tagIssue,
      kodeIssue: kodeIssue ?? this.kodeIssue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tgl': tgl.toIso8601String(),
      'area': area,
      'kategori': kategori,
      'issue': issue,
      'penanganan': penanganan,
      'status': status,
      'perulangan_masalah': perulanganMasalah,
      'penyebab': penyebab,
      'evide': evide,
      'tag_issue': tagIssue,
      'kode_issue': kodeIssue,
    };
  }

  factory Issue.fromMap(Map<String, dynamic> map) {
    final issueText = (map['issue'] ?? map['ISSUE/KENDALA'] ?? map['ISSUE\/KENDALA'] ?? '') as String;
    return Issue(
      id: map['id'] as int?,
      tgl: map['tgl'] != null ? DateTime.parse(map['tgl'] as String) : DateTime.now(),
      area: (map['area'] ?? map['AREA'] ?? '') as String,
      kategori: (map['kategori'] ?? map['KATEGORI'] ?? '') as String,
      issue: issueText,
      penanganan: (map['penanganan'] ?? map['PENANGANAN VENDOR'] ?? '') as String,
      status: (map['status'] ?? map['STATUS PERBAIKAN'] ?? 'pending') as String,
      perulanganMasalah: (map['perulangan_masalah'] ?? map['lama_perbaikan'] ?? map['LAMA PERBAIKAN'] ?? 1) is int 
          ? (map['perulangan_masalah'] ?? map['lama_perbaikan'] ?? map['LAMA PERBAIKAN'] ?? 1) as int
          : int.tryParse((map['perulangan_masalah'] ?? map['lama_perbaikan'] ?? map['LAMA PERBAIKAN'] ?? '1').toString().replaceAll(RegExp(r'\D'), '')) ?? 1,
      penyebab: (map['penyebab'] ?? map['PENYEBAB'] ?? '') as String,
      evide: (map['evide'] ?? map['EVIDE'] ?? map['eviden']) as String?,
      tagIssue: (map['tag_issue'] ?? map['TAG ISSUE'] ?? map['TAG\u0020ISSUE']) as String?,
      kodeIssue: (map['kode_issue'] ?? map['KODE ISSUE'] ?? map['kode_kendala'] ?? '') as String,
    );
  }
}
