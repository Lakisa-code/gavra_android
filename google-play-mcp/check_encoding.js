import fs from 'fs';
const buf = fs.readFileSync('C:/Users/Bojan/gavra_android/AI BACKUP/secrets/google/play-store-key.json');
console.log('File size:', buf.length);
console.log('First 10 bytes:', buf.slice(0, 10));
console.log('UTF8 start:', buf.slice(0, 50).toString('utf8'));
