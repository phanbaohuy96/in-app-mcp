import 'package:flutter/material.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

/// Lists currently-active [EphemeralGrant]s with per-grant revoke buttons
/// and a "Revoke all" action. Shown as a Card inside the Settings screen.
class SettingsGrantsScreen extends StatefulWidget {
  const SettingsGrantsScreen({super.key, required this.mcp});

  final InAppMcp mcp;

  @override
  State<SettingsGrantsScreen> createState() => _SettingsGrantsScreenState();
}

class _SettingsGrantsScreenState extends State<SettingsGrantsScreen> {
  List<EphemeralGrant> _grants = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final grants = await widget.mcp.listActiveGrants();
      if (!mounted) return;
      setState(() {
        _grants = grants;
        _loading = false;
      });
    } on StateError {
      if (!mounted) return;
      setState(() {
        _grants = const [];
        _loading = false;
      });
    }
  }

  Future<void> _revoke(String toolName) async {
    await widget.mcp.revokeGrant(toolName);
    await _load();
  }

  Future<void> _revokeAll() async {
    await widget.mcp.revokeAllGrants();
    await _load();
  }

  String _describe(EphemeralGrant grant) {
    final uses = grant.remainingUses;
    final expires = grant.expiresAt;
    if (uses != null) return '$uses remaining';
    if (expires != null) {
      final delta = expires.difference(DateTime.now());
      if (delta.inMinutes >= 1) return 'expires in ${delta.inMinutes} min';
      if (delta.inSeconds >= 1) return 'expires in ${delta.inSeconds} s';
      return 'expired';
    }
    return 'until cleared';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Active grants',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_grants.isNotEmpty)
                  TextButton.icon(
                    key: const ValueKey('revoke-all-grants-button'),
                    onPressed: _revokeAll,
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('Revoke all'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_grants.isEmpty)
              const Text('No active grants.')
            else
              ..._grants.map(
                (grant) => ListTile(
                  key: ValueKey('grant-row-${grant.toolName}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(grant.toolName),
                  subtitle: Text('${grant.policy.name} · ${_describe(grant)}'),
                  trailing: TextButton(
                    key: ValueKey('revoke-grant-${grant.toolName}'),
                    onPressed: () => _revoke(grant.toolName),
                    child: const Text('Revoke'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
