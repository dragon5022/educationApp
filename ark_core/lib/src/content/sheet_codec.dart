/// Converts question packs to spreadsheet rows and back (pure Dart).
///
/// A pack is a JSON object whose questions live in **item arrays** — lists
/// of objects at stable paths (`items`, `grades.g5`, `grades.g5.levels.0`).
/// Everything else (timers, question counts…) is a pack setting and stays
/// as bundled in the app.
///
/// Sheet layout (one tab per pack):
///
/// | _path     | id  | ja.0.t | ja.1.t | answer.0 | answer.1 | tip |
/// |-----------|-----|--------|--------|----------|----------|-----|
/// | grades.g5 | s1  | 彼は    | 走る    | He       | runs     | …   |
///
/// - `_path` says which item array the row belongs to; rows keep sheet order.
///   Rows with an empty `_path` are ignored (handy for notes).
/// - Nested fields use dotted names; numbers index lists. Empty cells are
///   simply absent, and lists are compacted, so items may have different
///   lengths (3 vs 5 word parts) in the same tab.
/// - Cell text is converted to the type the bundled pack uses for that
///   column (int / double / bool / string).
library;

const pathColumn = '_path';

/// Item arrays of [pack]: path → list of item objects.
Map<String, List<Map<String, dynamic>>> itemArrays(Map<String, dynamic> pack) {
  final out = <String, List<Map<String, dynamic>>>{};
  void walk(Map<String, dynamic> m, String prefix) {
    m.forEach((k, v) {
      final p = prefix.isEmpty ? k : '$prefix.$k';
      if (v is List && v.isNotEmpty && v.every((e) => e is Map)) {
        out[p] = [for (final e in v) Map<String, dynamic>.from(e as Map)];
      } else if (v is Map) {
        walk(Map<String, dynamic>.from(v), p);
      }
    });
  }

  walk(pack, '');
  return out;
}

/// Flattens [pack]'s questions into a header + rows for one sheet tab.
List<List<String>> flattenPack(Map<String, dynamic> pack) {
  final columns = <String>[];
  final seen = <String>{};
  final records = <Map<String, String>>[];
  itemArrays(pack).forEach((path, items) {
    for (final item in items) {
      final flat = <String, String>{pathColumn: path};
      _flatten(item, '', flat);
      for (final k in flat.keys) {
        if (k != pathColumn && seen.add(k)) columns.add(k);
      }
      records.add(flat);
    }
  });
  final header = [pathColumn, ..._ordered(columns)];
  return [
    header,
    for (final r in records) [for (final h in header) r[h] ?? ''],
  ];
}

/// Groups related columns: `ja.0.t, ja.0.pick, ja.1.t …` before
/// `answer.0.w …`, list indices ascending, otherwise first-seen order.
List<String> _ordered(List<String> columns) {
  final rank = <String, int>{};
  for (final c in columns) {
    final segs = c.split('.');
    for (var i = 0; i < segs.length; i++) {
      final key = _Schema.norm(segs.sublist(0, i + 1));
      rank.putIfAbsent(key, () => rank.length);
    }
  }
  int cmp(String a, String b) {
    final x = a.split('.'), y = b.split('.');
    for (var i = 0; i < x.length && i < y.length; i++) {
      if (x[i] == y[i]) continue;
      final xi = int.tryParse(x[i]), yi = int.tryParse(y[i]);
      if (xi != null && yi != null) return xi.compareTo(yi);
      return rank[_Schema.norm(x.sublist(0, i + 1))]!
          .compareTo(rank[_Schema.norm(y.sublist(0, i + 1))]!);
    }
    return x.length.compareTo(y.length);
  }

  return [...columns]..sort(cmp);
}

void _flatten(dynamic v, String prefix, Map<String, String> out) {
  if (v is Map) {
    v.forEach((k, e) => _flatten(e, prefix.isEmpty ? '$k' : '$prefix.$k', out));
  } else if (v is List) {
    for (var i = 0; i < v.length; i++) {
      _flatten(v[i], prefix.isEmpty ? '$i' : '$prefix.$i', out);
    }
  } else if (v != null) {
    out[prefix] = '$v';
  }
}

/// Rebuilds a pack from sheet [rows] using [template] (the bundled pack)
/// for settings, field types and structure. Item arrays that have no rows
/// in the sheet keep their bundled questions.
Map<String, dynamic> rebuildPack(
  Map<String, dynamic> template,
  List<Map<String, String>> rows,
) {
  final schema = _Schema.of(template);
  final out = _deepCopy(template) as Map<String, dynamic>;
  final grouped = <String, List<Map<String, String>>>{};
  for (final r in rows) {
    final path = (r[pathColumn] ?? '').trim();
    if (path.isEmpty) continue;
    grouped.putIfAbsent(path, () => []).add(r);
  }
  grouped.forEach((path, group) {
    final items = <Map<String, dynamic>>[];
    for (final r in group) {
      final item = <String, dynamic>{};
      r.forEach((key, raw) {
        if (key == pathColumn || key.trim().isEmpty) return;
        final value = raw.trim();
        if (value.isEmpty) return;
        _put(item, key.trim().split('.'), schema.coerce(key.trim(), value), schema, '');
      });
      if (item.isNotEmpty) items.add(_compact(item) as Map<String, dynamic>);
    }
    _setAt(out, path.split('.'), items);
  });
  return out;
}

/// Structure and leaf types seen in the template's items, keyed by field
/// path with list indices replaced by `#` (e.g. `ja.#.t`).
class _Schema {
  final Map<String, Type> leaf = {};
  final Set<String> lists = {};
  final Set<String> maps = {};

  static _Schema of(Map<String, dynamic> template) {
    final s = _Schema();
    for (final items in itemArrays(template).values) {
      for (final item in items) {
        s._scan(item, '');
      }
    }
    return s;
  }

  void _scan(dynamic v, String key) {
    if (v is Map) {
      if (key.isNotEmpty) maps.add(key);
      v.forEach((k, e) => _scan(e, key.isEmpty ? '$k' : '$key.$k'));
    } else if (v is List) {
      lists.add(key);
      for (final e in v) {
        _scan(e, '$key.#');
      }
    } else if (v != null) {
      leaf.putIfAbsent(key, () => v.runtimeType);
    }
  }

  static String norm(List<String> segs) =>
      segs.map((s) => int.tryParse(s) != null ? '#' : s).join('.');

  /// Whether the container at [norm] holds a list. Known template fields
  /// decide; for new columns a numeric next segment means a list.
  bool isListAt(String norm, String nextSeg) {
    if (lists.contains(norm)) return true;
    if (maps.contains(norm)) return false;
    return int.tryParse(nextSeg) != null;
  }

  dynamic coerce(String key, String value) {
    final t = leaf[norm(key.split('.'))];
    if (t == int) {
      final i = int.tryParse(value);
      if (i != null) return i;
      final d = double.tryParse(value);
      if (d != null && d == d.roundToDouble()) return d.toInt();
      return value;
    }
    if (t == double) return double.tryParse(value) ?? value;
    if (t == bool) {
      final l = value.toLowerCase();
      if (l == 'true' || l == '1' || l == 'yes') return true;
      if (l == 'false' || l == '0' || l == 'no') return false;
      return value;
    }
    return value;
  }
}

void _put(dynamic container, List<String> segs, dynamic value, _Schema s, String parentNorm) {
  final seg = segs.first;
  final segNorm = int.tryParse(seg) != null ? '#' : seg;
  final here = parentNorm.isEmpty ? segNorm : '$parentNorm.$segNorm';
  if (segs.length == 1) {
    _assign(container, seg, value);
    return;
  }
  var child = _read(container, seg);
  if (child == null) {
    child = s.isListAt(here, segs[1]) ? <dynamic>[] : <String, dynamic>{};
    _assign(container, seg, child);
  }
  _put(child, segs.sublist(1), value, s, here);
}

dynamic _read(dynamic c, String seg) {
  if (c is Map) return c[seg];
  final i = int.parse(seg);
  final l = c as List;
  return i < l.length ? l[i] : null;
}

void _assign(dynamic c, String seg, dynamic value) {
  if (c is Map) {
    c[seg] = value;
    return;
  }
  final l = c as List;
  final i = int.tryParse(seg);
  if (i == null) return; // map key under a list: ignore malformed column
  while (l.length <= i) {
    l.add(null);
  }
  l[i] = value;
}

/// Drops holes left by empty cells (`answer.0`, `answer.2` → 2 items).
dynamic _compact(dynamic v) {
  if (v is Map) return v.map((k, e) => MapEntry('$k', _compact(e)));
  if (v is List) return [for (final e in v) if (e != null) _compact(e)];
  return v;
}

void _setAt(Map<String, dynamic> root, List<String> path, dynamic value) {
  var m = root;
  for (final seg in path.take(path.length - 1)) {
    final next = m[seg];
    if (next is Map<String, dynamic>) {
      m = next;
    } else {
      final created = <String, dynamic>{};
      m[seg] = created;
      m = created;
    }
  }
  m[path.last] = value;
}

dynamic _deepCopy(dynamic v) {
  if (v is Map) return v.map((k, e) => MapEntry('$k', _deepCopy(e)));
  if (v is List) return [for (final e in v) _deepCopy(e)];
  return v;
}
