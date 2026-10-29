import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final familySelectionStoreProvider = Provider<FamilySelectionStore>((ref) {
  return SharedPreferencesFamilySelectionStore();
});

abstract interface class FamilySelectionStore {
  Future<int?> read(int userId);

  Future<void> write(int userId, int familyId);

  Future<void> clear(int userId);
}

class SharedPreferencesFamilySelectionStore implements FamilySelectionStore {
  String _key(int userId) => 'smart_fridge.selected_family.$userId';

  @override
  Future<int?> read(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_key(userId));
  }

  @override
  Future<void> write(int userId, int familyId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_key(userId), familyId);
  }

  @override
  Future<void> clear(int userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(userId));
  }
}
