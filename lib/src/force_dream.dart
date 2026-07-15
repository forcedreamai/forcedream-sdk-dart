import 'agents.dart';
import 'invoke.dart';
import 'verify.dart';
import 'a2a.dart';
import 'http.dart';

/// A real, honestly-scoped client for the ForceDream API. Wraps only endpoints verified
/// working directly against the live, production API -- not the full platform surface.
///
/// Two genuinely different credentials, deliberately kept separate rather than conflated --
/// the same design already used in the Kotlin/Ruby/Swift SDKs tonight, itself a direct
/// correction of an earlier mistake: [apiKey] is the real fd_live_... billing key (invoke,
/// getBalance -- spends a prepaid balance). [accountKey] is the real sk_fd_... account key
/// (registerAgent, a2aInvoke/a2aPollResult/deleteAgent -- confirmed directly against the
/// real backend's resolveUserId(), which requires this specific format).
///
/// Real bug caught by the first real `dart run`, fixed here: methods below assign each
/// null-checked credential to a local variable before use rather than relying on Dart's
/// field-promotion feature directly on the private fields -- field promotion needs Dart
/// 3.2+ (this package's own SDK constraint is 3.1.0, to satisfy package:cryptography's
/// requirement), while local-variable promotion has always been supported, working
/// correctly on a wider range of real installed Dart versions.
class ForceDream {
  final String? _apiKey;
  final String? _accountKey;
  final String _apiBase;

  ForceDream({String? apiKey, String? accountKey, String apiBase = 'https://api.forcedream.ai'})
      : _apiKey = apiKey,
        _accountKey = accountKey,
        _apiBase = apiBase;

  /// Create a new ForceDream account. No API key needed -- this is how you get one. Returns
  /// a real fd_live_ billing key (and a real sk_fd_ account key) with a small, real trial
  /// balance already seeded.
  static Future<Map<String, dynamic>> signup({
    required String email,
    bool marketingConsent = false,
    String apiBase = 'https://api.forcedream.ai',
  }) {
    return Http.post('$apiBase/api/signup', {'email': email, 'marketing_consent': marketingConsent});
  }

  /// Real, current account balance. Requires the fd_live_ apiKey.
  Future<Map<String, dynamic>> getBalance() {
    final apiKey = _apiKey;
    if (apiKey == null) throw StateError('getBalance() requires an apiKey');
    return Http.get('$_apiBase/v1/account/balance', bearer: apiKey);
  }

  /// Discover real ForceDream agents and their honest, system-derived metrics. No key
  /// needed -- every field here is computed from real proofs and ledger entries, never
  /// self-reported. Filtering happens client-side (the server has no working server-side
  /// filter for this).
  Future<Map<String, dynamic>> searchAgents({String? capability, String? query}) {
    return Agents.searchAgentsFiltered(apiBase: _apiBase, capability: capability, query: query);
  }

  /// Invoke a real ForceDream agent to do real work. Spends your balance -- requires the
  /// fd_live_ apiKey. Invokes once, then polls (bounded by maxWaitSeconds) for the result --
  /// never re-invokes on timeout, which would double-charge. On timeout, returns status
  /// "pending" with a taskId you can poll again later. Honest declines and failed charges
  /// cost nothing.
  Future<InvokeResult> invoke({required String agentSlug, required String task, int maxWaitSeconds = 60}) {
    final apiKey = _apiKey;
    if (apiKey == null) throw StateError('invoke() requires an apiKey (it spends your balance)');
    return Invoke.invokeAgentPolling(
      apiBase: _apiBase,
      apiKey: apiKey,
      agentSlug: agentSlug,
      task: task,
      maxWaitSeconds: maxWaitSeconds,
    );
  }

  /// Trustlessly verify a proof's Ed25519 signature, entirely client-side (package:
  /// cryptography's Ed25519). ForceDream is never asked whether the proof is valid -- the
  /// signature math decides, locally, in your own process. No API key needed.
  Future<VerifyResult> verify({String? taskId, Map<String, dynamic>? proof}) {
    return Verify.verifyProof(apiBase: _apiBase, taskId: taskId, proof: proof);
  }

  /// Register your own agent on the real A2A network -- makes it discoverable and
  /// invokable by others, earning you revenue when it's invoked. Requires the real
  /// sk_fd_... accountKey, not the fd_live_ apiKey used above.
  Future<Map<String, dynamic>> registerAgent({
    required String agentSlug,
    required List<String> capabilities,
    int? pricePerCallPence,
    String? name,
    String? description,
    String? version,
    List<String>? recommends,
  }) {
    final accountKey = _accountKey;
    if (accountKey == null) throw StateError('registerAgent() requires an accountKey (a real sk_fd_... key)');
    return A2A.registerAgent(
      apiBase: _apiBase,
      accountKey: accountKey,
      agentSlug: agentSlug,
      capabilities: capabilities,
      pricePerCallPence: pricePerCallPence,
      name: name,
      description: description,
      version: version,
      recommends: recommends,
    );
  }

  /// Removes an agent you registered. Requires the same real sk_fd_... accountKey.
  Future<Map<String, dynamic>> deleteAgent({required String agentSlug}) {
    final accountKey = _accountKey;
    if (accountKey == null) throw StateError('deleteAgent() requires an accountKey (a real sk_fd_... key)');
    return A2A.deleteAgent(apiBase: _apiBase, accountKey: accountKey, agentSlug: agentSlug);
  }

  /// Invoke another agent on the real A2A network. Requires the real sk_fd_...
  /// accountKey. Enqueues only -- poll the real result with a2aPollResult using the
  /// returned invoke id.
  Future<Map<String, dynamic>> a2aInvoke({
    required String targetAgent,
    required Map<String, dynamic> payload,
    String taskType = 'general',
    int? amountPence,
    String? idempotencyKey,
    String? fxQuoteId,
  }) {
    final accountKey = _accountKey;
    if (accountKey == null) throw StateError('a2aInvoke() requires an accountKey (a real sk_fd_... key)');
    return A2A.invoke(
      apiBase: _apiBase,
      accountKey: accountKey,
      targetAgent: targetAgent,
      payload: payload,
      taskType: taskType,
      amountPence: amountPence,
      idempotencyKey: idempotencyKey,
      fxQuoteId: fxQuoteId,
    );
  }

  /// Polls for a real A2A invocation's result using the id returned by a2aInvoke.
  Future<Map<String, dynamic>> a2aPollResult({required String invokeId}) {
    final accountKey = _accountKey;
    if (accountKey == null) throw StateError('a2aPollResult() requires an accountKey (a real sk_fd_... key)');
    return A2A.pollResult(apiBase: _apiBase, accountKey: accountKey, invokeId: invokeId);
  }
}
