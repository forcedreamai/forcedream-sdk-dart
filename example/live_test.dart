import 'package:forcedream/forcedream.dart';

Future<void> main() async {
  print('=== Real signup ===');
  final signup = await ForceDream.signup(email: 'dart-sdk-test-${DateTime.now().millisecondsSinceEpoch}@example.com');
  final liveKey = signup['live_key'] as String;
  final accountKey = signup['api_key'] as String;
  print('Signed up: user_id=${signup['user_id']}, trial_balance=${signup['trial_balance_gbp']}');

  final client = ForceDream(apiKey: liveKey, accountKey: accountKey);

  print('\n=== searchAgents (client-side filtered) ===');
  final results = await client.searchAgents(query: 'extract');
  print(results);

  print('\n=== invoke (real agent, real charge) ===');
  final invokeResult = await client.invoke(
    agentSlug: 'data-extract-v1',
    task: 'Extract year and location from: The exhibition traveled to Amsterdam in 2016.',
  );
  print(invokeResult);

  print('\n=== verify (real Ed25519 proof) ===');
  if (invokeResult.taskId != null) {
    final verifyResult = await client.verify(taskId: invokeResult.taskId);
    print(verifyResult);
  } else {
    print('No task_id to verify.');
  }

  print('\n=== A2A: register a real agent (uses the sk_fd_ account key) ===');
  final slug = 'dart-sdk-test-agent-${DateTime.now().millisecondsSinceEpoch}';
  final registerResult = await client.registerAgent(
    agentSlug: slug,
    capabilities: ['data:extraction'],
    pricePerCallPence: 5,
    name: 'Dart SDK Test Agent',
  );
  print(registerResult);

  print('\n=== A2A: clean up -- delete the just-registered test agent ===');
  final deleteResult = await client.deleteAgent(agentSlug: slug);
  print(deleteResult);
}
