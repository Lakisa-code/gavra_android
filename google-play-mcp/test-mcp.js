import * as dotenv from 'dotenv';

dotenv.config();

const keyJson = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;
console.log('Service Account Key present:', !!keyJson);
console.log('Package Name:', process.env.GOOGLE_PLAY_PACKAGE_NAME);

if (keyJson) {
    try {
        const parsed = JSON.parse(keyJson);
        console.log('✓ JSON parsed successfully');
        console.log('Project ID:', parsed.project_id);
        console.log('Client Email:', parsed.client_email);
        console.log('Private Key ID:', parsed.private_key_id);
    } catch (e) {
        console.error('✗ Failed to parse JSON:', e.message);
    }
}
