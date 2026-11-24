import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Libellés français des codes d'erreur renvoyés par les fonctions SQL (RPC).
const libellesCodes = <String, String>{
  // Étape 1 : scan du QR
  'non_connecte': 'Vous devez être connecté.',
  'non_inscrit': 'Vous n\'êtes pas inscrit à cette séance.',
  'seance_non_ouverte': 'Le pointage n\'est pas encore ouvert pour cette séance.',
  'seance_cloturee': 'La séance est clôturée.',
  'hors_fenetre': 'La fenêtre de pointage est terminée.',
  'deja_pointe': 'Votre présence est déjà enregistrée pour cette séance.',
  'qr_invalide': 'Ce QR code n\'appartient à aucune séance.',
  'qr_expire': 'Le QR code a expiré. Scannez le code actuel.',
  // Étape 2 : validation
  'ticket_invalide': 'Ticket de pointage invalide.',
  'ticket_deja_utilise': 'Ce ticket a déjà été utilisé.',
  'ticket_expire': 'Le délai de 2 minutes après le scan est dépassé.',
  'methode_invalide': 'Méthode de pointage invalide.',
  'visage_requis': 'La vérification du visage est obligatoire.',
  'trop_de_tentatives': 'Trop de tentatives. Scannez à nouveau le QR code.',
  'vivacite_echouee': 'Le test de vivacité a échoué.',
  'embedding_invalide': 'Analyse du visage invalide.',
  'visage_non_enregistre': 'Votre visage n\'est pas encore enregistré.',
  'visage_non_reconnu': 'Votre visage n\'a pas été reconnu.',
  // Côté application
  'aucun_visage': 'Aucun visage détecté sur la photo.',
  'plusieurs_visages': 'Plusieurs visages détectés : un seul visage est accepté.',
  // Enseignant
  'acces_refuse': 'Accès refusé.',
  'seance_introuvable': 'Séance introuvable.',
  'seance_pas_aujourdhui': 'Seules les séances du jour peuvent être ouvertes.',
  'nb_captures_invalide': 'Il faut exactement 5 captures du visage.',
  'motif_obligatoire': 'Le motif est obligatoire.',
  // Visage (précision renforcée)
  'captures_incoherentes':
      'Les 5 captures ne se ressemblent pas assez. Recommencez, bien éclairé et seul face à la caméra.',
  'visage_deja_utilise': 'Ce visage est déjà enregistré sur un autre compte.',
  'visage_flou': 'Photo floue : tenez le téléphone immobile.',
  'mauvais_eclairage': 'Éclairage insuffisant ou trop fort : placez-vous face à la lumière.',
  'visage_de_profil': 'Regardez la caméra bien en face.',
  'visage_trop_petit': 'Approchez-vous de la caméra.',
  'yeux_fermes': 'Gardez les yeux ouverts pendant la photo.',
  // Sprint 2
  'introuvable': 'Élément introuvable (il a peut-être été supprimé).',
  'deja_traitee': 'Cette demande a déjà été traitée.',
  'decision_invalide': 'Décision invalide.',
  'statut_invalide': 'Statut invalide.',
  'recours_impossible': "Un recours n'est possible qu'après un refus de l'enseignant.",
  'role_invalide': 'Rôle invalide.',
  'action_interdite': 'Vous ne pouvez pas retirer vos propres droits de directeur.',
  'email_invalide': 'E-mail invalide.',
  'email_existe': 'Un compte existe déjà avec cet e-mail.',
  'mot_de_passe_faible': 'Mot de passe trop faible (8 caractères minimum).',
  'horaire_invalide': "L'heure de fin doit être après l'heure de début.",
  'semaines_invalides': 'Nombre de semaines invalide (1 à 30).',
  'duplicate key': 'Une demande existe déjà pour cette séance.',
};

/// Convertit n'importe quelle erreur en message lisible pour l'utilisateur.
String messageErreur(Object erreur) {
  if (erreur is AuthException) {
    final m = erreur.message.toLowerCase();
    if (m.contains('invalid login')) return 'E-mail ou mot de passe incorrect.';
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'Un compte existe déjà avec cet e-mail.';
    }
    if (m.contains('email not confirmed')) {
      return 'Confirmez d\'abord votre e-mail (lien reçu par courriel).';
    }
    if (m.contains('password')) return 'Mot de passe trop faible (8 caractères minimum).';
    if (m.contains('rate limit')) return 'Trop de tentatives. Réessayez dans un instant.';
    return erreur.message;
  }
  if (erreur is PostgrestException) {
    return libellesCodes[erreur.message] ?? 'Erreur serveur : ${erreur.message}';
  }
  if (erreur is SocketException || erreur is TimeoutException) {
    return 'Connexion impossible. Vérifiez votre accès à Internet.';
  }
  final texte = erreur.toString();
  for (final entree in libellesCodes.entries) {
    if (texte.contains(entree.key)) return entree.value;
  }
  if (texte.contains('ClientException') || texte.contains('SocketException')) {
    return 'Connexion impossible. Vérifiez votre accès à Internet.';
  }
  return 'Une erreur est survenue. Réessayez.';
}
