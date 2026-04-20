import 'dart:convert';

// ─────────────────────────────────────────
// PLAYER
// ─────────────────────────────────────────
class Player {
  String id;
  String name;
  int runs;
  int balls;
  int fours;
  int sixes;
  bool isOut;
  String? dismissalInfo;

  // Bowling stats
  int oversBowled;
  int runsConceded;
  int wickets;
  int maidens;
  int wides;
  int noBalls;

  Player({
    required this.id,
    required this.name,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.dismissalInfo,
    this.oversBowled = 0,
    this.runsConceded = 0,
    this.wickets = 0,
    this.maidens = 0,
    this.wides = 0,
    this.noBalls = 0,
  });

  double get strikeRate =>
      balls == 0 ? 0.0 : (runs / balls * 100);

  double get bowlingEconomy =>
      oversBowled == 0 ? 0.0 : (runsConceded / (oversBowled / 6));

  String get oversBowledDisplay {
    int overs = oversBowled ~/ 6;
    int ball = oversBowled % 6;
    return '$overs.$ball';
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'runs': runs, 'balls': balls,
    'fours': fours, 'sixes': sixes, 'isOut': isOut,
    'dismissalInfo': dismissalInfo, 'oversBowled': oversBowled,
    'runsConceded': runsConceded, 'wickets': wickets,
    'maidens': maidens, 'wides': wides, 'noBalls': noBalls,
  };

  factory Player.fromJson(Map<String, dynamic> j) => Player(
    id: j['id'], name: j['name'], runs: j['runs'] ?? 0,
    balls: j['balls'] ?? 0, fours: j['fours'] ?? 0,
    sixes: j['sixes'] ?? 0, isOut: j['isOut'] ?? false,
    dismissalInfo: j['dismissalInfo'],
    oversBowled: j['oversBowled'] ?? 0,
    runsConceded: j['runsConceded'] ?? 0,
    wickets: j['wickets'] ?? 0, maidens: j['maidens'] ?? 0,
    wides: j['wides'] ?? 0, noBalls: j['noBalls'] ?? 0,
  );

  Player copyWith({String? name}) =>
      Player(id: id, name: name ?? this.name, runs: runs,
          balls: balls, fours: fours, sixes: sixes, isOut: isOut,
          dismissalInfo: dismissalInfo, oversBowled: oversBowled,
          runsConceded: runsConceded, wickets: wickets,
          maidens: maidens, wides: wides, noBalls: noBalls);
}

// ─────────────────────────────────────────
// TEAM
// ─────────────────────────────────────────
class Team {
  String id;
  String name;
  List<Player> players;
  int matchesPlayed;
  int won;
  int lost;

  Team({
    required this.id,
    required this.name,
    List<Player>? players,
    this.matchesPlayed = 0,
    this.won = 0,
    this.lost = 0,
  }) : players = players ?? [];

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name,
    'players': players.map((p) => p.toJson()).toList(),
    'matchesPlayed': matchesPlayed, 'won': won, 'lost': lost,
  };

  factory Team.fromJson(Map<String, dynamic> j) => Team(
    id: j['id'], name: j['name'],
    players: (j['players'] as List? ?? [])
        .map((p) => Player.fromJson(p)).toList(),
    matchesPlayed: j['matchesPlayed'] ?? 0,
    won: j['won'] ?? 0, lost: j['lost'] ?? 0,
  );
}

// ─────────────────────────────────────────
// BALL EVENT
// ─────────────────────────────────────────
enum BallType { normal, wide, noBall, bye, legBye, wicket }

class BallEvent {
  final BallType type;
  final int runs;
  final String? dismissalType;
  final String? fielderId;
  final String? batsmanId;
  final String? bowlerId;
  final String overNumber;
  final DateTime timestamp;
  final bool isFreeHit;

  BallEvent({
    required this.type,
    required this.runs,
    this.dismissalType,
    this.fielderId,
    this.batsmanId,
    this.bowlerId,
    required this.overNumber,
    DateTime? timestamp,
    this.isFreeHit = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type.name, 'runs': runs,
    'dismissalType': dismissalType,
    'fielderId': fielderId,
    'batsmanId': batsmanId,
    'bowlerId': bowlerId, 'overNumber': overNumber,
    'timestamp': timestamp.toIso8601String(),
    'isFreeHit': isFreeHit,
  };

  factory BallEvent.fromJson(Map<String, dynamic> j) => BallEvent(
    type: BallType.values.byName(j['type']),
    runs: j['runs'], dismissalType: j['dismissalType'],
    fielderId: j['fielderId'],
    batsmanId: j['batsmanId'], bowlerId: j['bowlerId'],
    overNumber: j['overNumber'],
    timestamp: DateTime.parse(j['timestamp']),
    isFreeHit: j['isFreeHit'] ?? false,
  );

  String get display {
    switch (type) {
      case BallType.wide: return runs > 1 ? '${runs - 1}' : '0';
      case BallType.noBall: return runs > 0 ? '$runs' : '0';
      case BallType.bye: return '${runs}B';
      case BallType.legBye: return '${runs}Lb';
      case BallType.wicket:

        if (isFreeHit && dismissalType == 'Run Out') return 'W';
        if (isFreeHit) return 'W';
        return 'W';
      default:
      // Free Hit  run
        return isFreeHit ? '${runs}F' : runs.toString();
    }
  }
}

// ─────────────────────────────────────────
// INNINGS
// ─────────────────────────────────────────
class Partnership {
  final String batsman1Id;
  final String batsman2Id;
  int runs;
  int balls;

  Partnership({
    required this.batsman1Id,
    required this.batsman2Id,
    this.runs = 0,
    this.balls = 0,
  });

  Map<String, dynamic> toJson() => {
    'batsman1Id': batsman1Id, 'batsman2Id': batsman2Id,
    'runs': runs, 'balls': balls,
  };

  factory Partnership.fromJson(Map<String, dynamic> j) => Partnership(
    batsman1Id: j['batsman1Id'], batsman2Id: j['batsman2Id'],
    runs: j['runs'] ?? 0, balls: j['balls'] ?? 0,
  );
}

class Innings {
  final String teamId;
  int totalRuns;
  int wickets;
  int totalBalls;
  List<BallEvent> ballEvents;
  List<String> battingOrder;
  List<String> bowlingOrder;
  String? strikerBatsmanId;
  String? nonStrikerBatsmanId;
  String? currentBowlerId;
  List<String> fallenWickets;
  List<Partnership> partnerships;
  bool isCompleted;
  List<int> overRunTotals;

  Innings({
    required this.teamId,
    this.totalRuns = 0,
    this.wickets = 0,
    this.totalBalls = 0,
    List<BallEvent>? ballEvents,
    List<String>? battingOrder,
    List<String>? bowlingOrder,
    this.strikerBatsmanId,
    this.nonStrikerBatsmanId,
    this.currentBowlerId,
    List<String>? fallenWickets,
    List<Partnership>? partnerships,
    this.isCompleted = false,
    List<int>? overRunTotals,
  })  : ballEvents = ballEvents ?? [],
        battingOrder = battingOrder ?? [],
        bowlingOrder = bowlingOrder ?? [],
        fallenWickets = fallenWickets ?? [],
        partnerships = partnerships ?? [],
        overRunTotals = overRunTotals ?? [];

  int get completedOvers => totalBalls ~/ 6;
  int get ballsInCurrentOver => totalBalls % 6;

  String get oversDisplay =>
      '$completedOvers.${ballsInCurrentOver}';

  double get runRate =>
      totalBalls == 0 ? 0.0 : totalRuns / (totalBalls / 6);

  Map<String, dynamic> toJson() => {
    'teamId': teamId, 'totalRuns': totalRuns,
    'wickets': wickets, 'totalBalls': totalBalls,
    'ballEvents': ballEvents.map((b) => b.toJson()).toList(),
    'battingOrder': battingOrder, 'bowlingOrder': bowlingOrder,
    'strikerBatsmanId': strikerBatsmanId,
    'nonStrikerBatsmanId': nonStrikerBatsmanId,
    'currentBowlerId': currentBowlerId,
    'fallenWickets': fallenWickets,
    'partnerships': partnerships.map((p) => p.toJson()).toList(),
    'isCompleted': isCompleted,
    'overRunTotals': overRunTotals,
  };

  factory Innings.fromJson(Map<String, dynamic> j) => Innings(
    teamId: j['teamId'],
    totalRuns: j['totalRuns'] ?? 0,
    wickets: j['wickets'] ?? 0,
    totalBalls: j['totalBalls'] ?? 0,
    ballEvents: (j['ballEvents'] as List? ?? [])
        .map((b) => BallEvent.fromJson(b)).toList(),
    battingOrder: List<String>.from(j['battingOrder'] ?? []),
    bowlingOrder: List<String>.from(j['bowlingOrder'] ?? []),
    strikerBatsmanId: j['strikerBatsmanId'],
    nonStrikerBatsmanId: j['nonStrikerBatsmanId'],
    currentBowlerId: j['currentBowlerId'],
    fallenWickets: List<String>.from(j['fallenWickets'] ?? []),
    partnerships: (j['partnerships'] as List? ?? [])
        .map((p) => Partnership.fromJson(p)).toList(),
    isCompleted: j['isCompleted'] ?? false,
    overRunTotals: List<int>.from(j['overRunTotals'] ?? []),
  );
}

// ─────────────────────────────────────────
// MATCH
// ─────────────────────────────────────────
enum MatchFormat { t20, odi, custom }
enum MatchStatus { upcoming, inProgress, completed }
enum TossDecision { bat, bowl }

class CricketMatch {
  String id;
  String hostTeamId;
  String visitorTeamId;
  MatchFormat format;
  int totalOvers;
  String? tossWonByTeamId;
  TossDecision? tossDecision;
  Innings? firstInnings;
  Innings? secondInnings;
  MatchStatus status;
  String? resultDescription;
  DateTime createdAt;
  bool isArchived;
  // For players created during match
  List<Player> tempHostPlayers;
  List<Player> tempVisitorPlayers;

  CricketMatch({
    required this.id,
    required this.hostTeamId,
    required this.visitorTeamId,
    required this.format,
    required this.totalOvers,
    this.tossWonByTeamId,
    this.tossDecision,
    this.firstInnings,
    this.secondInnings,
    this.status = MatchStatus.upcoming,
    this.resultDescription,
    DateTime? createdAt,
    this.isArchived = false,
    List<Player>? tempHostPlayers,
    List<Player>? tempVisitorPlayers,
  })  : createdAt = createdAt ?? DateTime.now(),
        tempHostPlayers = tempHostPlayers ?? [],
        tempVisitorPlayers = tempVisitorPlayers ?? [];

  String get currentInningsTeamId {
    if (firstInnings == null || !firstInnings!.isCompleted) {
      return hostTeamId;
    }
    return visitorTeamId;
  }

  Innings? get currentInnings {
    if (firstInnings == null || !firstInnings!.isCompleted) return firstInnings;
    if (secondInnings == null || !secondInnings!.isCompleted) return secondInnings;
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'hostTeamId': hostTeamId, 'visitorTeamId': visitorTeamId,
    'format': format.name, 'totalOvers': totalOvers,
    'tossWonByTeamId': tossWonByTeamId,
    'tossDecision': tossDecision?.name,
    'firstInnings': firstInnings?.toJson(),
    'secondInnings': secondInnings?.toJson(),
    'status': status.name, 'resultDescription': resultDescription,
    'createdAt': createdAt.toIso8601String(),
    'isArchived': isArchived,
    'tempHostPlayers': tempHostPlayers.map((p) => p.toJson()).toList(),
    'tempVisitorPlayers': tempVisitorPlayers.map((p) => p.toJson()).toList(),
  };

  factory CricketMatch.fromJson(Map<String, dynamic> j) => CricketMatch(
    id: j['id'], hostTeamId: j['hostTeamId'],
    visitorTeamId: j['visitorTeamId'],
    format: MatchFormat.values.byName(j['format']),
    totalOvers: j['totalOvers'],
    tossWonByTeamId: j['tossWonByTeamId'],
    tossDecision: j['tossDecision'] != null
        ? TossDecision.values.byName(j['tossDecision']) : null,
    firstInnings: j['firstInnings'] != null
        ? Innings.fromJson(j['firstInnings']) : null,
    secondInnings: j['secondInnings'] != null
        ? Innings.fromJson(j['secondInnings']) : null,
    status: MatchStatus.values.byName(j['status']),
    resultDescription: j['resultDescription'],
    createdAt: DateTime.parse(j['createdAt']),
    isArchived: j['isArchived'] ?? false,
    tempHostPlayers: (j['tempHostPlayers'] as List? ?? [])
        .map((p) => Player.fromJson(p)).toList(),
    tempVisitorPlayers: (j['tempVisitorPlayers'] as List? ?? [])
        .map((p) => Player.fromJson(p)).toList(),
  );
}