import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:classcheck/core/theme/app_theme.dart';
import 'package:classcheck/core/widgets/round_icon_button.dart';

/// En-tête « ← Titre » des écrans secondaires.
class AppBackHeader extends StatelessWidget {
  const AppBackHeader({
    super.key,
    required this.titre,
    this.actions = const [],
    this.repli = '/',
    this.onRetour,
  });

  final String titre;
  final List<Widget> actions;

  /// Route utilisée si la pile de navigation est vide.
  final String repli;
  final VoidCallback? onRetour;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          RoundIconButton(
            icone: Icons.arrow_back,
            infobulle: 'Retour',
            onPressed: onRetour ??
                () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(repli);
                  }
                },
          ),
          Expanded(
            child: Text(
              titre,
              textAlign: TextAlign.center,
              style: AppText.entete,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actions.isEmpty) const SizedBox(width: 44) else ...actions,
        ],
      ),
    );
  }
}
