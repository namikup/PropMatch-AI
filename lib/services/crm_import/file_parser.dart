import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';

/// Represents parsed raw tabular data from an uploaded CSV, TSV, or XLSX file.
class ParsedTable {
  final String fileName;
  final String fileType; // 'csv', 'tsv', 'xlsx'
  final int fileSizeBytes;
  final List<String> headers;
  final List<List<dynamic>> rows;
  final int emptyRowsSkipped;
  final List<String> availableSheets;
  final String? activeSheet;

  const ParsedTable({
    required this.fileName,
    required this.fileType,
    required this.fileSizeBytes,
    required this.headers,
    required this.rows,
    this.emptyRowsSkipped = 0,
    this.availableSheets = const [],
    this.activeSheet,
  });

  int get rowCount => rows.length;
  bool get isEmpty => rows.isEmpty;
}

/// Validation result for raw file bytes before parsing.
class FileValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? detectedFormat;

  const FileValidationResult._({
    required this.isValid,
    this.errorMessage,
    this.detectedFormat,
  });

  factory FileValidationResult.success(String format) {
    return FileValidationResult._(isValid: true, detectedFormat: format);
  }

  factory FileValidationResult.failure(String message) {
    return FileValidationResult._(isValid: false, errorMessage: message);
  }
}

/// Robust file parser handling CSV, TSV, and XLSX uploads for Flutter Web.
class CRMFileParser {
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB limit
  static const List<String> supportedExtensions = ['csv', 'tsv', 'txt', 'xlsx'];

  /// Validates raw file bytes and file name for extension, size, and magic byte integrity.
  static FileValidationResult validateFile({
    required String fileName,
    required Uint8List bytes,
  }) {
    if (fileName.trim().isEmpty) {
      return FileValidationResult.failure('File name is missing.');
    }

    if (bytes.isEmpty) {
      return FileValidationResult.failure('The uploaded file is empty (0 bytes).');
    }

    if (bytes.length > maxFileSizeBytes) {
      final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      return FileValidationResult.failure(
        'File size ($sizeMb MB) exceeds the maximum allowed limit of 5.0 MB.',
      );
    }

    final ext = _extractExtension(fileName);
    if (!supportedExtensions.contains(ext)) {
      return FileValidationResult.failure(
        'Unsupported file extension ".$ext". Please upload a CSV (.csv, .tsv) or Excel (.xlsx) file.',
      );
    }

    // Magic bytes content inspection
    if (ext == 'xlsx') {
      // XLSX is a zip package starting with PK\x03\x04
      if (bytes.length < 4 ||
          bytes[0] != 0x50 ||
          bytes[1] != 0x4B ||
          bytes[2] != 0x03 ||
          bytes[3] != 0x04) {
        return FileValidationResult.failure(
          'Corrupted or invalid XLSX file. File does not match Excel OpenXML binary signature.',
        );
      }
      return FileValidationResult.success('xlsx');
    }

    // Reject disguised ZIP/XLSX binary uploaded with a .csv/.tsv extension
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      return FileValidationResult.failure(
        'File has a .$ext extension but contains a binary ZIP/XLSX signature.',
      );
    }

    // CSV / TSV text inspection: check for illegal binary null bytes
    int nullByteCount = 0;
    final sampleLength = bytes.length > 2048 ? 2048 : bytes.length;
    for (int i = 0; i < sampleLength; i++) {
      if (bytes[i] == 0) nullByteCount++;
    }
    if (nullByteCount > 0) {
      return FileValidationResult.failure(
        'The file appears to be a binary format instead of a plain text CSV.',
      );
    }

    return FileValidationResult.success(ext == 'tsv' ? 'tsv' : 'csv');
  }

  /// Parses file bytes into a normalized [ParsedTable].
  static Future<ParsedTable> parseFile({
    required String fileName,
    required Uint8List bytes,
    String? targetSheetName,
  }) async {
    final validation = validateFile(fileName: fileName, bytes: bytes);
    if (!validation.isValid) {
      throw FormatException(validation.errorMessage ?? 'File validation failed.');
    }

    final format = validation.detectedFormat ?? 'csv';
    if (format == 'xlsx') {
      return _parseXlsx(fileName: fileName, bytes: bytes, targetSheetName: targetSheetName);
    } else {
      return _parseCsv(fileName: fileName, bytes: bytes, delimiter: format == 'tsv' ? '\t' : null);
    }
  }

  /// Parses CSV / TSV bytes with quote, BOM, and newline awareness.
  static ParsedTable _parseCsv({
    required String fileName,
    required Uint8List bytes,
    String? delimiter,
  }) {
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = latin1.decode(bytes);
    }

    // Strip UTF-8 BOM (\uFEFF) if present
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }

    if (text.trim().isEmpty) {
      throw const FormatException('CSV file contains no readable text.');
    }

    final effectiveDelimiter = delimiter ?? _detectDelimiter(text);
    final rawLines = _splitCsvLines(text, effectiveDelimiter);

    if (rawLines.isEmpty) {
      throw const FormatException('CSV file contains no data rows.');
    }

    // Find first non-blank line as header row
    int headerLineIdx = -1;
    for (int i = 0; i < rawLines.length; i++) {
      if (rawLines[i].any((cell) => cell.trim().isNotEmpty)) {
        headerLineIdx = i;
        break;
      }
    }

    if (headerLineIdx == -1) {
      throw const FormatException('CSV header row is empty or unreadable.');
    }

    final rawHeaderCells = rawLines[headerLineIdx].map((h) => h.trim()).toList();
    final headers = _normalizeHeadersPreservingPositions(rawHeaderCells);

    if (headers.isEmpty) {
      throw const FormatException('CSV header row is empty or unreadable.');
    }

    final dataRows = <List<dynamic>>[];
    int emptyRowsSkipped = headerLineIdx; // count any leading blank lines before header

    for (int i = headerLineIdx + 1; i < rawLines.length; i++) {
      final row = rawLines[i];
      final isAllBlank = row.every((cell) => cell.toString().trim().isEmpty);
      if (isAllBlank) {
        emptyRowsSkipped++;
        continue;
      }
      dataRows.add(_normalizeRowLength(row, headers.length));
    }

    return ParsedTable(
      fileName: fileName,
      fileType: effectiveDelimiter == '\t' ? 'tsv' : 'csv',
      fileSizeBytes: bytes.length,
      headers: headers,
      rows: dataRows,
      emptyRowsSkipped: emptyRowsSkipped,
    );
  }

  /// Decodes Excel OpenXML (.xlsx) files across one or multiple worksheets.
  static ParsedTable _parseXlsx({
    required String fileName,
    required Uint8List bytes,
    String? targetSheetName,
  }) {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw FormatException('Corrupted or invalid XLSX workbook structure: $e');
    }

    if (excel.tables.isEmpty) {
      throw const FormatException('The Excel workbook contains no worksheets.');
    }

    final availableSheets = excel.tables.keys.toList();
    String? selectedSheetName;

    if (targetSheetName != null && excel.tables.containsKey(targetSheetName)) {
      selectedSheetName = targetSheetName;
    } else {
      // Pass 1: Pick the first worksheet that has BOTH a non-blank header row AND at least one non-blank data row
      for (final name in availableSheets) {
        final sheet = excel.tables[name];
        if (sheet == null || sheet.rows.isEmpty) continue;
        final nonBlankRowCount = sheet.rows.where((row) => !_isExcelRowBlank(row)).length;
        if (nonBlankRowCount >= 2) {
          selectedSheetName = name;
          break;
        }
      }
      // Pass 2: Fallback to the first worksheet that has at least one non-blank row (headers only)
      if (selectedSheetName == null) {
        for (final name in availableSheets) {
          final sheet = excel.tables[name];
          if (sheet == null || sheet.rows.isEmpty) continue;
          if (sheet.rows.any((row) => !_isExcelRowBlank(row))) {
            selectedSheetName = name;
            break;
          }
        }
      }
    }

    if (selectedSheetName == null) {
      throw const FormatException('All sheets in the Excel workbook are empty.');
    }

    final sheet = excel.tables[selectedSheetName]!;
    if (sheet.rows.isEmpty) {
      throw const FormatException('Selected Excel worksheet has no rows.');
    }

    // Locate first non-blank row as header row
    int headerRowIdx = -1;
    for (int i = 0; i < sheet.rows.length; i++) {
      if (!_isExcelRowBlank(sheet.rows[i])) {
        headerRowIdx = i;
        break;
      }
    }

    if (headerRowIdx == -1) {
      throw const FormatException('Excel worksheet header row is empty.');
    }

    final headerRow = sheet.rows[headerRowIdx];
    final rawHeaderCells = headerRow.map((cell) => _extractExcelCellText(cell)).toList();
    final headers = _normalizeHeadersPreservingPositions(rawHeaderCells);

    if (headers.isEmpty) {
      throw const FormatException('Excel worksheet header row is empty.');
    }

    final dataRows = <List<dynamic>>[];
    int emptyRowsSkipped = headerRowIdx;

    for (int i = headerRowIdx + 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final extracted = row.map((cell) => _extractExcelCellText(cell)).toList();
      final isAllBlank = extracted.every((c) => c.trim().isEmpty);
      if (isAllBlank) {
        emptyRowsSkipped++;
        continue;
      }
      dataRows.add(_normalizeRowLength(extracted, headers.length));
    }

    return ParsedTable(
      fileName: fileName,
      fileType: 'xlsx',
      fileSizeBytes: bytes.length,
      headers: headers,
      rows: dataRows,
      emptyRowsSkipped: emptyRowsSkipped,
      availableSheets: availableSheets,
      activeSheet: selectedSheetName,
    );
  }

  static bool _isExcelRowBlank(List<Data?> row) {
    return row.every((cell) => _extractExcelCellText(cell).trim().isEmpty);
  }

  /// Safely extracts text from an Excel cell, handling integer-like doubles and formulas.
  static String _extractExcelCellText(Data? cell) {
    if (cell == null) return '';
    try {
      final val = cell.value;
      if (val == null) return '';
      if (val is DoubleCellValue) {
        final d = val.value;
        if (d.isNaN || d.isInfinite) return '';
        if (d == d.truncateToDouble()) {
          return d.toInt().toString();
        }
        return d.toString();
      }
      if (val is IntCellValue) {
        return val.value.toString();
      }
      if (val is TextCellValue) {
        return val.value.toString().trim();
      }
      if (val is BoolCellValue) {
        return val.value ? 'true' : 'false';
      }
      final str = val.toString().trim();
      // Handle trailing .0 if numeric cell stringified as float
      if (RegExp(r'^\d+\.0$').hasMatch(str)) {
        return str.substring(0, str.length - 2);
      }
      return str;
    } catch (_) {
      return '';
    }
  }

  /// Preserves positional column alignment when intermediate header cells are blank,
  /// while trimming trailing empty header cells.
  static List<String> _normalizeHeadersPreservingPositions(List<String> rawHeaders) {
    int lastNonEmptyIdx = -1;
    for (int i = rawHeaders.length - 1; i >= 0; i--) {
      if (rawHeaders[i].trim().isNotEmpty) {
        lastNonEmptyIdx = i;
        break;
      }
    }
    if (lastNonEmptyIdx == -1) return [];

    final headers = <String>[];
    final seenNames = <String>{};

    for (int i = 0; i <= lastNonEmptyIdx; i++) {
      String h = rawHeaders[i].trim();
      if (h.isEmpty) {
        h = 'Column_${i + 1}';
      } else if (seenNames.contains(h)) {
        h = '${h}_${i + 1}';
      }
      seenNames.add(h);
      headers.add(h);
    }
    return headers;
  }

  /// Ensures each row has at least [headerCount] cells so positional indexing never shifts.
  static List<String> _normalizeRowLength(List<String> row, int headerCount) {
    if (row.length == headerCount) return row;
    if (row.length < headerCount) {
      return [
        ...row,
        ...List<String>.filled(headerCount - row.length, ''),
      ];
    }
    return row;
  }

  /// Heuristically detects the most likely delimiter (comma, semicolon, or tab).
  static String _detectDelimiter(String text) {
    final firstLine = text.split(RegExp(r'\r?\n')).firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    // Count delimiters outside quotes
    int commaCount = 0;
    int tabCount = 0;
    int semicolonCount = 0;
    bool inQuotes = false;

    for (int i = 0; i < firstLine.length; i++) {
      final c = firstLine[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (c == ',') commaCount++;
        if (c == '\t') tabCount++;
        if (c == ';') semicolonCount++;
      }
    }

    if (tabCount > commaCount && tabCount > semicolonCount) return '\t';
    if (semicolonCount > commaCount) return ';';
    return ',';
  }

  /// State-machine CSV parser handling quoted tokens, escaped quotes, commas, and line breaks within quotes.
  static List<List<String>> _splitCsvLines(String text, String delimiter) {
    final results = <List<String>>[];
    final currentLine = <String>[];
    final currentField = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == '"') {
        if (insideQuotes && i + 1 < text.length && text[i + 1] == '"') {
          // Escaped quote ("")
          currentField.write('"');
          i++;
        } else {
          // Toggle quote state
          insideQuotes = !insideQuotes;
        }
      } else if (char == delimiter && !insideQuotes) {
        currentLine.add(currentField.toString().trim());
        currentField.clear();
      } else if ((char == '\n' || char == '\r') && !insideQuotes) {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++; // Skip \n in \r\n
        }
        currentLine.add(currentField.toString().trim());
        currentField.clear();
        results.add(List<String>.from(currentLine));
        currentLine.clear();
      } else {
        currentField.write(char);
      }
    }

    // Trailing field/line
    if (currentField.isNotEmpty || currentLine.isNotEmpty) {
      currentLine.add(currentField.toString().trim());
      results.add(List<String>.from(currentLine));
    }

    return results;
  }

  static String _extractExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase().trim();
    }
    return '';
  }
}
