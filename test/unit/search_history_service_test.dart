import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:map_now/services/search_history_service.dart';
import 'package:map_now/models/place_model.dart';

PlaceModel _place(String addr, {String placeId = ''}) => PlaceModel(
      fullAddress: addr,
      latitude: 0,
      longitude: 0,
      placeId: placeId,
    );

void main() {
  late SearchHistoryService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = SearchHistoryService();
  });

  group('SearchHistoryService', () {
    test('getHistory returns empty list initially', () async {
      final history = await service.getHistory();
      expect(history, isEmpty);
    });

    test('addToHistory adds items', () async {
      await service.addToHistory(_place('Place A', placeId: 'a'));
      final history = await service.getHistory();
      expect(history.length, 1);
      expect(history.first.fullAddress, 'Place A');
    });

    test('addToHistory moves duplicate to top', () async {
      await service.addToHistory(_place('Place A', placeId: 'a'));
      await service.addToHistory(_place('Place B', placeId: 'b'));
      await service.addToHistory(_place('Place A', placeId: 'a'));

      final history = await service.getHistory();
      expect(history.length, 2);
      expect(history.first.fullAddress, 'Place A');
      expect(history[1].fullAddress, 'Place B');
    });

    test('addToHistory deduplicates by fullAddress', () async {
      await service.addToHistory(_place('Same Address', placeId: 'id1'));
      await service.addToHistory(_place('Same Address', placeId: 'id2'));

      final history = await service.getHistory();
      expect(history.length, 1);
      expect(history.first.placeId, 'id2');
    });

    test('addToHistory limits to 20 items', () async {
      for (int i = 0; i < 25; i++) {
        await service.addToHistory(_place('Place $i', placeId: 'id_$i'));
      }

      final history = await service.getHistory();
      expect(history.length, 20);
      // Most recent should be first
      expect(history.first.fullAddress, 'Place 24');
    });

    test('removeFromHistory removes item at index', () async {
      await service.addToHistory(_place('A'));
      await service.addToHistory(_place('B'));
      await service.removeFromHistory(0);

      final history = await service.getHistory();
      expect(history.length, 1);
      expect(history.first.fullAddress, 'A');
    });

    test('removeFromHistory with invalid index does nothing', () async {
      await service.addToHistory(_place('A'));
      await service.removeFromHistory(-1);
      await service.removeFromHistory(5);

      final history = await service.getHistory();
      expect(history.length, 1);
    });

    test('clearHistory removes all items', () async {
      await service.addToHistory(_place('A'));
      await service.addToHistory(_place('B'));
      await service.clearHistory();

      final history = await service.getHistory();
      expect(history, isEmpty);
    });

    test('getHistory handles corrupted data gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('search_history', 'not valid json!!!');

      final history = await service.getHistory();
      expect(history, isEmpty);
    });

    test('operator precedence fix: placeId match requires non-empty placeId', () async {
      // Add a place with empty placeId
      await service.addToHistory(_place('Place A', placeId: ''));
      // Add another with same empty placeId but different address
      await service.addToHistory(_place('Place B', placeId: ''));

      final history = await service.getHistory();
      // Both should exist since empty placeId match should be ignored
      // Only fullAddress match should remove
      expect(history.length, 2);
    });
  });
}
