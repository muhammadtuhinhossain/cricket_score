import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../models/tournament_models.dart';

const _uuid = Uuid();


class PlayerMatchStat {
  final String playerId;
  final String teamId;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final int wickets;
  final int runsConceded;
  final int oversBowled;

  PlayerMatchStat({
    required this.playerId,
    required this.teamId,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.wickets,
    required this.runsConceded,
    required this.oversBowled,
  });
}

class TournamentProvider extends ChangeNotifier {
  List<Tournament> _tournaments = [];

  late Box _box;

  List<Tournament> get tournaments => _tournaments;

  List<Tournament> get activeTournaments => _tournaments
      .where((t) => t.status != TournamentStatus.completed)
      .toList();

  List<Tournament> get completedTournaments =>
      _tournaments.where((t) => t.status == TournamentStatus.completed).toList();


  Future<void> loadData() async {
    _box = await Hive.openBox('tournament_data');
    final json = _box.get('tournaments');
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        _tournaments = list.map((t) => Tournament.fromJson(t)).toList();
      } catch (_) {
        _tournaments = [];
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await _box.put(
        'tournaments',
        jsonEncode(_tournaments.map((t) => t.toJson()).toList()));
  }

  void _saveAsync() {
    Future.microtask(() => _save());
  }


  Tournament createTournament({
    required String name,
    required List<String> teamIds,
    required int teamsPerGroup,
    required int totalOvers,
    required String format,
  }) {
    final tournament = Tournament(
      id: _uuid.v4(),
      name: name,
      teamIds: teamIds,
      teamsPerGroup: teamsPerGroup,
      totalOvers: totalOvers,
      format: format,
      status: TournamentStatus.groupStage,
    );

    // Assign teams to groups
    for (int i = 0; i < teamIds.length; i++) {
      final groupIdx = i ~/ teamsPerGroup;
      final groupName = String.fromCharCode(65 + groupIdx);
      tournament.tournamentTeams.add(TournamentTeam(
        teamId: teamIds[i],
        groupName: groupName,
      ));
    }

    // Generate round-robin group matches
    _generateGroupMatches(tournament);

    _tournaments.add(tournament);
    _saveAsync();
    notifyListeners();
    return tournament;
  }

  void _generateGroupMatches(Tournament tournament) {
    for (final groupName in tournament.groupNames) {
      final groupTeams = tournament.tournamentTeams
          .where((t) => t.groupName == groupName)
          .toList();

      for (int i = 0; i < groupTeams.length; i++) {
        for (int j = i + 1; j < groupTeams.length; j++) {
          tournament.matches.add(TournamentMatch(
            matchId: _uuid.v4(),
            team1Id: groupTeams[i].teamId,
            team2Id: groupTeams[j].teamId,
            stage: 'group',
            groupName: groupName,
          ));
        }
      }
    }
  }

  // ── Update teams & groups ─────

  void updateTournamentTeamsAndGroups({
    required String tournamentId,
    required Map<String, String> teamGroupMap,
    required List<String> allTeamIds,
  }) {
    final tournament = _tournaments.firstWhere((t) => t.id == tournamentId);

    // ── TeamIds update ──
    tournament.teamIds
      ..clear()
      ..addAll(allTeamIds);


    final oldTeamMap = {for (final t in tournament.tournamentTeams) t.teamId: t};

    tournament.tournamentTeams.clear();
    for (final entry in teamGroupMap.entries) {
      final teamId = entry.key;
      final groupName = entry.value;

      if (oldTeamMap.containsKey(teamId)) {

        final old = oldTeamMap[teamId]!;
        old.groupName = groupName;
        tournament.tournamentTeams.add(old);
      } else {

        tournament.tournamentTeams.add(TournamentTeam(
          teamId: teamId,
          groupName: groupName,
        ));
      }
    }


    tournament.matches.removeWhere((m) => m.stage == 'group' && !m.isCompleted);


    final existingPairs = <String>{};
    for (final m in tournament.matches) {
      if (m.stage == 'group') {
        final key1 = '${m.team1Id}|${m.team2Id}';
        final key2 = '${m.team2Id}|${m.team1Id}';
        existingPairs.add(key1);
        existingPairs.add(key2);
      }
    }


    final groupNames = teamGroupMap.values.toSet().toList()..sort();

    for (final groupName in groupNames) {
      final groupTeamIds = teamGroupMap.entries
          .where((e) => e.value == groupName)
          .map((e) => e.key)
          .toList();

      for (int i = 0; i < groupTeamIds.length; i++) {
        for (int j = i + 1; j < groupTeamIds.length; j++) {
          final t1 = groupTeamIds[i];
          final t2 = groupTeamIds[j];
          final pairKey = '$t1|$t2';


          if (existingPairs.contains(pairKey)) continue;

          tournament.matches.add(TournamentMatch(
            matchId: _uuid.v4(),
            team1Id: t1,
            team2Id: t2,
            stage: 'group',
            groupName: groupName,
          ));
        }
      }
    }

    _saveAsync();
    notifyListeners();
  }

  // ── Link Cricket match ─────────
  void linkCricketMatch({
    required String tournamentId,
    required String tournamentMatchId,
    required String cricketMatchId,
  }) {
    final tournament =
    _tournaments.firstWhere((t) => t.id == tournamentId);
    final tMatch = tournament.matches
        .firstWhereOrNull((m) => m.matchId == tournamentMatchId);
    if (tMatch != null) {
      tMatch.cricketMatchId = cricketMatchId;
    }
    _saveAsync();
    notifyListeners();
  }

  // ── Record Result ───
  void recordMatchResult({
    required String tournamentId,
    required String tournamentMatchId,
    required String winnerId,
    required String loserId,
    required int winnerRuns,
    required int winnerBalls,
    required int loserRuns,
    required int loserBalls,
    required bool isTie,
    String? manOfTheMatch,
    required List<PlayerMatchStat> playerMatchStats,
  }) {
    final tournament =
    _tournaments.firstWhere((t) => t.id == tournamentId);
    final tMatch = tournament.matches
        .firstWhere((m) => m.matchId == tournamentMatchId);

    tMatch.isCompleted = true;
    tMatch.winnerId = isTie ? null : winnerId;
    tMatch.manOfTheMatch = manOfTheMatch;

    // Update group standings
    if (tMatch.stage == 'group') {
      final winnerTeam = tournament.tournamentTeams
          .firstWhere((t) => t.teamId == winnerId, orElse: () {
        return TournamentTeam(teamId: winnerId, groupName: '');
      });
      final loserTeam = tournament.tournamentTeams
          .firstWhere((t) => t.teamId == loserId, orElse: () {
        return TournamentTeam(teamId: loserId, groupName: '');
      });

      winnerTeam.played++;
      loserTeam.played++;

      if (isTie) {
        winnerTeam.tied++;
        loserTeam.tied++;
        winnerTeam.points += 1;
        loserTeam.points += 1;
      } else {
        winnerTeam.won++;
        loserTeam.lost++;
        winnerTeam.points += 2;
      }

      winnerTeam.runsFor += winnerRuns;
      winnerTeam.ballsFor += winnerBalls;
      winnerTeam.runsAgainst += loserRuns;
      winnerTeam.ballsAgainst += loserBalls;

      loserTeam.runsFor += loserRuns;
      loserTeam.ballsFor += loserBalls;
      loserTeam.runsAgainst += winnerRuns;
      loserTeam.ballsAgainst += winnerBalls;
    }

    // Update player stats
    for (final ps in playerMatchStats) {
      PlayerTournamentStats? existing =
      tournament.playerStats.firstWhereOrNull((s) => s.playerId == ps.playerId);

      if (existing == null) {
        existing = PlayerTournamentStats(
          playerId: ps.playerId,
          teamId: ps.teamId,
        );
        tournament.playerStats.add(existing);
      }

      existing.totalRuns += ps.runs;
      existing.totalBalls += ps.balls;
      existing.totalFours += ps.fours;
      existing.totalSixes += ps.sixes;
      if (ps.balls > 0) existing.innings++;
      if (ps.runs > existing.highScore) existing.highScore = ps.runs;
      existing.totalWickets += ps.wickets;
      existing.totalRunsConceded += ps.runsConceded;
      existing.totalOversBowled += ps.oversBowled;

      if (manOfTheMatch == ps.playerId) {
        existing.manOfTheMatchCount++;
      }
    }

    _checkAndAdvanceStage(tournament);

    _saveAsync();
    notifyListeners();
  }

  void _checkAndAdvanceStage(Tournament tournament) {
    final allGroupDone =
    tournament.groupMatches.every((m) => m.isCompleted);

    if (!allGroupDone) return;

    if (tournament.knockoutMatches.isNotEmpty) {
      final qfDone = tournament.quarterFinals.isNotEmpty &&
          tournament.quarterFinals.every((m) => m.isCompleted);
      final sfExist = tournament.semiFinals.isNotEmpty;

      if (qfDone && !sfExist) {
        final winners =
        tournament.quarterFinals.map((m) => m.winnerId!).toList();
        for (int i = 0; i < winners.length ~/ 2; i++) {
          tournament.matches.add(TournamentMatch(
            matchId: _uuid.v4(),
            team1Id: winners[i * 2],
            team2Id: winners[i * 2 + 1],
            stage: 'sf',
            knockoutRound: KnockoutRound.semiFinal,
          ));
        }
        _saveAsync();
        notifyListeners();
        return;
      }

      final sfDone = tournament.semiFinals.isNotEmpty &&
          tournament.semiFinals.every((m) => m.isCompleted);
      final finalExist = tournament.finalMatch != null;

      if (sfDone && !finalExist) {
        final winners =
        tournament.semiFinals.map((m) => m.winnerId!).toList();
        if (winners.length >= 2) {
          tournament.matches.add(TournamentMatch(
            matchId: _uuid.v4(),
            team1Id: winners[0],
            team2Id: winners[1],
            stage: 'final',
            knockoutRound: KnockoutRound.final_,
          ));
        }
        _saveAsync();
        notifyListeners();
        return;
      }

      final finalDone =
          tournament.finalMatch != null && tournament.finalMatch!.isCompleted;
      if (finalDone && tournament.status != TournamentStatus.completed) {
        tournament.status = TournamentStatus.completed;
        tournament.winnerId = tournament.finalMatch!.winnerId;
        _saveAsync();
        notifyListeners();
      }
      return;
    }

    tournament.status = TournamentStatus.knockout;
    _generateKnockoutMatches(tournament);
    _saveAsync();
    notifyListeners();
  }

  void _generateKnockoutMatches(Tournament tournament) {
    final qualifiedTeams = <String>[];
    for (final groupName in tournament.groupNames) {
      final sorted = tournament.getGroupTeams(groupName);
      if (sorted.isNotEmpty) qualifiedTeams.add(sorted[0].teamId);
      if (sorted.length > 1) qualifiedTeams.add(sorted[1].teamId);
    }

    final count = qualifiedTeams.length;

    if (count >= 8) {
      for (int i = 0; i < 4; i++) {
        tournament.matches.add(TournamentMatch(
          matchId: _uuid.v4(),
          team1Id: qualifiedTeams[i],
          team2Id: qualifiedTeams[count - 1 - i],
          stage: 'qf',
          knockoutRound: KnockoutRound.quarterFinal,
        ));
      }
    } else if (count >= 4) {
      for (int i = 0; i < 2; i++) {
        tournament.matches.add(TournamentMatch(
          matchId: _uuid.v4(),
          team1Id: qualifiedTeams[i],
          team2Id: qualifiedTeams[count - 1 - i],
          stage: 'sf',
          knockoutRound: KnockoutRound.semiFinal,
        ));
      }
    } else if (count >= 2) {
      tournament.matches.add(TournamentMatch(
        matchId: _uuid.v4(),
        team1Id: qualifiedTeams[0],
        team2Id: qualifiedTeams[1],
        stage: 'final',
        knockoutRound: KnockoutRound.final_,
      ));
    }
  }

  void advanceKnockout(String tournamentId) {
    final tournament =
    _tournaments.firstWhere((t) => t.id == tournamentId);
    _checkAndAdvanceStage(tournament);
  }

  void completeTournament({
    required String tournamentId,
    required String winnerId,
    String? manOfTheSeries,
  }) {
    final tournament =
    _tournaments.firstWhere((t) => t.id == tournamentId);
    tournament.status = TournamentStatus.completed;
    tournament.winnerId = winnerId;
    tournament.manOfTheSeries = manOfTheSeries;
    _saveAsync();
    notifyListeners();
  }

  void deleteTournament(String id) {
    _tournaments.removeWhere((t) => t.id == id);
    _saveAsync();
    notifyListeners();
  }

  Tournament? getTournament(String id) {
    return _tournaments.firstWhereOrNull((t) => t.id == id);
  }
}