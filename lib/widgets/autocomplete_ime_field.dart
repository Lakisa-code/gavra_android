import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/imena_service.dart';

class AutocompleteImeField extends StatefulWidget {
  const AutocompleteImeField({
    Key? key,
    required this.controller,
    this.hintText,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.mesecnaKarta = false,
    this.dozvoljenaImena,
  }) : super(key: key);
  final TextEditingController controller;
  final String? hintText;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool mesecnaKarta;
  final List<String>? dozvoljenaImena;

  @override
  State<AutocompleteImeField> createState() => _AutocompleteImeFieldState();
}

class _AutocompleteImeFieldState extends State<AutocompleteImeField> {
  @override
  Widget build(BuildContext context) {
    return TypeAheadField<String>(
      controller: widget.controller,
      builder: (context, controller, focusNode) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            hintText: widget.mesecnaKarta
                ? 'Ime putnika (samo dozvoljena imena)'
                : (widget.hintText ?? 'Ime putnika'),
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.9),
            prefixIcon: Icon(
              widget.mesecnaKarta ? Icons.verified_user : Icons.person,
              color: widget.mesecnaKarta ? Colors.green : Colors.blue,
            ),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged?.call('');
                    },
                  )
                : null,
          ),
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
          textCapitalization: TextCapitalization.words,
          validator: widget.validator,
          onChanged: (value) {
            if (mounted) setState(() {}); // Za suffixIcon
            widget.onChanged?.call(value);
          },
        );
      },
      suggestionsCallback: (pattern) async {
        if (pattern.isEmpty) return [];

        // Za mesečne karte koristi dozvoljena imena
        if (widget.mesecnaKarta && widget.dozvoljenaImena != null) {
          return widget.dozvoljenaImena!
              .where((ime) => ime.toLowerCase().contains(pattern.toLowerCase()))
              .toList();
        }

        // Inače koristi česta imena iz servisa
        return await ImenaService.pretraziImena(pattern);
      },
      itemBuilder: (context, suggestion) {
        return ListTile(
          leading: Icon(
            widget.mesecnaKarta ? Icons.verified_user : Icons.person_outline,
            color: widget.mesecnaKarta ? Colors.green : Colors.blue,
          ),
          title: Text(
            suggestion,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            widget.mesecnaKarta
                ? 'Dozvoljen za mesečnu kartu'
                : 'Često korišćeno ime',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
        );
      },
      onSelected: (suggestion) {
        widget.controller.text = suggestion;
        widget.onChanged?.call(suggestion);

        // Dodaj ime u česta imena
        ImenaService.dodajIme(suggestion);
      },
      hideOnEmpty: true,
      hideOnError: true,
      loadingBuilder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.blue),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Pretražujem imena...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      },
      errorBuilder: (context, error) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Greška pri pretragama: $error',
            style: const TextStyle(color: Colors.red),
          ),
        );
      },
      emptyBuilder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: const Text(
            'Nema predloga za ovo ime',
            style: TextStyle(color: Colors.grey),
          ),
        );
      },
    );
  }
}
