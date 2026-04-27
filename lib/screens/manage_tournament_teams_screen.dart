import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/tournament_models.dart';
import '../provider/app_provider.dart';
import '../provider/tournament_provider.dart';
import '../utils/theme.dart';


class ManageTournamentTeamsScreen extends StatefulWidget {
  final String tournamentId;
  const ManageTournamentTeamsScreen({super.key, required this.tournamentId});

  @override
  State<ManageTournamentTeamsScreen> createState() =>
      _ManageTournamentTeamsScreenState();
}

class _ManageTournamentTeamsScreenState
    extends State<ManageTournamentTeamsScreen> {
  // ── Local mutable state ──
  late List<_GroupData> _groups;
  late List<String> _tournamentTeamIds;

  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadFromProvider();
  }

  void _loadFromProvider() {
    final tProvider = context.read<TournamentProvider>();
    final tournament = tProvider.getTournament(widget.tournamentId)!;

    _tournamentTeamIds = List.from(tournament.teamIds);


    final groupNames = tournament.tournamentTeams
        .map((t) => t.groupName)
        .toSet()
        .toList()
      ..sort();

    _groups = groupNames.map((gName) {
      final teamIds = tournament.tournamentTeams
          .where((t) => t.groupName == gName)
          .map((t) => t.teamId)
          .toList();
      return _GroupData(name: gName, teamIds: teamIds);
    }).toList();


    if (_groups.isEmpty) {
      _groups = [_GroupData(name: 'A', teamIds: List.from(_tournamentTeamIds))];
    }
  }

  // ── Group rename ──
  void _renameGroup(int groupIdx) {
    showDialog(
      context: context,
      builder: (_) => _RenameGroupDialog(
        currentName: _groups[groupIdx].name,
        existingNames: _groups.map((g) => g.name).toSet(),
        onRename: (newName) {
          setState(() {
            _groups[groupIdx] = _GroupData(
              name: newName,
              teamIds: _groups[groupIdx].teamIds,
            );
            _dirty = true;
          });
        },
      ),
    );
  }

  // ── new custom group add ──
  void _addNewGroup() {

    final usedNames = _groups.map((g) => g.name).toSet();
    String newName = '';
    for (int i = 0; i < 26; i++) {
      final candidate = String.fromCharCode(65 + i);
      if (!usedNames.contains(candidate)) {
        newName = candidate;
        break;
      }
    }
    if (newName.isEmpty) newName = 'G${_groups.length + 1}';

    setState(() {
      _groups.add(_GroupData(name: newName, teamIds: []));
      _dirty = true;
    });
  }

  // ── Group delete ──
  void _deleteGroup(int groupIdx) {
    final group = _groups[groupIdx];
    if (group.teamIds.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('প্রথমে group এর সব team সরিয়ে নিন বা অন্য group এ move করুন।'),
        ),
      );
      return;
    }
    setState(() {
      _groups.removeAt(groupIdx);
      _dirty = true;
    });
  }


  void _moveTeam(String teamId, String fromGroup, String toGroup) {
    setState(() {
      final from = _groups.firstWhere((g) => g.name == fromGroup);
      final to = _groups.firstWhere((g) => g.name == toGroup);
      from.teamIds.remove(teamId);
      to.teamIds.add(teamId);
      _dirty = true;
    });
  }

  // ── Team tournament from remove ──
  void _removeTeam(String teamId, String groupName) {
    setState(() {
      final group = _groups.firstWhere((g) => g.name == groupName);
      group.teamIds.remove(teamId);
      _tournamentTeamIds.remove(teamId);
      _dirty = true;
    });
  }

  // ── new team tournament add ──
  void _showAddTeamDialog(AppProvider aProvider) {

    final available = aProvider.teams
        .where((t) => !_tournamentTeamIds.contains(t.id))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('কোনো available team নেই। আগে নতুন team তৈরি করুন।')),
      );
      return;
    }

    String? selectedTeamId;
    String? selectedGroupName = _groups.isNotEmpty ? _groups.first.name : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16, right: 16, top: 20,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Team to Tournament',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Team select
            Text('Team নির্বাচন করুন',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 13)),
            const SizedBox(height: 8),
            ...available.map((team) => RadioListTile<String>(
              value: team.id,
              groupValue: selectedTeamId,
              onChanged: (v) => setModal(() => selectedTeamId = v),
              title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('${team.players.length} players',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              secondary: CircleAvatar(
                backgroundColor: selectedTeamId == team.id ? AppTheme.primary : Colors.grey.shade200,
                child: Text(team.name[0],
                    style: TextStyle(
                        color: selectedTeamId == team.id ? Colors.white : AppTheme.textSecondary,
                        fontWeight: FontWeight.bold)),
              ),
              activeColor: AppTheme.primary,
              contentPadding: EdgeInsets.zero,
            )),

            const SizedBox(height: 16),

            // Group select
            Text('কোন Group এ যোগ করবেন?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: _groups.map((g) {
              final sel = selectedGroupName == g.name;
              return ChoiceChip(
                label: Text('Group ${g.name} (${g.teamIds.length} teams)'),
                selected: sel,
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                    color: sel ? Colors.white : AppTheme.textSecondary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
                onSelected: (_) => setModal(() => selectedGroupName = g.name),
              );
            }).toList()),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () {
                if (selectedTeamId == null || selectedGroupName == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Team এবং Group উভয় select করুন।')),
                  );
                  return;
                }
                setState(() {
                  _tournamentTeamIds.add(selectedTeamId!);
                  _groups.firstWhere((g) => g.name == selectedGroupName).teamIds.add(selectedTeamId!);
                  _dirty = true;
                });
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add to Tournament'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── Move team dialog ──
  void _showMoveDialog(String teamId, String currentGroup, AppProvider aProvider) {
    final team = aProvider.getTeam(teamId);
    if (team == null) return;

    final otherGroups = _groups.where((g) => g.name != currentGroup).toList();
    if (otherGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Move করার জন্য অন্তত একটি আরও group থাকতে হবে।')),
      );
      return;
    }

    String? targetGroup;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('"${team.name}" কোন group এ move করবেন?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: otherGroups.map((g) => RadioListTile<String>(
              value: g.name,
              groupValue: targetGroup,
              onChanged: (v) => setDlg(() => targetGroup = v),
              title: Text('Group ${g.name} (${g.teamIds.length} teams)'),
              activeColor: AppTheme.primary,
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (targetGroup == null) return;
                _moveTeam(teamId, currentGroup, targetGroup!);
                Navigator.pop(context);
              },
              child: const Text('Move'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Save: provider apply ──
  void _saveChanges() {

    final Map<String, String> teamGroupMap = {};
    for (final g in _groups) {
      for (final tId in g.teamIds) {
        teamGroupMap[tId] = g.name;
      }
    }

    final tProvider = context.read<TournamentProvider>();


    final tournament = tProvider.getTournament(widget.tournamentId)!;
    final playedCount = tournament.matches.where((m) => m.isCompleted).length;

    if (playedCount > 0) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('সতর্কতা', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.orange)),
          content: Text(
            '$playedCount টি match ইতোমধ্যে complete হয়েছে। '
                'Team/Group পরিবর্তন করলে বাকি unplayed match গুলো regenerate হবে, '
                'কিন্তু played match এর result অক্ষুণ্ণ থাকবে।\n\nএগিয়ে যাবেন?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(context);
                _applyChanges(tProvider, teamGroupMap);
              },
              child: const Text('হ্যাঁ, Save করুন'),
            ),
          ],
        ),
      );
    } else {
      _applyChanges(tProvider, teamGroupMap);
    }
  }

  void _applyChanges(TournamentProvider tProvider, Map<String, String> teamGroupMap) {
    tProvider.updateTournamentTeamsAndGroups(
      tournamentId: widget.tournamentId,
      teamGroupMap: teamGroupMap,
      allTeamIds: _tournamentTeamIds,
    );
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ পরিবর্তন save হয়েছে এবং matches regenerate হয়েছে।'),
        backgroundColor: AppTheme.primary,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TournamentProvider, AppProvider>(
      builder: (ctx, tProvider, aProvider, _) {
        final tournament = tProvider.getTournament(widget.tournamentId);
        if (tournament == null) {
          return const Scaffold(body: Center(child: Text('Tournament পাওয়া যায়নি')));
        }

        return Scaffold(
          backgroundColor: AppTheme.surface,
          appBar: AppBar(
            title: Text('Teams & Groups', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            actions: [
              if (_dirty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save, color: Colors.white, size: 18),
                    label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          body: Column(children: [
            // Info banner
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Team add/remove করুন, group rename করুন, বা team কে drag করে অন্য group এ move করুন। শেষে Save করুন।',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                  ),
                ),
              ]),
            ),

            // Group list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                children: [
                  ..._groups.asMap().entries.map((entry) {
                    final i = entry.key;
                    final group = entry.value;
                    return _GroupCard(
                      group: group,
                      groupIndex: i,
                      allTeamIds: _tournamentTeamIds,
                      aProvider: aProvider,
                      otherGroupNames: _groups
                          .where((g) => g.name != group.name)
                          .map((g) => g.name)
                          .toList(),
                      onRename: () => _renameGroup(i),
                      onDelete: () => _deleteGroup(i),
                      onRemoveTeam: (teamId) => _removeTeam(teamId, group.name),
                      onMoveTeam: (teamId) => _showMoveDialog(teamId, group.name, aProvider),
                    );
                  }),
                ],
              ),
            ),
          ]),

          // Bottom buttons
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addNewGroup,
                    icon: const Icon(Icons.add_box_outlined, color: AppTheme.primary),
                    label: const Text('New Group', style: TextStyle(color: AppTheme.primary)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddTeamDialog(aProvider),
                    icon: const Icon(Icons.group_add),
                    label: const Text('Add Team'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppTheme.primary,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}


class _GroupCard extends StatelessWidget {
  final _GroupData group;
  final int groupIndex;
  final List<String> allTeamIds;
  final AppProvider aProvider;
  final List<String> otherGroupNames;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(String teamId) onRemoveTeam;
  final void Function(String teamId) onMoveTeam;

  const _GroupCard({
    required this.group,
    required this.groupIndex,
    required this.allTeamIds,
    required this.aProvider,
    required this.otherGroupNames,
    required this.onRename,
    required this.onDelete,
    required this.onRemoveTeam,
    required this.onMoveTeam,
  });

  @override
  Widget build(BuildContext context) {
    // group color: cycle through a palette
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.red];
    final color = colors[groupIndex % colors.length];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Group header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: color,
              child: Text(group.name[0],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Text('Group ${group.name}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            const SizedBox(width: 6),
            Text('(${group.teamIds.length} teams)',
                style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7))),
            const Spacer(),
            // Rename
            IconButton(
              icon: Icon(Icons.drive_file_rename_outline, size: 18, color: color),
              tooltip: 'Rename Group',
              onPressed: onRename,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              tooltip: 'Delete Group',
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ]),
        ),

        // Teams
        if (group.teamIds.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.group_off, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text('এই group এ কোনো team নেই',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ]),
          )
        else
          ...group.teamIds.map((teamId) {
            final team = aProvider.getTeam(teamId);
            if (team == null) return const SizedBox.shrink();
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(
                  team.name.isNotEmpty ? team.name[0] : 'T',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: Text('${team.players.length} players',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {
                  if (v == 'move') onMoveTeam(teamId);
                  if (v == 'remove') {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Remove "${team.name}"?',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                        content: const Text(
                            'এই team টি tournament থেকে সরিয়ে দেওয়া হবে। সংশ্লিষ্ট unplayed match গুলো মুছে যাবে।'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () {
                              Navigator.pop(context);
                              onRemoveTeam(teamId);
                            },
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  if (otherGroupNames.isNotEmpty)
                    const PopupMenuItem(
                      value: 'move',
                      child: Row(children: [
                        Icon(Icons.swap_horiz, size: 16, color: AppTheme.primary),
                        SizedBox(width: 8),
                        Text('অন্য Group এ Move করুন'),
                      ]),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(children: [
                      Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Tournament থেকে Remove', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 4),
      ]),
    );
  }
}

// ── Helper data class ──
class _GroupData {
  String name;
  List<String> teamIds;
  _GroupData({required this.name, required this.teamIds});
}

// ── Rename Group Dialog — proper dispose সহ ───────────────────────────────────
class _RenameGroupDialog extends StatefulWidget {
  final String currentName;
  final Set<String> existingNames;
  final void Function(String newName) onRename;

  const _RenameGroupDialog({
    required this.currentName,
    required this.existingNames,
    required this.onRename,
  });

  @override
  State<_RenameGroupDialog> createState() => _RenameGroupDialogState();
}

class _RenameGroupDialogState extends State<_RenameGroupDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Rename Group',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
    content: TextField(
      controller: _ctrl,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      maxLength: 5,
      decoration: const InputDecoration(
        labelText: 'Group Name',
        prefixIcon: Icon(Icons.drive_file_rename_outline,
            color: AppTheme.primary),
      ),
    ),
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel')),
      ElevatedButton(
        onPressed: () {
          final newName = _ctrl.text.trim().toUpperCase();
          if (newName.isEmpty) return;
          if (widget.existingNames.contains(newName) &&
              newName != widget.currentName) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Group "$newName" already exists!')),
            );
            return;
          }
          widget.onRename(newName);
          Navigator.pop(context);
        },
        child: const Text('Rename'),
      ),
    ],
  );
}