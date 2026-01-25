# Skripta za automatsko podešavanje ključeva na tvom nalogu
$REPO = "kadpitamkurac-hash/gavra_android"

Write-Host "🚀 Podešavam ključeve na repozitorijumu: $REPO" -ForegroundColor Cyan

# --- APPLE SECRETS ---
"d8b50e72-6330-401d-9aaf-4ead356495cb" | gh secret set APP_STORE_CONNECT_ISSUER_ID --repo $REPO
"Q95YKW2L9S" | gh secret set APP_STORE_CONNECT_KEY_IDENTIFIER --repo $REPO
@"
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgas+nw1dcayHyy4k8
YSwQjwtV4/uhNooZlpBY4ZVolpqgCgYIKoZIzj0DAQehRANCAATNqxCErnCrPTH/
SwAO7wifq+eKcLs9in9IxrrMG/vG1P7vKoHczHyaKis3gDTOb3EbEnqlozMuBkZg
kMf3Q6gm
-----END PRIVATE KEY-----
"@ | gh secret set APP_STORE_CONNECT_PRIVATE_KEY --repo $REPO

# --- ANDROID / GOOGLE PLAY / HUAWEI SECRETS ---
"GavraRelease2024" | gh secret set KEYSTORE_PASSWORD --repo $REPO
"GavraRelease2024" | gh secret set STORE_PASSWORD --repo $REPO
"GavraRelease2024" | gh secret set KEY_PASSWORD --repo $REPO
"gavra-release-key" | gh secret set KEY_ALIAS --repo $REPO
$KEYSTORE_B64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\Bojan\gavra_android\gavra-release-key-production.keystore"))
$KEYSTORE_B64.Trim() | gh secret set KEYSTORE_BASE64 --repo $REPO

# Google Play JSON - Koristimo Base64 da izbegnemo probleme sa JWT signature (vazno!)
$GP_BYTES = [System.IO.File]::ReadAllBytes("C:\Users\Bojan\gavra_android\AI BACKUP\secrets\google\play-store-key.json")
$GP_B64 = [Convert]::ToBase64String($GP_BYTES)
$GP_B64 | gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64 --repo $REPO

# --- HUAWEI SECRETS ---
"116046535" | gh secret set AGC_APP_ID --repo $REPO
"1850740994484473152" | gh secret set AGC_CLIENT_ID --repo $REPO
"F4CC48ADE493A712D729DDF8B7A11542591BDBC52AD2999E950CC7BED1DEDC98" | gh secret set AGC_CLIENT_SECRET --repo $REPO

$AGC_JSON_PATH = "C:\Users\Bojan\gavra_android\android\app\agconnect-services.json"
$AGC_B64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($AGC_JSON_PATH))
$AGC_B64 | gh secret set AGC_BASE64 --repo $REPO

Write-Host "✅ Gotovo! Svi ključevi (iOS, Google, Huawei) su podešeni." -ForegroundColor Green
