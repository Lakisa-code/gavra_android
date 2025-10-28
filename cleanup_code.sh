#!/bin/bash

# 🧹 FLUTTER CODE CLEANUP SCRIPT
# Čisti debug komentare, prazne linije i organizuje import-ove

echo "🧹 POČETAK ČIŠĆENJA KODA..."

# Uklanjanje debug komentara iz svih Dart fajlova
find lib -name "*.dart" -type f -exec sed -i '/Debug logging removed for production/d' {} \;

# Uklanjanje komentara o importima koji su uklonjeni
find lib -name "*.dart" -type f -exec sed -i '/\/\/ import.*Removed in simple version/d' {} \;

# Uklanjanje praznih linija koje su nastale
find lib -name "*.dart" -type f -exec sed -i '/^[[:space:]]*$/N;/^\n$/d' {} \;

echo "✅ Debug komentari uklonjeni!"

# Provera postojanja nekorišćenih servisa
echo "🔍 PROVERA NEKORIŠĆENIH SERVISA..."

# Lista potencijalno nekorišćenih servisa
unused_services=(
    "driver_registration_service.dart"
    "email_auth_service.dart" 
    "adresa_statistics_service.dart"
    "clean_statistika_service.dart"
)

for service in "${unused_services[@]}"; do
    if [ -f "lib/services/$service" ]; then
        # Proverava da li se koristi u kodu
        usage_count=$(grep -r "import.*$service" lib/ | wc -l)
        if [ $usage_count -eq 0 ]; then
            echo "⚠️  Nekorišćen servis: $service"
        fi
    fi
done

echo "🧹 ČIŠĆENJE ZAVRŠENO!"