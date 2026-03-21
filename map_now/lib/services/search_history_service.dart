import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place_model.dart';

class SearchHistoryService {
  static const String _key = 'search_history';

  Future<List<PlaceModel>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => PlaceModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addToHistory(PlaceModel place) async {
    final history = await getHistory();
    
    // Remove if exists to avoid duplicates (and move to top)
    history.removeWhere((p) => 
      (p.placeId == place.placeId && p.placeId.isNotEmpty) || 
      p.fullAddress == place.fullAddress
    );

    // Add to front
    history.insert(0, place);

    // Limit history size (e.g., 20)
    if (history.length > 20) {
      history.removeLast();
    }

    await _saveHistory(history);
  }

  Future<void> removeFromHistory(int index) async {
    final history = await getHistory();
    if (index >= 0 && index < history.length) {
      history.removeAt(index);
      await _saveHistory(history);
    }
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _saveHistory(List<PlaceModel> history) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = history.map((place) => place.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }
}
