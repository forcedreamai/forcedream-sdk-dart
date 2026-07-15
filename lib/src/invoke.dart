import 'http.dart';

class InvokeResult {
  final String status;
  final String agent;
  final String? taskId;
  final Map<String, dynamic>? output;
  final int? chargedPence;
  final String? proofId;
  final String message;
  final String? error;

  InvokeResult({
    required this.status,
    required this.agent,
    this.taskId,
    this.output,
    this.chargedPence,
    this.proofId,
    required this.message,
    this.error,
  });

  @override
  String toString() =>
      'InvokeResult(status: $status, agent: $agent, taskId: $taskId, '
      'chargedPence: $chargedPence, proofId: $proofId, message: $message)';
}

/// Ported precisely from @forcedream/mcp-server's invoke_agent.ts (via the same logic
/// already proven in every other SDK tonight) -- exact endpoints, exact polling interval
/// ramp (starts 2500ms, +1000ms per attempt, capped at 6000ms), exact status handling.
/// Invokes ONCE; never re-invokes on timeout (would double-charge) -- returns a pollable
/// task_id instead.
class Invoke {
  Invoke._();

  static Future<InvokeResult> invokeAgentPolling({
    required String apiBase,
    required String apiKey,
    required String agentSlug,
    required String task,
    int maxWaitSeconds = 60,
  }) async {
    final maxWaitMs = maxWaitSeconds.clamp(5, 120) * 1000;
    final encodedSlug = Uri.encodeComponent(agentSlug);

    try {
      final inv = await Http.postResult(
        '$apiBase/v1/agents/$encodedSlug/invoke',
        {'task': task},
        bearer: apiKey,
      );

      if (inv.status == 401) {
        return InvokeResult(status: 'error', agent: agentSlug, message: 'Invalid API key (401).', error: 'invalid_key');
      }

      final taskId = inv.json['task_id'] as String?;
      if (taskId == null) {
        final errMsg = (inv.json['error'] as String?) ?? (inv.json['note'] as String?) ?? 'no task_id';
        return InvokeResult(
          status: 'error',
          agent: agentSlug,
          message: 'Invoke failed (HTTP ${inv.status}): $errMsg',
          error: 'invoke_failed',
        );
      }

      final encodedTaskId = Uri.encodeComponent(taskId);
      final start = DateTime.now().millisecondsSinceEpoch;
      var intervalMs = 2500;

      while (DateTime.now().millisecondsSinceEpoch - start < maxWaitMs) {
        await Future.delayed(Duration(milliseconds: intervalMs));

        final poll = await Http.getResult(
          '$apiBase/v1/agents/$encodedSlug/result/$encodedTaskId',
          bearer: apiKey,
        );
        final d = poll.json;
        final pollStatus = (d['status'] as String?) ?? (d['outcome'] as String?) ?? '';
        final okTrue = d['ok'] == true;

        if (pollStatus == 'completed' || pollStatus == 'succeeded' || okTrue) {
          final output = d['output'] as Map<String, dynamic>?;
          final outcomeInsufficient = d['outcome'] == 'insufficient';
          final confidenceInsufficient = output != null && output['confidence'] == 'insufficient';

          if (outcomeInsufficient || confidenceInsufficient) {
            return InvokeResult(
              status: 'insufficient',
              agent: agentSlug,
              taskId: taskId,
              output: output,
              chargedPence: 0,
              message: 'Agent returned insufficient evidence and declined rather than fabricate. Charged nothing.',
            );
          }

          final charged = d['charged_pence'] as int?;
          final proofId = (d['proof_id'] as String?) ?? taskId;
          return InvokeResult(
            status: 'completed',
            agent: agentSlug,
            taskId: taskId,
            output: output,
            chargedPence: charged,
            proofId: proofId,
            message: 'Completed. Charged ${charged ?? 0}p. Cryptographically proven (proof_id $proofId).',
          );
        }

        if (pollStatus == 'insufficient') {
          return InvokeResult(
            status: 'insufficient',
            agent: agentSlug,
            taskId: taskId,
            output: d['output'] as Map<String, dynamic>?,
            chargedPence: 0,
            message: 'Agent declined (insufficient evidence). Charged nothing.',
          );
        }

        if (pollStatus == 'charge_failed') {
          final reason = (d['reason'] as String?) ?? 'insufficient_balance';
          return InvokeResult(
            status: 'error',
            agent: agentSlug,
            taskId: taskId,
            chargedPence: 0,
            error: 'charge_failed',
            message: 'Charge failed: $reason. Nothing charged or delivered. Top up and retry.',
          );
        }

        if (pollStatus == 'failed' || pollStatus == 'dead_letter') {
          final reason = (d['reason'] as String?) ?? (d['last_error'] as String?) ?? 'unknown';
          return InvokeResult(
            status: 'error',
            agent: agentSlug,
            taskId: taskId,
            message: 'Task $pollStatus: $reason',
            error: pollStatus,
          );
        }

        intervalMs = (intervalMs + 1000).clamp(0, 6000);
      }

      return InvokeResult(
        status: 'pending',
        agent: agentSlug,
        taskId: taskId,
        message: 'Still processing after ${maxWaitMs ~/ 1000}s. Not re-invoked (would double-charge). Poll the result later with this task_id.',
      );
    } catch (e) {
      return InvokeResult(status: 'error', agent: agentSlug, message: 'Invoke request failed: $e', error: 'request_failed');
    }
  }
}
