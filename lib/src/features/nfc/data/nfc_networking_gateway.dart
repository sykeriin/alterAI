import 'dart:async';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../domain/nfc_profile.dart';
import 'nfc_payload_codec.dart';

enum AlterNfcAvailability { enabled, disabled, unsupported }

abstract class NfcNetworkingGateway {
  Future<AlterNfcAvailability> checkAvailability();

  Future<NfcProfile> scanProfile();

  Future<void> writeProfile(NfcProfile profile);

  Future<void> stop();
}

class NfcManagerNetworkingGateway implements NfcNetworkingGateway {
  NfcManagerNetworkingGateway({
    NfcPayloadCodec codec = const NfcPayloadCodec(),
    Duration sessionTimeout = const Duration(seconds: 28),
  }) : _codec = codec,
       _sessionTimeout = sessionTimeout;

  final NfcPayloadCodec _codec;
  final Duration _sessionTimeout;

  @override
  Future<AlterNfcAvailability> checkAvailability() async {
    final availability = await NfcManager.instance.checkAvailability();
    return switch (availability) {
      NfcAvailability.enabled => AlterNfcAvailability.enabled,
      NfcAvailability.disabled => AlterNfcAvailability.disabled,
      NfcAvailability.unsupported => AlterNfcAvailability.unsupported,
    };
  }

  @override
  Future<NfcProfile> scanProfile() async {
    await _ensureEnabled();
    final completer = Completer<NfcProfile>();
    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      alertMessageIos: 'Hold near an ALTER NFC profile.',
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            throw const NfcNetworkingException(
              'NDEF is not available on this tag.',
            );
          }
          final message = ndef.cachedMessage ?? await ndef.read();
          if (message == null) {
            throw const NfcNetworkingException('No NDEF message was found.');
          }
          final profile = _codec.decodeProfile(message);
          await NfcManager.instance.stopSession(
            alertMessageIos: 'ALTER profile received.',
          );
          if (!completer.isCompleted) {
            completer.complete(profile);
          }
        } catch (error, stackTrace) {
          await NfcManager.instance.stopSession(
            errorMessageIos: 'Unable to read ALTER profile.',
          );
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
      },
    );
    return _withTimeout(completer.future);
  }

  @override
  Future<void> writeProfile(NfcProfile profile) async {
    await _ensureEnabled();
    final completer = Completer<void>();
    final message = _codec.encodeProfile(profile);
    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      alertMessageIos: 'Hold near an NFC tag to share ALTER.',
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            throw const NfcNetworkingException(
              'NDEF is not available on this tag.',
            );
          }
          if (!ndef.isWritable) {
            throw const NfcNetworkingException('This NFC tag is read-only.');
          }
          if (ndef.maxSize > 0 && message.byteLength > ndef.maxSize) {
            throw NfcNetworkingException(
              'ALTER profile is ${message.byteLength} bytes; tag capacity is '
              '${ndef.maxSize} bytes.',
            );
          }
          await ndef.write(message: message);
          await NfcManager.instance.stopSession(
            alertMessageIos: 'ALTER profile shared.',
          );
          if (!completer.isCompleted) {
            completer.complete();
          }
        } catch (error, stackTrace) {
          await NfcManager.instance.stopSession(
            errorMessageIos: 'Unable to share ALTER profile.',
          );
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
      },
    );
    return _withTimeout(completer.future);
  }

  @override
  Future<void> stop() {
    return NfcManager.instance.stopSession();
  }

  Future<void> _ensureEnabled() async {
    final availability = await checkAvailability();
    if (availability != AlterNfcAvailability.enabled) {
      throw NfcNetworkingException('NFC is ${availability.name}.');
    }
  }

  Future<T> _withTimeout<T>(Future<T> future) {
    return future.timeout(
      _sessionTimeout,
      onTimeout: () async {
        await stop();
        throw TimeoutException('NFC session timed out.');
      },
    );
  }
}

class NfcNetworkingException implements Exception {
  const NfcNetworkingException(this.message);

  final String message;

  @override
  String toString() => message;
}
