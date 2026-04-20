import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../provider/app_provider.dart';
import '../utils/theme.dart';


class ScoreboardScreen extends StatelessWidget {
  final String matchId;
  const ScoreboardScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (ctx, provider, _) {
      final match = provider.matches.firstWhere((m) => m.id == matchId);
      final hostTeam = provider.getTeam(match.hostTeamId);
      final visitorTeam = provider.getTeam(match.visitorTeamId);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Scoreboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareScorecard(context, match, provider),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            if (match.resultDescription != null)
              _ResultBanner(match.resultDescription!),
            _TossInfo(match: match, provider: provider),
            if (match.firstInnings != null)
              _InningsCard(
                innings: match.firstInnings!,
                match: match,
                provider: provider,
                label: '1st Innings',
              ),
            if (match.secondInnings != null)
              _InningsCard(
                innings: match.secondInnings!,
                match: match,
                provider: provider,
                label: '2nd Innings',
              ),
            if (match.status == MatchStatus.inProgress)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume Scoring'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
          ]),
        ),
      );
    });
  }

  void _shareScorecard(BuildContext context, CricketMatch match, AppProvider provider) {
    final buffer = StringBuffer();
    final hostTeam = provider.getTeam(match.hostTeamId);
    final visitorTeam = provider.getTeam(match.visitorTeamId);
    buffer.writeln('🏏 Cricket Scorecard');
    buffer.writeln('${hostTeam?.name} vs ${visitorTeam?.name}');
    if (match.firstInnings != null) {
      final i = match.firstInnings!;
      final team = provider.getTeam(i.teamId);
      buffer.writeln('\n${team?.name}: ${i.totalRuns}/${i.wickets} (${i.completedOvers}.${i.ballsInCurrentOver} ov)');
    }
    if (match.secondInnings != null) {
      final i = match.secondInnings!;
      final team = provider.getTeam(i.teamId);
      buffer.writeln('${team?.name}: ${i.totalRuns}/${i.wickets} (${i.completedOvers}.${i.ballsInCurrentOver} ov)');
    }
    if (match.resultDescription != null) {
      buffer.writeln('\nResult: ${match.resultDescription}');
    }
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Share Scorecard'),
      content: SelectableText(buffer.toString()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ));
  }
}

class _ResultBanner extends StatelessWidget {
  final String result;
  const _ResultBanner(this.result);

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      const Icon(Icons.emoji_events, color: AppTheme.accent, size: 28),
      const SizedBox(width: 12),
      Expanded(child: Text(result, style: GoogleFonts.poppins(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
    ]),
  );
}

class _TossInfo extends StatelessWidget {
  final CricketMatch match;
  final AppProvider provider;
  const _TossInfo({required this.match, required this.provider});

  @override
  Widget build(BuildContext context) {
    final tossTeam = match.tossWonByTeamId != null
        ? provider.getTeam(match.tossWonByTeamId!) : null;
    final decision = match.tossDecision?.name.toUpperCase() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.monetization_on, color: AppTheme.accent),
          const SizedBox(width: 8),
          Text('Toss: ${tossTeam?.name ?? '-'} won & elected to $decision',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
        ]),
      ),
    );
  }
}

class _InningsCard extends StatefulWidget {
  final Innings innings;
  final CricketMatch match;
  final AppProvider provider;
  final String label;
  const _InningsCard({required this.innings, required this.match,
    required this.provider, required this.label});
  @override State<_InningsCard> createState() => _InningsCardState();
}

class _InningsCardState extends State<_InningsCard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final innings = widget.innings;
    final team = widget.provider.getTeam(innings.teamId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Text(widget.label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(child: Text(team?.name ?? '',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
            Text('${innings.totalRuns}/${innings.wickets}',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(width: 8),
            Text('(${innings.completedOvers}.${innings.ballsInCurrentOver} ov)',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),

        Row(children: [
          for (final t in ['Batting', 'Bowling', 'FOW'])
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _tab = ['Batting', 'Bowling', 'FOW'].indexOf(t)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(
                    color: _tab == ['Batting', 'Bowling', 'FOW'].indexOf(t)
                        ? AppTheme.primary : Colors.transparent,
                    width: 2,
                  )),
                ),
                child: Text(t, textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: _tab == ['Batting', 'Bowling', 'FOW'].indexOf(t)
                            ? AppTheme.primary : AppTheme.textSecondary)),
              ),
            )),
        ]),

        if (_tab == 0) _BattingTable(innings: innings, match: widget.match, provider: widget.provider),
        if (_tab == 1) _BowlingTable(innings: innings, match: widget.match, provider: widget.provider),
        if (_tab == 2) _FOWTable(innings: innings),
      ]),
    );
  }
}

// ── Shared cell helpers ───

Widget _hCell(String text, double width) => SizedBox(
  width: width,
  child: Text(text, textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary,
          fontWeight: FontWeight.w500)),
);

Widget _dCell(String text, double width, {bool bold = false, Color? color}) => SizedBox(
  width: width,
  child: Text(text, textAlign: TextAlign.right,
      style: TextStyle(fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color)),
);

// ── Batting ───

class _BattingTable extends StatelessWidget {
  final Innings innings;
  final CricketMatch match;
  final AppProvider provider;
  const _BattingTable({required this.innings, required this.match, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          const Expanded(child: Text('Batsman',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500))),
          _hCell('R', 36),
          _hCell('B', 34),
          _hCell('4s', 30),
          _hCell('6s', 30),
          _hCell('SR', 40),
        ]),
      ),
      ...innings.battingOrder.map((id) {
        final p = provider.getPlayerById(id, match);
        if (p == null) return const SizedBox.shrink();
        return _BattingRow(
          player: p,
          isStriker: id == innings.strikerBatsmanId,
          isNonStriker: id == innings.nonStrikerBatsmanId,
        );
      }),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Expanded(child: Text('Extras', style: TextStyle(fontWeight: FontWeight.w500))),
          Text('${_calculateExtras(innings)}'),
        ]),
      ),
      Container(
        color: AppTheme.primary.withOpacity(0.08),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: Text('Total', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
          Text('${innings.totalRuns}/${innings.wickets} (${innings.oversDisplay} ov)',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ]),
      ),
    ]);
  }

  int _calculateExtras(Innings innings) {
    int extras = 0;
    for (final b in innings.ballEvents) {
      if (b.type == BallType.wide || b.type == BallType.noBall ||
          b.type == BallType.bye || b.type == BallType.legBye) {
        extras += b.runs;
        if (b.type == BallType.wide || b.type == BallType.noBall) extras++;
      }
    }
    return extras;
  }
}

class _BattingRow extends StatelessWidget {
  final Player player;
  final bool isStriker;
  final bool isNonStriker;
  const _BattingRow({required this.player, required this.isStriker, required this.isNonStriker});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: isStriker ? AppTheme.primary.withOpacity(0.05) : null,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade200,
            border: Border.all(
              color: isStriker ? AppTheme.primary : Colors.grey.shade400,
              width: 1.5,
            ),
          ),
          child: Center(child: Text(
            player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: isStriker ? AppTheme.primary : Colors.grey.shade600),
          )),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (isStriker)
              const Padding(padding: EdgeInsets.only(right: 3),
                  child: Icon(Icons.sports_cricket, size: 11, color: AppTheme.primary)),
            Flexible(child: Text(player.name,
                softWrap: true,
                style: TextStyle(
                    fontWeight: isStriker ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12))),
          ]),
          if (!player.isOut && !isStriker && !isNonStriker)
            const Text('yet to bat',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ])),
        _dCell('${player.runs}', 36, bold: true,
            color: player.balls > 0 ? AppTheme.primary : null),
        _dCell('${player.balls}', 34),
        _dCell('${player.fours}', 30),
        _dCell('${player.sixes}', 30),
        _dCell(player.strikeRate.toStringAsFixed(1), 40),
      ]),
      if (player.isOut)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Text('▾ ${player.dismissalInfo ?? 'out'}',
              overflow: TextOverflow.ellipsis, maxLines: 1,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic)),
        ),
      if (!player.isOut && player.balls > 0)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.green.shade200, width: 1),
          ),
          child: Text('✦ not out',
              style: TextStyle(fontSize: 10, color: Colors.green.shade700,
                  fontWeight: FontWeight.w600)),
        ),
    ]),
  );
}

// ── Bowling ─────

class _BowlingTable extends StatelessWidget {
  final Innings innings;
  final CricketMatch match;
  final AppProvider provider;
  const _BowlingTable({required this.innings, required this.match, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header — widths must match _BowlingRow stats
      Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          const Expanded(child: Text('Bowler',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500))),
          _hCell('O', 36),
          _hCell('M', 30),
          _hCell('R', 30),
          _hCell('W', 30),
          _hCell('Eco', 40),
        ]),
      ),
      ...innings.bowlingOrder.map((id) {
        final p = provider.getPlayerById(id, match);
        if (p == null) return const SizedBox.shrink();
        return _BowlingRow(
          player: p, innings: innings, match: match,
          provider: provider, isCurrent: id == innings.currentBowlerId,
        );
      }),
    ]);
  }
}

class _BowlingRow extends StatefulWidget {
  final Player player;
  final Innings innings;
  final CricketMatch match;
  final AppProvider provider;
  final bool isCurrent;
  const _BowlingRow({required this.player, required this.innings,
    required this.match, required this.provider, required this.isCurrent});
  @override
  State<_BowlingRow> createState() => _BowlingRowState();
}

class _BowlingRowState extends State<_BowlingRow> {
  bool _expanded = false;

  List<List<BallEvent>> _getOverBreakdown() {
    final bowlerEvents = widget.innings.ballEvents
        .where((b) => b.bowlerId == widget.player.id)
        .toList();
    final List<List<BallEvent>> overs = [];
    List<BallEvent> currentOver = [];
    int legalCount = 0;
    for (final b in bowlerEvents) {
      currentOver.add(b);
      if (b.type != BallType.wide && b.type != BallType.noBall) {
        legalCount++;
        if (legalCount == 6) {
          overs.add(List.from(currentOver));
          currentOver = [];
          legalCount = 0;
        }
      }
    }
    if (currentOver.isNotEmpty) overs.add(currentOver);
    return overs;
  }

  // each batsman for color
  static const List<Color> _batsmanColors = [
    Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
    Color(0xFFFF8F00), Color(0xFF8E24AA), Color(0xFF00ACC1),
    Color(0xFFF4511E), Color(0xFF3949AB), Color(0xFF00897B),
    Color(0xFFD81B60),
  ];

  Map<String, Color> _buildBatsmanColorMap(List<BallEvent> allBalls) {
    final ids = <String>[];
    for (final b in allBalls) {
      if (b.batsmanId != null && !ids.contains(b.batsmanId)) ids.add(b.batsmanId!);
    }
    final map = <String, Color>{};
    for (int i = 0; i < ids.length; i++) {
      map[ids[i]] = _batsmanColors[i % _batsmanColors.length];
    }
    return map;
  }

  String _getBatsmenInOver(List<BallEvent> balls) {
    final ids = <String>[];
    for (final b in balls) {
      if (b.batsmanId != null && !ids.contains(b.batsmanId)) ids.add(b.batsmanId!);
    }
    return ids.map((id) {
      final p = widget.provider.getPlayerById(id, widget.match);
      return p?.name ?? '?';
    }).join(' & ');
  }

  Color _ballColor(BallEvent b) {
    if (b.type == BallType.wicket) return Colors.red;
    if (b.type == BallType.noBall && b.dismissalType == 'Run Out') return Colors.red;
    if (b.type == BallType.wide) return Colors.white;
    if (b.type == BallType.noBall) return Colors.black87;
    if (b.runs == 4) return Colors.blue;
    if (b.runs == 6) return Colors.purple;
    if (b.runs == 0) return Colors.grey.shade400;
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final overs = _getOverBreakdown();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isCurrent ? AppTheme.primary.withOpacity(0.05) : null,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Avatar — same style as batting
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
                border: Border.all(
                  color: widget.isCurrent ? AppTheme.primary : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: Center(child: Text(
                widget.player.name.isNotEmpty
                    ? widget.player.name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: widget.isCurrent ? AppTheme.primary : Colors.grey.shade600),
              )),
            ),
            const SizedBox(width: 8),
            // Name — Expanded + Flexible, same as batting
            Expanded(child: Row(children: [
              if (widget.isCurrent)
                const Padding(padding: EdgeInsets.only(right: 3),
                    child: Icon(Icons.sports_baseball, size: 11, color: AppTheme.primary)),
              Flexible(child: Text(widget.player.name,
                  softWrap: true,
                  style: TextStyle(
                      fontWeight: widget.isCurrent ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12))),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 14, color: AppTheme.textSecondary),
            ])),
            // Stats — widths match header exactly
            _dCell(widget.player.oversBowledDisplay, 36),
            _dCell('${widget.player.maidens}', 30),
            _dCell('${widget.player.runsConceded}', 30,
                bold: widget.isCurrent,
                color: widget.isCurrent ? AppTheme.primary : null),
            _dCell('${widget.player.wickets}', 30,
                bold: widget.player.wickets > 0,
                color: widget.player.wickets > 0 ? Colors.red : null),
            _dCell(widget.player.bowlingEconomy.toStringAsFixed(2), 40),
          ]),
        ),
      ),

      // Over breakdown
      if (_expanded && overs.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Legend: player name + color dot ──
                  () {
                final colorMap = _buildBatsmanColorMap(widget.innings.ballEvents);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: colorMap.entries.map((e) {
                        final p = widget.provider.getPlayerById(e.key, widget.match);
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(color: e.value, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(p?.name ?? '?',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }(),
              // ── Over rows ──
              ...overs.asMap().entries.map((entry) {
                final overIdx = entry.key;
                final balls = entry.value;
                final colorMap = _buildBatsmanColorMap(widget.innings.ballEvents);
                final overRuns = balls.fold<int>(0, (s, b) {
                  if (b.type == BallType.wide) return s + b.runs;
                  if (b.type == BallType.noBall) return s + b.runs + 1;
                  return s + b.runs;
                });
                final hasWicket = balls.any((b) => b.type == BallType.wicket);
                final batsmenStr = _getBatsmenInOver(balls);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Ov ${overIdx + 1}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                color: AppTheme.primary)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(batsmenStr,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasWicket
                              ? Colors.red.withOpacity(0.1)
                              : AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('$overRuns${hasWicket ? ' W' : ''}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                color: hasWicket ? Colors.red : AppTheme.primary)),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4, runSpacing: 6,
                      children: balls.map((b) {
                        final batsmanColor = b.batsmanId != null
                            ? (colorMap[b.batsmanId] ?? Colors.transparent)
                            : Colors.transparent;
                        final isNoBallRunOut = b.type == BallType.noBall &&
                            b.dismissalType == 'Run Out';
                        final isWide = b.type == BallType.wide;
                        final isNoBall = b.type == BallType.noBall;
                        return Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: isNoBallRunOut ? Colors.red : _ballColor(b),
                              shape: BoxShape.circle,
                              border: isWide
                                  ? Border.all(color: Colors.grey.shade400, width: 1.5)
                                  : Border.all(color: batsmanColor, width: 2.5),
                            ),
                            child: Center(child: Text(
                                isNoBallRunOut ? 'W' : b.display,
                                style: TextStyle(
                                    color: isWide ? Colors.black87 : Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold))),
                          ),
                          const SizedBox(height: 1),
                          if (isNoBallRunOut || isNoBall)
                            Text('NB',
                                style: TextStyle(fontSize: 7,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700))
                          else if (isWide)
                            Text('Wd',
                                style: TextStyle(fontSize: 7,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600))
                          else
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(color: batsmanColor, shape: BoxShape.circle),
                            ),
                        ]);
                      }).toList(),
                    ),
                  ]),
                );
              }).toList(),
            ],
          ),
        ),
    ]);
  }
}

// ── Fow ────

class _FOWTable extends StatelessWidget {
  final Innings innings;
  const _FOWTable({required this.innings});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (innings.fallenWickets.isEmpty) const Text('No wickets fallen yet'),
      ...innings.fallenWickets.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: Center(child: Text('${e.key + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Text(e.value, style: const TextStyle(fontSize: 14)),
        ]),
      )),
    ]),
  );
}