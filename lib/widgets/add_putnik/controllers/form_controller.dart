import 'dart:async';

import 'package:flutter/material.dart';

import '../models/add_putnik_form_data.dart';
import '../validation/putnik_validator.dart';

/// 🎮 Centralizovani controller za dodavanje putnika
/// Upravlja state-om, validacijom i cleanup-om
class AddPutnikFormController extends ChangeNotifier {
  // Form data model
  AddPutnikFormData _formData = AddPutnikFormData();

  // Validation rezultat
  ValidationResult _validationResult = ValidationResult({});

  // Text controllers (lazy loading)
  final Map<String, TextEditingController> _controllers = {};

  // Real-time validation debounce
  Timer? _validationTimer;

  // Loading state
  bool _isLoading = false;

  // Getters
  AddPutnikFormData get formData => _formData;
  ValidationResult get validationResult => _validationResult;
  bool get isLoading => _isLoading;
  bool get isValid => _validationResult.isValid;

  /// 📱 Lazy controller creation pattern
  TextEditingController getController(String fieldName) {
    if (!_controllers.containsKey(fieldName)) {
      _controllers[fieldName] = TextEditingController();

      // Auto-populate sa trenutnim podacima
      switch (fieldName) {
        case 'ime':
          _controllers[fieldName]!.text = _formData.ime;
          break;
        case 'tipSkole':
          _controllers[fieldName]!.text = _formData.tipSkole ?? '';
          break;
        case 'brojTelefona':
          _controllers[fieldName]!.text = _formData.brojTelefona ?? '';
          break;
        case 'brojTelefonaOca':
          _controllers[fieldName]!.text = _formData.brojTelefonaOca ?? '';
          break;
        case 'brojTelefonaMajke':
          _controllers[fieldName]!.text = _formData.brojTelefonaMajke ?? '';
          break;
        case 'adresaBelaCrkva':
          _controllers[fieldName]!.text = _formData.adresaBelaCrkva ?? '';
          break;
        case 'adresaVrsac':
          _controllers[fieldName]!.text = _formData.adresaVrsac ?? '';
          break;
        // Vremena - format: vreme_bc_pon, vreme_vs_utorak, itd.
        default:
          if (fieldName.startsWith('vreme_bc_')) {
            final dan = fieldName.replaceFirst('vreme_bc_', '');
            _controllers[fieldName]!.text =
                _formData.vremenaBelaCrkva[dan] ?? '';
          } else if (fieldName.startsWith('vreme_vs_')) {
            final dan = fieldName.replaceFirst('vreme_vs_', '');
            _controllers[fieldName]!.text = _formData.vremenaVrsac[dan] ?? '';
          }
          break;
      }

      // Add listener za real-time sync
      _controllers[fieldName]!.addListener(() {
        _syncControllerToModel(fieldName);
      });
    }

    return _controllers[fieldName]!;
  }

  /// 🔄 Sync controller vrednosti sa modelom
  void _syncControllerToModel(String fieldName) {
    final value = _controllers[fieldName]?.text ?? '';

    switch (fieldName) {
      case 'ime':
        _formData = _formData.copyWith(ime: value);
        break;
      case 'tipSkole':
        _formData = _formData.copyWith(tipSkole: value.isEmpty ? null : value);
        break;
      case 'brojTelefona':
        _formData =
            _formData.copyWith(brojTelefona: value.isEmpty ? null : value);
        break;
      case 'brojTelefonaOca':
        _formData =
            _formData.copyWith(brojTelefonaOca: value.isEmpty ? null : value);
        break;
      case 'brojTelefonaMajke':
        _formData =
            _formData.copyWith(brojTelefonaMajke: value.isEmpty ? null : value);
        break;
      case 'adresaBelaCrkva':
        _formData =
            _formData.copyWith(adresaBelaCrkva: value.isEmpty ? null : value);
        break;
      case 'adresaVrsac':
        _formData =
            _formData.copyWith(adresaVrsac: value.isEmpty ? null : value);
        break;
      default:
        // Handle vremena
        if (fieldName.startsWith('vreme_bc_')) {
          final dan = fieldName.replaceFirst('vreme_bc_', '');
          final novaVremena =
              Map<String, String>.from(_formData.vremenaBelaCrkva);
          novaVremena[dan] = value;
          _formData = _formData.copyWith(vremenaBelaCrkva: novaVremena);
        } else if (fieldName.startsWith('vreme_vs_')) {
          final dan = fieldName.replaceFirst('vreme_vs_', '');
          final novaVremena = Map<String, String>.from(_formData.vremenaVrsac);
          novaVremena[dan] = value;
          _formData = _formData.copyWith(vremenaVrsac: novaVremena);
        }
        break;
    }

    // Debounced validation
    _scheduleValidation();

    // Notify listeners
    notifyListeners();
  }

  /// 🎯 Update tip putnika
  void updateTip(String tip) {
    _formData = _formData.copyWith(tip: tip);
    _scheduleValidation();
    notifyListeners();
  }

  /// 📅 Update radni dan
  void updateRadniDan(String dan, bool selected) {
    final noviRadniDani = Map<String, bool>.from(_formData.radniDani);
    noviRadniDani[dan] = selected;
    _formData = _formData.copyWith(radniDani: noviRadniDani);
    _scheduleValidation();
    notifyListeners();
  }

  /// ⚡ Postavlja sve radne dane
  void setAllWorkingDays(bool selected) {
    final noviRadniDani = <String, bool>{};
    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      noviRadniDani[dan] = selected;
    }
    _formData = _formData.copyWith(radniDani: noviRadniDani);
    _scheduleValidation();
    notifyListeners();
  }

  /// 🕐 Popuni standardna vremena
  void popuniStandardnaVremena(String tip) {
    Map<String, String> bcVremena = {};
    Map<String, String> vsVremena = {};

    switch (tip) {
      case 'jutarnja_smena':
        for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
          bcVremena[dan] = '06:00';
          vsVremena[dan] = '14:00';
        }
        break;
      case 'popodnevna_smena':
        for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
          bcVremena[dan] = '14:00';
          vsVremena[dan] = '22:00';
        }
        break;
      case 'skola':
        for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
          bcVremena[dan] = '07:30';
          vsVremena[dan] = '14:00';
        }
        break;
      case 'ocisti':
        for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
          bcVremena[dan] = '';
          vsVremena[dan] = '';
        }
        break;
    }

    _formData = _formData.copyWith(
      vremenaBelaCrkva: bcVremena,
      vremenaVrsac: vsVremena,
    );

    // Update kontroleri
    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      final bcController = _controllers['vreme_bc_$dan'];
      final vsController = _controllers['vreme_vs_$dan'];

      if (bcController != null) {
        bcController.text = bcVremena[dan] ?? '';
      }
      if (vsController != null) {
        vsController.text = vsVremena[dan] ?? '';
      }
    }

    _scheduleValidation();
    notifyListeners();
  }

  /// ⏰ Schedule validation sa debounce
  void _scheduleValidation() {
    _validationTimer?.cancel();
    _validationTimer = Timer(const Duration(milliseconds: 300), () {
      _validateForm();
    });
  }

  /// 🔍 Immediate validacija
  void _validateForm() {
    _validationResult = PutnikValidator.validateForm(_formData);
    notifyListeners();
  }

  /// 🔥 Forsiraj validaciju (za submit)
  bool validateNow() {
    _validationResult = PutnikValidator.validateForm(_formData);
    notifyListeners();
    return _validationResult.isValid;
  }

  /// 🧹 Reset ceo form
  void resetForm() {
    // Clear controllers
    for (final controller in _controllers.values) {
      controller.clear();
    }

    // Reset data
    _formData.reset();
    _validationResult = ValidationResult({});
    _isLoading = false;

    notifyListeners();
  }

  /// ⚡ Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 🎯 Da li je polje označeno kao radni dan
  bool isWorkingDay(String dan) {
    return _formData.radniDani[dan] ?? false;
  }

  /// 📊 Broj označenih radnih dana
  int get workingDaysCount => _formData.workingDaysCount;

  /// 🔍 Get error za određeno polje
  String? getFieldError(String field) {
    return _validationResult.getError(field);
  }

  /// ✅ Da li polje ima grešku
  bool hasFieldError(String field) {
    return _validationResult.hasError(field);
  }

  @override
  void dispose() {
    // Cancel timer
    _validationTimer?.cancel();

    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    super.dispose();
  }
}
