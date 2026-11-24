import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/utils/validateurs.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/auth/data/auth_repository.dart';
import 'package:classcheck/features/auth/domain/profil.dart';

/// Maquette « E-Profil » (partagée par les trois rôles).
class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider);
    return Scaffold(
      body: SafeArea(
        child: AsyncValueView<Profil?>(
          valeur: profil,
          onReessayer: () => ref.invalidate(profilProvider),
          donnees: (p) => p == null ? const Chargement() : _FormulaireProfil(profil: p),
        ),
      ),
    );
  }
}

class _FormulaireProfil extends ConsumerStatefulWidget {
  const _FormulaireProfil({required this.profil});
  final Profil profil;

  @override
  ConsumerState<_FormulaireProfil> createState() => _FormulaireProfilState();
}

class _FormulaireProfilState extends ConsumerState<_FormulaireProfil> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.profil.nom);
  late final _email = TextEditingController(text: widget.profil.email);
  late final _classe = TextEditingController(text: widget.profil.classe ?? '');
  bool _chargement = false;

  @override
  void dispose() {
    _nom.dispose();
    _email.dispose();
    _classe.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _chargement = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).modifierProfil(widget.profil.id, nom: _nom.text);
      ref.invalidate(profilProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(messageErreur(e))));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _deconnexion() async {
    await ref.read(authRepositoryProvider).deconnexion();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profil;
    final etudiant = p.role == Role.etudiant;
    return Column(
      children: [
        AppBackHeader(
          titre: 'Mon profil',
          repli: p.role.accueil,
          actions: [
            RoundIconButton(
              icone: Icons.logout_rounded,
              infobulle: 'Se déconnecter',
              onPressed: _deconnexion,
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: AppColors.violet,
                      child: Text(
                        Fmt.initiale(p.nom),
                        style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(p.nom, textAlign: TextAlign.center, style: AppText.sousTitre),
                  Text(p.sousTitre, textAlign: TextAlign.center, style: AppText.petit),
                  const SizedBox(height: 18),
                  PillField(
                    libelle: 'Nom complet',
                    controller: _nom,
                    validator: (v) => validerRequis(v, 'Le nom'),
                  ),
                  const SizedBox(height: 12),
                  PillField(libelle: 'E-mail', controller: _email, lectureSeule: true),
                  if (etudiant) ...[
                    const SizedBox(height: 12),
                    // Classe en lecture seule : seul le directeur peut la changer.
                    PillField(libelle: 'Classe', controller: _classe, lectureSeule: true),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mon visage', style: AppText.sousTitre.copyWith(fontSize: 13)),
                                Text(
                                  p.visageEnregistre
                                      ? 'Enregistré · ${p.nbCaptures} captures'
                                      : 'Non enregistré',
                                  style: AppText.petit,
                                ),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: 'Refaire',
                            couleur: AppColors.lavande,
                            onTap: () => context.push('/visage/intro'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: PillButton(
            label: 'Enregistrer',
            chargement: _chargement,
            onPressed: _enregistrer,
          ),
        ),
      ],
    );
  }
}
