import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/formatters.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/utils/validateurs.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/auth/data/auth_repository.dart';
import 'package:classcheck/features/auth/domain/profil.dart';

/// Maquette « Inscription » — étape 1 sur 2 (l'étape 2 est l'enregistrement du visage).
class InscriptionScreen extends ConsumerStatefulWidget {
  const InscriptionScreen({super.key});

  @override
  ConsumerState<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends ConsumerState<InscriptionScreen> {
  final _form = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _classe = TextEditingController();
  final _mdp = TextEditingController();
  Role _role = Role.etudiant;
  bool _chargement = false;
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _email.dispose();
    _classe.dispose();
    _mdp.dispose();
    super.dispose();
  }

  Future<void> _continuer() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final busy = ref.read(authBusyProvider.notifier);
    busy.state = true;
    var confirmationEmail = false;
    try {
      final res = await ref.read(authRepositoryProvider).inscription(
            email: _email.text,
            motDePasse: _mdp.text,
            nom: _nom.text,
            role: _role,
            classe: _role == Role.etudiant ? Fmt.normaliserClasse(_classe.text) : null,
          );
      // Si la confirmation d'e-mail est activée dans Supabase, aucune session n'est ouverte.
      confirmationEmail = res.session == null;
    } catch (e) {
      _erreur = messageErreur(e);
    } finally {
      busy.state = false;
      if (mounted) setState(() => _chargement = false);
    }
    if (!mounted || !confirmationEmail) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmez votre e-mail'),
        content: const Text(
          'Un lien de confirmation vous a été envoyé. Ouvrez-le, puis connectez-vous.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    if (mounted) context.go('/connexion');
  }

  @override
  Widget build(BuildContext context) {
    final etudiant = _role == Role.etudiant;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBackHeader(titre: 'Créer un compte'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PillTabs<Role>(
                        etirer: true,
                        options: [for (final r in Role.values) (r, r.libelle)],
                        valeur: _role,
                        onChanged: (r) => setState(() => _role = r),
                      ),
                      if (!etudiant)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Les comptes ${_role.libelle.toLowerCase()} sont activés par le directeur.',
                            style: AppText.petit,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 18),
                      PillField(
                        libelle: 'Nom complet',
                        controller: _nom,
                        indice: 'Ali Ben Salah',
                        actionClavier: TextInputAction.next,
                        validator: (v) => validerRequis(v, 'Le nom'),
                      ),
                      const SizedBox(height: 14),
                      PillField(
                        libelle: 'E-mail',
                        controller: _email,
                        indice: 'ali@ecole.tn',
                        clavier: TextInputType.emailAddress,
                        actionClavier: TextInputAction.next,
                        validator: validerEmail,
                      ),
                      if (etudiant) ...[
                        const SizedBox(height: 14),
                        PillField(
                          libelle: 'Classe',
                          controller: _classe,
                          indice: 'DSI 2',
                          actionClavier: TextInputAction.next,
                          validator: validerClasse,
                        ),
                      ],
                      const SizedBox(height: 14),
                      PillField(
                        libelle: 'Mot de passe',
                        controller: _mdp,
                        motDePasse: true,
                        validator: validerMotDePasse,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _segment(AppColors.violet),
                          const SizedBox(width: 4),
                          _segment(AppColors.puce),
                          const SizedBox(width: 10),
                          Text('Étape 1 sur 2', style: AppText.petit),
                        ],
                      ),
                      if (_erreur != null) ...[
                        const SizedBox(height: 14),
                        Text(_erreur!,
                            textAlign: TextAlign.center,
                            style: AppText.secondaire
                                .copyWith(color: Theme.of(context).colorScheme.error)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: PillButton(
                label: 'Continuer',
                chargement: _chargement,
                onPressed: _continuer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(Color c) => Container(
        width: 22,
        height: 5,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
      );
}
