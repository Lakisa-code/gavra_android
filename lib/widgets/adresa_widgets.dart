import 'package:flutter/material.dart';

import '../models/mesecni_putnik.dart';
import '../services/adresa_supabase_service.dart';

/// Widget za prikaz adresa mesečnog putnika sa UUID referencama
class AdresaPrikazWidget extends StatelessWidget {
  const AdresaPrikazWidget({
    super.key,
    required this.putnik,
    this.showBelaCrkva = true,
    this.showVrsac = true,
    this.style,
    this.compactMode = false,
  });

  final MesecniPutnik putnik;
  final bool showBelaCrkva;
  final bool showVrsac;
  final TextStyle? style;
  final bool compactMode;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getAdresePrikaz(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return compactMode
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Učitavam adrese...'),
                  ],
                );
        }

        if (snapshot.hasError) {
          return Text(
            'Greška pri učitavanju adresa',
            style: style?.copyWith(color: Colors.red) ?? TextStyle(color: Colors.red.shade600),
          );
        }

        final adreseTekst = snapshot.data ?? 'Nema adresa';

        if (compactMode) {
          return Text(
            adreseTekst,
            style: style,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
        }

        return Row(
          children: [
            Icon(
              Icons.location_on,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                adreseTekst,
                style: style,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String> _getAdresePrikaz() async {
    final adrese = <String>[];

    if (showBelaCrkva && putnik.adresaBelaCrkvaId != null) {
      final bcNaziv = await AdresaSupabaseService.getNazivAdreseByUuid(
        putnik.adresaBelaCrkvaId,
      );
      if (bcNaziv != null) {
        adrese.add(compactMode ? bcNaziv : '🏠 BC: $bcNaziv');
      }
    }

    if (showVrsac && putnik.adresaVrsacId != null) {
      final vsNaziv = await AdresaSupabaseService.getNazivAdreseByUuid(
        putnik.adresaVrsacId,
      );
      if (vsNaziv != null) {
        adrese.add(compactMode ? vsNaziv : '🏢 VS: $vsNaziv');
      }
    }

    if (adrese.isEmpty) {
      return 'Nema adresa';
    }

    return compactMode ? adrese.join(', ') : adrese.join(' | ');
  }
}

/// Widget za dropdown adresa sa UUID referencama
class AdresaDropdownWidget extends StatefulWidget {
  const AdresaDropdownWidget({
    super.key,
    required this.grad,
    required this.onChanged,
    this.initialValue,
    this.hint,
    this.label,
    this.prefixIcon,
  });

  final String grad; // 'Bela Crkva' ili 'Vršac'
  final void Function(String? adresaId) onChanged;
  final String? initialValue;
  final String? hint;
  final String? label;
  final Widget? prefixIcon;

  @override
  State<AdresaDropdownWidget> createState() => _AdresaDropdownWidgetState();
}

class _AdresaDropdownWidgetState extends State<AdresaDropdownWidget> {
  List<Map<String, dynamic>> _adrese = [];
  bool _loading = true;
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
    _loadAdrese();
  }

  Future<void> _loadAdrese() async {
    setState(() => _loading = true);

    try {
      final adrese = await AdresaSupabaseService.getAdreseDropdownData(widget.grad);
      setState(() {
        _adrese = adrese;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Učitavam adrese...'),
            ],
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use - value is valid for DropdownButtonFormField
      initialValue: _selectedValue,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(
          child: Text('-- Izaberi adresu --'),
        ),
        ..._adrese.map((adresa) {
          return DropdownMenuItem<String>(
            value: adresa['id'] as String,
            child: Text(adresa['naziv'] as String),
          );
        }),
      ],
      onChanged: (value) {
        setState(() => _selectedValue = value);
        widget.onChanged(value);
      },
    );
  }
}

/// Widget za autocomplete adresa sa UUID referencama
class AdresaAutocompleteWidget extends StatefulWidget {
  const AdresaAutocompleteWidget({
    super.key,
    required this.grad,
    required this.onChanged,
    this.controller,
    this.initialValue,
    this.hint,
    this.label,
    this.prefixIcon,
  });

  final String grad;
  final void Function(String? adresaId, String? adresaNaziv) onChanged;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? label;
  final Widget? prefixIcon;

  @override
  State<AdresaAutocompleteWidget> createState() => _AdresaAutocompleteWidgetState();
}

class _AdresaAutocompleteWidgetState extends State<AdresaAutocompleteWidget> {
  late TextEditingController _controller;
  String? _selectedAdresaId;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, dynamic>>.empty();
        }

        final adrese = await AdresaSupabaseService.searchAdrese(
          textEditingValue.text,
          grad: widget.grad,
        );

        return adrese.map(
          (adresa) => {
            'id': adresa.id,
            'naziv': adresa.naziv,
            'displayText': adresa.displayAddress,
          },
        );
      },
      displayStringForOption: (option) => option['naziv'] as String,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sinhronizuj sa spoljnim kontrolerom
        if (widget.controller != null && _controller != widget.controller) {
          _controller = widget.controller!;
        }

        return TextFormField(
          controller: _controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon,
            border: const OutlineInputBorder(),
          ),
          onFieldSubmitted: (value) => onFieldSubmitted(),
        );
      },
      onSelected: (option) {
        _selectedAdresaId = option['id'] as String;
        _controller.text = option['naziv'] as String;
        widget.onChanged(_selectedAdresaId, option['naziv'] as String);
      },
    );
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }
}
