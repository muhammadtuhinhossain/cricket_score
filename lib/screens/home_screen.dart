import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../models/tournament_models.dart';
import '../provider/app_provider.dart';
import '../provider/tournament_provider.dart';
import '../utils/theme.dart';
import 'new_match_screen.dart';
import 'scoring_screen.dart';
import 'scoreboard_screen.dart';
import 'teams_screen.dart';
import 'tournaments_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.sports_cricket, color: Colors.white),
          const SizedBox(width: 8),
          Text('Cricket Scorer',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          if (_tab == 0)
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archive',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _ArchiveScreen())),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sports_cricket,
                        size: 36, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Text('Cricket Scorer',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text('Made by',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Muhammad Tuhin Hasan',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text('Vitapara, Santhia, Pabna',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ]),
                  const SizedBox(height: 12),
                ]),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          _MatchListTab(),
          TournamentsScreen(),
          TeamsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.sports_cricket), label: 'Matches'),
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events), label: 'Tournaments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.group), label: 'Teams'),
        ],
      ),

      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
        heroTag: 'home_new_match_fab',
        backgroundColor: AppTheme.primary,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NewMatchScreen())),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('New Match',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}


// match list tab

class _MatchListTab extends StatefulWidget {
  const _MatchListTab();

  @override
  State<_MatchListTab> createState() => _MatchListTabState();
}

class _MatchListTabState extends State<_MatchListTab> {
  final Set<String> _selected = {};
  bool get _selectMode => _selected.isNotEmpty;

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll(List<CricketMatch> matches) {
    setState(() {
      _selected.addAll(matches.map((m) => m.id));
    });
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  void _deleteSelected(AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Matches?'),
        content: Text(
            '${_selected.length}টি match delete হবে। এটা undo করা যাবে না।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              for (final id in _selected) {
                provider.deleteMatch(id);
              }
              _clearSelection();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppProvider, TournamentProvider>(
        builder: (ctx, provider, tProvider, _) {
          final matches = provider.recentMatches;
          if (matches.isEmpty) return _EmptyMatches();

          // tournament match id → tournament name map
          final Map<String, String> cricketMatchTournamentName = {};
          for (final t in tProvider.tournaments) {
            for (final m in t.matches) {
              if (m.cricketMatchId != null) {
                cricketMatchTournamentName[m.cricketMatchId!] = t.name;
              }
            }
          }

          return Column(children: [
            // select mode top bar
            if (_selectMode)
              Container(
                color: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _clearSelection,
                    tooltip: 'Cancel',
                  ),
                  Text('${_selected.length} selected',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _selectAll(matches),
                    child: const Text('Select All',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: () => _deleteSelected(provider),
                    tooltip: 'Delete selected',
                  ),
                ]),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: matches.length,
                itemBuilder: (_, i) {
                  final match = matches[i];
                  final isSelected = _selected.contains(match.id);
                  return _MatchCard(
                    match: match,
                    provider: provider,
                    tournamentName: cricketMatchTournamentName[match.id],
                    isSelected: isSelected,
                    selectMode: _selectMode,
                    onSelect: () => _toggleSelect(match.id),
                    onLongPress: () => _toggleSelect(match.id),
                  );
                },
              ),
            ),
          ]);
        });
  }
}

class _MatchCard extends StatelessWidget {
  final CricketMatch match;
  final AppProvider provider;
  final String? tournamentName;
  final bool isSelected;
  final bool selectMode;
  final VoidCallback onSelect;
  final VoidCallback onLongPress;

  const _MatchCard({
    required this.match,
    required this.provider,
    this.tournamentName,
    this.isSelected = false,
    this.selectMode = false,
    required this.onSelect,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hostTeam = provider.getTeam(match.hostTeamId);
    final visitorTeam = provider.getTeam(match.visitorTeamId);
    final isLive = match.status == MatchStatus.inProgress;
    final isCompleted = match.status == MatchStatus.completed;
    final isTournamentMatch = tournamentName != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? AppTheme.primary.withValues(alpha: 0.07) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: AppTheme.primary.withValues(alpha: 0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: onLongPress,
        onTap: () {
          if (selectMode) { onSelect(); return; }
          if (isLive) {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => ScoringScreen(matchId: match.id)));
          } else {
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => ScoreboardScreen(matchId: match.id)));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (selectMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: AppTheme.primary,
                  onChanged: (_) => onSelect(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
              ],
              if (isLive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.red, borderRadius: BorderRadius.circular(4)),
                  child: const Row(children: [
                    Icon(Icons.circle, size: 8, color: Colors.white),
                    SizedBox(width: 4),
                    Text('LIVE', style: TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(width: 6),
              ],
              if (isTournamentMatch)
                Tooltip(
                  message: tournamentName!,
                  triggerMode: TooltipTriggerMode.tap,
                  preferBelow: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.emoji_events, size: 10, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            tournamentName!,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.sports_cricket, size: 10, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text('Single Match',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              const Spacer(),
              Text(DateFormat('d MMM, HH:mm').format(match.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              if (!selectMode)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (v) {
                    if (v == 'archive') provider.archiveMatch(match.id);
                    if (v == 'delete') provider.deleteMatch(match.id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'archive', child: Text('Archive')),
                    const PopupMenuItem(value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _TeamScore(
                teamName: hostTeam?.name ?? 'Host',
                innings: _getTeamInnings(match, match.hostTeamId),
                isBatting: match.currentInnings?.teamId == match.hostTeamId,
                color: AppTheme.host,
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('vs',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500)),
              ),
              Expanded(child: _TeamScore(
                teamName: visitorTeam?.name ?? 'Visitor',
                innings: _getTeamInnings(match, match.visitorTeamId),
                isBatting: match.currentInnings?.teamId == match.visitorTeamId,
                color: AppTheme.visitor,
                alignRight: true,
              )),
            ]),
            if (isCompleted && match.resultDescription != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(match.resultDescription!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
            if (!selectMode && (isLive || isCompleted)) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (isLive)
                  Expanded(child: ElevatedButton.icon(
                    icon: const Icon(Icons.sports_cricket, size: 16),
                    label: const Text('Resume'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(fontSize: 13)),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                            ScoringScreen(matchId: match.id))),
                  )),
                if (isLive) const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.list_alt, size: 16, color: AppTheme.primary),
                  label: const Text('Scoreboard',
                      style: TextStyle(color: AppTheme.primary)),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 13)),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) =>
                          ScoreboardScreen(matchId: match.id))),
                )),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Innings? _getTeamInnings(CricketMatch match, String teamId) {
    if (match.firstInnings?.teamId == teamId) return match.firstInnings;
    if (match.secondInnings?.teamId == teamId) return match.secondInnings;
    return null;
  }
}

class _TeamScore extends StatelessWidget {
  final String teamName;
  final Innings? innings;
  final bool isBatting;
  final Color color;
  final bool alignRight;
  const _TeamScore({
    required this.teamName,
    required this.innings,
    required this.isBatting,
    required this.color,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment:
    alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment:
        alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isBatting && !alignRight) ...[
            Icon(Icons.sports_cricket, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(child: Text(teamName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600,
                  fontSize: 14, color: color))),
          if (isBatting && alignRight) ...[
            const SizedBox(width: 4),
            Icon(Icons.sports_cricket, size: 12, color: color),
          ],
        ],
      ),
      if (innings != null)
        Text(
          '${innings!.totalRuns}/${innings!.wickets}'
              ' (${innings!.completedOvers}.${innings!.ballsInCurrentOver})',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
        )
      else
        Text('Yet to bat',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: alignRight ? TextAlign.right : TextAlign.left),
    ],
  );
}

class _EmptyMatches extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.sports_cricket, size: 80, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text('No matches yet', style: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary)),
      const SizedBox(height: 8),
      Text('Tap + to start a new match',
          style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
    ]),
  );
}

class _ArchiveScreen extends StatelessWidget {
  const _ArchiveScreen();

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppProvider, TournamentProvider>(
        builder: (ctx, provider, tProvider, _) {
          final matches = provider.archivedMatches;

          final Map<String, String> cricketMatchTournamentName = {};
          for (final t in tProvider.tournaments) {
            for (final m in t.matches) {
              if (m.cricketMatchId != null) {
                cricketMatchTournamentName[m.cricketMatchId!] = t.name;
              }
            }
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Archived Matches')),
            body: matches.isEmpty
                ? Center(child: Text('No archived matches',
                style: GoogleFonts.poppins(color: AppTheme.textSecondary)))
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: matches.length,
              itemBuilder: (_, i) => _MatchCard(
                match: matches[i],
                provider: provider,
                tournamentName: cricketMatchTournamentName[matches[i].id],
                onSelect: () {},
                onLongPress: () {},
              ),
            ),
          );
        });
  }
}