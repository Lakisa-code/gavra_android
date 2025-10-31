import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../services/adrese_service.dart';

class AutocompleteAdresaField extends StatefulWidget {
  const AutocompleteAdresaField({
    Key? key,
    required this.controller,
    required this.grad,
    this.hintText,
    this.labelText,
    this.onChanged,
  }) : super(key: key);
  final TextEditingController controller;
  final String grad; // 'Bela Crkva' ili 'Vršac'
  final String? hintText;
  final String? labelText;
  final void Function(String)? onChanged;

  @override
  State<AutocompleteAdresaField> createState() => _AutocompleteAdresaFieldState();
}

class _AutocompleteAdresaFieldState extends State<AutocompleteAdresaField> {
  List<String> _filteredAdrese = [];
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  bool _isLoading = false;
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadAdrese();
    _checkConnectivity();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);

    // Listen za connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted)
        setState(() {
          _isOnline = !result.contains(ConnectivityResult.none);
        });
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted)
      setState(() {
        _isOnline = !result.contains(ConnectivityResult.none);
      });
  }

  /// Dobija ikonu na osnovu tipa adrese/mesta
  IconData _getIconForPlace(String adresa) {
    final adresaLower = adresa.toLowerCase();

    if (adresaLower.contains('bolnica') || adresaLower.contains('dom zdravlja') || adresaLower.contains('ambulanta')) {
      return Icons.local_hospital;
    } else if (adresaLower.contains('škola') || adresaLower.contains('vrtić') || adresaLower.contains('fakultet')) {
      return Icons.school;
    } else if (adresaLower.contains('pošta')) {
      return Icons.local_post_office;
    } else if (adresaLower.contains('banka')) {
      return Icons.account_balance;
    } else if (adresaLower.contains('crkva')) {
      return Icons.church;
    } else if (adresaLower.contains('park') || adresaLower.contains('stadion')) {
      return Icons.park;
    } else if (adresaLower.contains('market') ||
        adresaLower.contains('prodavnica') ||
        adresaLower.contains('trgovina')) {
      return Icons.shopping_cart;
    } else if (adresaLower.contains('restoran') || adresaLower.contains('kafić')) {
      return Icons.restaurant;
    } else if (adresaLower.contains('hotel')) {
      return Icons.hotel;
    } else if (adresaLower.contains('apoteka')) {
      return Icons.local_pharmacy;
    } else {
      return Icons.location_on;
    }
  }

  /// Dobija boju ikone na osnovu tipa mesta
  Color _getColorForPlace(String adresa) {
    final adresaLower = adresa.toLowerCase();

    if (adresaLower.contains('bolnica') || adresaLower.contains('dom zdravlja') || adresaLower.contains('ambulanta')) {
      return Colors.red[600]!;
    } else if (adresaLower.contains('škola') || adresaLower.contains('vrtić')) {
      return Colors.orange[600]!;
    } else if (adresaLower.contains('pošta')) {
      return Colors.yellow[700]!;
    } else if (adresaLower.contains('banka')) {
      return Colors.green[600]!;
    } else if (adresaLower.contains('crkva')) {
      return Colors.purple[600]!;
    } else if (adresaLower.contains('park')) {
      return Colors.green[700]!;
    } else if (adresaLower.contains('market') || adresaLower.contains('prodavnica')) {
      return Colors.blue[600]!;
    } else if (adresaLower.contains('restoran') || adresaLower.contains('kafić')) {
      return Colors.brown[600]!;
    } else {
      return Colors.blue[600]!;
    }
  }

  // _getCurrentLocation metoda uklonjena pošto se više ne koristi

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    _connectivitySubscription?.cancel();
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
    if (mounted)
      setState(() {
        _filteredAdrese = adrese;
      });
  }

  Future<void> _filterAdrese(String query) async {
    if (mounted)
      setState(() {
        _isLoading = true;
      });

    try {
      final adrese = await AdreseService.pretraziAdrese(widget.grad, query);
      if (mounted)
        setState(() {
          _filteredAdrese = adrese;
          _isLoading = false;
          // Prikaži overlay samo ako ima unos ili je fokusiran
          if (_focusNode.hasFocus && adrese.isNotEmpty) {
            _showOverlay();
          } else {
            _removeOverlay();
          }
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
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
                if (widget.controller.text.isEmpty && _filteredAdrese.isNotEmpty)
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
                        leading: Icon(
                          _getIconForPlace(adresa),
                          color: _getColorForPlace(adresa),
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
                // OpenStreetMap attribution
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Powered by OpenStreetMap',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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
              color: widget.controller.text.trim().isNotEmpty ? Colors.green : Colors.orange,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Loading indicator
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                // Offline indicator
                if (!_isOnline)
                  Icon(
                    Icons.wifi_off,
                    color: Colors.orange[600],
                    size: 18,
                  ),
                // Success indicator
                if (widget.controller.text.trim().isNotEmpty && !_isLoading)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.controller.text.trim().isNotEmpty ? Colors.green : Colors.grey,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.controller.text.trim().isNotEmpty ? Colors.green : Colors.grey.withOpacity(0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.controller.text.trim().isNotEmpty ? Colors.green : Colors.blue,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (value) {
            if (mounted) setState(() {}); // Refresh UI
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
        // GPS dugme za trenutnu lokaciju
        // Uklonjen 'Trenutna lokacija' dugme po korisnikovom zahtevu
      ],
    );
  }
}
