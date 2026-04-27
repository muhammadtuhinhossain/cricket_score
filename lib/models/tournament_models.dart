// ─────────────────────────────────────────
// TOURNAMENT MODELS
// ─────────────────────────────────────────

enum TournamentStatus { upcoming, groupStage, knockout, completed }
enum KnockoutRound { quarterFinal, semiFinal, final_ }

class TournamentTeam {
  final String teamId;
  String groupName;
  int played;
  int won;
  int lost;
  int tied;
  int points;
  int runsFor;
  int ballsFor;
  int runsAgainst;
  int ballsAgainst;

  TournamentTeam({
    required this.teamId,
    required this.groupName,
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.tied = 0,
    this.points = 0,
    this.runsFor = 0,
    this.ballsFor = 0,
    this.runsAgainst = 0,
    this.ballsAgainst = 0,
  });

  double get nrr {
    if (ballsFor == 0 || ballsAgainst == 0) return 0.0;
    final rrFor = runsFor / (ballsFor / 6);
    final rrAgainst = runsAgainst / (ballsAgainst / 6);
    return rrFor - rrAgainst;
  }

  Map<String, dynamic> toJson() => {
    'teamId': teamId,
    'groupName': groupName,
    'played': played,
    'won': won,
    'lost': lost,
    'tied': tied,
    'points': points,
    'runsFor': runsFor,
    'ballsFor': ballsFor,
    'runsAgainst': runsAgainst,
    'ballsAgainst': ballsAgainst,
  };

  factory TournamentTeam.fromJson(Map<String, dynamic> j) => TournamentTeam(
    teamId: j['teamId'],
    groupName: j['groupName'],
    played: j['played'] ?? 0,
    won: j['won'] ?? 0,
    lost: j['lost'] ?? 0,
    tied: j['tied'] ?? 0,
    points: j['points'] ?? 0,
    runsFor: j['runsFor'] ?? 0,
    ballsFor: j['ballsFor'] ?? 0,
    runsAgainst: j['runsAgainst'] ?? 0,
    ballsAgainst: j['ballsAgainst'] ?? 0,
  );
}

class TournamentMatch {
  final String matchId;       // tournament এর নিজস্ব stable id — কখনো বদলায় না
  final String team1Id;
  final String team2Id;
  final String stage;
  final String? groupName;
  final KnockoutRound? knockoutRound;
  String? winnerId;
  String? manOfTheMatch;
  bool isCompleted;
  String? cricketMatchId;     // linked cricket match এর id (scoring এর পর set হয়)

  TournamentMatch({
    required this.matchId,
    required this.team1Id,
    required this.team2Id,
    required this.stage,
    this.groupName,
    this.knockoutRound,
    this.winnerId,
    this.manOfTheMatch,
    this.isCompleted = false,
    this.cricketMatchId,
  });

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'team1Id': team1Id,
    'team2Id': team2Id,
    'stage': stage,
    'groupName': groupName,
    'knockoutRound': knockoutRound?.name,
    'winnerId': winnerId,
    'manOfTheMatch': manOfTheMatch,
    'isCompleted': isCompleted,
    'cricketMatchId': cricketMatchId,
  };

  factory TournamentMatch.fromJson(Map<String, dynamic> j) => TournamentMatch(
    matchId: j['matchId'],
    team1Id: j['team1Id'],
    team2Id: j['team2Id'],
    stage: j['stage'],
    groupName: j['groupName'],
    knockoutRound: j['knockoutRound'] != null
        ? KnockoutRound.values.byName(j['knockoutRound'])
        : null,
    winnerId: j['winnerId'],
    manOfTheMatch: j['manOfTheMatch'],
    isCompleted: j['isCompleted'] ?? false,
    cricketMatchId: j['cricketMatchId'],
  );
}

class PlayerTournamentStats {
  final String playerId;
  final String teamId;
  int totalRuns;
  int totalBalls;
  int totalFours;
  int totalSixes;
  int highScore;
  int innings;
  int totalWickets;
  int totalRunsConceded;
  int totalOversBowled;
  int manOfTheMatchCount;

  PlayerTournamentStats({
    required this.playerId,
    required this.teamId,
    this.totalRuns = 0,
    this.totalBalls = 0,
    this.totalFours = 0,
    this.totalSixes = 0,
    this.highScore = 0,
    this.innings = 0,
    this.totalWickets = 0,
    this.totalRunsConceded = 0,
    this.totalOversBowled = 0,
    this.manOfTheMatchCount = 0,
  });

  double get battingAverage =>
      innings == 0 ? 0.0 : totalRuns / innings;

  double get strikeRate =>
      totalBalls == 0 ? 0.0 : (totalRuns / totalBalls * 100);

  double get bowlingEconomy => totalOversBowled == 0
      ? 0.0
      : totalRunsConceded / (totalOversBowled / 6);

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'teamId': teamId,
    'totalRuns': totalRuns,
    'totalBalls': totalBalls,
    'totalFours': totalFours,
    'totalSixes': totalSixes,
    'highScore': highScore,
    'innings': innings,
    'totalWickets': totalWickets,
    'totalRunsConceded': totalRunsConceded,
    'totalOversBowled': totalOversBowled,
    'manOfTheMatchCount': manOfTheMatchCount,
  };

  factory PlayerTournamentStats.fromJson(Map<String, dynamic> j) =>
      PlayerTournamentStats(
        playerId: j['playerId'],
        teamId: j['teamId'],
        totalRuns: j['totalRuns'] ?? 0,
        totalBalls: j['totalBalls'] ?? 0,
        totalFours: j['totalFours'] ?? 0,
        totalSixes: j['totalSixes'] ?? 0,
        highScore: j['highScore'] ?? 0,
        innings: j['innings'] ?? 0,
        totalWickets: j['totalWickets'] ?? 0,
        totalRunsConceded: j['totalRunsConceded'] ?? 0,
        totalOversBowled: j['totalOversBowled'] ?? 0,
        manOfTheMatchCount: j['manOfTheMatchCount'] ?? 0,
      );
}

class Tournament {
  String id;
  String name;
  List<String> teamIds;
  int teamsPerGroup;
  int totalOvers;
  String format;
  TournamentStatus status;
  List<TournamentTeam> tournamentTeams;
  List<TournamentMatch> matches;
  List<PlayerTournamentStats> playerStats;
  String? manOfTheSeries;
  String? winnerId;
  DateTime createdAt;

  Tournament({
    required this.id,
    required this.name,
    required this.teamIds,
    required this.teamsPerGroup,
    required this.totalOvers,
    required this.format,
    this.status = TournamentStatus.upcoming,
    List<TournamentTeam>? tournamentTeams,
    List<TournamentMatch>? matches,
    List<PlayerTournamentStats>? playerStats,
    this.manOfTheSeries,
    this.winnerId,
    DateTime? createdAt,
  })  : tournamentTeams = tournamentTeams ?? [],
        matches = matches ?? [],
        playerStats = playerStats ?? [],
        createdAt = createdAt ?? DateTime.now();

  int get totalGroups => (teamIds.length / teamsPerGroup).ceil();

  List<String> get groupNames {
    final groups = <String>[];
    for (int i = 0; i < totalGroups; i++) {
      groups.add(String.fromCharCode(65 + i));
    }
    return groups;
  }

  List<TournamentTeam> getGroupTeams(String groupName) =>
      tournamentTeams.where((t) => t.groupName == groupName).toList()
        ..sort((a, b) {
          if (b.points != a.points) return b.points.compareTo(a.points);
          return b.nrr.compareTo(a.nrr);
        });

  List<TournamentMatch> get groupMatches =>
      matches.where((m) => m.stage == 'group').toList();

  List<TournamentMatch> get knockoutMatches =>
      matches.where((m) => m.stage != 'group').toList();

  TournamentMatch? get finalMatch =>
      matches.where((m) => m.stage == 'final').firstOrNull;

  List<TournamentMatch> get semiFinals =>
      matches.where((m) => m.stage == 'sf').toList();

  List<TournamentMatch> get quarterFinals =>
      matches.where((m) => m.stage == 'qf').toList();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teamIds': teamIds,
    'teamsPerGroup': teamsPerGroup,
    'totalOvers': totalOvers,
    'format': format,
    'status': status.name,
    'tournamentTeams':
    tournamentTeams.map((t) => t.toJson()).toList(),
    'matches': matches.map((m) => m.toJson()).toList(),
    'playerStats': playerStats.map((p) => p.toJson()).toList(),
    'manOfTheSeries': manOfTheSeries,
    'winnerId': winnerId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Tournament.fromJson(Map<String, dynamic> j) => Tournament(
    id: j['id'],
    name: j['name'],
    teamIds: List<String>.from(j['teamIds']),
    teamsPerGroup: j['teamsPerGroup'],
    totalOvers: j['totalOvers'],
    format: j['format'],
    status: TournamentStatus.values.byName(j['status']),
    tournamentTeams: (j['tournamentTeams'] as List? ?? [])
        .map((t) => TournamentTeam.fromJson(t))
        .toList(),
    matches: (j['matches'] as List? ?? [])
        .map((m) => TournamentMatch.fromJson(m))
        .toList(),
    playerStats: (j['playerStats'] as List? ?? [])
        .map((p) => PlayerTournamentStats.fromJson(p))
        .toList(),
    manOfTheSeries: j['manOfTheSeries'],
    winnerId: j['winnerId'],
    createdAt: DateTime.parse(j['createdAt']),
  );
}