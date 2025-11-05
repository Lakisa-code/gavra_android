// TODO: Refaktorisanje mesecni_putnici_screen.dart
// 
// Ovaj fajl ima 5285 linija što je preview za održavanje.
// 
// Preporučene izmene:
//
// 1. IZDVOJITI WIDGET-E:
//    - _buildPutnikCard() -> MesecniPutnikCard widget
//    - _buildStatistikeContent() -> MesecniStatistikeWidget widget  
//    - _buildRadniDanCheckbox() -> RadniDanCheckboxWidget
//    - _buildVremenaPolaskaSekcija() -> VremenaPolaskaWidget
//    - _buildDanVremeInput() -> DanVremeInputWidget
//
// 2. IZDVOJITI LOGIKU:
//    - Filtering logiku -> MesecniPutniciFilterService
//    - Statistics računanje -> MesecniStatistikeService  
//    - Form validaciju -> MesecniPutnikFormValidator
//
// 3. KREIRATI FOLADER STRUKTURU:
//    lib/screens/mesecni_putnici/
//    ├── mesecni_putnici_screen.dart (glavni screen - ~500 linija)
//    ├── widgets/
//    │   ├── mesecni_putnik_card.dart
//    │   ├── mesecni_statistike_widget.dart
//    │   ├── radni_dan_checkbox_widget.dart
//    │   ├── vremena_polaska_widget.dart
//    │   └── dan_vreme_input_widget.dart
//    └── services/
//        ├── mesecni_putnici_filter_service.dart
//        ├── mesecni_statistike_service.dart
//        └── mesecni_putnik_form_validator.dart
//
// 4. DODATI PERFORMANCE OPTIMIZACIJE:
//    - ListView.builder umesto Column za velike liste
//    - AutomaticKeepAliveClientMixin za cached widget-e
//    - ValueNotifier umesto setState za lokalne izmene
//    - Debounce za search i filter funkcije
//
// Ova refaktorisanje će:
// ✅ Smanjiti kompleksnost glavnog fajla
// ✅ Povećati reusability widget-a
// ✅ Olakšati testiranje
// ✅ Poboljšati performance
// ✅ Smanjiti memory usage