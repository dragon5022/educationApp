/// Minimal RFC 4180 CSV reader/writer (pure Dart; also used by tools).
///
/// Handles quoted fields with commas, doubled quotes and line breaks, CRLF
/// or LF line endings, and a UTF-8 BOM — enough for Google Sheets exports.
library;

/// Parses [text] into rows of fields.
List<List<String>> parseCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;
  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  while (i < text.length) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
      } else {
        field.write(c);
      }
      i++;
      continue;
    }
    switch (c) {
      case '"':
        inQuotes = true;
      case ',':
        endField();
      case '\r':
        if (i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      case '\n':
        endRow();
      default:
        field.write(c);
    }
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// Rows of a CSV with a header line, as maps keyed by header name.
/// Blank header cells and completely empty rows are skipped.
List<Map<String, String>> parseCsvRecords(String text) {
  final rows = parseCsv(text);
  if (rows.isEmpty) return const [];
  final header = rows.first.map((h) => h.trim()).toList();
  final out = <Map<String, String>>[];
  for (final r in rows.skip(1)) {
    if (r.every((v) => v.trim().isEmpty)) continue;
    final m = <String, String>{};
    for (var i = 0; i < header.length && i < r.length; i++) {
      if (header[i].isEmpty) continue;
      m[header[i]] = r[i];
    }
    out.add(m);
  }
  return out;
}

/// Encodes rows as CSV (quotes only when needed).
String toCsv(List<List<String>> rows) {
  String q(String v) {
    if (v.contains(RegExp('[",\r\n]')) || v.startsWith(' ') || v.endsWith(' ')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  return rows.map((r) => r.map(q).join(',')).join('\r\n');
}
