import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/supabase/supabase_providers.dart';
import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/utils/messages_erreur.dart';
import 'package:classcheck/core/utils/validateurs.dart';
import 'package:classcheck/core/widgets/widgets.dart';
import 'package:classcheck/features/auth/data/auth_repository.dart';
import 'package:classcheck/features/auth/domain/profil.dart';

/// Maquette « Connexion » (Bon retour).
class ConnexionScreen extends ConsumerStatefulWidget {
  const ConnexionScreen({super.key});

  @override
  ConsumerState<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends ConsumerState<ConnexionScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  Role _role = Role.etudiant;
  bool _chargement = false;
  String? _erreur;

  @override
  void dispose() {
    _email.dispose();
    _mdp.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final repo = ref.read(authRepositoryProvider);
    final busy = ref.read(authBusyProvider.notifier);
    busy.state = true;
    try {
      await repo.connexion(_email.text, _mdp.text);
      // Vérifie que le rôle choisi correspond au compte.
      final uid = ref.read(supabaseProvider).auth.currentUser?.id;
      final profil = uid == null ? null : await repo.profil(uid);
      if (profil != null && profil.role != _role) {
        await repo.deconnexion();
        _erreur = 'Ce compte est un compte « ${profil.role.libelle} ». '
            'Sélectionnez le bon rôle.';
      }
    } catch (e) {
      _erreur = messageErreur(e);
    } finally {
      busy.state = false;
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _motDePasseOublie() async {
    if (validerEmail(_email.text) != null) {
      setState(() => _erreur = 'Saisissez d\'abord votre e-mail.');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).motDePasseOublie(_email.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Un lien de réinitialisation vous a été envoyé.')),
      );
    } catch (e) {
      setState(() => _erreur = messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lavande,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bon retour', style: AppText.grandTitre),
                        const SizedBox(height: 6),
                        Text('Connectez-vous pour pointer votre présence',
                            style: AppText.secondaire),
                      ],
                    ),
                  ),
                  const Icon(Icons.qr_code_2_rounded, size: 52, color: AppColors.bleu),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.fond,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                  child: Form(
                    key: _form,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PillTabs<Role>(
                            etirer: true,
                            options: [for (final r in Role.values) (r, r.libelle)],
                            valeur: _role,
                            onChanged: (r) => setState(() => _role = r),
                          ),
                          const SizedBox(height: 22),
                          PillField(
                            libelle: 'E-mail',
                            controller: _email,
                            indice: 'ali@ecole.tn',
                            clavier: TextInputType.emailAddress,
                            actionClavier: TextInputAction.next,
                            autofill: const [AutofillHints.email],
                            validator: validerEmail,
                          ),
                          const SizedBox(height: 14),
                          PillField(
                            libelle: 'Mot de passe',
                            controller: _mdp,
                            motDePasse: true,
                            autofill: const [AutofillHints.password],
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _motDePasseOublie,
                              child: Text('Mot de passe oublié ?', style: AppText.lien),
                            ),
                          ),
                          if (_erreur != null) ...[
                            Text(_erreur!,
                                textAlign: TextAlign.center,
                                style: AppText.secondaire
                                    .copyWith(color: Theme.of(context).colorScheme.error)),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 8),
                          PillButton(
                            label: 'Se connecter',
                            chargement: _chargement,
                            onPressed: _seConnecter,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Pas encore de compte ? ', style: AppText.secondaire),
                              GestureDetector(
                                onTap: () => context.pushReplacement('/inscription'),
                                child: Text('S\'inscrire', style: AppText.lien),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
