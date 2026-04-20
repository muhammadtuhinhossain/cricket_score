import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../provider/app_provider.dart';
import '../utils/theme.dart';
import 'scoring_screen.dart';

class NewMatchScreen extends StatefulWidget {
  const NewMatchScreen({super.key});
  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostCtrl = TextEditingController(text: 'Host Team');
  final _visitorCtrl = TextEditingController(text: 'Visitor Team');
  MatchFormat _format = MatchFormat.t20;
  int _overs = 20;
  String _tossWonBy = 'host';
  TossDecision _tossDecision = TossDecision.bat;

  int _hostPlayerCount = 11;
  int _visitorPlayerCount = 11;

  late List<TextEditingController> _hostPlayers;
  late List<TextEditingController> _visitorPlayers;

  @override
  void initState() {
    super.initState();
    _hostPlayers = List.generate(11, (i) => TextEditingController(text: 'Player ${i + 1}'));
    _visitorPlayers = List.generate(11, (i) => TextEditingController(text: 'Player ${i + 1}'));
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _visitorCtrl.dispose();
    for (var c in [..._hostPlayers, ..._visitorPlayers]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startMatch() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();

    final hostNames = _hostPlayers
        .map((c) => c.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final visitorNames = _visitorPlayers
        .map((c) => c.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    final match = provider.createMatch(
      hostTeamName: _hostCtrl.text.trim(),
      visitorTeamName: _visitorCtrl.text.trim(),
      hostPlayerNames: hostNames,
      visitorPlayerNames: visitorNames,
      format: _format,
      totalOvers: _overs,
      tossWonBy: _tossWonBy,
      tossDecision: _tossDecision,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ScoringScreen(matchId: match.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('New Match'),
        leading: const BackButton(),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Teams ──
            _sectionCard(
              'Teams',
              Column(children: [
                _teamField(_hostCtrl, 'Host Team'),
                const SizedBox(height: 12),
                _teamField(_visitorCtrl, 'Visitor Team'),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Toss ──
            _sectionCard(
              'Toss',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Won by:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _tossChip('host', 'Host Team')),
                    const SizedBox(width: 8),
                    Expanded(child: _tossChip('visitor', 'Visitor Team')),
                  ]),
                  const SizedBox(height: 12),
                  const Text('Elected to:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _decisionChip(TossDecision.bat, '🏏 Bat')),
                    const SizedBox(width: 8),
                    Expanded(child: _decisionChip(TossDecision.bowl, '⚾ Bowl')),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Format ──
            _sectionCard(
              'Format & Overs',
              Column(children: [
                Row(children: [
                  Expanded(child: _formatChip(MatchFormat.t20, 'T20', 20)),
                  const SizedBox(width: 8),
                  Expanded(child: _formatChip(MatchFormat.odi, 'ODI', 50)),
                  const SizedBox(width: 8),
                  Expanded(child: _formatChip(MatchFormat.custom, 'Custom', _overs)),
                ]),
                if (_format == MatchFormat.custom) ...[
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
                        onChanged: (v) => setState(() => _overs = v.toInt()),
                      ),
                    ),
                    Text('$_overs',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 12),

            // ── Advanced ──
            Card(
              child: ExpansionTile(
                title: Text('Advanced Settings',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                leading: const Icon(Icons.settings, color: AppTheme.primary),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _playersSection(
                          'Host Team Players',
                          _hostPlayers,
                          _hostPlayerCount,
                              (v) => setState(() => _hostPlayerCount = v),
                        ),
                        const SizedBox(height: 16),
                        _playersSection(
                          'Visitor Team Players',
                          _visitorPlayers,
                          _visitorPlayerCount,
                              (v) => setState(() => _visitorPlayerCount = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _startMatch,
              icon: const Icon(Icons.sports_cricket),
              label: const Text('Start Match'),
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
  }

  Widget _sectionCard(String title, Widget child) => Card(
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
        ],
      ),
    ),
  );

  Widget _teamField(TextEditingController ctrl, String label) =>
      TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.group, color: AppTheme.primary),
        ),
        validator: (v) =>
        v == null || v.trim().isEmpty ? 'Required' : null,
      );

  Widget _tossChip(String value, String label) {
    final selected = _tossWonBy == value;
    return GestureDetector(
      onTap: () => setState(() => _tossWonBy = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppTheme.primary : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Widget _decisionChip(TossDecision dec, String label) {
    final selected = _tossDecision == dec;
    return GestureDetector(
      onTap: () => setState(() => _tossDecision = dec),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppTheme.primary : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Widget _formatChip(MatchFormat fmt, String label, int overs) {
    final selected = _format == fmt;
    return GestureDetector(
      onTap: () => setState(() {
        _format = fmt;
        if (fmt != MatchFormat.custom) _overs = overs;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppTheme.primary : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Widget _playersSection(
      String title,
      List<TextEditingController> ctrls,
      int count,
      ValueChanged<int> onCountChanged,
      ) {

    final actualCount = ctrls.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        // Player count control row
        Row(children: [
          const Text('Players: ',
              style: TextStyle(fontWeight: FontWeight.w500)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: AppTheme.primary),
            onPressed: actualCount > 1
                ? () {

              final last = ctrls.removeLast();
              last.dispose();
              onCountChanged(ctrls.length);
            }
                : null,
          ),
          Text('$actualCount',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: AppTheme.primary),
            onPressed: actualCount < 15
                ? () {
              ctrls.add(TextEditingController(
                  text: 'Player ${actualCount + 1}'));
              onCountChanged(ctrls.length);
            }
                : null,
          ),
        ]),
        const SizedBox(height: 4),

        ...List.generate(
          ctrls.length,
              (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              controller: ctrls[i],
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
          ),
        ),
      ],
    );
  }
}