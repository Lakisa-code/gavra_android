import 'package:flutter/material.dart';

import '../../models/mesecni_putnik.dart';
import '../../services/adresa_supabase_service.dart';
import '../../services/mesecni_putnik_service.dart';
import '../../services/realtime_service.dart';
import 'controllers/form_controller.dart';
import 'sections/addresses_section.dart';
import 'sections/basic_info_section.dart';
import 'sections/contact_info_section.dart';
import 'sections/times_section.dart';
import 'sections/working_days_section.dart';

/// 🎯 Glavni dialog za dodavanje novog putnika
/// Refaktorisan iz monolitnog popup-a u modularni widget
class AddPutnikDialog extends StatefulWidget {
  /// Callback pozvan kada se putnik uspešno doda
  final Function(MesecniPutnik)? onPutnikAdded;

  const AddPutnikDialog({
    Key? key,
    this.onPutnikAdded,
  }) : super(key: key);

  @override
  State<AddPutnikDialog> createState() => _AddPutnikDialogState();
}

class _AddPutnikDialogState extends State<AddPutnikDialog> {
  late AddPutnikFormController _formController;
  final MesecniPutnikService _mesecniPutnikService = MesecniPutnikService();

  @override
  void initState() {
    super.initState();
    _formController = AddPutnikFormController();
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight * 0.9;
          return Container(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            decoration: BoxDecoration(
              gradient: _createGradient(),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.13),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildHeader(),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BasicInfoSection(controller: _formController),
                        ContactInfoSection(controller: _formController),
                        WorkingDaysSection(controller: _formController),
                        AddressesSection(controller: _formController),
                        TimesSection(controller: _formController),
                      ],
                    ),
                  ),
                ),

                // Actions
                _buildActions(),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 🎨 Header sa glassmorphism stilom
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        final tip = _formController.formData.tip;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.13),
              ),
            ),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey('${tip}_add'),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getTypeColor(tip).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _getTypeIcon(tip),
                        key: ValueKey(tip),
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '✨ Dodaj ${tip == 'ucenik' ? 'učenika' : 'radnika'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Close button
              GestureDetector(
                onTap: () {
                  _formController.resetForm();
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🔘 Actions deo sa dugmadima
  Widget _buildActions() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.13),
              ),
            ),
          ),
          child: Row(
            children: [
              // Cancel button
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: TextButton(
                    onPressed: () {
                      _formController.resetForm();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Otkaži',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 15),

              // Save button
              Expanded(
                flex: 2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _formController.isLoading ? null : _sacuvajPutnika,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: _formController.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.save,
                            color: Colors.white,
                            size: 20,
                          ),
                    label: Text(
                      _formController.isLoading ? 'Čuva...' : 'Sačuvaj',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 💾 Čuvanje novog putnika
  Future<void> _sacuvajPutnika() async {
    // Validacija
    if (!_formController.validateNow()) {
      final firstError = _formController.validationResult.firstError;
      if (firstError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(firstError),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _formController.setLoading(true);

    try {
      final formData = _formController.formData;

      // Kreiraj ili pronađi adrese i dobij UUID-ove
      String? adresaBelaCrkvaId;
      String? adresaVrsacId;

      if (formData.adresaBelaCrkva != null && formData.adresaBelaCrkva!.isNotEmpty) {
        final adresaBC = await AdresaSupabaseService.createOrGetAdresa(
          naziv: formData.adresaBelaCrkva!,
          grad: 'Bela Crkva',
        );
        adresaBelaCrkvaId = adresaBC?.id;
      }

      if (formData.adresaVrsac != null && formData.adresaVrsac!.isNotEmpty) {
        final adresaVS = await AdresaSupabaseService.createOrGetAdresa(
          naziv: formData.adresaVrsac!,
          grad: 'Vršac',
        );
        adresaVrsacId = adresaVS?.id;
      }

      // Kreiraj putnika
      final noviPutnik = MesecniPutnik(
        id: '', // Biće generisan od strane baze
        putnikIme: formData.ime,
        tip: formData.tip,
        tipSkole: formData.tipSkole,
        brojTelefona: formData.brojTelefona,
        brojTelefonaOca: formData.brojTelefonaOca,
        brojTelefonaMajke: formData.brojTelefonaMajke,
        polasciPoDanu: formData.polasciPoDanu,
        adresaBelaCrkvaId: adresaBelaCrkvaId,
        adresaVrsacId: adresaVrsacId,
        radniDani: formData.radniDaniString,
        datumPocetkaMeseca: DateTime(DateTime.now().year, DateTime.now().month),
        datumKrajaMeseca: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final dodatiPutnik = await _mesecniPutnikService.dodajMesecnogPutnika(noviPutnik);

      // Refresh realtime service
      try {
        await RealtimeService.instance.refreshNow();
      } catch (e) {
        // Ne prekidaj proces zbog realtime greške
      }

      // Kreiraj dnevna putovanja za danas
      try {
        await _mesecniPutnikService.kreirajDnevnaPutovanjaIzMesecnih(
          dodatiPutnik,
          DateTime.now().add(const Duration(days: 1)),
        );
      } catch (e) {
        // Ne prekidaj proces zbog greške u kreiranje dnevnih putovanja
      }

      if (mounted) {
        // Pozovi callback
        widget.onPutnikAdded?.call(dodatiPutnik);

        // Zatvori dialog
        Navigator.pop(context);

        // Prikaži uspešnu poruku
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Uspešno dodat putnik: ${dodatiPutnik.putnikIme}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška pri dodavanju putnika: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _formController.setLoading(false);
      }
    }
  }

  /// 🎨 Kreira pozadinski gradijent
  LinearGradient _createGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1E3C72),
        Color(0xFF2A5298),
        Color(0xFF3B7DD8),
      ],
      stops: [0.0, 0.5, 1.0],
    );
  }

  /// 🎯 Vraća boju za tip putnika
  Color _getTypeColor(String tip) {
    switch (tip) {
      case 'ucenik':
        return Colors.blue;
      case 'radnik':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  /// 📱 Vraća ikonu za tip putnika
  IconData _getTypeIcon(String tip) {
    switch (tip) {
      case 'ucenik':
        return Icons.school;
      case 'radnik':
        return Icons.business;
      default:
        return Icons.person;
    }
  }
}
