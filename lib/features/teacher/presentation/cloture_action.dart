import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/data/seance_repository.dart';
import 'package:classcheck/core/models/seance.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/features/teacher/data/teacher_repository.dart';

/// Demande confirmation puis clôture la séance (les non-pointés passent absents).
Future<void> cloturerSeance(BuildContext context, WidgetRef ref, Seance seance) async {
  final confirme = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Clôturer la séance ?'),
      content: const Text(
        'Les étudiants qui n\'ont pas pointé seront automatiquement marqués absents. '
        'Plus aucun pointage ne sera possible.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clôturer')),
      ],
    ),
  );
  if (confirme != true || !context.mounted) return;
  try {
    await ref.read(teacherRepositoryProvider).cloturer(seance.id);
    ref.invalidate(seanceProvider(seance.id));
    ref.invalidate(seancesDuJourProvider);
    if (context.mounted) context.pushReplacement('/enseignant/seance/${seance.id}/cloture');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreur(e))));
    }
  }
}
