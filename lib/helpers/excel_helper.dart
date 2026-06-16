import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/issue.dart';

class ExcelHelper {
  // Select an Excel file and import issues
  static Future<List<Issue>> importIssues() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.single.path == null) {
      return [];
    }

    final bytes = await File(result.files.single.path!).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final List<Issue> importedIssues = [];

    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table]!;
      if (sheet.maxRows <= 1) continue;

      // Extract Headers
      final List<String> headers = [];
      final firstRow = sheet.rows.first;
      for (var cell in firstRow) {
        headers.add(cell?.value?.toString().trim().toUpperCase() ?? '');
      }

      // Column Indices Mapping
      int idxKode = headers.indexWhere((h) => h.contains('KODE') || h.contains('CODE'));
      int idxTgl = headers.indexWhere((h) => h.contains('TGL') || h.contains('DATE') || h.contains('HARI'));
      int idxArea = headers.indexWhere((h) => h.contains('AREA') || h.contains('LOKASI'));
      int idxKategori = headers.indexWhere((h) => h.contains('KATEGORI') || h.contains('CATEGORY'));
      int idxIssue = headers.indexWhere((h) => h.contains('ISSUE') || h.contains('KENDALA') || h.contains('MASALAH'));
      int idxPenanganan = headers.indexWhere((h) => h.contains('PENANGANAN') || h.contains('VENDOR') || h.contains('ACTION'));
      int idxStatus = headers.indexWhere((h) => h.contains('STATUS') || h.contains('PERBAIKAN'));
      int idxPenyebab = headers.indexWhere((h) => h.contains('PENYEBAB') || h.contains('CAUSE'));
      int idxLama = headers.indexWhere((h) => h.contains('LAMA') || h.contains('DURASI') || h.contains('DURATION') || h.contains('PERULANGAN') || h.contains('REPEAT'));
      int idxEvide = headers.indexWhere((h) => h.contains('EVIDE') || h.contains('FOTO') || h.contains('DOCUMENT') || h.contains('PICTURE'));
      int idxTag = headers.indexWhere((h) => h.contains('TAG') || h.contains('KLASIFIKASI') || h.contains('LABEL'));
      int idxTagDetail = headers.indexWhere((h) => h.contains('DETAIL') && h.contains('TAG'));

      // If we don't find correct headers, try default indices
      if (idxTgl == -1) idxTgl = 0;
      if (idxArea == -1 && sheet.maxColumns > 1) idxArea = 1;
      if (idxKategori == -1 && sheet.maxColumns > 2) idxKategori = 2;
      if (idxIssue == -1 && sheet.maxColumns > 3) idxIssue = 3;
      if (idxPenanganan == -1 && sheet.maxColumns > 4) idxPenanganan = 4;
      if (idxStatus == -1 && sheet.maxColumns > 5) idxStatus = 5;
      if (idxLama == -1 && sheet.maxColumns > 6) idxLama = 6;
      if (idxPenyebab == -1 && sheet.maxColumns > 7) idxPenyebab = 7;
      if (idxEvide == -1 && sheet.maxColumns > 8) idxEvide = 8;

      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty || row[idxIssue]?.value == null) continue;

        String kodeVal = idxKode != -1 && idxKode < row.length ? (row[idxKode]?.value?.toString() ?? '') : '';
        String tglVal = row[idxTgl]?.value?.toString() ?? '';
        String areaVal = row[idxArea]?.value?.toString() ?? 'All Wahana';
        String kategoriVal = row[idxKategori]?.value?.toString() ?? 'SISTEM';
        String issueVal = row[idxIssue]?.value?.toString() ?? '';
        String penangananVal = row[idxPenanganan]?.value?.toString() ?? 'IT SUPPORT';
        String statusVal = row[idxStatus]?.value?.toString().toLowerCase() ?? 'pending';
        String penyebabVal = idxPenyebab < row.length ? (row[idxPenyebab]?.value?.toString() ?? '') : '';
        String evideVal = idxEvide < row.length ? (row[idxEvide]?.value?.toString() ?? '') : '';
        String tagVal = idxTag != -1 && idxTag < row.length ? (row[idxTag]?.value?.toString() ?? '') : '';
        String tagDetailVal = idxTagDetail != -1 && idxTagDetail < row.length ? (row[idxTagDetail]?.value?.toString() ?? '') : '';

        // Clean status
        if (statusVal.contains('solve')) {
          statusVal = 'solved';
        } else {
          statusVal = 'pending';
        }

        DateTime parsedTgl;
        if (tglVal.isNotEmpty) {
          parsedTgl = Issue.parseTgl(tglVal);
        } else {
          parsedTgl = DateTime.now();
        }

        // Clean lama perbaikan
        int lamaVal = 1;
        if (idxLama < row.length && row[idxLama]?.value != null) {
          final rawLama = row[idxLama]?.value?.toString() ?? '';
          // Extract only digits
          final digits = rawLama.replaceAll(RegExp(r'\D'), '');
          lamaVal = int.tryParse(digits) ?? 1;
        }

        importedIssues.add(Issue(
          tgl: parsedTgl,
          area: areaVal,
          kategori: kategoriVal.toUpperCase().contains('ASSET') ? 'ASSET' : 'SISTEM',
          issue: issueVal,
          penanganan: penangananVal,
          status: statusVal,
          perulanganMasalah: lamaVal,
          penyebab: penyebabVal,
          evide: evideVal.isNotEmpty ? evideVal : null,
          tagIssue: tagVal.isNotEmpty ? tagVal : Issue.calculateTag(issueVal),
          kodeIssue: kodeVal,
          tagDetail: tagDetailVal,
        ));
      }
    }

    return importedIssues;
  }

  // Export issues to Excel (.xlsx) file and return the path
  static Future<String> exportIssues(List<Issue> issues) async {
    final excel = Excel.createExcel();
    
    // ----------------------------------------------------
    // SHEET 1: DETAILED ISSUES DATA (Ensures Eviden column is immediately visible upon opening)
    // ----------------------------------------------------
    final Sheet sheet = excel['ALL MONTH ISSUES'];
    excel.delete('Sheet1'); // Remove default sheet

    final CellStyle headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#0F1A2C'),
      fontColorHex: ExcelColor.fromHexString('#FFFFD166'),
      horizontalAlign: HorizontalAlign.Center,
    );

    // Headers with new ordered columns
    final List<String> headers = [
      'TGL',
      'AREA',
      'KATEGORI',
      'KODE ISSUE',
      'ISSUE/KENDALA',
      'TAG ISSUE',
      'TAG DETAIL',
      'PENANGANAN VENDOR',
      'STATUS PERBAIKAN',
      'PERULANGAN MASALAH',
      'PENYEBAB',
      'EVIDEN'
    ];

    final Map<int, int> colWidths = {};
    for (int i = 0; i < headers.length; i++) {
      colWidths[i] = headers[i].length;
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Sort issues chronologically by date (oldest first) so that edited issues remain in order
    final List<Issue> sortedIssues = List.from(issues);
    sortedIssues.sort((a, b) => a.tgl.compareTo(b.tgl));

    // Data rows in matching order
    for (int r = 0; r < sortedIssues.length; r++) {
      final issue = sortedIssues[r];
      final List<dynamic> rowValues = [
        issue.tglFormatted,
        issue.area.toUpperCase(),
        issue.kategori,
        issue.kodeIssue,
        issue.issue,
        issue.tagIssue,
        issue.tagDetail,
        issue.penanganan,
        issue.status,
        '${issue.perulanganMasalah} kali',
        issue.penyebab,
        issue.evide ?? ''
      ];

      for (int c = 0; c < rowValues.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final String valStr = rowValues[c].toString();
        
        // Eviden column (index 11) gets clickable formula link if it contains http/https
        if (c == 11 && valStr.isNotEmpty && (valStr.startsWith('http://') || valStr.startsWith('https://'))) {
          cell.value = FormulaCellValue('HYPERLINK("$valStr", "$valStr")');
        } else {
          cell.value = TextCellValue(valStr);
        }

        if (valStr.length > colWidths[c]!) {
          colWidths[c] = valStr.length;
        }
      }
    }

    // Auto-fit columns for Detailed Data Sheet
    colWidths.forEach((colIndex, maxLen) {
      sheet.setColumnWidth(colIndex, (maxLen + 4).toDouble());
    });

    // ----------------------------------------------------
    // SHEET 2: DASHBOARD ANALYSIS
    // ----------------------------------------------------
    final Sheet analysisSheet = excel['Dashboard Analysis'];
    
    final CellStyle titleStyle = CellStyle(
      bold: true,
      fontSize: 13,
      fontColorHex: ExcelColor.fromHexString('#FFFFD166'),
      backgroundColorHex: ExcelColor.fromHexString('#0F1A2C'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final CellStyle labelStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#EAEFF8'),
      horizontalAlign: HorizontalAlign.Left,
    );

    // Compute metrics
    final total = issues.length;
    final solved = issues.where((e) => e.status.toLowerCase() == 'solved').length;
    final pending = total - solved;
    final uniqueCodes = issues
        .map((e) => e.kodeIssue.trim().toUpperCase())
        .where((c) => c.isNotEmpty)
        .toSet();
    final uniqueIssuesCount = uniqueCodes.length;

    final Map<String, int> byArea = {};
    final Map<String, int> byKategori = {};
    for (var issue in issues) {
      final areaUpper = issue.area.toUpperCase();
      byArea[areaUpper] = (byArea[areaUpper] ?? 0) + 1;
      byKategori[issue.kategori] = (byKategori[issue.kategori] ?? 0) + 1;
    }

    // Write Laporan Title
    analysisSheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
    final titleCell = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('LAPORAN ANALISIS KENDALA');
    titleCell.cellStyle = titleStyle;

    // Overview Table Headers
    final overviewHeader1 = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2));
    overviewHeader1.value = TextCellValue('METRIK UTAMA');
    overviewHeader1.cellStyle = headerStyle;
    final overviewHeader2 = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2));
    overviewHeader2.value = TextCellValue('NILAI');
    overviewHeader2.cellStyle = headerStyle;

    final List<List<dynamic>> overviewData = [
      ['Total Issues', total],
      ['Jumlah Kode Issue', uniqueIssuesCount],
      ['Solved Issues', solved],
      ['Pending Issues', pending],
    ];
    for (int i = 0; i < overviewData.length; i++) {
      final cellLabel = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3 + i));
      cellLabel.value = TextCellValue(overviewData[i][0].toString());
      cellLabel.cellStyle = labelStyle;
      final cellVal = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3 + i));
      cellVal.value = TextCellValue(overviewData[i][1].toString());
    }

    // Kategori Table
    int startRowKategori = 8;
    final katHeader1 = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRowKategori));
    katHeader1.value = TextCellValue('ANALISIS KATEGORI');
    katHeader1.cellStyle = headerStyle;
    final katHeader2 = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: startRowKategori));
    katHeader2.value = TextCellValue('JUMLAH');
    katHeader2.cellStyle = headerStyle;

    int katIndex = 0;
    byKategori.forEach((key, val) {
      final cellLabel = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRowKategori + 1 + katIndex));
      cellLabel.value = TextCellValue(key);
      cellLabel.cellStyle = labelStyle;
      final cellVal = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: startRowKategori + 1 + katIndex));
      cellVal.value = TextCellValue(val.toString());
      katIndex++;
    });

    // Area Table
    int startRowArea = startRowKategori + 2 + byKategori.length + 1;
    final areaHeader1 = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRowArea));
    areaHeader1.value = TextCellValue('JUMLAH ISSUES PER AREA');
    areaHeader1.cellStyle = headerStyle;
    final areaHeader2 = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: startRowArea));
    areaHeader2.value = TextCellValue('JUMLAH');
    areaHeader2.cellStyle = headerStyle;

    int areaIndex = 0;
    byArea.forEach((key, val) {
      final cellLabel = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRowArea + 1 + areaIndex));
      cellLabel.value = TextCellValue(key);
      cellLabel.cellStyle = labelStyle;
      final cellVal = analysisSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: startRowArea + 1 + areaIndex));
      cellVal.value = TextCellValue(val.toString());
      areaIndex++;
    });

    // Auto-fit Dashboard Analysis Sheet
    analysisSheet.setColumnWidth(0, 32.0);
    analysisSheet.setColumnWidth(1, 16.0);

    // Save File inside local user Downloads/collected_issue folder
    String downloadPath;
    try {
      if (Platform.isAndroid) {
        downloadPath = '/storage/emulated/0/Download/collected_issue';
      } else {
        final homeDir = Platform.environment['USERPROFILE'];
        if (homeDir != null) {
          downloadPath = '$homeDir/Downloads/collected_issue';
        } else {
          final directory = await getApplicationDocumentsDirectory();
          downloadPath = '${directory.path}/collected_issue';
        }
      }
    } catch (_) {
      final directory = await getApplicationDocumentsDirectory();
      downloadPath = '${directory.path}/collected_issue';
    }

    try {
      final dir = Directory(downloadPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      print('[ExcelHelper] Gagal membuat direktori download publik: $e. Fallback ke app documents.');
      final directory = await getApplicationDocumentsDirectory();
      downloadPath = '${directory.path}/collected_issue';
      final dir = Directory(downloadPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }

    final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '$downloadPath/Issues_Export_$formattedDate.xlsx';
    
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(path);
      await file.writeAsBytes(fileBytes);
    }
    
    return path;
  }
}
