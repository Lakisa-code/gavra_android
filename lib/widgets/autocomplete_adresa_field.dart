import 'package:flutter/material.dart';
import '../services/adrese_service.dart';

class AutocompleteAdresaField extends StatefulWidget {
  final TextEditingController controller;
  final String grad; // 'Bela Crkva' ili 'Vršac'
  final String? hintText;
  final String? labelText;
  final Function(String)? onChanged;

  const AutocompleteAdresaField({
    Key? key,
    required this.controller,
    required this.grad,
    this.hintText,
    this.labelText,
    this.onChanged,
  }) : super(key: key);

  @override
  State<AutocompleteAdresaField> createState() =>
      _AutocompleteAdresaFieldState();
}

class _AutocompleteAdresaFieldState extends State<AutocompleteAdresaField> {
  List<String> _filteredAdrese = [];
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _loadAdrese();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _filteredAdrese.isNotEmpty) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _onTextChanged() {
    _filterAdrese(widget.controller.text);
    widget.onChanged?.call(widget.controller.text);
  }

  Future<void> _loadAdrese() async {
    final adrese = await AdreseService.getAdreseZaGrad(widget.grad);
    setState(() {
      _filteredAdrese = adrese;
    });
  }

  Future<void> _filterAdrese(String query) async {
    final adrese = await AdreseService.pretraziAdrese(widget.grad, query);
    setState(() {
      _filteredAdrese = adrese;
      // Prikaži overlay samo ako ima unos ili je fokusiran
      if (_focusNode.hasFocus && adrese.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();

    if (_filteredAdrese.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                // Opcija "Bez adrese" - prikazuje se kad je fokusiran ali prazan
                if (widget.controller.text.isEmpty)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.location_off,
                      color: Colors.grey,
                      size: 18,
                    ),
                    title: Text(
                      'Bez adrese',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    subtitle: Text(
                      'Putnik se dodaje bez adrese',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    onTap: () {
                      widget.controller.clear();
                      _removeOverlay();
                      _focusNode.unfocus();
                    },
                  ),
                // Separator ako ima i opciju bez adrese i adrese
                if (widget.controller.text.isEmpty &&
                    _filteredAdrese.isNotEmpty)
                  Divider(height: 1, color: Colors.grey[300]),
                // ListView.builder za adrese
                Flexible(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _filteredAdrese.take(8).length,
                    itemBuilder: (context, index) {
                      final adresa = _filteredAdrese[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 18,
                        ),
                        title: Text(
                          adresa,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          widget.grad,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        onTap: () async {
                          widget.controller.text = adresa;
                          _removeOverlay();
                          _focusNode.unfocus();

                          // Dodaj adresu u često korišćene
                          await AdreseService.dodajAdresu(widget.grad, adresa);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText ?? 'Adresa',
            hintText: widget.hintText ?? 'Unesite adresu...',
            prefixIcon: Icon(
              Icons.location_on,
              color: widget.controller.text.trim().isNotEmpty
                  ? Colors.green
                  : Colors.orange,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.controller.text.trim().isNotEmpty)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.grad.toLowerCase() == 'bela crkva'
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: widget.grad.toLowerCase() == 'bela crkva'
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.purple.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    widget.grad == 'Bela Crkva' ? 'BC' : 'VS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: widget.grad.toLowerCase() == 'bela crkva'
                          ? Colors.blue[700]
                          : Colors.purple[700],
                    ),
                  ),
                ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.controller.text.trim().isNotEmpty
                    ? Colors.green
                    : Colors.grey,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.controller.text.trim().isNotEmpty
                    ? Colors.green
                    : Colors.grey.withOpacity(0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.controller.text.trim().isNotEmpty
                    ? Colors.green
                    : (widget.grad.toLowerCase() == 'bela crkva'
                        ? Colors.blue
                        : Colors.purple),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: widget.controller.text.trim().isNotEmpty
                ? Colors.green.withOpacity(0.1)
                : (widget.grad.toLowerCase() == 'bela crkva'
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.purple.withOpacity(0.1)),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            setState(() {}); // Refresh UI
          },
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              if (value.trim().length < 3) {
                return 'Adresa je prekratka (min 3 karaktera)';
              }
              if (!RegExp(r'^[a-žA-Ž0-9\s.,/-]+$').hasMatch(value.trim())) {
                return 'Adresa sadrži neispravne karaktere';
              }
            }
            return null;
          },
        ),
        // Info widget
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.grad.toLowerCase() == 'bela crkva'
                ? Colors.blue.withOpacity(0.1)
                : Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.grad.toLowerCase() == 'bela crkva'
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.purple.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.controller.text.trim().isNotEmpty
                    ? Icons.location_on
                    : Icons.info_outline,
                color: widget.grad.toLowerCase() == 'bela crkva'
                    ? Colors.blue[700]
                    : Colors.purple[700],
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.controller.text.trim().isNotEmpty
                      ? '📍 Filtriraju se adrese samo za ${widget.grad}'
                      : '💡 Adresa je opciona - možete ostaviti prazno',
                  style: TextStyle(
                    color: widget.grad.toLowerCase() == 'bela crkva'
                        ? Colors.blue[700]
                        : Colors.purple[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

