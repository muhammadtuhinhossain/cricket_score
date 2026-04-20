import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../models/tournament_models.dart';
import '../provider/app_provider.dart';
import '../provider/tournament_provider.dart';
import '../utils/theme.dart';
import 'tournament_detail_screen.dart';
import 'create_tournament_screen.dart';

class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TournamentProvider, AppProvider>(
        builder: (ctx, tProvider, aProvider, _) {
          final tournaments = tProvider.tournaments
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Scaffold(
            backgroundColor: AppTheme.surface,
            body: tournaments.isEmpty
                ? _EmptyTournaments(
              onAdd: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreateTournamentScreen()),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: tournaments.length,
              itemBuilder: (_, i) => _TournamentCard(
                tournament: tournaments[i],
                appProvider: aProvider,
                tProvider: tProvider,
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreateTournamentScreen()),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('New Tournament',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          );
        });
  }
}

class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final AppProvider appProvider;
  final TournamentProvider tProvider;

  const _TournamentCard({
    required this.tournament,
    required this.appProvider,
    required this.tProvider,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(tournament.status);
    final statusText = _statusText(tournament.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TournamentDetailScreen(tournamentId: tournament.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusText,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('d MMM yyyy')
                        .format(tournament.createdAt),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (v) {
                      if (v == 'delete') {
                        tProvider.deleteTournament(tournament.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ]),
                const SizedBox(height: 8),
                Text(tournament.name,
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.group,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('${tournament.teamIds.length} Teams',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary)),
                  const SizedBox(width: 12),
                  const Icon(Icons.sports_cricket,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                      '${tournament.totalOvers} Overs · ${tournament.format.toUpperCase()}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary)),
                  const SizedBox(width: 12),
                  const Icon(Icons.grid_view,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                      '${tournament.totalGroups} Groups',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary)),
                ]),
                const SizedBox(height: 8),
                // Progress bar
                _MatchProgress(tournament: tournament),

                // Winner
                if (tournament.status == TournamentStatus.completed &&
                    tournament.winnerId != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.emoji_events,
                        color: AppTheme.accent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Winner: ${appProvider.getTeam(tournament.winnerId!)?.name ?? '-'}',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                          fontSize: 13),
                    ),
                  ]),
                ],
              ]),
        ),
      ),
    );
  }

  Color _statusColor(TournamentStatus s) {
    switch (s) {
      case TournamentStatus.groupStage:
        return Colors.blue;
      case TournamentStatus.knockout:
        return Colors.orange;
      case TournamentStatus.completed:
        return AppTheme.primary;
      default:
        return Colors.grey;
    }
  }

  String _statusText(TournamentStatus s) {
    switch (s) {
      case TournamentStatus.groupStage:
        return 'GROUP STAGE';
      case TournamentStatus.knockout:
        return 'KNOCKOUT';
      case TournamentStatus.completed:
        return 'COMPLETED';
      default:
        return 'UPCOMING';
    }
  }
}

class _MatchProgress extends StatelessWidget {
  final Tournament tournament;
  const _MatchProgress({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final total = tournament.matches.length;
    final done =
        tournament.matches.where((m) => m.isCompleted).length;
    final progress = total == 0 ? 0.0 : done / total;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Matches: $done/$total',
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
        Text('${(progress * 100).round()}%',
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          color: AppTheme.primary,
          minHeight: 6,
        ),
      ),
    ]);
  }
}

class _EmptyTournaments extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTournaments({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events,
              size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No tournaments yet',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create Tournament'),
            onPressed: onAdd,
          ),
        ]),
  );
}