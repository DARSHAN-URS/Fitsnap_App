import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sabtrack_ai/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthNotifier Tests', () {
    test('Initial state is idle/empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(authProvider);
      expect(state.isLoading, false);
      expect(state.success, false);
      expect(state.errorMessage, isNull);
    });

    test('State copyWith works correctly', () {
      const state = AuthState();
      final updated = state.copyWith(isLoading: true, errorMessage: 'Error');
      expect(updated.isLoading, true);
      expect(updated.success, false);
      expect(updated.errorMessage, 'Error');
    });
  });
}
