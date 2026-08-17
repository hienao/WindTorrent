import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/add_task/presentation/services/qbit_link_input_normalizer.dart';

void main() {
  test('removes blank lines and trims each magnet line', () {
    final result = normalizeQBitBulkInput('''
      magnet:?xt=urn:btih:AAA

        magnet:?xt=urn:btih:BBB  

    ''');

    expect(result, 'magnet:?xt=urn:btih:AAA\nmagnet:?xt=urn:btih:BBB');
  });

  test('returns empty string when all lines are blank', () {
    expect(normalizeQBitBulkInput(' \n\n  '), '');
  });
}
