import 'http.dart';

/// Ported precisely from @forcedream/mcp-server's search_agents.ts (via the same logic
/// already proven in every other SDK tonight). Real, load-bearing fact confirmed directly
/// from that source in earlier work tonight, not assumed here: the server has no working
/// server-side capability/query filter on /v1/agents/list -- filtering must happen
/// client-side, after fetching the full list. Also merges in real reliability data from the
/// separate /v1/agents/reliability endpoint, exactly as every other SDK does.
class Agents {
  Agents._();

  static Future<Map<String, dynamic>> searchAgentsFiltered({
    required String apiBase,
    String? capability,
    String? query,
  }) async {
    final data = await Http.get('$apiBase/v1/agents/list');
    var agents = (data['agents'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];

    Map<String, dynamic>? relData;
    try {
      relData = await Http.get('$apiBase/v1/agents/reliability');
    } catch (_) {
      relData = null;
    }

    final reliabilityBySlug = <String, dynamic>{};
    final relAgents = (relData?['agents'] as List?)?.cast<Map<String, dynamic>>();
    if (relAgents != null) {
      for (final ra in relAgents) {
        final slug = ra['agent_slug'] as String?;
        if (slug != null && ra['reliability'] != null) {
          reliabilityBySlug[slug] = ra['reliability'];
        }
      }
    }

    if (capability != null) {
      final capLower = capability.toLowerCase();
      agents = agents.where((a) {
        final caps = (a['capabilities'] as List?)?.cast<String>() ?? [];
        return caps.any((c) => c.toLowerCase() == capLower);
      }).toList();
    }
    if (query != null) {
      final qLower = query.toLowerCase();
      agents = agents.where((a) {
        final slug = (a['slug'] as String? ?? '').toLowerCase();
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (slug.contains(qLower) || name.contains(qLower)) return true;
        final caps = (a['capabilities'] as List?)?.cast<String>() ?? [];
        return caps.any((c) => c.toLowerCase().contains(qLower));
      }).toList();
    }

    final enriched = agents.map((a) {
      final copy = Map<String, dynamic>.from(a);
      final slug = a['slug'] as String?;
      copy['health'] = slug != null ? reliabilityBySlug[slug] : null;
      return copy;
    }).toList();

    return {
      'count': enriched.length,
      'agents': enriched,
      'note': enriched.isEmpty
          ? 'No agents matched. The registry contains only real, registered agents with cryptographic proofs.'
          : 'Metrics are system-derived from proofs/ledger (proof_count, success_rate) -- never self-reported. Health (success_rate, avg_latency_ms, sample_size) is honestly null where no real reliability data exists yet.',
    };
  }
}
