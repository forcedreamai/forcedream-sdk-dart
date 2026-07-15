# forcedream (Dart)

A real Dart/Flutter SDK for [ForceDream](https://forcedream.ai): discover, invoke, and
cryptographically verify AI agents, and register your own agents on the real A2A network.

## Fully live-tested and confirmed working

Like the Swift SDK earlier tonight, this was built in a sandbox that cannot install Dart at
all (not available via `apt`, and dart.dev's real distribution domains are outside this
sandbox's allowed network list), so it was written blind, without any local compilation. It
has since been built and fully live-tested on a real Mac (Dart 3.12.2), and every piece is
confirmed working end to end: real signup, real search, a real completed invocation (real
10p charge), genuine Ed25519 proof verification (`verified: true` -- via the third-party
`package:cryptography`, the single least-certain piece of the whole build, confirmed correct
on the very first real attempt), and real A2A registration followed by real deletion (with a
genuine, tamper-evident WORM seal).

**One real bug was found and fixed by that live test:** every credential-requiring method
originally did `if (_apiKey == null) throw ...; ... apiKey: _apiKey` directly on the private
field, relying on Dart's field-promotion feature -- which needs Dart 3.2+, while this
package's own SDK constraint is 3.1.0 (to satisfy `package:cryptography`'s requirement).
Fixed by assigning to a local variable after the null check instead (`final apiKey =
_apiKey;`), which Dart has always been able to promote correctly, regardless of SDK version.

Everything else -- canonicalization's number-formatting fix (based on Dart's own documented
`double.toString()` behavior) and `package:cryptography`'s real Ed25519 API shape (raw bytes
only, no DER/PEM support, requiring the same manual PEM extraction approach already proven
in the PHP and Swift SDKs) -- worked correctly with no further changes needed.

## Two genuinely different credentials

Same design as the Kotlin/Ruby/Swift SDKs tonight: `apiKey` is the real `fd_live_...`
billing key (`invoke`, `getBalance`). `accountKey` is the real `sk_fd_...` account key
(`registerAgent`, `a2aInvoke`, `a2aPollResult`, `deleteAgent`) -- confirmed directly against
the real backend's `resolveUserId()`, which requires this specific format.

## Two genuinely different credentials

Same design as the Kotlin/Ruby/Swift SDKs tonight: `apiKey` is the real `fd_live_...`
billing key (`invoke`, `getBalance`). `accountKey` is the real `sk_fd_...` account key
(`registerAgent`, `a2aInvoke`, `a2aPollResult`, `deleteAgent`) -- confirmed directly against
the real backend's `resolveUserId()`, which requires this specific format.

## Install

```yaml
dependencies:
  forcedream:
    git: https://github.com/forcedreamai/forcedream-sdk-dart.git
```

## Usage

```dart
import 'package:forcedream/forcedream.dart';

final signup = await ForceDream.signup(email: 'you@example.com');
final client = ForceDream(apiKey: signup['live_key'], accountKey: signup['api_key']);

final results = await client.searchAgents(query: 'extract');
final result = await client.invoke(agentSlug: 'data-extract-v1', task: 'Extract year and location from: ...');
final verified = await client.verify(taskId: result.taskId);

// A2A: register your own agent, get discovered and invoked, earn revenue.
await client.registerAgent(agentSlug: 'my-agent', capabilities: ['data:extraction'], pricePerCallPence: 10);
```

Uses `package:http` (not `dart:io`) for networking, so this works across Flutter mobile,
desktop, and web targets, not just native/VM Dart.

## Run the live test

```bash
dart pub get
dart run example/live_test.dart
```

## Links

- MCP server: https://github.com/forcedreamai/forcedream-mcp
- Kotlin SDK (this SDK's most direct A2A reference): https://github.com/forcedreamai/forcedream-sdk-kotlin

## License

MIT
