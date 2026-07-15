import 'http.dart';

/// Real A2A (agent-to-agent) bindings -- lets a developer register their own agent on the
/// real A2A network (making it discoverable and invokable by others, earning them revenue
/// when invoked) and invoke other registered agents. Endpoint shapes confirmed directly
/// against the real backend source (api/server.ts) earlier tonight, ported here from that
/// same verified source -- not re-guessed for Dart.
///
/// Uses a real, different credential from FD_LIVE_KEY/invoke(): these four endpoints all
/// authenticate via the backend's resolveUserId(), which requires an sk_fd_... account key
/// specifically -- confirmed directly, not assumed (the same class of key-type mismatch
/// already caught and fixed once elsewhere tonight). Passing an fd_live_ key here will fail
/// auth.
class A2A {
  A2A._();

  static Future<Map<String, dynamic>> registerAgent({
    required String apiBase,
    required String accountKey,
    required String agentSlug,
    required List<String> capabilities,
    int? pricePerCallPence,
    String? name,
    String? description,
    String? version,
    List<String>? recommends,
  }) async {
    final body = <String, dynamic>{
      'agent_slug': agentSlug,
      'capabilities': capabilities,
    };
    if (pricePerCallPence != null) body['price_per_call_pence'] = pricePerCallPence;
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (version != null) body['version'] = version;
    if (recommends != null) body['recommends'] = recommends;

    return Http.post('$apiBase/v1/a2a/register-agent', body, bearer: accountKey);
  }

  static Future<Map<String, dynamic>> deleteAgent({
    required String apiBase,
    required String accountKey,
    required String agentSlug,
  }) {
    return Http.post('$apiBase/v1/a2a/delete-agent', {'agent_slug': agentSlug}, bearer: accountKey);
  }

  static Future<Map<String, dynamic>> invoke({
    required String apiBase,
    required String accountKey,
    required String targetAgent,
    required Map<String, dynamic> payload,
    String taskType = 'general',
    int? amountPence,
    String? idempotencyKey,
    String? fxQuoteId,
  }) async {
    final body = <String, dynamic>{
      'target_agent': targetAgent,
      'payload': payload,
      'task_type': taskType,
    };
    if (amountPence != null) body['amount_pence'] = amountPence;
    if (idempotencyKey != null) body['idempotency_key'] = idempotencyKey;
    if (fxQuoteId != null) body['fx_quote_id'] = fxQuoteId;

    return Http.post('$apiBase/v1/a2a/invoke', body, bearer: accountKey);
  }

  static Future<Map<String, dynamic>> pollResult({
    required String apiBase,
    required String accountKey,
    required String invokeId,
  }) {
    return Http.get('$apiBase/v1/a2a/result/$invokeId', bearer: accountKey);
  }
}
