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
  final _hostCtrl = TextEditingController();
  final _visitorCtrl = TextEditingController();
  final _oversCtrl = TextEditingController();
  String _tossWonBy = 'host';
  TossDecision _tossDecision = TossDecision.bat;

  int _hostPlayerCount = 11;
  int _visitorPlayerCount = 11;

  late List<TextEditingController> _hostPlayers;
  late List<TextEditingController> _visitorPlayers;
  final Set<int> _hostReserveIndices = {};
  final Set<int> _visitorReserveIndices = {};

  @override
  void initState() {
    super.initState();
    _hostPlayers = List.generate(11, (i) => TextEditingController());
    _visitorPlayers = List.generate(11, (i) => TextEditingController());

    _hostCtrl.addListener(() => _onTeamNameChanged(_hostCtrl.text, isHost: true));
    _visitorCtrl.addListener(() => _onTeamNameChanged(_visitorCtrl.text, isHost: false));
  }

  void _onTeamNameChanged(String name, {required bool isHost}) {
    final provider = context.read<AppProvider>();
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    Team? matched;
    try {
      matched = provider.teams.firstWhere(
            (t) => t.name.toLowerCase() == trimmed.toLowerCase(),
      );
    } catch (_) {
      matched = null;
    }

    if (matched == null) return;

    setState(() {
      final players = matched!.players;
      final ctrls = isHost ? _hostPlayers : _visitorPlayers;
      final reserveIndices = isHost ? _hostReserveIndices : _visitorReserveIndices;

      for (final c in ctrls) {
        c.dispose();
      }
      ctrls.clear();
      reserveIndices.clear();

      for (int i = 0; i < players.length; i++) {
        ctrls.add(TextEditingController(text: players[i].name));
        if (players[i].isReserve) {
          reserveIndices.add(i);
        }
      }

      if (isHost) {
        _hostPlayerCount = ctrls.length;
      } else {
        _visitorPlayerCount = ctrls.length;
      }
    });
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _visitorCtrl.dispose();
    _oversCtrl.dispose();
    for (var c in [..._hostPlayers, ..._visitorPlayers]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startMatch() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();

    final overs = int.tryParse(_oversCtrl.text.trim()) ?? 20;

    final hostNames = _hostPlayers
        .map((c) => c.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final visitorNames = _visitorPlayers
        .map((c) => c.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    final hostReserve = _hostReserveIndices.toSet();
    final visitorReserve = _visitorReserveIndices.toSet();

    final match = provider.createMatch(
      hostTeamName: _hostCtrl.text.trim(),
      visitorTeamName: _visitorCtrl.text.trim(),
      hostPlayerNames: hostNames,
      visitorPlayerNames: visitorNames,
      hostReserveIndices: hostReserve,
      visitorReserveIndices: visitorReserve,
      format: MatchFormat.custom,
      totalOvers: overs,
      tossWonBy: _tossWonBy,
      tossDecision: _tossDecision,
    );

    // Advanced settings এ reserve mark করলে team এও player id দিয়ে save হবে
    // host reserve player ids বের করো
    final hostReserveIds = <String>{};
    for (final idx in hostReserve) {
      if (idx < match.tempHostPlayers.length) {
        hostReserveIds.add(match.tempHostPlayers[idx].id);
      }
    }
    final visitorReserveIds = <String>{};
    for (final idx in visitorReserve) {
      if (idx < match.tempVisitorPlayers.length) {
        visitorReserveIds.add(match.tempVisitorPlayers[idx].id);
      }
    }
    provider.syncReserveToTeamByIds(
      teamId: match.hostTeamId,
      reservePlayerIds: hostReserveIds,
    );
    provider.syncReserveToTeamByIds(
      teamId: match.visitorTeamId,
      reservePlayerIds: visitorReserveIds,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ScoringScreen(matchId: match.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final teamNames = provider.teams.map((t) => t.name).toList();

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
              Column(
                children: [
                  _teamField(_hostCtrl, 'Host Team', teamNames),
                  const SizedBox(height: 12),
                  _teamField(_visitorCtrl, 'Visitor Team', teamNames),
                ],
              ),
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

            // ── Overs ──
            _sectionCard(
              'Overs',
              TextFormField(
                controller: _oversCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Overs (e.g. 6, 10, 20)',
                  hintStyle: TextStyle(color: Colors.black26),
                  prefixIcon:
                  Icon(Icons.sports_cricket, color: AppTheme.primary),
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 1) return 'Valid over number দিন (min 1)';
                  return null;
                },
              ),
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
                          _hostReserveIndices,
                        ),
                        const SizedBox(height: 16),
                        _playersSection(
                          'Visitor Team Players',
                          _visitorPlayers,
                          _visitorPlayerCount,
                              (v) => setState(() => _visitorPlayerCount = v),
                          _visitorReserveIndices,
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

  Widget _teamField(
      TextEditingController ctrl, String hint, List<String> teamNames) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text.trim().toLowerCase();
        if (q.isEmpty) return const [];
        return teamNames.where((n) => n.toLowerCase().contains(q));
      },
      onSelected: (selection) {
        ctrl.text = selection;
        // listener trigger হবে, players load হবে
      },
      fieldViewBuilder: (ctx, fieldCtrl, focusNode, onSubmit) {
        // আমাদের ctrl এর সাথে sync রাখো
        if (fieldCtrl.text != ctrl.text) fieldCtrl.text = ctrl.text;
        fieldCtrl.addListener(() {
          if (ctrl.text != fieldCtrl.text) ctrl.text = fieldCtrl.text;
        });
        return TextFormField(
          controller: fieldCtrl,
          focusNode: focusNode,
          onFieldSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black26),
            prefixIcon: const Icon(Icons.group, color: AppTheme.primary),
          ),
          validator: (_) => ctrl.text.trim().isEmpty ? 'Required' : null,
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final opt = options.elementAt(i);
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.group,
                      size: 18, color: AppTheme.primary),
                  title: Text(opt, style: const TextStyle(fontSize: 14)),
                  onTap: () => onSelected(opt),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _playersSection(
      String title,
      List<TextEditingController> ctrls,
      int count,
      ValueChanged<int> onCountChanged,
      Set<int> reserveIndices,
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
              reserveIndices.remove(actualCount - 1);
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
              ctrls.add(TextEditingController());
              onCountChanged(ctrls.length);
            }
                : null,
          ),
        ]),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 13, color: Colors.orange),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Player এর পাশের "R" চাপলে সে Reserve হবে — match এ substitute হিসেবে আসবে',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        ...List.generate(ctrls.length, (i) {
          final isReserve = reserveIndices.contains(i);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: TextFormField(
                  controller: ctrls[i],
                  decoration: InputDecoration(
                    hintText: isReserve
                        ? 'Player ${i + 1} (Reserve)'
                        : 'Player ${i + 1}',
                    hintStyle:
                    const TextStyle(color: Colors.black26),
                    isDense: true,
                    filled: true,
                    fillColor: isReserve
                        ? Colors.orange.withValues(alpha: 0.06)
                        : Colors.white,
                    prefixIcon: CircleAvatar(
                      radius: 14,
                      backgroundColor:
                      isReserve ? Colors.orange : AppTheme.primary,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() {
                  if (isReserve) {
                    reserveIndices.remove(i);
                  } else {
                    reserveIndices.add(i);
                  }
                }),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isReserve
                        ? Colors.orange
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('R',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isReserve
                                ? Colors.white
                                : Colors.grey.shade600)),
                  ),
                ),
              ),
            ]),
          );
        }),
      ],
    );
  }
}