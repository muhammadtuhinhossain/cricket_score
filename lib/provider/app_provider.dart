import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

const _uuid = Uuid();

class AppProvider extends ChangeNotifier {
  List<Team> _teams = [];
  List<CricketMatch> _matches = [];
  CricketMatch? _activeMatch;

  late Box _box;

  List<Team> get teams => _teams;
  List<CricketMatch> get matches => _matches;
  CricketMatch? get activeMatch => _activeMatch;

  // Milestone notification
  String? lastMilestone;
  String? wicketMilestone;
  void clearMilestone() { lastMilestone = null; }
  void clearWicketMilestone() { wicketMilestone = null; }

  List<CricketMatch> get recentMatches =>
      _matches.where((m) => !m.isArchived).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<CricketMatch> get archivedMatches =>
      _matches.where((m) => m.isArchived).toList();

  Future<void> loadData() async {
    _box = await Hive.openBox('cricket_data');

    final teamsJson = _box.get('teams');
    final matchesJson = _box.get('matches');

    if (teamsJson != null) {
      final list = jsonDecode(teamsJson) as List;
      _teams = list.map((t) => Team.fromJson(t)).toList();
    }
    if (matchesJson != null) {
      final list = jsonDecode(matchesJson) as List;
      _matches = list.map((m) => CricketMatch.fromJson(m)).toList();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await _box.put('teams', jsonEncode(_teams.map((t) => t.toJson()).toList()));
    await _box.put('matches', jsonEncode(_matches.map((m) => m.toJson()).toList()));
  }


  bool updateMatchOvers(int newOvers) {
    if (_activeMatch == null) return false;

    _activeMatch!.totalOvers = newOvers;
    final match = _activeMatch!;
    final innings = match.currentInnings;

    bool inningsJustCompleted = false;

    if (innings != null) {
      final isFirstInnings = match.firstInnings != null &&
          !match.firstInnings!.isCompleted;
      final isSecondInnings = match.firstInnings != null &&
          match.firstInnings!.isCompleted &&
          match.secondInnings != null &&
          !match.secondInnings!.isCompleted;

      int maxLegalBalls = newOvers * 6;


      if (isFirstInnings && innings.totalBalls > maxLegalBalls) {
        int ballsToRemove = innings.totalBalls - maxLegalBalls;
        for (int i = 0; i < ballsToRemove; i++) {
          _undoBallFromInnings(match, innings);
        }
        _recalculateOverRunTotals(innings);
      }


      if (isSecondInnings) {
        final firstInnings = match.firstInnings!;
        final currentOvers = newOvers;


        if (innings.totalBalls > maxLegalBalls) {
          int ballsToRemove = innings.totalBalls - maxLegalBalls;
          for (int i = 0; i < ballsToRemove; i++) {
            _undoBallFromInnings(match, innings);
          }
          _recalculateOverRunTotals(innings);
        }


        if (firstInnings.totalBalls > maxLegalBalls) {
          int firstBallsToRemove = firstInnings.totalBalls - maxLegalBalls;
          for (int i = 0; i < firstBallsToRemove; i++) {
            _undoBallFromInnings(match, firstInnings);
          }
          _recalculateOverRunTotals(firstInnings);
        }
      }


      if (isFirstInnings && innings.totalBalls >= newOvers * 6 && !innings.isCompleted) {
        _completeInnings(match, innings);
        inningsJustCompleted = true;
      }


      if (isSecondInnings && innings.totalBalls >= newOvers * 6 && !innings.isCompleted) {
        _completeInnings(match, innings);
        inningsJustCompleted = true;
      }
    }

    _save();
    notifyListeners();
    return inningsJustCompleted;
  }


  void _undoBallFromInnings(CricketMatch match, Innings innings) {
    if (innings.ballEvents.isEmpty) return;

    final lastEvent = innings.ballEvents.removeLast();
    final allPlayers = _getAllPlayersForMatch(match);

    bool isLegal = lastEvent.type != BallType.wide &&
        lastEvent.type != BallType.noBall;

    switch (lastEvent.type) {
      case BallType.normal:
        final striker = _findPlayer(allPlayers, lastEvent.batsmanId ?? innings.strikerBatsmanId ?? '');
        final bowler = _findPlayer(allPlayers, lastEvent.bowlerId ?? innings.currentBowlerId ?? '');
        striker?.runs -= lastEvent.runs;
        striker?.balls--;
        if (lastEvent.runs == 4) striker?.fours--;
        if (lastEvent.runs == 6) striker?.sixes--;
        bowler?.runsConceded -= lastEvent.runs;
        innings.totalRuns -= lastEvent.runs;
        innings.totalBalls--;
        if (lastEvent.runs % 2 != 0) _swapBatsmen(innings);
        break;
      case BallType.wide:
        final bowler = _findPlayer(allPlayers, lastEvent.bowlerId ?? innings.currentBowlerId ?? '');
        bowler?.wides--;
        bowler?.runsConceded -= lastEvent.runs;
        innings.totalRuns -= lastEvent.runs;
        break;
      case BallType.noBall:
        final striker = _findPlayer(allPlayers, lastEvent.batsmanId ?? innings.strikerBatsmanId ?? '');
        final bowler = _findPlayer(allPlayers, lastEvent.bowlerId ?? innings.currentBowlerId ?? '');
        striker?.runs -= lastEvent.runs;
        if (lastEvent.runs > 0) striker?.balls--;
        bowler?.noBalls--;
        bowler?.runsConceded -= (lastEvent.runs + 1);
        innings.totalRuns -= (lastEvent.runs + 1);
        break;
      case BallType.bye:
        final striker = _findPlayer(allPlayers, lastEvent.batsmanId ?? innings.strikerBatsmanId ?? '');
        innings.totalRuns -= lastEvent.runs;
        innings.totalBalls--;
        striker?.balls--;
        if (lastEvent.runs % 2 != 0) _swapBatsmen(innings);
        break;
      case BallType.legBye:
        final striker = _findPlayer(allPlayers, lastEvent.batsmanId ?? innings.strikerBatsmanId ?? '');
        innings.totalRuns -= lastEvent.runs;
        innings.totalBalls--;
        striker?.balls--;
        if (lastEvent.runs % 2 != 0) _swapBatsmen(innings);
        break;
      case BallType.wicket:
        final striker = _findPlayer(allPlayers, lastEvent.batsmanId ?? innings.strikerBatsmanId ?? '');
        final bowler = _findPlayer(allPlayers, lastEvent.bowlerId ?? innings.currentBowlerId ?? '');
        striker?.isOut = false;
        striker?.dismissalInfo = null;
        striker?.balls--;
        bowler?.wickets--;
        bowler?.runsConceded -= lastEvent.runs;
        innings.totalRuns -= lastEvent.runs;

        final wasNoBallRunOut = !isLegal && lastEvent.dismissalType == 'Run Out';
        if (!wasNoBallRunOut) innings.totalBalls--;
        innings.wickets--;
        if (innings.fallenWickets.isNotEmpty) innings.fallenWickets.removeLast();
        break;
    }

    if (isLegal && innings.overRunTotals.isNotEmpty &&
        innings.totalBalls % 6 == 0) {
      innings.overRunTotals.removeLast();
    }
  }


  void _recalculateOverRunTotals(Innings innings) {
    innings.overRunTotals.clear();
    int legalBalls = 0;
    int cumRuns = 0;
    for (final b in innings.ballEvents) {
      final isLegal = b.type != BallType.wide && b.type != BallType.noBall;

      if (b.type == BallType.noBall) {
        cumRuns += b.runs + 1;
      } else {
        cumRuns += b.runs;
      }
      if (isLegal) {
        legalBalls++;
        if (legalBalls % 6 == 0) {
          innings.overRunTotals.add(cumRuns);
        }
      }
    }
  }

  Team createTeam(String name, List<String> playerNames) {
    final team = Team(
      id: _uuid.v4(),
      name: name,
      players: playerNames
          .where((n) => n.trim().isNotEmpty)
          .map((n) => Player(id: _uuid.v4(), name: n.trim()))
          .toList(),
    );
    _teams.add(team);
    _save();
    notifyListeners();
    return team;
  }

  void updateTeam(String teamId, String newName) {
    final idx = _teams.indexWhere((t) => t.id == teamId);
    if (idx >= 0) {
      _teams[idx].name = newName;
      _save();
      notifyListeners();
    }
  }

  void addPlayerToTeam(String teamId, String playerName) {
    final team = _teams.firstWhere((t) => t.id == teamId);
    team.players.add(Player(id: _uuid.v4(), name: playerName.trim()));
    _save();
    notifyListeners();
  }

  void removePlayerFromTeam(String teamId, int playerIndex) {
    final team = _teams.firstWhere((t) => t.id == teamId);
    if (playerIndex < 0 || playerIndex >= team.players.length) return;
    team.players.removeAt(playerIndex);
    _save();
    notifyListeners();
  }

  void deleteTeam(String teamId) {
    _teams.removeWhere((t) => t.id == teamId);
    _save();
    notifyListeners();
  }

  Team? getTeam(String id) {
    try { return _teams.firstWhere((t) => t.id == id); }
    catch (_) { return null; }
  }

  CricketMatch createMatch({
    required String hostTeamName,
    required String visitorTeamName,
    required List<String> hostPlayerNames,
    required List<String> visitorPlayerNames,
    required MatchFormat format,
    required int totalOvers,
    required String tossWonBy,
    required TossDecision tossDecision,
  }) {
    Team hostTeam = _getOrCreateTeam(hostTeamName, hostPlayerNames);
    Team visitorTeam = _getOrCreateTeam(visitorTeamName, visitorPlayerNames);

    String firstBattingTeamId;
    if (tossWonBy == 'host') {
      firstBattingTeamId = tossDecision == TossDecision.bat
          ? hostTeam.id : visitorTeam.id;
    } else {
      firstBattingTeamId = tossDecision == TossDecision.bat
          ? visitorTeam.id : hostTeam.id;
    }

    final freshHostPlayers = hostTeam.players
        .map((p) => Player(id: p.id, name: p.name))
        .toList();
    final freshVisitorPlayers = visitorTeam.players
        .map((p) => Player(id: p.id, name: p.name))
        .toList();

    final match = CricketMatch(
      id: _uuid.v4(),
      hostTeamId: hostTeam.id,
      visitorTeamId: visitorTeam.id,
      format: format,
      totalOvers: totalOvers,
      tossWonByTeamId: tossWonBy == 'host' ? hostTeam.id : visitorTeam.id,
      tossDecision: tossDecision,
      status: MatchStatus.inProgress,
      firstInnings: Innings(teamId: firstBattingTeamId),
      tempHostPlayers: freshHostPlayers,
      tempVisitorPlayers: freshVisitorPlayers,
    );

    _matches.add(match);
    _activeMatch = match;
    _save();
    notifyListeners();
    return match;
  }

  Team _getOrCreateTeam(String name, List<String> playerNames) {
    try {
      return _teams.firstWhere(
              (t) => t.name.toLowerCase() == name.toLowerCase());
    } catch (_) {
      return createTeam(name, playerNames);
    }
  }

  void setActiveMatch(CricketMatch match) {
    _activeMatch = match;
    notifyListeners();
  }

  void initInnings({
    required String strikerBatsmanId,
    required String nonStrikerBatsmanId,
    required String bowlerId,
  }) {
    final innings = _activeMatch!.currentInnings!;
    innings.strikerBatsmanId = strikerBatsmanId;
    innings.nonStrikerBatsmanId = nonStrikerBatsmanId;
    innings.currentBowlerId = bowlerId;
    innings.battingOrder.addAll([strikerBatsmanId, nonStrikerBatsmanId]);
    innings.bowlingOrder.add(bowlerId);
    innings.partnerships.add(Partnership(
      batsman1Id: strikerBatsmanId,
      batsman2Id: nonStrikerBatsmanId,
    ));
    _save();
    notifyListeners();
  }

  void addBall(BallEvent event) {
    final match = _activeMatch!;
    final innings = match.currentInnings!;
    final allPlayers = _getAllPlayersForMatch(match);

    innings.ballEvents.add(event);

    final striker = _findPlayer(allPlayers, innings.strikerBatsmanId!);
    final bowler = _findPlayer(allPlayers, innings.currentBowlerId!);
    final currentPartnership = innings.partnerships.isNotEmpty
        ? innings.partnerships.last : null;

    bool isLegalBall = event.type != BallType.wide &&
        event.type != BallType.noBall;

    switch (event.type) {
      case BallType.normal:
        final prevRuns = striker?.runs ?? 0;
        striker?.runs += event.runs;
        striker?.balls++;
        if (event.runs == 4) striker?.fours++;
        if (event.runs == 6) striker?.sixes++;
        bowler?.runsConceded += event.runs;
        innings.totalRuns += event.runs;
        innings.totalBalls++;
        currentPartnership?.runs += event.runs;
        currentPartnership?.balls++;
        if (event.runs % 2 != 0) _swapBatsmen(innings);

        final newRuns = striker?.runs ?? 0;
        final name = striker?.name ?? '';
        if (prevRuns < 50 && newRuns >= 50 && newRuns < 100) {
          lastMilestone = '$name scored a 50';
        } else if (prevRuns < 100 && newRuns >= 100) {
          lastMilestone = '$name scored a 100';
        }
        break;

      case BallType.wide:
        bowler?.wides++;
        bowler?.runsConceded += event.runs;
        innings.totalRuns += event.runs;
        break;

      case BallType.noBall:

        if (event.dismissalType == 'Run Out') {
          striker?.isOut = true;
          final fielderName = event.fielderId != null
              ? _findPlayer(allPlayers, event.fielderId!)?.name
              : null;
          striker?.dismissalInfo = fielderName != null
              ? 'run out ($fielderName)'
              : 'run out';
          bowler?.noBalls++;
          bowler?.runsConceded += (event.runs + 1);
          innings.totalRuns += (event.runs + 1);
          innings.wickets++;
          innings.fallenWickets.add('${innings.totalRuns}/${innings.wickets}');

        } else {
          striker?.runs += event.runs;
          if (event.runs > 0) striker?.balls++;
          bowler?.noBalls++;
          bowler?.runsConceded += (event.runs + 1);
          innings.totalRuns += (event.runs + 1);
        }
        break;

      case BallType.bye:
        innings.totalRuns += event.runs;
        innings.totalBalls++;
        currentPartnership?.runs += event.runs;
        currentPartnership?.balls++;
        striker?.balls++;
        if (event.runs % 2 != 0) _swapBatsmen(innings);
        break;

      case BallType.legBye:
        innings.totalRuns += event.runs;
        innings.totalBalls++;
        currentPartnership?.runs += event.runs;
        currentPartnership?.balls++;
        striker?.balls++;
        if (event.runs % 2 != 0) _swapBatsmen(innings);
        break;

      case BallType.wicket:
        striker?.balls++;
        striker?.isOut = true;


        final allPlayers2 = _getAllPlayersForMatch(match);
        final fielderName = event.fielderId != null
            ? _findPlayer(allPlayers2, event.fielderId!)?.name
            : null;
        final bowlerName = bowler?.name ?? '';
        final dtype = event.dismissalType ?? 'out';

        String dismissalStr;
        switch (dtype) {
          case 'Bowled':
            dismissalStr = 'b $bowlerName';
            break;
          case 'Caught':
            if (fielderName != null) {
              dismissalStr = fielderName == bowlerName
                  ? 'c & b $bowlerName'
                  : 'c $fielderName b $bowlerName';
            } else {
              dismissalStr = 'c ? b $bowlerName';
            }
            break;
          case 'LBW':
            dismissalStr = 'lbw b $bowlerName';
            break;
          case 'Run Out':
            dismissalStr = fielderName != null
                ? 'run out ($fielderName)'
                : 'run out';
            break;
          case 'Stumped':
            dismissalStr = fielderName != null
                ? 'st $fielderName b $bowlerName'
                : 'st ? b $bowlerName';
            break;
          case 'Hit Wicket':
            dismissalStr = 'hit wkt b $bowlerName';
            break;
          case 'Retired':
            dismissalStr = 'retired out';
            break;
          default:
            dismissalStr = dtype;
        }

        striker?.dismissalInfo = dismissalStr;
        final prevWickets = bowler?.wickets ?? 0;
        bowler?.wickets++;
        bowler?.runsConceded += event.runs;
        innings.totalRuns += event.runs;

        final isNoBallRunOut = !isLegalBall && dtype == 'Run Out';
        if (!isNoBallRunOut) innings.totalBalls++;
        innings.wickets++;
        innings.fallenWickets.add('${innings.totalRuns}/${innings.wickets}');

        final newWickets = bowler?.wickets ?? 0;
        final bowlerName2 = bowler?.name ?? '';
        if (prevWickets == 2 && newWickets == 3) {
          wicketMilestone = 'HAT-TRICK! $bowlerName2';
        }
        break;
    }

    if (isLegalBall && innings.totalBalls % 6 == 0) {
      innings.overRunTotals.add(innings.totalRuns);
      _calculateMaidens(innings, bowler);
      _swapBatsmen(innings);
    }

    bool oversCompleted = innings.totalBalls >= match.totalOvers * 6;


    final battingTeamPlayers = getTeamPlayersForMatch(innings.teamId, match);
    final maxWickets = (battingTeamPlayers.length - 1).clamp(1, battingTeamPlayers.length);
    bool allOut = innings.wickets >= maxWickets;


    bool targetChased = false;
    if (match.firstInnings != null &&
        match.firstInnings!.isCompleted &&
        match.secondInnings != null &&
        innings.teamId == match.secondInnings!.teamId) {
      final target = match.firstInnings!.totalRuns + 1;
      targetChased = innings.totalRuns >= target;
    }

    if (oversCompleted || allOut || targetChased) {
      _completeInnings(match, innings);
    }

    _save();
    notifyListeners();
  }

  void _swapBatsmen(Innings innings) {
    final tmp = innings.strikerBatsmanId;
    innings.strikerBatsmanId = innings.nonStrikerBatsmanId;
    innings.nonStrikerBatsmanId = tmp;
  }

  void _calculateMaidens(Innings innings, Player? bowler) {
    if (bowler == null) return;
    final bowlerBalls = innings.ballEvents
        .where((b) => b.bowlerId == bowler.id &&
        b.type != BallType.wide && b.type != BallType.noBall)
        .toList();
    if (bowlerBalls.length >= 6) {
      final lastOver = bowlerBalls.sublist(bowlerBalls.length - 6);
      final overRuns = lastOver.fold<int>(0, (s, b) => s + b.runs);
      if (overRuns == 0) bowler.maidens++;
    }
    bowler.oversBowled++;
  }

  void _completeInnings(CricketMatch match, Innings innings) {
    innings.isCompleted = true;

    if (match.firstInnings != null && match.firstInnings!.isCompleted &&
        match.secondInnings == null) {
      final secondTeamId = match.firstInnings!.teamId == match.hostTeamId
          ? match.visitorTeamId : match.hostTeamId;
      match.secondInnings = Innings(teamId: secondTeamId);
    } else if (match.secondInnings != null &&
        match.secondInnings!.isCompleted) {
      _calculateResult(match);
    }
  }

  void _calculateResult(CricketMatch match) {
    match.status = MatchStatus.completed;
    final first = match.firstInnings!;
    final second = match.secondInnings!;

    final firstTeam = getTeam(first.teamId);
    final secondTeam = getTeam(second.teamId);

    if (second.totalRuns > first.totalRuns) {
      final secondTeamPlayers = getTeamPlayersForMatch(second.teamId, match);
      final maxWickets2 = (secondTeamPlayers.length - 1).clamp(1, secondTeamPlayers.length);
      final wicketsLeft = maxWickets2 - second.wickets;
      match.resultDescription =
      '${secondTeam?.name ?? 'Team'} won by $wicketsLeft wickets';
      _updateTeamStats(second.teamId, won: true);
      _updateTeamStats(first.teamId, won: false);
    } else if (first.totalRuns > second.totalRuns) {
      final diff = first.totalRuns - second.totalRuns;
      match.resultDescription =
      '${firstTeam?.name ?? 'Team'} won by $diff runs';
      _updateTeamStats(first.teamId, won: true);
      _updateTeamStats(second.teamId, won: false);
    } else {
      match.resultDescription = 'Match Tied';
    }
  }

  void _updateTeamStats(String teamId, {required bool won}) {
    final idx = _teams.indexWhere((t) => t.id == teamId);
    if (idx >= 0) {
      _teams[idx].matchesPlayed++;
      if (won) _teams[idx].won++; else _teams[idx].lost++;
    }
  }

  void renameTempPlayer(String playerId, String newName, CricketMatch match) {
    final all = _getAllPlayersForMatch(match);
    final p = _findPlayer(all, playerId);
    if (p != null) p.name = newName;
    _save();
    notifyListeners();
  }

  void setNonStriker(String playerId) {
    final innings = _activeMatch!.currentInnings!;
    innings.nonStrikerBatsmanId = playerId;
    if (!innings.battingOrder.contains(playerId)) {
      innings.battingOrder.add(playerId);
    }
    _save();
    notifyListeners();
  }

  void swapBatsmen() {
    final innings = _activeMatch?.currentInnings;
    if (innings == null) return;
    _swapBatsmen(innings);
    _save();
    notifyListeners();
  }

  void setNextBatsman(String playerId) {
    final innings = _activeMatch!.currentInnings!;
    innings.strikerBatsmanId = playerId;
    if (!innings.battingOrder.contains(playerId)) {
      innings.battingOrder.add(playerId);
    }

    final nonStriker = innings.nonStrikerBatsmanId;
    if (nonStriker != null) {
      innings.partnerships.add(Partnership(
        batsman1Id: playerId,
        batsman2Id: nonStriker,
      ));
    }
    _save();
    notifyListeners();
  }

  void setNewBowler(String bowlerId) {
    final innings = _activeMatch!.currentInnings!;
    innings.currentBowlerId = bowlerId;
    if (!innings.bowlingOrder.contains(bowlerId)) {
      innings.bowlingOrder.add(bowlerId);
    }
    _save();
    notifyListeners();
  }

  void undoLastBall() {
    final match = _activeMatch;
    if (match == null) return;
    final innings = match.currentInnings;
    if (innings == null || innings.ballEvents.isEmpty) return;

    final lastEvent = innings.ballEvents.removeLast();
    final allPlayers = _getAllPlayersForMatch(match);

    bool isLegal = lastEvent.type != BallType.wide &&
        lastEvent.type != BallType.noBall;

    switch (lastEvent.type) {
      case BallType.normal:
        final striker = _findPlayer(allPlayers, innings.strikerBatsmanId!);
        final bowler = _findPlayer(allPlayers, innings.currentBowlerId!);
        striker?.runs -= lastEvent.runs;
        striker?.balls--;
        if (lastEvent.runs == 4) striker?.fours--;
        if (lastEvent.runs == 6) striker?.sixes--;
        bowler?.runsConceded -= lastEvent.runs;
        innings.totalRuns -= lastEvent.runs;
        innings.totalBalls--;
        if (lastEvent.runs % 2 != 0) _swapBatsmen(innings);
        break;
      case BallType.wide:
        final bowler = _findPlayer(allPlayers, innings.currentBowlerId!);
        bowler?.wides--;
        bowler?.runsConceded -= lastEvent.runs;
        innings.totalRuns -= lastEvent.runs;
        break;
      case BallType.noBall:
        final striker = _findPlayer(allPlayers, innings.strikerBatsmanId!);
        final bowler = _findPlayer(allPlayers, innings.currentBowlerId!);
        striker?.runs -= lastEvent.runs;
        if (lastEvent.runs > 0) striker?.balls--;
        bowler?.noBalls--;
        bowler?.runsConceded -= (lastEvent.runs + 1);
        innings.totalRuns -= (lastEvent.runs + 1);
        break;
      case BallType.bye:
        final striker = _findPlayer(allPlayers, innings.strikerBatsmanId!);
        innings.totalRuns -= lastEvent.runs;
        innings.totalBalls--;
        striker?.balls--;
        if (lastEvent.runs % 2 != 0) _swapBatsmen(innings);
        break;
      case BallType.legBye:
        final striker = _findPlayer(allPlayers, innings.strikerBatsmanId!);
        innings.totalRuns -= lastEvent.runs;
        innings.totalBalls--;
        striker?.balls--;
        if (lastEvent.runs % 2 != 0) _swapBatsmen(innings);
        break;
      case BallType.wicket:
        final striker = _findPlayer(allPlayers, innings.strikerBatsmanId!);
        final bowler = _findPlayer(allPlayers, innings.currentBowlerId!);
        striker?.isOut = false;
        striker?.dismissalInfo = null;
        striker?.balls--;
        bowler?.wickets--;
        bowler?.runsConceded -= lastEvent.runs;
        innings.totalRuns -= lastEvent.runs;

        final wasNoBallRunOut = !isLegal && lastEvent.dismissalType == 'Run Out';
        if (!wasNoBallRunOut) innings.totalBalls--;
        innings.wickets--;
        if (innings.fallenWickets.isNotEmpty) innings.fallenWickets.removeLast();
        break;
    }

    if (isLegal && innings.overRunTotals.isNotEmpty &&
        innings.totalBalls % 6 == 0) {
      innings.overRunTotals.removeLast();
    }

    _save();
    notifyListeners();
  }

  void archiveMatch(String matchId) {
    final idx = _matches.indexWhere((m) => m.id == matchId);
    if (idx >= 0) {
      _matches[idx].isArchived = true;
      _save();
      notifyListeners();
    }
  }

  void deleteMatch(String matchId) {
    _matches.removeWhere((m) => m.id == matchId);
    if (_activeMatch?.id == matchId) _activeMatch = null;
    _save();
    notifyListeners();
  }

  List<Player> _getAllPlayersForMatch(CricketMatch match) {
    return [
      ...match.tempHostPlayers,
      ...match.tempVisitorPlayers,
    ];
  }

  List<Player> getAllPlayersForMatch(CricketMatch match) =>
      _getAllPlayersForMatch(match);

  Player? _findPlayer(List<Player> players, String id) {
    try { return players.firstWhere((p) => p.id == id); }
    catch (_) { return null; }
  }

  Player? getPlayerById(String id, CricketMatch match) {
    return _findPlayer(_getAllPlayersForMatch(match), id);
  }

  List<Player> getTeamPlayersForMatch(String teamId, CricketMatch match) {
    if (teamId == match.hostTeamId) {
      return match.tempHostPlayers;
    } else {
      return match.tempVisitorPlayers;
    }
  }

  String addTempPlayer(String name, String teamId, CricketMatch match) {
    final player = Player(id: _uuid.v4(), name: name.trim());
    if (teamId == match.hostTeamId) {
      match.tempHostPlayers.add(player);
    } else {
      match.tempVisitorPlayers.add(player);
    }
    _save();
    notifyListeners();
    return player.id;
  }

  double getWinProbability(CricketMatch match) {
    if (match.secondInnings == null) return 0.5;
    final target = (match.firstInnings?.totalRuns ?? 0) + 1;
    final innings2 = match.secondInnings!;
    final runsNeeded = target - innings2.totalRuns;
    final ballsLeft = (match.totalOvers * 6) - innings2.totalBalls;
    final batting2Players = getTeamPlayersForMatch(innings2.teamId, match);

    final maxWickets2 = (batting2Players.length - 1).clamp(1, batting2Players.length);
    final wicketsLeft = maxWickets2 - innings2.wickets;
    if (ballsLeft <= 0 || runsNeeded <= 0) {
      return innings2.totalRuns >= target ? 1.0 : 0.0;
    }
    final rrRequired = runsNeeded / (ballsLeft / 6);
    final currentRR = innings2.runRate;
    final factor = currentRR / (rrRequired == 0 ? 1 : rrRequired);
    final wicketFactor = wicketsLeft / batting2Players.length;
    final prob = (factor * 0.6 + wicketFactor * 0.4).clamp(0.05, 0.95);
    return prob;
  }
}