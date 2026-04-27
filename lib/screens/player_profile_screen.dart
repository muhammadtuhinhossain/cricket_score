import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../provider/app_provider.dart';
import '../utils/theme.dart';

class PlayerProfileScreen extends StatefulWidget {
  final String playerId;
  final String teamId;

  const PlayerProfileScreen({
    super.key,
    required this.playerId,
    required this.teamId,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (ctx, provider, _) {
      // সব match থেকে player stats aggregate করা
      final stats = _aggregateStats(provider, widget.playerId, widget.teamId);
      final player = _findPlayer(provider);

      if (player == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Player Profile')),
          body: const Center(child: Text('Player not found')),
        );
      }

      return Scaffold(
        backgroundColor: AppTheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, innerScrolled) => [
            _buildSliverAppBar(context, player, stats),
          ],
          body: Column(
            children: [
              // Tab Bar
              Container(
                color: AppTheme.primary,
                child: TabBar(
                  controller: _tab,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(text: 'BATTING'),
                    Tab(text: 'BOWLING'),
                    Tab(text: 'FIELDING'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _BattingTab(stats: stats),
                    _BowlingTab(stats: stats),
                    _FieldingTab(stats: stats, provider: provider, playerId: widget.playerId),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  SliverAppBar _buildSliverAppBar(
      BuildContext context, Player player, _PlayerStats stats) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppTheme.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryDark,
                AppTheme.primary,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                // Avatar
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      player.name.isNotEmpty
                          ? player.name[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  player.name,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (player.isReserve)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: const Text('RESERVE',
                        style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Player? _findPlayer(AppProvider provider) {
    // Team এ খোঁজো
    try {
      final team = provider.getTeam(widget.teamId);
      if (team != null) {
        return team.players.firstWhere((p) => p.id == widget.playerId);
      }
    } catch (_) {}

    // Match temp players এ খোঁজো
    for (final match in provider.matches) {
      for (final p in [
        ...match.tempHostPlayers,
        ...match.tempVisitorPlayers
      ]) {
        if (p.id == widget.playerId) return p;
      }
    }
    return null;
  }

  _PlayerStats _aggregateStats(
      AppProvider provider, String playerId, String teamId) {
    final stats = _PlayerStats();

    for (final match in provider.matches) {
      if (match.status != MatchStatus.completed) continue;

      final allPlayers = provider.getAllPlayersForMatch(match);
      Player? player;
      try {
        player = allPlayers.firstWhere((p) => p.id == playerId);
      } catch (_) {
        continue;
      }

      // Batting stats — এই match এ এই player কি batting করেছে?
      final firstInnings = match.firstInnings;
      final secondInnings = match.secondInnings;

      for (final innings in [firstInnings, secondInnings]) {
        if (innings == null) continue;
        if (!innings.battingOrder.contains(playerId)) continue;

        stats.matches++;
        stats.innings++;

        // Runs, balls etc এই innings এর ball events থেকে
        int runsThisInnings = 0;
        int ballsThisInnings = 0;
        int foursThisInnings = 0;
        int sixesThisInnings = 0;

        for (final ball in innings.ballEvents) {
          if (ball.batsmanId == playerId) {
            if (ball.type == BallType.normal || ball.type == BallType.noBall) {
              runsThisInnings += ball.runs;
            }
            if (ball.type != BallType.wide) {
              ballsThisInnings++;
            }
            if (ball.runs == 4 &&
                (ball.type == BallType.normal ||
                    ball.type == BallType.noBall)) {
              foursThisInnings++;
            }
            if (ball.runs == 6 &&
                (ball.type == BallType.normal ||
                    ball.type == BallType.noBall)) {
              sixesThisInnings++;
            }
          }
        }

        // Player isOut?
        final isOut = innings.ballEvents
            .any((b) => b.batsmanId == playerId && b.type == BallType.wicket);

        stats.totalRuns += runsThisInnings;
        stats.totalBalls += ballsThisInnings;
        stats.fours += foursThisInnings;
        stats.sixes += sixesThisInnings;

        if (!isOut) stats.notOuts++;
        if (runsThisInnings > stats.highScore) {
          stats.highScore = runsThisInnings;
          stats.highScoreNotOut = !isOut;
        }
        if (runsThisInnings >= 100) stats.hundreds++;
        if (runsThisInnings >= 50 && runsThisInnings < 100) stats.fifties++;
        if (runsThisInnings >= 30 && runsThisInnings < 50) stats.thirties++;
        if (runsThisInnings == 0 && isOut) stats.ducks++;

        // Bowling stats এই innings এর জন্য
        if (innings.bowlingOrder.contains(playerId)) {
          for (final ball in innings.ballEvents) {
            if (ball.bowlerId != playerId) continue;

            if (ball.type == BallType.wide) {
              stats.wides++;
              stats.runsConceded += ball.runs;
            } else if (ball.type == BallType.noBall) {
              stats.noBalls++;
              stats.runsConceded += ball.runs + 1;
              stats.ballsBowled++;
            } else if (ball.type == BallType.wicket) {
              stats.wickets++;
              stats.runsConceded += ball.runs;
              stats.ballsBowled++;
            } else {
              stats.runsConceded += ball.runs;
              stats.ballsBowled++;
            }
          }

          // Maidens — player এর শেষ over check
          // (simplified: innings থেকে directly নেওয়া হবে)
        }

        // Fielding — caught/runout/stumped
        for (final ball in innings.ballEvents) {
          if (ball.fielderId == playerId) {
            if (ball.dismissalType == 'Caught') stats.catches++;
            if (ball.dismissalType == 'Run Out') stats.runOuts++;
            if (ball.dismissalType == 'Stumped') stats.stumpings++;
          }
        }
      }
    }

    // Player এর team matches
    final team = provider.getTeam(teamId);
    if (team != null) {
      stats.teamMatches = team.matchesPlayed;
      stats.teamWon = team.won;
    }

    return stats;
  }
}

// ── Stats Model ──────────────────────────────────────────────────────────────

class _PlayerStats {
  int matches = 0;
  int innings = 0;
  int notOuts = 0;
  int totalRuns = 0;
  int totalBalls = 0;
  int highScore = 0;
  bool highScoreNotOut = false;
  int fours = 0;
  int sixes = 0;
  int hundreds = 0;
  int fifties = 0;
  int thirties = 0;
  int ducks = 0;

  // Bowling
  int ballsBowled = 0;
  int runsConceded = 0;
  int wickets = 0;
  int maidens = 0;
  int wides = 0;
  int noBalls = 0;

  // Fielding
  int catches = 0;
  int runOuts = 0;
  int stumpings = 0;

  // Team
  int teamMatches = 0;
  int teamWon = 0;

  double get battingAverage {
    final dismissed = innings - notOuts;
    return dismissed == 0 ? 0.0 : totalRuns / dismissed;
  }

  double get strikeRate =>
      totalBalls == 0 ? 0.0 : (totalRuns / totalBalls * 100);

  String get oversBowled {
    final overs = ballsBowled ~/ 6;
    final balls = ballsBowled % 6;
    return '$overs.$balls';
  }

  double get bowlingAverage =>
      wickets == 0 ? 0.0 : runsConceded / wickets;

  double get economy =>
      ballsBowled == 0 ? 0.0 : runsConceded / (ballsBowled / 6);

  double get bowlingStrikeRate =>
      wickets == 0 ? 0.0 : ballsBowled / wickets;

  String get highScoreDisplay =>
      highScore == 0 ? '0' : '$highScore${highScoreNotOut ? '*' : ''}';
}

// ── Batting Tab ──────────────────────────────────────────────────────────────

class _BattingTab extends StatelessWidget {
  final _PlayerStats stats;
  const _BattingTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        // Row 1
        _StatsRow(items: [
          _StatItem('Matches', '${stats.matches}'),
          _StatItem('Innings', '${stats.innings}'),
          _StatItem('Runs', '${stats.totalRuns}'),
        ]),
        const SizedBox(height: 10),
        _StatsRow(items: [
          _StatItem('Not Outs', '${stats.notOuts}'),
          _StatItem('Best Score', stats.highScoreDisplay),
          _StatItem('Strike Rate', stats.strikeRate.toStringAsFixed(2)),
        ]),
        const SizedBox(height: 10),
        _StatsRow(items: [
          _StatItem('Average', stats.battingAverage.toStringAsFixed(2)),
          _StatItem('Fours', '${stats.fours}'),
          _StatItem('Sixes', '${stats.sixes}'),
        ]),
        const SizedBox(height: 10),
        _StatsRow(items: [
          _StatItem('Thirties', '${stats.thirties}'),
          _StatItem('Fifties', '${stats.fifties}'),
          _StatItem('Hundreds', '${stats.hundreds}'),
        ]),
        const SizedBox(height: 10),
        _StatsRow(items: [
          _StatItem('Ducks', '${stats.ducks}'),
          _StatItem('Balls Faced', '${stats.totalBalls}'),
          _StatItem('Boundary %',
              stats.totalBalls == 0
                  ? '0.00'
                  : '${((stats.fours * 4 + stats.sixes * 6) / stats.totalRuns * 100).isNaN ? 0 : ((stats.fours * 4 + stats.sixes * 6) / (stats.totalRuns == 0 ? 1 : stats.totalRuns) * 100).toStringAsFixed(1)}%'),
        ]),
        const SizedBox(height: 16),
        // Summary card
        if (stats.innings > 0)
          _SummaryCard(
            title: 'Batting Summary',
            icon: Icons.sports_cricket,
            color: AppTheme.host,
            lines: [
              'Total ${stats.totalRuns} runs in ${stats.innings} innings',
              '${stats.hundreds} hundreds, ${stats.fifties} fifties, ${stats.thirties} thirties',
              'Best: ${stats.highScoreDisplay} | Avg: ${stats.battingAverage.toStringAsFixed(2)} | SR: ${stats.strikeRate.toStringAsFixed(2)}',
            ],
          ),
      ]),
    );
  }
}

// ── Bowling Tab ──────────────────────────────────────────────────────────────

class _BowlingTab extends StatelessWidget {
  final _PlayerStats stats;
  const _BowlingTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        _StatsRow(items: [
          _StatItem('Matches', '${stats.matches}'),
          _StatItem('Innings', '${stats.innings}'),
          _StatItem('Wickets', '${stats.wickets}'),
        ]),
        const SizedBox(height: 10),
        _StatsRow(items: [
          _StatItem('Overs', stats.oversBowled),
          _StatItem('Runs', '${stats.runsConceded}'),
          _StatItem('Economy', stats.economy.toStringAsFixed(2)),
        ]),
        const SizedBox(height: 10),
        _StatsRow(items: [
          _StatItem('Average', stats.wickets == 0 ? '-' : stats.bowlingAverage.toStringAsFixed(2)),
          _StatItem('Strike Rate', stats.wickets == 0 ? '-' : stats.bowlingStrikeRate.toStringAsFixed(2)),
          _StatItem('Maidens', '${stats.maidens}'),
        ]),
        const SizedBox(height: 10),
        _StatsRow(items: [
          _StatItem('Wides', '${stats.wides}'),
          _StatItem('No Balls', '${stats.noBalls}'),
          _StatItem('Extras', '${stats.wides + stats.noBalls}'),
        ]),
        const SizedBox(height: 16),
        if (stats.ballsBowled > 0)
          _SummaryCard(
            title: 'Bowling Summary',
            icon: Icons.sports_baseball,
            color: AppTheme.visitor,
            lines: [
              '${stats.wickets} wickets in ${stats.oversBowled} overs',
              '${stats.runsConceded} runs conceded',
              'Eco: ${stats.economy.toStringAsFixed(2)} | Avg: ${stats.wickets == 0 ? "-" : stats.bowlingAverage.toStringAsFixed(2)} | SR: ${stats.wickets == 0 ? "-" : stats.bowlingStrikeRate.toStringAsFixed(2)}',
            ],
          )
        else
          _EmptyStats(message: 'No bowling data available'),
      ]),
    );
  }
}

// ── Fielding Tab ─────────────────────────────────────────────────────────────

class _FieldingTab extends StatelessWidget {
  final _PlayerStats stats;
  final AppProvider provider;
  final String playerId;

  const _FieldingTab({
    required this.stats,
    required this.provider,
    required this.playerId,
  });

  @override
  Widget build(BuildContext context) {
    final totalDismissals =
        stats.catches + stats.runOuts + stats.stumpings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        _StatsRow(items: [
          _StatItem('Matches', '${stats.matches}'),
          _StatItem('Innings', '${stats.innings}'),
          _StatItem('Dismissals', '$totalDismissals'),
        ]),
        const SizedBox(height: 10),
        _StatsRow(items: [
          _StatItem('Catches', '${stats.catches}'),
          _StatItem('Run Outs', '${stats.runOuts}'),
          _StatItem('Stumpings', '${stats.stumpings}'),
        ]),
        const SizedBox(height: 16),
        if (totalDismissals > 0)
          _SummaryCard(
            title: 'Fielding Summary',
            icon: Icons.catching_pokemon,
            color: Colors.green,
            lines: [
              '$totalDismissals total dismissals',
              '${stats.catches} catches, ${stats.runOuts} run outs, ${stats.stumpings} stumpings',
            ],
          )
        else
          _EmptyStats(message: 'No fielding dismissals recorded'),
      ]),
    );
  }
}

// ── Shared UI Components ─────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<_StatItem> items;
  const _StatsRow({required this.items});

  @override
  Widget build(BuildContext context) => Row(
    children: items
        .map((item) => Expanded(child: _StatCard(item: item)))
        .toList()
        .expand((w) => [w, const SizedBox(width: 10)])
        .toList()
      ..removeLast(),
  );
}

class _StatItem {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          item.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> lines;

  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 13)),
      ]),
      const SizedBox(height: 10),
      ...lines.map((l) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(l,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4)),
      )),
    ]),
  );
}

class _EmptyStats extends StatelessWidget {
  final String message;
  const _EmptyStats({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      Icon(Icons.info_outline, color: Colors.grey.shade400, size: 36),
      const SizedBox(height: 8),
      Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
    ]),
  );
}