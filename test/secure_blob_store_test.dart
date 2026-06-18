import 'package:alter/src/core/storage/secure_blob_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryCipher (local memory encryption)', () {
    test('seals to tagged ciphertext that hides the plaintext, and round-trips',
        () async {
      final cipher = MemoryCipher(
        MemoryCipher.keyFromBytes(List<int>.generate(32, (i) => i)),
      );
      const secret = '{"people":["Priya"],"notes":"private decision context"}';

      final sealed = await cipher.seal(secret);

      // Tagged + the sensitive substrings are not present in the stored blob.
      expect(sealed.startsWith(MemoryCipher.tag), isTrue);
      expect(sealed.contains('Priya'), isFalse);
      expect(sealed.contains('private decision context'), isFalse);

      // Decrypts back to exactly the original.
      expect(await cipher.open(sealed), secret);
    });

    test('a different key cannot decrypt the data', () async {
      final a = MemoryCipher(
        MemoryCipher.keyFromBytes(List<int>.generate(32, (i) => i)),
      );
      final b = MemoryCipher(
        MemoryCipher.keyFromBytes(List<int>.generate(32, (i) => 255 - i)),
      );

      final sealed = await a.seal('top secret');
      await expectLater(b.open(sealed), throwsA(isA<Object>()));
    });
  });
}
