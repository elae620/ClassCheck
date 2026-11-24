import 'package:flutter/material.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/widgets/pill_button.dart';
import 'package:classcheck/core/widgets/pill_field.dart';

/// Exécute une action serveur : affiche le message de succès ou l'erreur
/// traduite. Renvoie vrai si l'action a réussi.
Future<bool> executerAction(
  BuildContext context,
  Future<void> Function() action, {
  String? succes,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (succes != null) messenger.showSnackBar(SnackBar(content: Text(succes)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(messageErreur(e))));
    return false;
  }
}

/// Demande un motif (obligatoire) dans une feuille du bas. Null si annulé.
Future<String?> demanderMotif(
  BuildContext context, {
  required String titre,
  String libelleBouton = 'Confirmer',
  String? indice,
}) {
  final controleur = TextEditingController();
  final cle = GlobalKey<FormState>();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.fond,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Form(
        key: cle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titre, style: AppText.entete),
            const SizedBox(height: 14),
            PillField(
              libelle: 'Motif obligatoire',
              controller: controleur,
              indice: indice,
              lignes: 3,
              validator: (v) => (v ?? '').trim().length < 3 ? 'Précisez le motif' : null,
            ),
            const SizedBox(height: 16),
            PillButton(
              label: libelleBouton,
              onPressed: () {
                if (cle.currentState!.validate()) Navigator.pop(ctx, controleur.text.trim());
              },
            ),
          ],
        ),
      ),
    ),
  );
}
