import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/config/app_config.dart';

void main() {
  test('falls back to the loopback gateway outside the browser', () {
    // Tests run on the VM, so the web branch is skipped and only the native
    // fallback is observable here.
    expect(AppConfig.apiBaseUrl, startsWith('http://'));
    expect(Uri.tryParse(AppConfig.apiBaseUrl)?.host, isNotEmpty);
  });
}
