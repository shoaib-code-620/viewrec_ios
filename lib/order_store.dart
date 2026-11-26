import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the order a person arranged things in (menu tiles, tabs) on this phone.
class OrderStore {
  static Future<List<String>?> load(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getStringList('order_$key');
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String key, List<String> ids) async {
    try {
      (await SharedPreferences.getInstance()).setStringList('order_$key', ids);
    } catch (_) {}
  }

  static Future<void> clear(String key) async {
    try {
      (await SharedPreferences.getInstance()).remove('order_$key');
    } catch (_) {}
  }
}

/// [items] in the saved order. Anything new that is not in the saved list goes at the end, and anything that no longer exists is dropped.
List<T> applyOrder<T>(List<T> items, List<String>? saved, String Function(T) id) {
  if (saved == null || saved.isEmpty) return List.of(items);
  final byId = {for (final i in items) id(i): i};
  return [
    for (final s in saved)
      if (byId.containsKey(s)) byId[s] as T,
    for (final i in items)
      if (!saved.contains(id(i))) i,
  ];
}

/// Moves [from] to where [to] is. Both are ids in [ids].
List<String> movedBefore(List<String> ids, String from, String to) {
  if (from == to || !ids.contains(from) || !ids.contains(to)) return ids;
  final next = List.of(ids)..remove(from);
  final at = next.indexOf(to);
  final fromIndex = ids.indexOf(from);
  final toIndex = ids.indexOf(to);
  // Dragging down puts it after the target, dragging up puts it before, like every list app.
  next.insert(fromIndex < toIndex ? at + 1 : at, from);
  return next;
}
