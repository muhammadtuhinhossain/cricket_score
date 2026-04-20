import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/tournament_models.dart';
import '../provider/app_provider.dart';
import '../provider/tournament_provider.dart';
import '../utils/theme.dart';
import 'scoring_screen.dart';
import 'manage_tournament_teams_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TournamentProvider, AppProvider>(
        builder: (ctx, tProvider, aProvider, _) {
          final tournament = tProvider.getTournament(widget.tournamentId);
          if (tournament == null) {
            return const Scaffold(
                body: Center(child: Text('Tournament not found')));
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(tournament.name,
                  style: const TextStyle(fontSize: 16)),
              actions: [
                // ── Manage Teams button ──
                if (tournament.status == TournamentStatus.groupStage)
                  IconButton(
                    icon: const Icon(Icons.group_add, color: Colors.white),
                    tooltip: 'Teams & Groups Manage করুন',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageTournamentTeamsScreen(
                            tournamentId: widget.tournamentId),
                      ),
                    ),
                  ),
              ],
              bottom: TabBar(
                controller: _tab,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'FIXTURES'),
                  Tab(text: 'POINTS'),
                  Tab(text: 'STATS'),
                  Tab(text: 'BRACKET'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tab,
              children: [
                _FixturesTab(
                    tournament: tournament,
                    aProvider: aProvider,
                    tProvider: tProvider),
                _PointsTab(
                    tournament: tournament, aProvider: aProvider),
                _StatsTab(
                    tournament: tournament, aProvider: aProvider),
                _BracketTab(
                    tournament: tournament, aProvider: aProvider),
              ],
            ),
          );
        });
  }
}


// Fixtures Tab

class _FixturesTab extends StatelessWidget {
  final Tournament tournament;
  final AppProvider aProvider;
  final TournamentProvider tProvider;

  const _FixturesTab({
    required this.tournament,
    required this.aProvider,
    required this.tProvider,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Manage Teams shortcut (groupStage only) ──
        if (tournament.status == TournamentStatus.groupStage)
          Builder(builder: (context) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManageTournamentTeamsScreen(
                      tournamentId: tournament.id),
                ),
              ),
              icon: const Icon(Icons.group_add, color: AppTheme.primary, size: 18),
              label: Text(
                'Teams ও Groups Edit করুন  (Add / Remove / Move)',
                style: GoogleFonts.poppins(color: AppTheme.primary, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )),
        _sectionTitle('Group Stage'),
        ...tournament.groupNames.map((g) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 6),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Group $g',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 13)),
                ),
              ]),
            ),
            ...tournament.groupMatches
                .where((m) => m.groupName == g)
                .map((m) => _MatchTile(
              tMatch: m,
              tournament: tournament,
              aProvider: aProvider,
              tProvider: tProvider,
            )),
          ],
        )),

        if (tournament.knockoutMatches.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionTitle('Knockout Stage'),
          if (tournament.quarterFinals.isNotEmpty) ...[
            _stageLabel('Quarter Finals'),
            ...tournament.quarterFinals.map((m) => _MatchTile(
              tMatch: m,
              tournament: tournament,
              aProvider: aProvider,
              tProvider: tProvider,
            )),
          ],
          if (tournament.semiFinals.isNotEmpty) ...[
            _stageLabel('Semi Finals'),
            ...tournament.semiFinals.map((m) => _MatchTile(
              tMatch: m,
              tournament: tournament,
              aProvider: aProvider,
              tProvider: tProvider,
            )),
          ],
          if (tournament.finalMatch != null) ...[
            _stageLabel('🏆 Final'),
            _MatchTile(
              tMatch: tournament.finalMatch!,
              tournament: tournament,
              aProvider: aProvider,
              tProvider: tProvider,
            ),
          ],
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(t,
        style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.bold)),
  );

  Widget _stageLabel(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
    child: Text(t,
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.orange,
            fontSize: 14)),
  );
}

// Match Tile

class _MatchTile extends StatelessWidget {
  final TournamentMatch tMatch;
  final Tournament tournament;
  final AppProvider aProvider;
  final TournamentProvider tProvider;

  const _MatchTile({
    required this.tMatch,
    required this.tournament,
    required this.aProvider,
    required this.tProvider,
  });

  @override
  Widget build(BuildContext context) {
    final team1 = aProvider.getTeam(tMatch.team1Id);
    final team2 = aProvider.getTeam(tMatch.team2Id);
    final done = tMatch.isCompleted;
    final winner = done ? aProvider.getTeam(tMatch.winnerId ?? '') : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => done
            ? _showResultSummary(context)
            : _showMatchOptions(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Text(
                  team1?.name ?? '-',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: tMatch.winnerId == tMatch.team1Id
                        ? FontWeight.bold
                        : FontWeight.w400,
                    fontSize: 14,
                    color: tMatch.winnerId == tMatch.team1Id
                        ? AppTheme.primary
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: done
                      ? AppTheme.primary
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  done ? 'DONE' : 'vs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color:
                    done ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  team2?.name ?? '-',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: tMatch.winnerId == tMatch.team2Id
                        ? FontWeight.bold
                        : FontWeight.w400,
                    fontSize: 14,
                    color: tMatch.winnerId == tMatch.team2Id
                        ? AppTheme.primary
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
            ]),
            if (done && winner != null) ...[
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.emoji_events,
                    size: 14, color: AppTheme.accent),
                const SizedBox(width: 4),
                Text('${winner.name} won',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500)),
              ]),
            ],
            if (!done) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showMatchOptions(context),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Start Match'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  void _showResultSummary(BuildContext context) {
    final team1 = aProvider.getTeam(tMatch.team1Id);
    final team2 = aProvider.getTeam(tMatch.team2Id);
    final winner = aProvider.getTeam(tMatch.winnerId ?? '');

    String motmName = '-';
    if (tMatch.manOfTheMatch != null) {
      for (final t in aProvider.teams) {
        for (final p in t.players) {
          if (p.id == tMatch.manOfTheMatch) {
            motmName = p.name;
            break;
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Match Result',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${team1?.name ?? '-'} vs ${team2?.name ?? '-'}',
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          if (winner != null) ...[
            const Icon(Icons.emoji_events,
                color: AppTheme.accent, size: 36),
            const SizedBox(height: 6),
            Text('Winner: ${winner.name}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    fontSize: 16)),
          ],
          const SizedBox(height: 8),
          Text('⭐ MOTM: $motmName',
              style: const TextStyle(color: AppTheme.textSecondary)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showMatchOptions(BuildContext context) {
    final team1 = aProvider.getTeam(tMatch.team1Id);
    final team2 = aProvider.getTeam(tMatch.team2Id);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${team1?.name ?? '-'} vs ${team2?.name ?? '-'}',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.sports_cricket,
                  color: AppTheme.primary),
            ),
            title: const Text('Score this match',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Open live scoring'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.pop(context);
              _showTossDialog(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child:
              const Icon(Icons.edit_note, color: Colors.orange),
            ),
            title: const Text('Enter result manually',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Just save who won'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.pop(context);
              _showManualResultDialog(context);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Toss Dialog ─────
  void _showTossDialog(BuildContext context) {
    final team1 = aProvider.getTeam(tMatch.team1Id);
    final team2 = aProvider.getTeam(tMatch.team2Id);

    String tossWonBy = tMatch.team1Id;
    TossDecision tossDecision = TossDecision.bat;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: Text('Toss',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Toss won by:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _tossChip(
                    label: team1?.name ?? 'Team 1',
                    selected: tossWonBy == tMatch.team1Id,
                    onTap: () => setS(() => tossWonBy = tMatch.team1Id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _tossChip(
                    label: team2?.name ?? 'Team 2',
                    selected: tossWonBy == tMatch.team2Id,
                    onTap: () => setS(() => tossWonBy = tMatch.team2Id),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              const Text('Elected to:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _tossChip(
                    label: '🏏 Bat',
                    selected: tossDecision == TossDecision.bat,
                    onTap: () =>
                        setS(() => tossDecision = TossDecision.bat),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _tossChip(
                    label: '⚾ Bowl',
                    selected: tossDecision == TossDecision.bowl,
                    onTap: () =>
                        setS(() => tossDecision = TossDecision.bowl),
                  ),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx2);
                _startScoring(context,
                    tossWonById: tossWonBy,
                    tossDecision: tossDecision);
              },
              child: const Text('Start Match'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tossChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
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
                  textAlign: TextAlign.center,
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

  // ── Start Live Scoring─────
  void _startScoring(BuildContext context,
      {required String tossWonById,
        required TossDecision tossDecision}) {
    final team1 = aProvider.getTeam(tMatch.team1Id);
    final team2 = aProvider.getTeam(tMatch.team2Id);


    final tossWonBy =
    tossWonById == tMatch.team1Id ? 'host' : 'visitor';

    final match = aProvider.createMatch(
      hostTeamName: team1?.name ?? 'Team 1',
      visitorTeamName: team2?.name ?? 'Team 2',
      hostPlayerNames:
      team1?.players.map((p) => p.name).toList() ?? [],
      visitorPlayerNames:
      team2?.players.map((p) => p.name).toList() ?? [],
      format: tournament.format == 't20'
          ? MatchFormat.t20
          : tournament.format == 'odi'
          ? MatchFormat.odi
          : MatchFormat.custom,
      totalOvers: tournament.totalOvers,
      tossWonBy: tossWonBy,
      tossDecision: tossDecision,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ScoringScreen(matchId: match.id)),
    ).then((_) {
      if (!context.mounted) return;
      final updated = aProvider.matches
          .where((m) => m.id == match.id)
          .firstOrNull;
      if (updated != null &&
          updated.status == MatchStatus.completed) {
        _showPostScoringDialog(context, updated);
      }
    });
  }

  void _showPostScoringDialog(
      BuildContext context, CricketMatch match) {
    final first = match.firstInnings;
    final second = match.secondInnings;

    String? winnerId;
    String? loserId;
    int winnerRuns = 0, winnerBalls = 1, loserRuns = 0, loserBalls = 1;

    if (first != null && second != null) {
      if (second.totalRuns > first.totalRuns) {
        final winTeamId = second.teamId;
        winnerId = winTeamId == match.hostTeamId
            ? tMatch.team1Id
            : tMatch.team2Id;
        winnerRuns = second.totalRuns;
        winnerBalls = second.totalBalls;
        loserRuns = first.totalRuns;
        loserBalls = first.totalBalls;
      } else {
        final winTeamId = first.teamId;
        winnerId = winTeamId == match.hostTeamId
            ? tMatch.team1Id
            : tMatch.team2Id;
        winnerRuns = first.totalRuns;
        winnerBalls = first.totalBalls;
        loserRuns = second.totalRuns;
        loserBalls = second.totalBalls;
      }
      loserId = winnerId == tMatch.team1Id
          ? tMatch.team2Id
          : tMatch.team1Id;
    }

    final allPlayers = aProvider.getAllPlayersForMatch(match);
    String? motmId =
    allPlayers.isNotEmpty ? allPlayers[0].id : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: Text('Save Result',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(match.resultDescription ?? '',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (allPlayers.isNotEmpty)
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: motmId,
                decoration: const InputDecoration(
                    labelText: '⭐ Man of the Match'),
                items: allPlayers
                    .map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name,
                        overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setS(() => motmId = v),
              ),
          ]),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (winnerId != null && loserId != null) {
                  final stats = allPlayers
                      .where((p) =>
                  p.balls > 0 || p.oversBowled > 0)
                      .map((p) {
                    final teamId = _findPlayerTeamTournamentId(
                        p.id, match);
                    return PlayerMatchStat(
                      playerId: p.id,
                      teamId: teamId,
                      runs: p.runs,
                      balls: p.balls,
                      fours: p.fours,
                      sixes: p.sixes,
                      wickets: p.wickets,
                      runsConceded: p.runsConceded,
                      oversBowled: p.oversBowled,
                    );
                  }).toList();

                  tProvider.recordMatchResult(
                    tournamentId: tournament.id,
                    tournamentMatchId: tMatch.matchId,
                    winnerId: winnerId!,
                    loserId: loserId!,
                    winnerRuns: winnerRuns,
                    winnerBalls: winnerBalls,
                    loserRuns: loserRuns,
                    loserBalls: loserBalls,
                    isTie: match.resultDescription
                        ?.contains('Tied') ??
                        false,
                    manOfTheMatch: motmId,
                    playerMatchStats: stats,
                  );
                }
                Navigator.pop(ctx2);
              },
              child: const Text('Save to Tournament'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Manual Result ───
  void _showManualResultDialog(BuildContext context) {
    final team1 = aProvider.getTeam(tMatch.team1Id);
    final team2 = aProvider.getTeam(tMatch.team2Id);

    String? winnerId = tMatch.team1Id;
    String? motmId;

    final allPlayers = [
      ...aProvider.getTeam(tMatch.team1Id)?.players ?? [],
      ...aProvider.getTeam(tMatch.team2Id)?.players ?? [],
    ];
    if (allPlayers.isNotEmpty) motmId = allPlayers[0].id;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: Text('Enter Result',
              style:
              GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Winner:',
                      style:
                      TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _selChip(
                          label: team1?.name ?? 'Team 1',
                          selected: winnerId == tMatch.team1Id,
                          onTap: () =>
                              setS(() => winnerId = tMatch.team1Id),
                        )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _selChip(
                          label: team2?.name ?? 'Team 2',
                          selected: winnerId == tMatch.team2Id,
                          onTap: () =>
                              setS(() => winnerId = tMatch.team2Id),
                        )),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Man of the Match:',
                      style:
                      TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  if (allPlayers.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: motmId,
                      decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10)),
                      items: allPlayers
                          .map((p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(p.name,
                              overflow:
                              TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setS(() => motmId = v),
                    ),
                ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (winnerId == null) return;
                final loserId = winnerId == tMatch.team1Id
                    ? tMatch.team2Id
                    : tMatch.team1Id;
                tProvider.recordMatchResult(
                  tournamentId: tournament.id,
                  tournamentMatchId: tMatch.matchId,
                  winnerId: winnerId!,
                  loserId: loserId,
                  winnerRuns: 0,
                  winnerBalls: 1,
                  loserRuns: 0,
                  loserBalls: 1,
                  isTie: false,
                  manOfTheMatch: motmId,
                  playerMatchStats: [],
                );
                Navigator.pop(ctx2);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
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
                  textAlign: TextAlign.center,
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

  String _findPlayerTeamTournamentId(
      String playerId, CricketMatch match) {
    final hostTeam = aProvider.getTeam(match.hostTeamId);
    if (hostTeam != null &&
        hostTeam.players.any((p) => p.id == playerId)) {
      return tMatch.team1Id;
    }
    return tMatch.team2Id;
  }
}


// Points Table Tab

class _PointsTab extends StatelessWidget {
  final Tournament tournament;
  final AppProvider aProvider;
  const _PointsTab({required this.tournament, required this.aProvider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...tournament.groupNames.map((g) {
          final teams = tournament.getGroupTeams(g);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Group $g',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Card(
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12)),
                    ),
                    child: Row(children: [
                      const Expanded(
                          child: Text('Team',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                      for (final h in ['P', 'W', 'L', 'Pts', 'NRR'])
                        SizedBox(
                            width: 38,
                            child: Text(h,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                    ]),
                  ),
                  if (teams.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No matches played yet',
                          style: TextStyle(
                              color: AppTheme.textSecondary)),
                    ),
                  ...teams.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final t = entry.value;
                    final team = aProvider.getTeam(t.teamId);
                    final qualified = idx < 2;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: qualified
                            ? AppTheme.primary.withOpacity(0.05)
                            : null,
                        border: Border(
                            bottom: BorderSide(
                                color: Colors.grey.shade100)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Row(children: [
                            if (qualified)
                              const Icon(Icons.arrow_upward,
                                  size: 12,
                                  color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Flexible(
                                child: Text(
                                  team?.name ?? '-',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: qualified
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 13),
                                )),
                          ]),
                        ),
                        for (final v in [
                          '${t.played}',
                          '${t.won}',
                          '${t.lost}',
                          '${t.points}',
                          t.nrr >= 0
                              ? '+${t.nrr.toStringAsFixed(2)}'
                              : t.nrr.toStringAsFixed(2),
                        ])
                          SizedBox(
                              width: 38,
                              child: Text(v,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                      v == '${t.points}'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: v == '${t.points}'
                                          ? AppTheme.primary
                                          : null))),
                      ]),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      const Icon(Icons.arrow_upward,
                          size: 10, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      const Text('Top 2 qualify for next stage',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }
}


// Stats Tab

class _StatsTab extends StatelessWidget {
  final Tournament tournament;
  final AppProvider aProvider;
  const _StatsTab({required this.tournament, required this.aProvider});

  Player? _findPlayer(String id) {
    for (final t in aProvider.teams) {
      try {
        return t.players.firstWhere((p) => p.id == id);
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stats = tournament.playerStats;

    if (stats.isEmpty) {
      return const Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('No stats yet.\nComplete matches to see stats!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary)),
            ]),
      );
    }

    final scorers = [...stats]
      ..sort((a, b) => b.totalRuns.compareTo(a.totalRuns));
    final wickets = [...stats]
      ..sort((a, b) => b.totalWickets.compareTo(a.totalWickets));
    final motm = stats
        .where((p) => p.manOfTheMatchCount > 0)
        .toList()
      ..sort((a, b) =>
          b.manOfTheMatchCount.compareTo(a.manOfTheMatchCount));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (tournament.status == TournamentStatus.completed &&
            tournament.manOfTheSeries != null)
          _MotsCard(
              tournament: tournament, aProvider: aProvider),

        _section('🏏 Top Scorers', scorers.take(10).toList(),
            ['Player', 'Team', 'Inn', 'Runs', 'HS', 'SR'], (p) {
              final pl = _findPlayer(p.playerId);
              final tm = aProvider.getTeam(p.teamId);
              return [
                pl?.name ?? '-',
                tm?.name ?? '-',
                '${p.innings}',
                '${p.totalRuns}',
                '${p.highScore}',
                p.strikeRate.toStringAsFixed(1),
              ];
            }),
        const SizedBox(height: 16),

        _section(
            '⚾ Top Wicket Takers',
            wickets
                .where((p) => p.totalWickets > 0)
                .take(10)
                .toList(),
            ['Player', 'Team', 'Wkts', 'Runs', 'Eco'], (p) {
          final pl = _findPlayer(p.playerId);
          final tm = aProvider.getTeam(p.teamId);
          return [
            pl?.name ?? '-',
            tm?.name ?? '-',
            '${p.totalWickets}',
            '${p.totalRunsConceded}',
            p.bowlingEconomy.toStringAsFixed(2),
          ];
        }),
        const SizedBox(height: 16),

        if (motm.isNotEmpty)
          _section('⭐ MOTM Awards', motm.take(10).toList(),
              ['Player', 'Team', 'Awards'], (p) {
                final pl = _findPlayer(p.playerId);
                final tm = aProvider.getTeam(p.teamId);
                return [
                  pl?.name ?? '-',
                  tm?.name ?? '-',
                  '${p.manOfTheMatchCount}',
                ];
              }),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _section(
      String title,
      List<PlayerTournamentStats> list,
      List<String> headers,
      List<String> Function(PlayerTournamentStats) row,
      ) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Card(
        child: Column(children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12)),
            ),
            child: Row(children: [
              Expanded(
                  child: Text(headers[0],
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
              ...headers.skip(1).map((h) => SizedBox(
                  width: 44,
                  child: Text(h,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)))),
            ]),
          ),
          ...list.map((p) {
            final r = row(p);
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: Colors.grey.shade100))),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(r[0],
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13)),
                        Text(r[1],
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary)),
                      ]),
                ),
                ...r.skip(2).map((v) => SizedBox(
                    width: 44,
                    child: Text(v,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12)))),
              ]),
            );
          }),
        ]),
      ),
    ]);
  }
}

class _MotsCard extends StatelessWidget {
  final Tournament tournament;
  final AppProvider aProvider;
  const _MotsCard(
      {required this.tournament, required this.aProvider});

  Player? _find(String id) {
    for (final t in aProvider.teams) {
      try {
        return t.players.firstWhere((p) => p.id == id);
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pl = _find(tournament.manOfTheSeries!);
    final winner = aProvider.getTeam(tournament.winnerId ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Icon(Icons.emoji_events,
              color: AppTheme.accent, size: 40),
          const SizedBox(height: 8),
          Text('🏆 ${winner?.name ?? ''} won the tournament!',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('⭐ Man of the Series: ${pl?.name ?? '-'}',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}


// Bracket Tab

class _BracketTab extends StatelessWidget {
  final Tournament tournament;
  final AppProvider aProvider;
  const _BracketTab(
      {required this.tournament, required this.aProvider});

  @override
  Widget build(BuildContext context) {
    if (tournament.knockoutMatches.isEmpty) {
      final total = tournament.groupMatches.length;
      final done =
          tournament.groupMatches.where((m) => m.isCompleted).length;
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_tree_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Bracket appears after\nGroup Stage completes',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary,
                      fontSize: 15)),
              const SizedBox(height: 8),
              Text('$done / $total matches done',
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13)),
            ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        if (tournament.quarterFinals.isNotEmpty) ...[
          _round('Quarter Finals', tournament.quarterFinals),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Icon(Icons.keyboard_arrow_down,
                color: AppTheme.primary, size: 32),
          ),
        ],
        if (tournament.semiFinals.isNotEmpty) ...[
          _round('Semi Finals', tournament.semiFinals),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Icon(Icons.keyboard_arrow_down,
                color: AppTheme.primary, size: 32),
          ),
        ],
        if (tournament.finalMatch != null)
          _round('🏆 Final', [tournament.finalMatch!]),
        if (tournament.winnerId != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent, width: 2),
            ),
            child: Column(children: [
              const Icon(Icons.emoji_events,
                  color: AppTheme.accent, size: 40),
              const SizedBox(height: 8),
              Text(
                '🏆 Champion',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary),
              ),
              Text(
                aProvider.getTeam(tournament.winnerId!)?.name ??
                    '-',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _round(String title, List<TournamentMatch> matches) =>
      Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.primary)),
        ),
        const SizedBox(height: 10),
        ...matches.map((m) {
          final t1 = aProvider.getTeam(m.team1Id);
          final t2 = aProvider.getTeam(m.team2Id);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(
                    child: Text(t1?.name ?? '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight:
                            m.winnerId == m.team1Id
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: m.winnerId == m.team1Id
                                ? AppTheme.primary
                                : null))),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: m.isCompleted
                        ? AppTheme.primary
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    m.isCompleted ? 'Done' : 'vs',
                    style: TextStyle(
                        color: m.isCompleted
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                Expanded(
                    child: Text(t2?.name ?? '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight:
                            m.winnerId == m.team2Id
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: m.winnerId == m.team2Id
                                ? AppTheme.primary
                                : null))),
              ]),
            ),
          );
        }),
        const SizedBox(height: 8),
      ]);
}