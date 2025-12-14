import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class HistoryService {
  static const _kHistoryKey = 'prompt_history_v1';

  Future<List<HistoryRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_kHistoryKey);
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => HistoryRecord.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveHistory(List<HistoryRecord> history) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_kHistoryKey, jsonString);
  }
}

// === Riverpod Notifier ===

class HistoryNotifier extends StateNotifier<List<HistoryRecord>> {
  final HistoryService _service;

  HistoryNotifier(this._service) : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await _service.loadHistory();
  }

  Future<void> addRecord(String instruction, String result) async {
    final newRecord = HistoryRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      instruction: instruction,
      result: result,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    // 新的在最前
    final newState = [newRecord, ...state];
    state = newState;
    await _service.saveHistory(newState);
  }

  Future<void> toggleFavorite(String id) async {
    final newState = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isFavorite: !item.isFavorite);
      }
      return item;
    }).toList();
    state = newState;
    await _service.saveHistory(newState);
  }

  Future<void> deleteRecord(String id) async {
    final newState = state.where((item) => item.id != id).toList();
    state = newState;
    await _service.saveHistory(newState);
  }
  
  Future<void> clearAll() async {
    state = [];
    await _service.saveHistory([]);
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, List<HistoryRecord>>((ref) {
  return HistoryNotifier(HistoryService());
});