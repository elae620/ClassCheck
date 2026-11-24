import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/face/presentation/widgets/face_oval.dart';

/// Maquette « Visage-Intro » : consignes + consentement.
class VisageIntroScreen extends StatefulWidget {
  const VisageIntroScreen({super.key});

  @override
  State<VisageIntroScreen> createState() => _VisageIntroScreenState();
}

class _VisageIntroScreenState extends State<VisageIntroScreen> {
  bool _consentement = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Enregistrer mon visage', repli: '/profil'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    const FaceOval(largeur: 190, hauteur: 240),
                    const SizedBox(height: 20),
                    const _Consigne(texte: 'Bonne lumière, visage de face'),
                    const SizedBox(height: 10),
                    const _Consigne(texte: 'Un seul visage dans le cadre'),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => setState(() => _consentement = !_consentement),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Checkbox(
                              value: _consentement,
                              activeColor: AppColors.bleu,
                              onChanged: (v) => setState(() => _consentement = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'J\'accepte que seul un code numérique de mon visage soit '
                                'conservé, jamais ma photo.',
                                style: AppText.petit,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PillButton(
                label: 'Commencer',
                onPressed: _consentement ? () => context.push('/visage/capture') : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Consigne extends StatelessWidget {
  const _Consigne({required this.texte});
  final String texte;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(child: Text(texte, style: AppText.secondaire.copyWith(color: AppColors.texte))),
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(color: AppColors.menthe, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 16),
          ),
        ],
      ),
    );
  }
}
