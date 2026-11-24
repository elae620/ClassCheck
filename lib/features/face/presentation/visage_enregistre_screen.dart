import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/auth/data/auth_repository.dart';
import 'package:classcheck/features/auth/domain/profil.dart';

/// Maquette « Visage-Enregistre ».
class VisageEnregistreScreen extends ConsumerWidget {
  const VisageEnregistreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(profilProvider).valueOrNull?.role ?? Role.etudiant;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              const Spacer(),
              const CercleResultat(couleur: AppColors.menthe, icone: Icons.check),
              const SizedBox(height: 22),
              Text('Visage enregistré', style: AppText.titre),
              const SizedBox(height: 8),
              Text(
                '5 captures converties en code numérique.\nVotre photo n\'est pas conservée.',
                textAlign: TextAlign.center,
                style: AppText.secondaire,
              ),
              const SizedBox(height: 22),
              AppCard(
                couleur: AppColors.jaune,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Vous pourrez pointer', style: AppText.sousTitre)),
                        const StatusPill(label: 'Prêt'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scannez le QR de la séance, puis validez par selfie.',
                      style: AppText.petit,
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              PillButton(
                label: 'Accéder à mon espace',
                onPressed: () => context.go(role.accueil),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grand cercle coloré avec icône centrale (écrans de résultat).
class CercleResultat extends StatelessWidget {
  const CercleResultat({super.key, required this.couleur, required this.icone});

  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(color: AppColors.blanc, shape: BoxShape.circle),
        child: Icon(icone, size: 34, color: AppColors.texte),
      ),
    );
  }
}
