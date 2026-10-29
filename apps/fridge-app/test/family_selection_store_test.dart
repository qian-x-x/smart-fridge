import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_fridge_app/features/family/data/family_selection_store.dart';

void main() {
  test('persists family selection separately for each account', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesFamilySelectionStore();
    await store.write(7, 4);
    await store.write(9, 5);
    final reopened = SharedPreferencesFamilySelectionStore();
    expect(await reopened.read(7), 4);
    expect(await reopened.read(9), 5);
    await reopened.clear(7);
    expect(await store.read(7), isNull);
    expect(await store.read(9), 5);
  });
}
