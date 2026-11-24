import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/widgets/pill_button.dart';

/// Affiche chargement / erreur / contenu pour un `AsyncValue`.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.valeur,
    required this.donnees,
    this.onReessayer,
  });

  final AsyncValue<T> valeur;
  final Widget Function(T donnees) donnees;
  final VoidCallback? onReessayer;

  @override
  Widget build(BuildContext context) {
    return valeur.when(
      skipLoadingOnRefresh: true,
      data: donnees,
      loading: () => const Chargement(),
      error: (e, _) => VueErreur(message: messageErreur(e), onReessayer: onReessayer),
    );
  }
}

class Chargement extends StatelessWidget {
  const Chargement({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
}

class VueErreur extends StatelessWidget {
  const VueErreur({super.key, required this.message, this.onReessayer});

  final String message;
  final VoidCallback? onReessayer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.texteSecondaire),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: AppText.corps),
          if (onReessayer != null) ...[
            const SizedBox(height: 16),
            PillButton.petit(label: 'Réessayer', onPressed: onReessayer),
          ],
        ],
      ),
    );
  }
}

class VueVide extends StatelessWidget {
  const VueVide({super.key, required this.message, this.icone = Icons.event_available_outlined});

  final String message;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 40, color: AppColors.violet),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: AppText.secondaire),
        ],
      ),
    );
  }
}
