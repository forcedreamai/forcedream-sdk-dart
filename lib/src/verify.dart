import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'canonical.dart';
import 'http.dart';

/// Confirmed building and running correctly on a real Mac, including a real, live
/// verified: true result -- see README for the full confirmation.
/// The package:cryptography API shape used below (Ed25519(), SimplePublicKey, Signature,
/// algorithm.verify) was confirmed via direct research against real, current pub.dev
/// documentation before writing this -- not assumed from memory alone. Unlike Java/Kotlin's
/// KeyFactory, this package's PublicKey types take raw bytes only (confirmed via the same
/// research), the same situation as PHP's sodium and Swift's CryptoKit -- so this file does
/// its own PEM extraction, the same proven approach.
class VerifyResult {
  final bool verified;
  final String? taskId;
  final String? keyId;
  final String algorithm;
  final int fieldsSigned;
  final bool trustless;
  final String message;

  VerifyResult({
    required this.verified,
    this.taskId,
    this.keyId,
    required this.algorithm,
    required this.fieldsSigned,
    required this.trustless,
    required this.message,
  });

  @override
  String toString() =>
      'VerifyResult(verified: $verified, taskId: $taskId, keyId: $keyId, '
      'algorithm: $algorithm, fieldsSigned: $fieldsSigned, message: $message)';
}

/// Trustlessly verifies a ForceDream proof's Ed25519 signature entirely client-side.
/// ForceDream is never asked whether the proof is valid -- the math decides, locally.
class Verify {
  Verify._();

  static Map<String, dynamic> _buildSignable(Map<String, dynamic> proof) {
    final hasExt = proof['external_cost_hash'] != null;

    final base = <String, dynamic>{
      'task_id': _textOrNull(proof['task_id']),
      'agent_id': _textOrNull(proof['agent_id']),
      'input_hash': _textOrNull(proof['input_hash']),
      'output_hash': _textOrNull(proof['output_hash']),
      'cost_pence': _numberOrZero(proof['cost_pence']),
      'budget_pence': _numberOrZero(proof['budget_pence']),
      'started_at': _numberOrZero(proof['started_at']),
      'completed_at': _stringValue(proof['completed_at']),
    };

    if (hasExt) {
      base['external_cost_hash'] = _stringValue(proof['external_cost_hash']);
      base['retrieved_count'] = _numberOrZero(proof['retrieved_count'] ?? 0);
      return {'signable': base, 'fieldCount': 10};
    }
    return {'signable': base, 'fieldCount': 8};
  }

  static String? _textOrNull(dynamic v) => v is String ? v : null;

  static double _numberOrZero(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static String _stringValue(dynamic v) {
    if (v is String) return v;
    if (v is num) return Canonical.jsNumber(v.toDouble());
    return '';
  }

  /// Extracts the raw 32-byte Ed25519 public key from a real SPKI PEM string. Ed25519 SPKI
  /// DER has a fixed, constant-length prefix (RFC 8410), so the raw key is reliably the
  /// final 32 bytes of the decoded DER -- the same approach already proven working live in
  /// the PHP and Swift SDKs tonight, not a hardcoded offset from the start (the class of
  /// bug caught in the Go SDK earlier).
  static Uint8List publicKeyBytesFromPem(String pem) {
    var body = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll(RegExp(r'\s+'), '');
    final der = base64.decode(body);
    if (der.length < 32) {
      throw StateError('publicKeyBytesFromPem: invalid PEM/DER');
    }
    return Uint8List.fromList(der.sublist(der.length - 32));
  }

  static Future<VerifyResult> verifyProof({
    required String apiBase,
    String? taskId,
    Map<String, dynamic>? proof,
  }) async {
    Map<String, dynamic> resolvedProof;
    if (proof != null) {
      resolvedProof = proof;
    } else {
      if (taskId == null) {
        throw ArgumentError('Provide task_id or proof');
      }
      final data = await Http.get('$apiBase/v1/workforce/proof/${Uri.encodeComponent(taskId)}/public');
      if (data['proof'] == null) {
        throw StateError('proof_not_found');
      }
      resolvedProof = data['proof'] as Map<String, dynamic>;
    }

    final keyData = await Http.get('$apiBase/v1/workforce/proof/public-key');
    final keyId = keyData['key_id'] as String?;
    final pem = (keyData['public_key_pem'] as String?) ?? '';

    final built = _buildSignable(resolvedProof);
    final signable = built['signable'] as Map<String, dynamic>;
    final fieldCount = built['fieldCount'] as int;
    final digestHex = Canonical.sha256Hex(Canonical.wfCanonical(signable));

    var verified = false;
    final signatureB64 = resolvedProof['signature'] as String?;
    final proofAlgorithm = resolvedProof['algorithm'] as String?;

    if (signatureB64 != null && (proofAlgorithm == null || proofAlgorithm == 'Ed25519')) {
      try {
        final rawKeyBytes = publicKeyBytesFromPem(pem);
        final publicKey = SimplePublicKey(rawKeyBytes, type: KeyPairType.ed25519);
        final sigBytes = base64.decode(signatureB64);
        final digestBytes = _hexToBytes(digestHex);

        final signature = Signature(sigBytes, publicKey: publicKey);
        final ed25519 = Ed25519();
        verified = await ed25519.verify(digestBytes, signature: signature);
      } catch (_) {
        verified = false;
      }
    }

    return VerifyResult(
      verified: verified,
      taskId: resolvedProof['task_id'] as String?,
      keyId: keyId,
      algorithm: 'Ed25519',
      fieldsSigned: fieldCount,
      trustless: true,
      message: verified
          ? 'Signature mathematically verified. This proof was signed by ForceDream and has not been altered.'
          : 'Signature verification FAILED. The proof was altered or not signed by ForceDream.',
    );
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
