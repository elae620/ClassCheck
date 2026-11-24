import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/auth/data/auth_repository.dart';

/// Écran transitoire pendant le chargement du profil après connexion.
class ChargementScreen extends ConsumerWidget {
  const ChargementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider);
    Widget contenu;
    if (profil.isLoading) {
      contenu = const Chargement();
    } else if (profil.hasError || profil.valueOrNull == null) {
      contenu = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VueErreur(
            message: profil.hasError
                ? messageErreur(profil.error!)
                : 'Profil introuvable. Vérifiez que les migrations SQL ont été exécutées.',
            onReessayer: () => ref.invalidate(profilProvider),
          ),
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).deconnexion(),
            child: Text('Se déconnecter', style: AppText.lien),
          ),
        ],
      );
    } else {
      contenu = const Chargement();
    }
    return Scaffold(body: SafeArea(child: Center(child: contenu)));
  }
}

/// Compte enseignant/directeur créé mais pas encore activé par le directeur.
class CompteEnAttenteScreen extends ConsumerWidget {
  const CompteEnAttenteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(color: AppColors.jaune, shape: BoxShape.circle),
                child: const Icon(Icons.hourglass_top_rounded, size: 48),
              ),
              const SizedBox(height: 24),
              Text('Compte en attente', style: AppText.titre),
              const SizedBox(height: 8),
              Text(
                'Votre compte doit être activé par le directeur avant de pouvoir être utilisé.',
                textAlign: TextAlign.center,
                style: AppText.secondaire,
              ),
              const Spacer(),
              PillButton(
                label: 'Actualiser',
                variant: PillVariant.clair,
                onPressed: () => ref.invalidate(profilProvider),
              ),
              const SizedBox(height: 10),
              PillButton(
                label: 'Se déconnecter',
                onPressed: () => ref.read(authRepositoryProvider).deconnexion(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
