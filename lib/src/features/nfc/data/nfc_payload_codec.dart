import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';

import '../domain/nfc_profile.dart';

class NfcPayloadCodec {
  const NfcPayloadCodec();

  static const mimeType = 'application/vnd.alter.profile+json';

  NdefMessage encodeProfile(NfcProfile profile) {
    final bytes = utf8.encode(jsonEncode(profile.toExchangePayload()));
    return NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(utf8.encode(mimeType)),
          identifier: Uint8List.fromList(utf8.encode('alter-profile')),
          payload: Uint8List.fromList(bytes),
        ),
      ],
    );
  }

  NfcProfile decodeProfile(NdefMessage message) {
    for (final record in message.records) {
      final recordType = utf8.decode(record.type, allowMalformed: true);
      if (record.typeNameFormat != TypeNameFormat.media ||
          recordType != mimeType) {
        continue;
      }
      final json = jsonDecode(utf8.decode(record.payload));
      if (json is! Map<String, dynamic>) {
        throw const NfcPayloadException('ALTER NFC payload is not an object.');
      }
      if (json['schema'] != alterNfcProfileSchema) {
        throw const NfcPayloadException(
          'ALTER NFC payload schema is unsupported.',
        );
      }
      return NfcProfile.fromJson(json);
    }
    throw const NfcPayloadException(
      'No ALTER profile found on this NFC payload.',
    );
  }
}

class NfcPayloadException implements Exception {
  const NfcPayloadException(this.message);

  final String message;

  @override
  String toString() => message;
}
