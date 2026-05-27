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
      int idxLama = headers.indexWhere((h) => h.contains('LAMA') || h.contains('DURASI') || h.contains('DURATION'));
      int idxEvide = headers.indexWhere((h) => h.contains('EVIDE') || h.contains('FOTO') || h.contains('DOCUMENT') || h.contains('PICTURE'));
      int idxTag = headers.indexWhere((h) => h.contains('TAG') || h.contains('KLASIFIKASI') || h.contains('LABEL'));

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
          lamaPerbaikan: lamaVal,
          penyebab: penyebabVal,
          evide: evideVal.isNotEmpty ? evideVal : null,
          tagIssue: tagVal.isNotEmpty ? tagVal : Issue.calculateTag(issueVal),
          kodeIssue: kodeVal,
        ));
      }
    }

    return importedIssues;
  }

  // Export issues to Excel (.xlsx) file and return the path
  static Future<String> exportIssues(List<Issue> issues) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Issues'];
    excel.delete('Sheet1'); // Remove default sheet

    // Styles for Headers
    final CellStyle headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#0F1A2C'), // Navy Blue
      fontColorHex: ExcelColor.fromHexString('#FFFFD166'), // Accent Yellow Gold
      horizontalAlign: HorizontalAlign.Center,
    );

    // Headers
    final List<String> headers = [
      'KODE ISSUE',
      'TGL',
      'AREA',
      'KATEGORI',
      'TAG ISSUE',
      'ISSUE/KENDALA',
      'PENANGANAN VENDOR',
      'STATUS PERBAIKAN',
      'LAMA PERBAIKAN',
      'PENYEBAB',
      'EVIDEN'
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Data rows
    for (int r = 0; r < issues.length; r++) {
      final issue = issues[r];
      final List<dynamic> rowValues = [
        issue.kodeIssue,
        issue.tglFormatted,
        issue.area,
        issue.kategori,
        issue.tagIssue,
        issue.issue,
        issue.penanganan,
        issue.status,
        '${issue.lamaPerbaikan} hari',
        issue.penyebab,
        issue.evide ?? ''
      ];

      for (int c = 0; c < rowValues.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        cell.value = TextCellValue(rowValues[c].toString());
      }
    }

    // Save File
    final directory = await getApplicationDocumentsDirectory();
    final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '${directory.path}/Issues_Export_$formattedDate.xlsx';
    
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(path);
      await file.writeAsBytes(fileBytes);
    }
    
    return path;
  }
}
