import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../provider/app_provider.dart';
import '../utils/theme.dart';

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
          backgroundColor: AppTheme.primary,
          onPressed: () => _showAddTeamDialog(context, provider),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      );
    });
  }

  void _showAddTeamDialog(BuildContext context, AppProvider provider) {
    final nameCtrl = TextEditingController();
    final playerCtrls = List<TextEditingController>.generate(
        11, (i) => TextEditingController(text: 'Player ${i + 1}'));
    int playerCount = 11;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                controller: nameCtrl,
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
              // Player count control row
              Row(children: [
                const Text('Count: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppTheme.primary),
                  onPressed: playerCount > 1
                      ? () {
                    playerCtrls.last.dispose();
                    playerCtrls.removeLast();
                    setModalState(() => playerCount--);
                  }
                      : null,
                ),
                Text('$playerCount',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.primary),
                  onPressed: playerCount < 15
                      ? () {
                    playerCtrls.add(TextEditingController(
                        text: 'Player ${playerCount + 1}'));
                    setModalState(() => playerCount++);
                  }
                      : null,
                ),
              ]),
              const SizedBox(height: 4),
              ...List.generate(
                  playerCount,
                      (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: playerCtrls[i],
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
                  if (nameCtrl.text.trim().isNotEmpty) {
                    provider.createTeam(
                        nameCtrl.text.trim(),
                        playerCtrls
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
            ]),
          ),
        ),
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
            leading: CircleAvatar(
              radius: 13,
              backgroundColor: AppTheme.primary.withOpacity(0.12),
              child: Text('${i + 1}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold)),
            ),
            title: Text(p.name, style: const TextStyle(fontSize: 13)),
            trailing: IconButton(
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
    final ctrl = TextEditingController(text: team.name);
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Edit Team Name'),
      content: TextField(controller: ctrl,
          decoration: const InputDecoration(labelText: 'Team Name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            provider.updateTeam(team.id, ctrl.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ));
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
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Add Player'),
      content: TextField(controller: ctrl,
          decoration: const InputDecoration(labelText: 'Player Name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (ctrl.text.trim().isNotEmpty) {
              provider.addPlayerToTeam(team.id, ctrl.text.trim());
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    ));
  }
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