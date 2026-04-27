import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../provider/app_provider.dart';
import '../utils/theme.dart';
import 'player_profile_screen.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (ctx, provider, _) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        body: provider.teams.isEmpty
            ? _EmptyTeams(onAdd: () => _showAddTeamDialog(context, provider))
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: provider.teams.length,
          itemBuilder: (_, i) => _TeamCard(
              team: provider.teams[i], provider: provider),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'teams_add_fab',
          backgroundColor: AppTheme.primary,
          onPressed: () => _showAddTeamDialog(context, provider),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      );
    });
  }

  void _showAddTeamDialog(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddTeamSheet(provider: provider),
    );
  }
}

// ── Add Team Sheet — proper dispose সহ ──────────────────────────
class _AddTeamSheet extends StatefulWidget {
  final AppProvider provider;
  const _AddTeamSheet({required this.provider});

  @override
  State<_AddTeamSheet> createState() => _AddTeamSheetState();
}

class _AddTeamSheetState extends State<_AddTeamSheet> {
  late TextEditingController _nameCtrl;
  late List<TextEditingController> _playerCtrls;
  int _playerCount = 11;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _playerCtrls = List.generate(
        11, (i) => TextEditingController(text: 'Player ${i + 1}'));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _playerCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16, right: 16, top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Create Team',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Team Name',
              prefixIcon: Icon(Icons.group, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text('Players',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary)),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Count: ',
                style: TextStyle(fontWeight: FontWeight.w500)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppTheme.primary),
              onPressed: _playerCount > 1
                  ? () {
                final ctrl = _playerCtrls.removeLast();
                ctrl.dispose();
                setState(() => _playerCount--);
              }
                  : null,
            ),
            Text('$_playerCount',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: AppTheme.primary),
              onPressed: _playerCount < 15
                  ? () {
                _playerCtrls.add(TextEditingController(
                    text: 'Player ${_playerCount + 1}'));
                setState(() => _playerCount++);
              }
                  : null,
            ),
          ]),
          const SizedBox(height: 4),
          ...List.generate(
              _playerCount,
                  (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _playerCtrls[i],
                  decoration: InputDecoration(
                    labelText: 'Player ${i + 1}',
                    isDense: true,
                    prefixIcon: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primary,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white)),
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              if (_nameCtrl.text.trim().isNotEmpty) {
                widget.provider.createTeam(
                    _nameCtrl.text.trim(),
                    _playerCtrls
                        .map((c) => c.text.trim())
                        .toList());
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Create Team'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final Team team;
  final AppProvider provider;
  const _TeamCard({required this.team, required this.provider});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.primary,
        child: Text(team.name.isNotEmpty ? team.name[0] : 'T',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold)),
      ),
      title: Text(team.name, style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600)),
      subtitle: Text(
          '${team.players.length} players  •  '
              '${team.won}W ${team.lost}L',
          style: const TextStyle(fontSize: 12,
              color: AppTheme.textSecondary)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
          onPressed: () => _editTeam(context),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: () => _deleteTeam(context),
        ),
      ]),
      children: [
        ...team.players.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          return ListTile(
            dense: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerProfileScreen(
                  playerId: p.id,
                  teamId: team.id,
                ),
              ),
            ),
            leading: CircleAvatar(
              radius: 13,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              child: Text('${i + 1}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold)),
            ),
            title: Row(children: [
              Text(p.name, style: const TextStyle(fontSize: 13)),
              if (p.isReserve) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('R', style: TextStyle(
                      fontSize: 10, color: Colors.orange,
                      fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              // Reserve toggle
              GestureDetector(
                onTap: () => provider.togglePlayerReserve(team.id, i),
                child: Container(
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: p.isReserve
                        ? Colors.orange.withValues(alpha: 0.15)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(child: Text('R',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: p.isReserve ? Colors.orange : Colors.grey,
                    ),
                  )),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                tooltip: 'Remove player',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('${p.name} কে সরাবেন?',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      content: const Text('এই player টি team থেকে বাদ যাবে।'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('বাতিল')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            provider.removePlayerFromTeam(team.id, i);
                            Navigator.pop(context);
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.person_add, color: AppTheme.primary),
            label: const Text('Add Player',
                style: TextStyle(color: AppTheme.primary)),
            onPressed: () => _addPlayer(context),
          ),
        ),
      ],
    ),
  );

  void _editTeam(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _EditTeamDialog(team: team, provider: provider),
    );
  }

  void _deleteTeam(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Team?'),
      content: Text('Are you sure you want to delete ${team.name}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            provider.deleteTeam(team.id);
            Navigator.pop(context);
          },
          child: const Text('Delete'),
        ),
      ],
    ));
  }

  void _addPlayer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddPlayerDialog(team: team, provider: provider),
    );
  }
}

// ── Edit Team Dialog — proper dispose সহ ──────────────────────────
class _EditTeamDialog extends StatefulWidget {
  final Team team;
  final AppProvider provider;
  const _EditTeamDialog({required this.team, required this.provider});

  @override
  State<_EditTeamDialog> createState() => _EditTeamDialogState();
}

class _EditTeamDialogState extends State<_EditTeamDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.team.name);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit Team Name'),
    content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(labelText: 'Team Name')),
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel')),
      ElevatedButton(
        onPressed: () {
          widget.provider.updateTeam(widget.team.id, _ctrl.text.trim());
          Navigator.pop(context);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

// ── Add Player Dialog — proper dispose সহ ──────────────────────────
class _AddPlayerDialog extends StatefulWidget {
  final Team team;
  final AppProvider provider;
  const _AddPlayerDialog({required this.team, required this.provider});

  @override
  State<_AddPlayerDialog> createState() => _AddPlayerDialogState();
}

class _AddPlayerDialogState extends State<_AddPlayerDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add Player'),
    content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(labelText: 'Player Name')),
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel')),
      ElevatedButton(
        onPressed: () {
          if (_ctrl.text.trim().isNotEmpty) {
            widget.provider.addPlayerToTeam(
                widget.team.id, _ctrl.text.trim());
            Navigator.pop(context);
          }
        },
        child: const Text('Add'),
      ),
    ],
  );
}

class _EmptyTeams extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTeams({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.group_off, size: 72, color: Colors.grey),
      const SizedBox(height: 16),
      Text('No teams yet', style: GoogleFonts.poppins(
          fontSize: 18, color: AppTheme.textSecondary)),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('Create Team'),
        onPressed: onAdd,
      ),
    ]),
  );
}