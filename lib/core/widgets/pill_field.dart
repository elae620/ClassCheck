import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:classcheck/core/theme/app_colors.dart';
import 'package:classcheck/core/theme/app_theme.dart';

/// Champ de saisie en pilule (hauteur 52) avec libellé au-dessus.
class PillField extends StatefulWidget {
  const PillField({
    super.key,
    required this.libelle,
    this.controller,
    this.indice,
    this.motDePasse = false,
    this.lignes = 1,
    this.clavier,
    this.validator,
    this.lectureSeule = false,
    this.actionClavier,
    this.autofill,
    this.onChanged,
  });

  final String libelle;
  final TextEditingController? controller;
  final String? indice;
  final bool motDePasse;
  final int lignes;
  final TextInputType? clavier;
  final String? Function(String?)? validator;
  final bool lectureSeule;
  final TextInputAction? actionClavier;
  final Iterable<String>? autofill;
  final ValueChanged<String>? onChanged;

  @override
  State<PillField> createState() => _PillFieldState();
}

class _PillFieldState extends State<PillField> {
  late bool _masque = widget.motDePasse;

  @override
  Widget build(BuildContext context) {
    final multiligne = widget.lignes > 1;
    final radius = BorderRadius.circular(multiligne ? 22 : 26);
    final bordure = OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(widget.libelle, style: AppText.petit),
        ),
        TextFormField(
          controller: widget.controller,
          obscureText: _masque,
          maxLines: widget.motDePasse ? 1 : widget.lignes,
          minLines: multiligne ? widget.lignes : 1,
          keyboardType: widget.clavier,
          validator: widget.validator,
          readOnly: widget.lectureSeule,
          textInputAction: widget.actionClavier,
          autofillHints: widget.autofill,
          onChanged: widget.onChanged,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: widget.lectureSeule ? AppColors.texteSecondaire : AppColors.texte,
          ),
          decoration: InputDecoration(
            hintText: widget.indice,
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.texteSecondaire),
            filled: true,
            fillColor: AppColors.blanc,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: multiligne ? 16 : 17,
            ),
            border: bordure,
            enabledBorder: bordure,
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(color: AppColors.violet, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(color: Color(0xFFE08A80)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(color: Color(0xFFE08A80), width: 1.5),
            ),
            errorStyle: GoogleFonts.poppins(fontSize: 11),
            suffixIcon: widget.motDePasse
                ? IconButton(
                    icon: Icon(
                      _masque ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.texteSecondaire,
                    ),
                    onPressed: () => setState(() => _masque = !_masque),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
