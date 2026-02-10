import crypto from 'crypto';
import fs from 'fs';

const KEY_PATH = 'C:/Users/Bojan/gavra_android/AI BACKUP/secrets/google/play-store-key.json';

try {
    const keyFile = JSON.parse(fs.readFileSync(KEY_PATH, 'utf8'));
    const privateKey = keyFile.private_key;

    const key = crypto.createPrivateKey(privateKey);
    console.log('✅ Key is valid PKCS#8!');
    console.log('Key object details:', key.asymmetricKeyType);
} catch (e) {
    console.error('❌ Key is INVALID!');
    console.error(e.message);
}
