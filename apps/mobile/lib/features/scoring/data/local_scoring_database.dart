import 'dart:convert';
import 'package:scoring_engine/scoring_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight offline event store using SharedPreferences.
/// Production: replace with Drift SQLite for large match logs.
class LocalScoringDatabase {
  Future<void> saveEvent(String matchId, BallEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'events_$matchId';
    final existing = prefs.getStringList(key) ?? [];
    existing.add(jsonEncode(event.toJson()));
    await prefs.setStringList(key, existing);
    await prefs.setString('${key}_synced', jsonEncode([]));
  }

  Future<List<BallEvent>> getUnsyncedEvents(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'events_$matchId';
    final syncedKey = '${key}_synced';
    final all = prefs.getStringList(key) ?? [];
    final synced = (jsonDecode(prefs.getString(syncedKey) ?? '[]') as List)
        .cast<int>()
        .toSet();
    return all
        .map((s) => BallEvent.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .where((e) => !synced.contains(e.sequence))
        .toList();
  }

  Future<void> markSynced(String matchId, int sequence) async {
    final prefs = await SharedPreferences.getInstance();
    final syncedKey = 'events_${matchId}_synced';
    final synced = (jsonDecode(prefs.getString(syncedKey) ?? '[]') as List)
        .cast<int>();
    synced.add(sequence);
    await prefs.setString(syncedKey, jsonEncode(synced));
  }

  Future<void> deleteLastEvent(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'events_$matchId';
    final existing = prefs.getStringList(key) ?? [];
    if (existing.isNotEmpty) existing.removeLast();
    await prefs.setStringList(key, existing);
  }
}
