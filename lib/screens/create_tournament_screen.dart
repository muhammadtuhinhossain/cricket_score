import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../provider/app_provider.dart';
import '../provider/tournament_provider.dart';
import '../utils/theme.dart';
import 'tournament_detail_screen.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});
  @override
  State<CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState
    extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _format = 't20';
  int _overs = 20;
  int _teamsPerGroup = 4;

  final List<String> _selectedTeamIds = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _totalGroups =>
      (_selectedTeamIds.length / _teamsPerGroup).ceil();

  void _create() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeamIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least 2 teams!')),
      );
      return;
    }

    final tProvider = context.read<TournamentProvider>();
    final tournament = tProvider.createTournament(
      name: _nameCtrl.text.trim(),
      teamIds: _selectedTeamIds,
      teamsPerGroup: _teamsPerGroup,
      totalOvers: _overs,
      format: _format,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TournamentDetailScreen(tournamentId: tournament.id),
      ),
    );
  }


  void _showCreateTeamDialog(BuildContext context, AppProvider aProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateTeamSheet(
        aProvider: aProvider,
        onTeamCreated: (teamId) {
          setState(() => _selectedTeamIds.add(teamId));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (ctx, aProvider, _) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Tournament')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Name
              _card('Tournament Name', TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'e.g. Summer Cup 2025',
                  prefixIcon: Icon(Icons.emoji_events,
                      color: AppTheme.primary),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Required'
                    : null,
              )),
              const SizedBox(height: 12),

              // Format
              _card(
                  'Format & Overs',
                  Column(children: [
                    Row(children: [
                      Expanded(child: _fmtChip('t20', 'T20', 20)),
                      const SizedBox(width: 8),
                      Expanded(child: _fmtChip('odi', 'ODI', 50)),
                      const SizedBox(width: 8),
                      Expanded(child: _fmtChip('custom', 'Custom', _overs)),
                    ]),
                    if (_format == 'custom') ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        const Text('Overs: '),
                        Expanded(
                          child: Slider(
                            value: _overs.toDouble(),
                            min: 1,
                            max: 50,
                            divisions: 49,
                            label: '$_overs',
                            onChanged: (v) =>
                                setState(() => _overs = v.toInt()),
                          ),
                        ),
                        Text('$_overs',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ]),
                    ],
                  ])),
              const SizedBox(height: 12),

              // Teams per group
              _card(
                  'Teams per Group',
                  Column(children: [
                    Row(children: [
                      for (final n in [2, 3, 4, 5])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _groupChip(n),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedTeamIds.length} teams → $_totalGroups group(s)',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary),
                    ),
                  ])),
              const SizedBox(height: 12),

              // Team selection — existing + create new button
              _card(
                  'Select Teams (${_selectedTeamIds.length})',
                  Column(children: [
                    // ── new team create button ──
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showCreateTeamDialog(context, aProvider),
                      icon: const Icon(Icons.add,
                          color: AppTheme.primary),
                      label: const Text('Create New Team',
                          style: TextStyle(color: AppTheme.primary)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: const BorderSide(
                            color: AppTheme.primary),
                      ),
                    ),
                    if (aProvider.teams.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                    ],
                    if (aProvider.teams.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                            'No saved teams yet. Create one above!',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13)),
                      ),
                    ...aProvider.teams.map((team) {
                      final selected =
                      _selectedTeamIds.contains(team.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedTeamIds.add(team.id);
                          } else {
                            _selectedTeamIds.remove(team.id);
                          }
                        }),
                        title: Text(team.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                        subtitle: Text(
                            '${team.players.length} players',
                            style: const TextStyle(fontSize: 12)),
                        secondary: CircleAvatar(
                          backgroundColor: selected
                              ? AppTheme.primary
                              : Colors.grey.shade200,
                          child: Text(
                            team.name.isNotEmpty
                                ? team.name[0]
                                : 'T',
                            style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        activeColor: AppTheme.primary,
                        controlAffinity:
                        ListTileControlAffinity.trailing,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ])),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.emoji_events),
                label: const Text('Create Tournament'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    });
  }

  Widget _card(String title, Widget child) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.primary)),
            const SizedBox(height: 12),
            child,
          ]),
    ),
  );

  Widget _fmtChip(String val, String label, int overs) {
    final selected = _format == val;
    return GestureDetector(
      onTap: () => setState(() {
        _format = val;
        if (val != 'custom') _overs = overs;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : Colors.grey.shade300),
        ),
        child: Center(
            child: Text(label,
                style: TextStyle(
                    color: selected
                        ? Colors.white
                        : AppTheme.textSecondary,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 13))),
      ),
    );
  }

  Widget _groupChip(int n) {
    final selected = _teamsPerGroup == n;
    return GestureDetector(
      onTap: () => setState(() => _teamsPerGroup = n),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? AppTheme.primary
                  : Colors.grey.shade300),
        ),
        child: Center(
            child: Text('$n teams',
                style: TextStyle(
                    color: selected
                        ? Colors.white
                        : AppTheme.textSecondary,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 12))),
      ),
    );
  }
}

// ── Create Team Sheet — proper dispose সহ ─────────────────────────────────────
class _CreateTeamSheet extends StatefulWidget {
  final AppProvider aProvider;
  final void Function(String teamId) onTeamCreated;

  const _CreateTeamSheet({
    required this.aProvider,
    required this.onTeamCreated,
  });

  @override
  State<_CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<_CreateTeamSheet> {
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
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Create New Team',
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
                  fontWeight: FontWeight.w600, color: AppTheme.primary)),
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
                              fontSize: 11, color: Colors.white)),
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              if (_nameCtrl.text.trim().isNotEmpty) {
                final team = widget.aProvider.createTeam(
                    _nameCtrl.text.trim(),
                    _playerCtrls.map((c) => c.text.trim()).toList());
                widget.onTeamCreated(team.id);
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Create & Add to Tournament'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}