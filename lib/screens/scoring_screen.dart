import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../provider/app_provider.dart';
import '../utils/theme.dart';
import 'scoreboard_screen.dart';
import 'analysis_screen.dart';

class ScoringScreen extends StatefulWidget {
  final String matchId;
  const ScoringScreen({super.key, required this.matchId});
  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> {
  bool _initDialogShown = false;
  bool _inningsTransitionShown = false;
  bool _inningsCancelledByUser = false;
  String? _lastSeenInningsTeamId;
  // Milestone popup
  String? _milestoneText;
  void _checkMilestone(AppProvider provider) {
    if (provider.lastMilestone != null) {
      setState(() => _milestoneText = provider.lastMilestone);
      provider.clearMilestone();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _milestoneText = null);
      });
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<AppProvider>();
    final match = provider.matches.firstWhereOrNull((m) => m.id == widget.matchId);
    if (match != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.setActiveMatch(match);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (ctx, provider, _) {
      final match = provider.matches.firstWhere((m) => m.id == widget.matchId);

      if (match.status == MatchStatus.completed) {
        return _MatchCompletedScreen(match: match, provider: provider);
      }

      final innings = match.currentInnings;

      // ── 2nd innings transition ──
      // 1st innings complete then 2nd innings dialog
      if (innings != null &&
          match.firstInnings != null &&
          match.firstInnings!.isCompleted &&
          match.secondInnings != null &&
          innings.strikerBatsmanId == null) {
        // innings  flag reset
        if (_lastSeenInningsTeamId != innings.teamId) {
          _lastSeenInningsTeamId = innings.teamId;
          _inningsTransitionShown = false;
          _inningsCancelledByUser = false;
        }
        if (!_inningsTransitionShown && !_inningsCancelledByUser) {
          _inningsTransitionShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showInningsBreakDialog(context, provider, match, innings);
            }
          });
        }
      }

      // ── 1st innings init ──
      if (innings != null &&
          innings.strikerBatsmanId == null &&
          !_initDialogShown &&
          !(match.firstInnings != null &&
              match.firstInnings!.isCompleted &&
              match.secondInnings != null)) {
        _initDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showInitDialog(context, provider, match, innings);
          }
        });
      }

      if (innings == null) {
        return _MatchCompletedScreen(match: match, provider: provider);
      }

      return Stack(
        children: [
          Scaffold(
            backgroundColor: AppTheme.surface,
            appBar: _buildAppBar(context, match, provider),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _ScoreHeader(
                            match: match,
                            innings: innings,
                            provider: provider,
                            onInningsReset: () {
                              setState(() {
                                _inningsTransitionShown = false;
                                _inningsCancelledByUser = false;
                                _lastSeenInningsTeamId = null;
                              });
                            },
                            onInningsContinue: () {
                              setState(() {
                                _inningsTransitionShown = true;
                                _inningsCancelledByUser = true;
                              });
                            },
                          ),
                          _BatsmenInfo(match: match, innings: innings, provider: provider),
                          _BowlerInfo(match: match, innings: innings, provider: provider),
                          _ExtrasInfo(innings: innings),
                          _ThisOver(innings: innings),
                          _NextBatsmenInfo(match: match, innings: innings, provider: provider),
                          _ReservePlayersPanel(match: match, innings: innings, provider: provider),
                        ],
                      ),
                    ),
                  ),
                  _ScoringPad(
                    match: match,
                    innings: innings,
                    provider: provider,
                    onWicket: ({bool showBowlerAfter = false, String? outBatsmanId}) =>
                        _showWicketDialog(context, provider, match, innings,
                            showBowlerAfter: showBowlerAfter,
                            outBatsmanId: outBatsmanId),
                    onOverEnd: () => _showChangeBowlerDialog(context, provider, match),
                    onMilestone: (text) {
                      setState(() => _milestoneText = text);
                      Future.delayed(const Duration(seconds: 5), () {
                        if (mounted) setState(() => _milestoneText = null);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // ── Milestone Overlay ──
          if (_milestoneText != null)
            Positioned(
              top: 80,
              left: 24,
              right: 24,
              child: AnimatedOpacity(
                opacity: _milestoneText != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 12)],
                  ),
                  child: Text(
                    _milestoneText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  AppBar _buildAppBar(
      BuildContext context, CricketMatch match, AppProvider provider) {
    final hostTeam = provider.getTeam(match.hostTeamId);
    final visitorTeam = provider.getTeam(match.visitorTeamId);
    return AppBar(
      title: Text(
        '${hostTeam?.name ?? ''} vs ${visitorTeam?.name ?? ''}',
        style: const TextStyle(fontSize: 15),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: 'Undo',
          onPressed: () => provider.undoLastBall(),
        ),
        IconButton(
          icon: const Icon(Icons.list_alt),
          tooltip: 'Scoreboard',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ScoreboardScreen(matchId: match.id)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.bar_chart),
          tooltip: 'Analysis',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AnalysisScreen(matchId: match.id)),
          ),
        ),
      ],
    );
  }

  void _showInitDialog(BuildContext context, AppProvider provider,
      CricketMatch match, Innings innings) {
    // শুধু main players (reserve বাদ)
    final teamPlayers = provider.getTeamPlayersForMatch(innings.teamId, match)
        .where((p) => !p.isReserve).toList();
    final bowlingTeamId = innings.teamId == match.hostTeamId
        ? match.visitorTeamId
        : match.hostTeamId;
    final bowlerPlayers =
    provider.getTeamPlayersForMatch(bowlingTeamId, match);

    // team এ যে order এ আছে সেভাবে auto-select
    String? striker = teamPlayers.isNotEmpty ? teamPlayers[0].id : null;
    String? nonStriker = teamPlayers.length > 1 ? teamPlayers[1].id : null;
    String? bowler = bowlerPlayers.isNotEmpty ? bowlerPlayers[0].id : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (ctx2, setS) {
            // all time latest player list take
            // reserve player init dialog এ আসবে না
            final latestTeamPlayers = provider.getTeamPlayersForMatch(innings.teamId, match)
                .where((p) => !p.isReserve).toList();
            final latestBowlerPlayers = provider.getTeamPlayersForMatch(bowlingTeamId, match);

            void addBatsman() {
              showDialog(
                context: ctx2,
                builder: (_) => _AddPlayerInlineDialog(
                  title: 'নতুন Batsman যোগ করুন',
                  onAdd: (name) {
                    final newId = provider.addTempPlayer(name, innings.teamId, match);
                    setS(() { striker ??= newId; });
                  },
                ),
              );
            }

            void addBowler() {
              showDialog(
                context: ctx2,
                builder: (_) => _AddPlayerInlineDialog(
                  title: 'নতুন Bowler যোগ করুন',
                  onAdd: (name) {
                    final newId = provider.addTempPlayer(name, bowlingTeamId, match);
                    setS(() { bowler ??= newId; });
                  },
                ),
              );
            }

            void deletePlayer(String teamId, String playerId, String role) {
              final players = provider.getTeamPlayersForMatch(teamId, match);
              final player = players.firstWhere((p) => p.id == playerId, orElse: () => players.first);
              showDialog(
                context: ctx2,
                builder: (_) => AlertDialog(
                  title: Text('${player.name} সরাবেন?',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  content: const Text('এই player টি list থেকে বাদ যাবে।'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('বাতিল')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        final idx = players.indexWhere((p) => p.id == playerId);
                        if (idx >= 0) {
                          if (teamId == match.hostTeamId) {
                            match.tempHostPlayers.removeAt(idx);
                          } else {
                            match.tempVisitorPlayers.removeAt(idx);
                          }
                        }
                        Navigator.pop(ctx2);
                        setS(() {
                          if (role == 'striker' || role == 'nonStriker') striker = null;
                          if (role == 'bowler') bowler = null;
                        });
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: Text('Start Innings',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Batting team players
                  Row(children: [
                    Expanded(
                      child: Text('Batting Team Players',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.primary)),
                    ),
                    TextButton.icon(
                      onPressed: addBatsman,
                      icon: const Icon(Icons.person_add, size: 14, color: AppTheme.primary),
                      label: const Text('Add', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                    ),
                  ]),
                  // Batsman player list with delete
                  ...latestTeamPlayers.map((p) => Row(children: [
                    Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      onPressed: () => deletePlayer(innings.teamId, p.id, 'striker'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ])),
                  const Divider(),
                  _PlayerDropdown(
                    label: 'Opening Batsman (Striker)',
                    players: latestTeamPlayers,
                    value: latestTeamPlayers.any((p) => p.id == striker) ? striker : null,
                    onChanged: (v) => setS(() => striker = v),
                  ),
                  const SizedBox(height: 12),
                  _PlayerDropdown(
                    label: 'Opening Batsman (Non-striker)',
                    players: latestTeamPlayers,
                    value: latestTeamPlayers.any((p) => p.id == nonStriker) ? nonStriker : null,
                    onChanged: (v) => setS(() => nonStriker = v),
                  ),
                  const SizedBox(height: 16),
                  // Bowling team players
                  Row(children: [
                    Expanded(
                      child: Text('Bowling Team Players',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.primary)),
                    ),
                    TextButton.icon(
                      onPressed: addBowler,
                      icon: const Icon(Icons.person_add, size: 14, color: AppTheme.primary),
                      label: const Text('Add', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                    ),
                  ]),
                  ...latestBowlerPlayers.map((p) => Row(children: [
                    Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      onPressed: () => deletePlayer(bowlingTeamId, p.id, 'bowler'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ])),
                  const Divider(),
                  _PlayerDropdown(
                    label: 'Opening Bowler',
                    players: latestBowlerPlayers,
                    value: latestBowlerPlayers.any((p) => p.id == bowler) ? bowler : null,
                    onChanged: (v) => setS(() => bowler = v),
                  ),
                ]),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    if (striker != null &&
                        nonStriker != null &&
                        bowler != null &&
                        striker != nonStriker) {
                      provider.initInnings(
                        strikerBatsmanId: striker!,
                        nonStrikerBatsmanId: nonStriker!,
                        bowlerId: bowler!,
                      );
                      Navigator.pop(ctx2);
                    } else {
                      ScaffoldMessenger.of(ctx2).showSnackBar(
                        const SnackBar(
                            content: Text('Please select different batsmen!')),
                      );
                    }
                  },
                  child: const Text('Start'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showInningsBreakDialog(BuildContext context, AppProvider provider,
      CricketMatch match, Innings innings) {
    final firstInnings = match.firstInnings!;
    final battingTeam = provider.getTeam(innings.teamId);
    final target = firstInnings.totalRuns + 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('Innings Break!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.sports_cricket,
                size: 48, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text(
              '${battingTeam?.name ?? "Team"} needs $target runs to win',
              style: GoogleFonts.poppins(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'in ${match.totalOvers} overs',
              style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '2nd innings শুরু করতে নিচের button চাপুন',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ]),
            ),
          ]),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _initDialogShown = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showInitDialog(context, provider, match, innings);
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('▶ Start 2nd Innings'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWicketDialog(BuildContext context, AppProvider provider,
      CricketMatch match, Innings innings, {bool showBowlerAfter = false, String? outBatsmanId}) {

    final battingTeamPlayers =
    provider.getTeamPlayersForMatch(innings.teamId, match);

    // out batsman — run out এ selected batsman, নাহলে striker
    final actualOutId = outBatsmanId ?? innings.strikerBatsmanId;
    // মাঠে যে থাকবে — out বাদে অন্যজন
    final remainingOnField = [innings.strikerBatsmanId, innings.nonStrikerBatsmanId]
        .where((id) => id != null && id != actualOutId)
        .toList();

    final available = battingTeamPlayers
        .where((p) =>
    !p.isOut &&
        !p.isReserve &&
        p.id != actualOutId &&
        !remainingOnField.contains(p.id))
        .toList();

    // আর কেউ নেই — all out, dialog দেখানোর দরকার নেই
    if (available.isEmpty) return;
    String? nextBatsman = available.isNotEmpty ? available[0].id : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (ctx2, setS) {
            final latestAvailable = provider
                .getTeamPlayersForMatch(innings.teamId, match)
                .where((p) =>
            !p.isOut &&
                !p.isReserve &&
                p.id != actualOutId &&
                !remainingOnField.contains(p.id))
                .toList();

            void addBatsman() {
              showDialog(
                context: ctx2,
                builder: (_) => _AddPlayerInlineDialog(
                  title: 'নতুন Batsman যোগ করুন',
                  onAdd: (name) {
                    final newId = provider.addTempPlayer(name, innings.teamId, match);
                    setS(() => nextBatsman = newId);
                  },
                ),
              );
            }


            void deleteBatsman(String playerId) {
              final players = provider.getTeamPlayersForMatch(innings.teamId, match);
              final player = players.firstWhere((p) => p.id == playerId, orElse: () => players.first);
              showDialog(
                context: ctx2,
                builder: (_) => AlertDialog(
                  title: Text('${player.name} সরাবেন?',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  content: const Text('এই player টি list থেকে বাদ যাবে।'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('বাতিল')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        final idx = players.indexWhere((p) => p.id == playerId);
                        if (idx >= 0) {
                          if (innings.teamId == match.hostTeamId) {
                            match.tempHostPlayers.removeAt(idx);
                          } else {
                            match.tempVisitorPlayers.removeAt(idx);
                          }
                        }
                        Navigator.pop(ctx2);
                        setS(() => nextBatsman = null);
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: Text('Wicket! — Next Batsman',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red)),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(
                      child: Text('Available Batsmen',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.primary)),
                    ),
                    TextButton.icon(
                      onPressed: addBatsman,
                      icon: const Icon(Icons.person_add, size: 14, color: AppTheme.primary),
                      label: const Text('Add', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                    ),
                  ]),
                  ...latestAvailable.map((p) => Row(children: [
                    Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      onPressed: () => deleteBatsman(p.id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ])),
                  const Divider(),
                  _PlayerDropdown(
                    label: 'Next Batsman',
                    players: latestAvailable,
                    value: latestAvailable.any((p) => p.id == nextBatsman)
                        ? nextBatsman
                        : (latestAvailable.isNotEmpty ? latestAvailable[0].id : null),
                    onChanged: (v) => setS(() => nextBatsman = v),
                  ),
                ]),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    if (nextBatsman != null) {
                      provider.setNextBatsman(nextBatsman!, outBatsmanId: outBatsmanId);
                      Navigator.pop(ctx2);
                      // Hat-trick milestone — confirm then see
                      if (provider.wicketMilestone != null) {
                        final text = provider.wicketMilestone!;
                        provider.clearWicketMilestone();
                        setState(() => _milestoneText = text);
                        Future.delayed(const Duration(seconds: 5), () {
                          if (mounted) setState(() => _milestoneText = null);
                        });
                      }
                      // Over শেষ হলে bowler dialog দেখাও
                      if (showBowlerAfter) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _showChangeBowlerDialog(context, provider, match);
                          }
                        });
                      }
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showChangeBowlerDialog(
      BuildContext context, AppProvider provider, CricketMatch match) {
    final innings = match.currentInnings;
    if (innings == null) return;

    final bowlingTeamId = innings.teamId == match.hostTeamId
        ? match.visitorTeamId
        : match.hostTeamId;
    final bowlers = provider.getTeamPlayersForMatch(bowlingTeamId, match);

    // আগের over এর bowler — consecutive over করতে পারবে না
    final lastOverBowlerId = provider.getLastOverBowlerId(innings);

    final available = bowlers.where((p) =>
    p.id != innings.currentBowlerId &&
        p.id != lastOverBowlerId).toList();

    // player কম হলে restriction তুলে দাও
    final initialList = available.isEmpty
        ? bowlers.where((p) => p.id != innings.currentBowlerId).toList()
        : available;

    if (initialList.isEmpty) return;
    String? newBowler = initialList[0].id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (ctx2, setS) {
            final latestAll = provider.getTeamPlayersForMatch(bowlingTeamId, match);
            final latestRestricted = latestAll.where((p) =>
            p.id != innings.currentBowlerId &&
                p.id != lastOverBowlerId).toList();
            final latestAvailable = latestRestricted.isEmpty
                ? latestAll.where((p) => p.id != innings.currentBowlerId).toList()
                : latestRestricted;

            void addBowler() {
              showDialog(
                context: ctx2,
                builder: (_) => _AddPlayerInlineDialog(
                  title: 'নতুন Bowler যোগ করুন',
                  onAdd: (name) {
                    final newId = provider.addTempPlayer(name, bowlingTeamId, match);
                    setS(() => newBowler = newId);
                  },
                ),
              );
            }

            void deleteBowler(String playerId) {
              final players = provider.getTeamPlayersForMatch(bowlingTeamId, match);
              final player = players.firstWhere((p) => p.id == playerId, orElse: () => players.first);
              showDialog(
                context: ctx2,
                builder: (_) => AlertDialog(
                  title: Text('${player.name} সরাবেন?',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  content: const Text('এই player টি list থেকে বাদ যাবে।'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('বাতিল')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        final idx = players.indexWhere((p) => p.id == playerId);
                        if (idx >= 0) {
                          if (bowlingTeamId == match.hostTeamId) {
                            match.tempHostPlayers.removeAt(idx);
                          } else {
                            match.tempVisitorPlayers.removeAt(idx);
                          }
                        }
                        Navigator.pop(ctx2);
                        setS(() => newBowler = null);
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            }

            // যদি restriction এর কারণে fallback হয়, note দেখাও
            final isUsingFallback = latestRestricted.isEmpty && latestAvailable.isNotEmpty;

            return AlertDialog(
              title: Text('End of Over — New Bowler',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (isUsingFallback)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          'Consecutive over restriction lifted (not enough players)',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange),
                        )),
                      ]),
                    ),
                  Row(children: [
                    Expanded(
                      child: Text('Bowling Team Players',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.primary)),
                    ),
                    TextButton.icon(
                      onPressed: addBowler,
                      icon: const Icon(Icons.person_add, size: 14, color: AppTheme.primary),
                      label: const Text('Add', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                    ),
                  ]),
                  ...latestAvailable.map((p) => Row(children: [
                    Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      onPressed: () => deleteBowler(p.id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ])),
                  const Divider(),
                  _PlayerDropdown(
                    label: 'Select Bowler',
                    players: latestAvailable,
                    value: latestAvailable.any((p) => p.id == newBowler) ? newBowler : null,
                    onChanged: (v) => setS(() => newBowler = v),
                  ),
                ]),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    if (newBowler != null) {
                      provider.setNewBowler(newBowler!);
                      Navigator.pop(ctx2);
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  final CricketMatch match;
  final Innings innings;
  final AppProvider provider;
  final VoidCallback? onInningsReset;
  final VoidCallback? onInningsContinue;

  const _ScoreHeader(
      {required this.match,
        required this.innings,
        required this.provider,
        this.onInningsReset,
        this.onInningsContinue});

  @override
  Widget build(BuildContext context) {
    final battingTeam = provider.getTeam(innings.teamId);
    final isSecondInnings = match.firstInnings != null &&
        match.firstInnings!.isCompleted &&
        match.secondInnings?.teamId == innings.teamId;

    Widget? targetBar;
    if (isSecondInnings && match.firstInnings != null) {
      final target = match.firstInnings!.totalRuns + 1;
      final needed = target - innings.totalRuns;
      final ballsLeft = (match.totalOvers * 6) - innings.totalBalls;
      final prob = provider.getWinProbability(match);

      targetBar = Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: AppTheme.primaryDark,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Target: $target',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13)),
            Text(
              needed > 0
                  ? 'Need $needed off $ballsLeft balls'
                  : 'Won!',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              '% ${(prob * 100).round()}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppTheme.primary,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(battingTeam?.name ?? 'Batting',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      Text(
                        '${innings.totalRuns} - ${innings.wickets}',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold),
                      ),
                    ]),
              ),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                        'CRR: ${innings.runRate.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _showEditOversDialog(context, provider, match),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${innings.completedOvers}.${innings.ballsInCurrentOver} / ${match.totalOvers} ov',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ]),
            ],
          ),
        ),
        if (targetBar != null) targetBar,
      ]),
    );
  }

  void _showEditOversDialog(BuildContext context, AppProvider provider, CricketMatch match) {
    showDialog(
      context: context,
      builder: (_) => _EditOversDialog(
        currentOvers: match.totalOvers,
        onUpdate: (val) {
          final inningsCompleted = provider.updateMatchOvers(val);
          if (inningsCompleted) {
            onInningsReset?.call();
          } else {
            onInningsContinue?.call();
          }
        },
      ),
    );
  }
}

class _BatsmenInfo extends StatelessWidget {
  final CricketMatch match;
  final Innings innings;
  final AppProvider provider;

  const _BatsmenInfo(
      {required this.match,
        required this.innings,
        required this.provider});

  @override
  Widget build(BuildContext context) {
    final striker = innings.strikerBatsmanId != null
        ? provider.getPlayerById(innings.strikerBatsmanId!, match)
        : null;
    final nonStriker = innings.nonStrikerBatsmanId != null
        ? provider.getPlayerById(innings.nonStrikerBatsmanId!, match)
        : null;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(children: [
          Row(children: [
            const Text('Batsmen',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => provider.swapBatsmen(),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.swap_vert,
                    size: 16, color: AppTheme.primary),
              ),
            ),
          ]),
          const Divider(height: 8),

          Table(
            columnWidths: const {
              0: FlexColumnWidth(),
              1: FixedColumnWidth(36),
              2: FixedColumnWidth(36),
              3: FixedColumnWidth(36),
              4: FixedColumnWidth(36),
              5: FixedColumnWidth(44),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(),
                children: [
                  for (final h in ['', 'R', 'B', '4s', '6s', 'SR'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(h,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ),
                ],
              ),
              if (striker != null)
                _batsmanTableRow(context, striker, true),
              if (nonStriker != null)
                _batsmanTableRow(context, nonStriker, false),
            ],
          ),

          if (striker == null && nonStriker == null)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Waiting for batsmen...',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
        ]),
      ),
    );
  }

  TableRow _batsmanTableRow(BuildContext context, Player p, bool isStriker) {
    return TableRow(children: [
      GestureDetector(
        onLongPress: () => _showEditNameDialog(context, p),
        onTap: () => _showChangeBatsmanDialog(context, p, isStriker),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            if (isStriker)
              const Icon(Icons.sports_cricket,
                  size: 13, color: AppTheme.primary),
            const SizedBox(width: 2),
            Flexible(
              child: Text(p.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                      fontWeight: isStriker ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13)),
            ),
            const Icon(Icons.keyboard_arrow_down,
                size: 13, color: AppTheme.textSecondary),
          ]),
        ),
      ),
      for (final val in [
        '${p.runs}',
        '${p.balls}',
        '${p.fours}',
        '${p.sixes}',
        p.strikeRate.toStringAsFixed(1),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(val,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isStriker && val == '${p.runs}'
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ),
    ]);
  }

  void _showChangeBatsmanDialog(BuildContext context, Player current, bool isStriker) {
    final battingTeamPlayers = provider.getTeamPlayersForMatch(innings.teamId, match);
    final available = battingTeamPlayers
        .where((p) =>
    !p.isOut &&
        p.id != innings.strikerBatsmanId &&
        p.id != innings.nonStrikerBatsmanId)
        .toList();
    if (available.isEmpty) return;
    String? selected = available[0].id;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: Text('Change Batsman',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: _PlayerDropdown(
            label: 'Select Batsman',
            players: available,
            value: selected,
            onChanged: (v) => setS(() => selected = v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selected != null) {
                  if (isStriker) {
                    provider.setNextBatsman(selected!);
                  } else {
                    provider.setNonStriker(selected!);
                  }
                  Navigator.pop(ctx2);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, Player p) {
    showDialog(
      context: context,
      builder: (_) => _EditNameDialog(
        initialName: p.name,
        onSave: (name) => provider.renameTempPlayer(p.id, name, match),
      ),
    );
  }

  Widget _batsmanRow(BuildContext context, Player p, bool isStriker) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(
        child: GestureDetector(
          onLongPress: () => _showEditNameDialog(context, p),
          onTap: () => _showChangeBatsmanDialog(context, p, isStriker),
          child: Row(children: [
            if (isStriker)
              const Icon(Icons.sports_cricket,
                  size: 14, color: AppTheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(p.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                      fontWeight: isStriker
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontSize: 13)),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down,
                size: 14, color: AppTheme.textSecondary),
          ]),
        ),
      ),
      for (final val in [
        '${p.runs}',
        '${p.balls}',
        '${p.fours}',
        '${p.sixes}',
        p.strikeRate.toStringAsFixed(1),
      ])
        SizedBox(
          width: 40,
          child: Text(val,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isStriker && val == '${p.runs}'
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ),
    ]),
  );
}

class _BowlerInfo extends StatelessWidget {
  final CricketMatch match;
  final Innings innings;
  final AppProvider provider;

  const _BowlerInfo(
      {required this.match,
        required this.innings,
        required this.provider});

  @override
  Widget build(BuildContext context) {
    final bowler = innings.currentBowlerId != null
        ? provider.getPlayerById(innings.currentBowlerId!, match)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          const Icon(Icons.sports_baseball,
              size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _showEditBowlerName(context, bowler),
              onTap: () => _showChangeBowler(context, bowler),
              child: Row(children: [
                Flexible(child: Text(bowler?.name ?? 'Bowler',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down,
                    size: 16, color: AppTheme.textSecondary),
              ]),
            ),
          ),
          const SizedBox(width: 4),
          for (final kv in [
            ('O', bowler?.oversBowledDisplay ?? '0.0'),
            ('M', '${bowler?.maidens ?? 0}'),
            ('R', '${bowler?.runsConceded ?? 0}'),
            ('W', '${bowler?.wickets ?? 0}'),
            ('Eco', bowler?.bowlingEconomy.toStringAsFixed(2) ?? '0.00'),
          ])
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(children: [
                Text(kv.$1,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
                Text(kv.$2,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 12)),
              ]),
            ),
        ]),
      ),
    );
  }

  void _showEditBowlerName(BuildContext context, Player? bowler) {
    if (bowler == null) return;
    showDialog(
      context: context,
      builder: (_) => _EditNameDialog(
        initialName: bowler.name,
        title: 'Edit Bowler Name',
        label: 'Bowler Name',
        onSave: (name) => provider.renameTempPlayer(bowler.id, name, match),
      ),
    );
  }

  void _showChangeBowler(BuildContext context, Player? currentBowler) {
    final bowlingTeamId = innings.teamId == match.hostTeamId
        ? match.visitorTeamId
        : match.hostTeamId;
    final available = provider
        .getTeamPlayersForMatch(bowlingTeamId, match)
        .where((p) => p.id != innings.currentBowlerId)
        .toList();
    if (available.isEmpty) return;
    String? selected = available[0].id;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: Text('Change Bowler',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: _PlayerDropdown(
            label: 'Select Bowler',
            players: available,
            value: selected,
            onChanged: (v) => setS(() => selected = v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selected != null) {
                  provider.setNewBowler(selected!);
                  Navigator.pop(ctx2);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtrasInfo extends StatelessWidget {
  final Innings innings;
  const _ExtrasInfo({required this.innings});

  Map<String, int> _calcExtras() {
    int wd = 0, nb = 0, b = 0, lb = 0;
    for (final e in innings.ballEvents) {
      switch (e.type) {
        case BallType.wide:
          wd += e.runs;
          break;
        case BallType.noBall:
          nb += e.runs + 1;
          break;
        case BallType.bye:
          b += e.runs;
          break;
        case BallType.legBye:
          lb += e.runs;
          break;
        default:
          break;
      }
    }
    return {'Wd': wd, 'Nb': nb, 'B': b, 'Lb': lb};
  }

  @override
  Widget build(BuildContext context) {
    final extras = _calcExtras();
    final total = extras.values.fold(0, (a, b) => a + b);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          const Icon(Icons.add_circle_outline, size: 15, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text('Extras',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$total',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const Spacer(),
          ...extras.entries.map((e) => Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Column(children: [
              Text(e.key,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
              Text('${e.value}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _ThisOver extends StatelessWidget {
  final Innings innings;

  const _ThisOver({required this.innings});

  List<BallEvent> _getCurrentOverBalls() {
    int legalCount = 0;
    int startIdx = 0;
    final targetLegal = innings.completedOvers * 6;

    for (int i = 0; i < innings.ballEvents.length; i++) {
      final b = innings.ballEvents[i];
      if (b.type != BallType.wide && b.type != BallType.noBall) {
        legalCount++;
      }
      if (legalCount == targetLegal) {
        startIdx = i + 1;
        break;
      }
    }

    if (targetLegal == 0 && legalCount == 0) {
      startIdx = 0;
    }

    return innings.ballEvents.sublist(startIdx);
  }

  @override
  Widget build(BuildContext context) {
    final thisOverBalls = _getCurrentOverBalls();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        const Text('This over: ',
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: thisOverBalls.isEmpty
                  ? [
                const Text('—',
                    style: TextStyle(
                        color: AppTheme.textSecondary))
              ]
                  : thisOverBalls.reversed
                  .map((b) => _BallChip(ball: b))
                  .toList(),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Next Batsmen Info ────

class _NextBatsmenInfo extends StatelessWidget {
  final CricketMatch match;
  final Innings innings;
  final AppProvider provider;

  const _NextBatsmenInfo({
    required this.match,
    required this.innings,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final allPlayers = provider.getTeamPlayersForMatch(innings.teamId, match);

    final waitingBatsmen = allPlayers.where((p) =>
    !p.isOut &&
        !p.isReserve &&  // reserve player আলাদা section এ থাকবে
        p.id != innings.strikerBatsmanId &&
        p.id != innings.nonStrikerBatsmanId).toList();

    final count = waitingBatsmen.length;
    final names = waitingBatsmen.map((p) => p.name).join(' | ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Next Batsmen ',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Flexible(
                child: Text('($count)',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              count == 0 ? '—' : names,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reserve Players Panel ────────────────────────────────────────────────────

class _ReservePlayersPanel extends StatelessWidget {
  final CricketMatch match;
  final Innings innings;
  final AppProvider provider;

  const _ReservePlayersPanel({
    required this.match,
    required this.innings,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final allPlayers = provider.getTeamPlayersForMatch(innings.teamId, match);
    final reservePlayers = allPlayers.where((p) => p.isReserve && !p.isOut).toList();

    if (reservePlayers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Reserve ',
                style: TextStyle(fontSize: 12, color: Colors.orange)),
            Text('(${reservePlayers.length})',
                style: const TextStyle(fontSize: 12, color: Colors.orange)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showSubstituteDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: const Text('Substitute',
                    style: TextStyle(fontSize: 11, color: Colors.orange,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              reservePlayers.map((p) => p.name).join(' | '),
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubstituteDialog(BuildContext context) {
    final allPlayers = provider.getTeamPlayersForMatch(innings.teamId, match);
    final reservePlayers = allPlayers.where((p) => p.isReserve && !p.isOut).toList();
    final mainPlayers = allPlayers.where((p) =>
    !p.isReserve && !p.isOut &&
        p.id != innings.strikerBatsmanId &&
        p.id != innings.nonStrikerBatsmanId).toList();

    if (reservePlayers.isEmpty || mainPlayers.isEmpty) return;

    String? selectedReserve = reservePlayers.first.id;
    String? selectedMain = mainPlayers.first.id;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: Row(children: [
            const Icon(Icons.swap_horiz, color: Colors.orange),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Substitute Player',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontSize: 16)),
            ),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Reserve player (আসবে)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('IN (Reserve)',
                        style: TextStyle(fontSize: 11, color: Colors.green,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      value: selectedReserve,
                      items: reservePlayers.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (v) => setS(() => selectedReserve = v),
                    ),
                  ]),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.swap_vert, color: Colors.grey),
                    ),
                    Expanded(child: Divider()),
                  ]),
                ),
                // Main player (বাইরে যাবে)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('OUT (যাবে)',
                        style: TextStyle(fontSize: 11, color: Colors.red,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      value: selectedMain,
                      items: mainPlayers.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (v) => setS(() => selectedMain = v),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                if (selectedReserve != null && selectedMain != null) {
                  provider.substituteReservePlayer(
                    match: match,
                    reservePlayerId: selectedReserve!,
                    outPlayerId: selectedMain!,
                    innings: innings,
                  );
                  Navigator.pop(ctx2);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BallChip extends StatelessWidget {
  final BallEvent ball;

  const _BallChip({required this.ball});

  @override
  Widget build(BuildContext context) {
    final isNoBallRunOut = ball.type == BallType.noBall && ball.dismissalType == 'Run Out';
    final isWide = ball.type == BallType.wide;
    final isNoBall = ball.type == BallType.noBall;

    Color bg;
    Color textColor = Colors.white;
    if (isNoBallRunOut) {
      bg = Colors.red;
    } else if (isWide) {
      bg = Colors.white;
      textColor = Colors.black87;
    } else if (isNoBall) {
      bg = Colors.black87;
    } else {
      switch (ball.type) {
        case BallType.wicket:
          bg = Colors.red;
          break;
        default:
          bg = ball.runs == 4
              ? Colors.blue
              : ball.runs == 6
              ? Colors.purple
              : AppTheme.primary;
      }
    }

    return SizedBox(
      width: 38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: isWide ? Border.all(color: Colors.grey.shade400, width: 1.5) : null,
            ),
            child: Center(
              child: Text(
                isNoBallRunOut ? 'W' : ball.display,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
            ),
          ),
          if (isNoBallRunOut || isNoBall)
            Text('NB',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700))
          else if (isWide)
            Text('Wd',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600))
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _ScoringPad extends StatefulWidget {
  final CricketMatch match;
  final Innings innings;
  final AppProvider provider;
  final void Function({bool showBowlerAfter, String? outBatsmanId}) onWicket;
  final VoidCallback onOverEnd;
  final ValueChanged<String> onMilestone;

  const _ScoringPad({
    required this.match,
    required this.innings,
    required this.provider,
    required this.onWicket,
    required this.onOverEnd,
    required this.onMilestone,
  });

  @override
  State<_ScoringPad> createState() => _ScoringPadState();
}

class _ScoringPadState extends State<_ScoringPad> {
  bool _wide = false;
  bool _noBall = false;
  bool _bye = false;
  bool _legBye = false;
  bool _freeHit = false;

  // innings বদলালে (1st → 2nd) সব flag reset করো
  String? _lastInningsTeamId;

  @override
  void didUpdateWidget(_ScoringPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTeamId = widget.innings.teamId;
    if (_lastInningsTeamId != null && _lastInningsTeamId != newTeamId) {
      // নতুন innings শুরু — সব extra/freeHit flag clear
      setState(() {
        _wide = false;
        _noBall = false;
        _bye = false;
        _legBye = false;
        _freeHit = false;
      });
    }
    _lastInningsTeamId = newTeamId;
  }

  @override
  void initState() {
    super.initState();
    _lastInningsTeamId = widget.innings.teamId;
  }

  void _addBall(int runs, {bool isWicket = false, String? dismissalType, String? fielderId, String? outBatsmanId}) {
    if (widget.innings.strikerBatsmanId == null) return;


    final isFreeHitNonRunOut = isWicket && _freeHit && dismissalType != 'Run Out';

    final isNoBallRunOut = isWicket && _noBall && dismissalType == 'Run Out';

    BallType type;
    if (isNoBallRunOut) {
      type = BallType.noBall;
    } else if (isWicket && !isFreeHitNonRunOut) {
      type = BallType.wicket;
    } else if (_noBall) {
      type = BallType.noBall;
    } else if (_wide) {
      type = BallType.wide;
    } else if (_bye) {
      type = BallType.bye;
    } else if (_legBye) {
      type = BallType.legBye;
    } else {
      type = BallType.normal;
    }


    final effectiveIsWicket = isWicket && !isFreeHitNonRunOut && !isNoBallRunOut;
    final currentFreeHit = _freeHit;
    final currentNoBall = _noBall;

    final innings = widget.innings;
    final over =
        '${innings.completedOvers}.${innings.ballsInCurrentOver + 1}';

    // Run Out এ outBatsmanId use করো, বাকি সব এ striker
    final effectiveBatsmanId = (dismissalType == 'Run Out' && outBatsmanId != null)
        ? outBatsmanId
        : innings.strikerBatsmanId;

    final event = BallEvent(
      type: type,
      runs: runs,
      dismissalType: (effectiveIsWicket || isNoBallRunOut) ? dismissalType : null,
      fielderId: (effectiveIsWicket || isNoBallRunOut) ? fielderId : null,
      bowlerId: innings.currentBowlerId,
      batsmanId: effectiveBatsmanId,
      overNumber: over,
      isFreeHit: currentFreeHit,
    );

    final prevLegalBalls = innings.totalBalls;
    widget.provider.addBall(event);
    if (widget.provider.lastMilestone != null) {
      widget.onMilestone(widget.provider.lastMilestone!);
      widget.provider.clearMilestone();
    }

    setState(() {
      _wide = false;
      _bye = false;
      _legBye = false;

      final isIllegal = type == BallType.wide || type == BallType.noBall;
      _freeHit = currentNoBall || (currentFreeHit && isIllegal);
      _noBall = false;
    });

    final isLegal = type != BallType.wide && type != BallType.noBall;

    // over শেষ check — addBall এর পর totalBalls দিয়ে check করো
    // prevLegalBalls + 1 এর বদলে addBall এর পরের actual value ব্যবহার করো
    final updatedInnings = widget.provider.currentInnings;
    final overJustEnded = isLegal &&
        updatedInnings != null &&
        updatedInnings.totalBalls % 6 == 0 &&
        updatedInnings.totalBalls > 0;

    if (isNoBallRunOut || effectiveIsWicket) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onWicket(showBowlerAfter: overJustEnded, outBatsmanId: effectiveBatsmanId);
      });
      return;
    }

    if (overJustEnded) {
      setState(() => _freeHit = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onOverEnd();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(children: [
        // Free Hit badge
        if (_freeHit)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('⚡ FREE HIT ',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ExtraChip('Wide', _wide, (v) => setState(() {
                _wide = v;
                if (v) {
                  _noBall = false;
                  _bye = false;
                  _legBye = false;
                }
              })),
              _ExtraChip('No Ball', _noBall, (v) => setState(() {
                _noBall = v;
                if (v) {
                  _wide = false;
                  _bye = false;
                  _legBye = false;
                }
              })),
              _ExtraChip('Bye', _bye, (v) => setState(() {
                _bye = v;
                if (v) {
                  _wide = false;
                  _noBall = false;
                  _legBye = false;
                }
              })),
              _ExtraChip('Leg Bye', _legBye, (v) => setState(() {
                _legBye = v;
                if (v) {
                  _wide = false;
                  _noBall = false;
                  _bye = false;
                }
              })),
            ]),
        const SizedBox(height: 12),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final r in [0, 1, 2, 3, 4, 5, 6])
                _RunButton(
                  label: '$r',
                  color: r == 4
                      ? Colors.blue
                      : r == 6
                      ? Colors.purple
                      : AppTheme.primary,
                  onTap: () => _addBall(r),
                ),
            ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding:
                  const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.close),
              label: const Text('Wicket',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showDismissalDialog(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.people,
                  color: AppTheme.primary),
              label: const Text("P'ship",
                  style: TextStyle(color: AppTheme.primary)),
              onPressed: () =>
                  _showPartnershipsSheet(context),
            ),
          ),
        ]),
      ]),
    );
  }

  void _showDismissalDialog() {
    final match = widget.match;
    final innings = widget.innings;
    final provider = widget.provider;

    final bowlingTeamId = innings.teamId == match.hostTeamId
        ? match.visitorTeamId
        : match.hostTeamId;
    final fieldingPlayers = provider.getTeamPlayersForMatch(bowlingTeamId, match);


    final types = (_noBall || _freeHit)
        ? ['Run Out']
        : ['Bowled', 'Caught', 'LBW', 'Run Out', 'Stumped', 'Hit Wicket', 'Retired'];
    String selected = types[0];
    String? catchFielderId;
    String? runOutFielderId;
    String? stumpedFielderId;
    // Run Out এ কোন batsman out — striker বা non-striker
    String? runOutBatsmanId = innings.strikerBatsmanId; // default striker

    bool needsFielder(String t) => t == 'Caught' || t == 'Run Out' || t == 'Stumped';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) {
          String? currentFielderId = selected == 'Caught'
              ? catchFielderId
              : selected == 'Run Out'
              ? runOutFielderId
              : selected == 'Stumped'
              ? stumpedFielderId
              : null;

          return AlertDialog(
            title: Text('Dismissal Info',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: Colors.red)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ...types.map((t) => RadioListTile<String>(
                  dense: true,
                  title: Text(t, style: const TextStyle(fontSize: 14)),
                  value: t,
                  groupValue: selected,
                  activeColor: Colors.red,
                  onChanged: (v) => setS(() => selected = v!),
                )),


                if (needsFielder(selected)) ...[
                  const Divider(),
                  Text(
                    selected == 'Caught'
                        ? 'Caught by'
                        : selected == 'Run Out'
                        ? 'Run out by'
                        : 'Stumped by',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.primary),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Fielder',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    value: currentFielderId,
                    items: fieldingPlayers
                        .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        )))
                        .toList(),
                    onChanged: (v) => setS(() {
                      if (selected == 'Caught') catchFielderId = v;
                      if (selected == 'Run Out') runOutFielderId = v;
                      if (selected == 'Stumped') stumpedFielderId = v;
                    }),
                  ),
                  // Run Out এ কোন batsman out সেটা select করো
                  if (selected == 'Run Out') ...[
                    const SizedBox(height: 12),
                    Text('Out Batsman',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.red)),
                    const SizedBox(height: 8),
                    // Striker
                    GestureDetector(
                      onTap: () => setS(() => runOutBatsmanId = innings.strikerBatsmanId),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: runOutBatsmanId == innings.strikerBatsmanId
                              ? Colors.red.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: runOutBatsmanId == innings.strikerBatsmanId
                                ? Colors.red
                                : Colors.grey.shade300,
                            width: runOutBatsmanId == innings.strikerBatsmanId ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.sports_cricket,
                              size: 16,
                              color: runOutBatsmanId == innings.strikerBatsmanId
                                  ? Colors.red : Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            provider.getPlayerById(innings.strikerBatsmanId ?? '', match)?.name ?? 'Striker',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: runOutBatsmanId == innings.strikerBatsmanId
                                  ? Colors.red : AppTheme.textPrimary,
                            ),
                          )),
                          Text('Striker',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              )),
                          if (runOutBatsmanId == innings.strikerBatsmanId)
                            const Icon(Icons.check_circle, size: 18, color: Colors.red),
                        ]),
                      ),
                    ),
                    // Non-Striker
                    GestureDetector(
                      onTap: () => setS(() => runOutBatsmanId = innings.nonStrikerBatsmanId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: runOutBatsmanId == innings.nonStrikerBatsmanId
                              ? Colors.red.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: runOutBatsmanId == innings.nonStrikerBatsmanId
                                ? Colors.red
                                : Colors.grey.shade300,
                            width: runOutBatsmanId == innings.nonStrikerBatsmanId ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.sports_cricket,
                              size: 16,
                              color: runOutBatsmanId == innings.nonStrikerBatsmanId
                                  ? Colors.red : Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            provider.getPlayerById(innings.nonStrikerBatsmanId ?? '', match)?.name ?? 'Non-Striker',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: runOutBatsmanId == innings.nonStrikerBatsmanId
                                  ? Colors.red : AppTheme.textPrimary,
                            ),
                          )),
                          Text('Non-Striker',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              )),
                          if (runOutBatsmanId == innings.nonStrikerBatsmanId)
                            const Icon(Icons.check_circle, size: 18, color: Colors.red),
                        ]),
                      ),
                    ),
                  ],
                ],
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  final fielderId = selected == 'Caught'
                      ? catchFielderId
                      : selected == 'Run Out'
                      ? runOutFielderId
                      : selected == 'Stumped'
                      ? stumpedFielderId
                      : null;

                  if (needsFielder(selected) && fielderId == null) {
                    ScaffoldMessenger.of(ctx2).showSnackBar(
                      SnackBar(
                        content: Text(
                          selected == 'Caught'
                              ? 'কে catch করেছে select করুন'
                              : selected == 'Run Out'
                              ? 'কে run out করেছে select করুন'
                              : 'কে stump করেছে select করুন',
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx2);
                  _addBall(0,
                      isWicket: true,
                      dismissalType: selected,
                      fielderId: fielderId,
                      outBatsmanId: selected == 'Run Out' ? runOutBatsmanId : null);
                },
                child: const Text('Confirm Wicket'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPartnershipsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _PartnershipsSheet(
          match: widget.match,
          innings: widget.innings,
          provider: widget.provider),
    );
  }
}

class _PartnershipsSheet extends StatelessWidget {
  final CricketMatch match;
  final Innings innings;
  final AppProvider provider;

  const _PartnershipsSheet(
      {required this.match,
        required this.innings,
        required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Partnerships',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...innings.partnerships.map((p) {
            final b1 =
            provider.getPlayerById(p.batsman1Id, match);
            final b2 =
            provider.getPlayerById(p.batsman2Id, match);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                    child: Text(
                        '${b1?.name ?? '-'} & ${b2?.name ?? '-'}')),
                Text('${p.runs} (${p.balls}b)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
              ]),
            );
          }),
          if (innings.partnerships.isEmpty)
            const Text('No partnerships yet'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MatchCompletedScreen extends StatelessWidget {
  final CricketMatch match;
  final AppProvider provider;

  const _MatchCompletedScreen(
      {required this.match, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Match Result')),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
          const SizedBox(height: 16),
          Text(match.resultDescription ?? 'Match Over',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Home'),
          ),
        ]),
      ),
    );
  }
}


class _PlayerDropdown extends StatelessWidget {
  final String label;
  final List<Player> players;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _PlayerDropdown({
    required this.label,
    required this.players,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true,
      value: value,
      items: players
          .map((p) => DropdownMenuItem(
        value: p.id,
        child: Text(
          p.name,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ExtraChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _ExtraChip(this.label, this.selected, this.onSelected);

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: selected ? Colors.white : Colors.black,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppTheme.primary,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? AppTheme.primary : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
    );
  }
}

class _RunButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RunButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable Dialogs — proper dispose সহ ──────────────────────────────────────

/// Player নাম edit করার dialog — controller properly dispose হয়
class _EditNameDialog extends StatefulWidget {
  final String initialName;
  final String title;
  final String label;
  final void Function(String name) onSave;

  const _EditNameDialog({
    required this.initialName,
    required this.onSave,
    this.title = 'Edit Name',
    this.label = 'Player Name',
  });

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
    content: TextField(
      controller: _ctrl,
      autofocus: true,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel')),
      ElevatedButton(
        onPressed: () {
          if (_ctrl.text.trim().isNotEmpty) {
            widget.onSave(_ctrl.text.trim());
            Navigator.pop(context);
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

/// Overs edit করার dialog — controller properly dispose হয়
class _EditOversDialog extends StatefulWidget {
  final int currentOvers;
  final void Function(int overs) onUpdate;

  const _EditOversDialog({
    required this.currentOvers,
    required this.onUpdate,
  });

  @override
  State<_EditOversDialog> createState() => _EditOversDialogState();
}

class _EditOversDialogState extends State<_EditOversDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentOvers.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Change Total Overs',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
    content: TextField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'New Overs Limit',
        hintText: 'Enter number of overs',
      ),
    ),
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel')),
      ElevatedButton(
        onPressed: () {
          final val = int.tryParse(_ctrl.text.trim());
          if (val != null && val > 0) {
            Navigator.pop(context);
            widget.onUpdate(val);
          }
        },
        child: const Text('Update'),
      ),
    ],
  );
}

/// Inline player add dialog (scoring screen এ) — controller properly dispose হয়
class _AddPlayerInlineDialog extends StatefulWidget {
  final String title;
  final void Function(String name) onAdd;

  const _AddPlayerInlineDialog({
    required this.title,
    required this.onAdd,
  });

  @override
  State<_AddPlayerInlineDialog> createState() => _AddPlayerInlineDialogState();
}

class _AddPlayerInlineDialogState extends State<_AddPlayerInlineDialog> {
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
    title: Text(widget.title),
    content: TextField(
      controller: _ctrl,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Player নাম'),
    ),
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('বাতিল')),
      ElevatedButton(
        onPressed: () {
          final name = _ctrl.text.trim();
          if (name.isEmpty) return;
          Navigator.pop(context);
          widget.onAdd(name);
        },
        child: const Text('Add'),
      ),
    ],
  );
}