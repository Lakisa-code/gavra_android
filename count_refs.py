import os, re

no_v2 = [
    ('globals.dart', ['UpdateInfo']),
    ('main.dart', ['MyApp']),
    ('theme.dart', ['SerbianTextStyle','TripleBlueFashionStyles','DarkSteelGreyStyles','DarkPinkStyles','PassionateRoseStyles']),
    ('config/v2_route_config.dart', ['RouteConfig']),
    ('helpers/v2_putnik_statistike_helper.dart', ['PutnikStatistikeHelper']),
    ('services/v2_admin_security_service.dart', ['AdminSecurityService']),
    ('services/v2_auth_manager.dart', ['AuthManager']),
    ('services/v2_battery_optimization_service.dart', ['BatteryOptimizationService']),
    ('services/v2_biometric_service.dart', ['BiometricService']),
    ('services/v2_cena_obracun_service.dart', ['CenaObracunService']),
    ('services/v2_config_service.dart', ['ConfigService']),
    ('services/v2_finansije_service.dart', ['Trosak','FinansijskiIzvestaj']),
    ('services/v2_firebase_service.dart', ['FirebaseService']),
    ('services/v2_geocoding_service.dart', ['GeocodingService']),
    ('services/v2_gorivo_service.dart', ['PumpaStanje','PumpaPunjenje','PumpaTocenje','VoziloStatistika']),
    ('services/v2_haptic_service.dart', ['HapticService','HapticElevatedButton']),
    ('services/v2_here_wego_navigation_service.dart', ['HereWeGoNavigationService','HereWeGoNavResult']),
    ('services/v2_huawei_push_service.dart', ['HuaweiPushService']),
    ('services/v2_local_notification_service.dart', ['LocalNotificationService']),
    ('services/v2_notification_navigation_service.dart', ['NotificationNavigationService']),
    ('services/v2_openrouteservice.dart', ['OpenRouteService','RealtimeEtaResult']),
    ('services/v2_osrm_service.dart', ['OsrmService','OsrmResult']),
    ('services/v2_permission_service.dart', ['PermissionService']),
    ('services/v2_putnik_push_service.dart', ['PutnikPushService']),
    ('services/v2_realtime_gps_service.dart', ['RealtimeGpsService']),
    ('services/v2_realtime_notification_service.dart', ['RealtimeNotificationService']),
    ('services/v2_slobodna_mesta_service.dart', ['SlobodnaMesta','SlobodnaMestaService']),
    ('services/v2_smart_navigation_service.dart', ['SmartNavigationService','NavigationResult']),
    ('services/v2_statistika_service.dart', ['StatistikaService']),
    ('services/v2_theme_manager.dart', ['ThemeManager']),
    ('services/v2_theme_registry.dart', ['ThemeRegistry','ThemeDefinition']),
    ('services/v2_unified_geocoding_service.dart', ['GeocodingResult','UnifiedGeocodingService']),
    ('services/v2_vozac_putnik_service.dart', ['VozacPutnikEntry']),
    ('services/v2_vozac_raspored_service.dart', ['VozacRasporedEntry']),
    ('services/v2_vozila_service.dart', ['Vozilo']),
    ('utils/v2_app_snack_bar.dart', ['AppSnackBar']),
    ('utils/v2_card_color_helper.dart', ['CardColorHelper']),
    ('utils/v2_grad_adresa_validator.dart', ['GradAdresaValidator']),
    ('utils/v2_page_transitions.dart', ['AnimatedNavigation']),
]

all_files = []
for root, dirs, files in os.walk('lib'):
    for f in files:
        if f.endswith('.dart'):
            all_files.append(os.path.join(root, f))

for fname, classes in no_v2:
    for cls in classes:
        callers = set()
        pattern = re.compile(r'\b' + cls + r'\b')
        for fp in all_files:
            text = open(fp, encoding='utf-8').read()
            matches = pattern.findall(text)
            n = len(matches)
            norm_fp = fp.replace('\\', '/')
            norm_fname = fname.replace('\\', '/')
            if norm_fname in norm_fp:
                n -= 1  # iskljuci definiciju
            if n > 0:
                rel = norm_fp.split('lib/')[-1]
                callers.add(rel)
        caller_list = ', '.join(sorted(callers)) if callers else '-'
        print(f'{cls}: {len(callers)} fajlova  [{caller_list}]')
