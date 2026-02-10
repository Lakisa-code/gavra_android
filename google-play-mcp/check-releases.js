#!/usr/bin/env node

/**
 * Google Play Publisher - objavljivanje na alpha track
 * Koristi googleapis biblioteku za direktan pristup API-ju
 */

import * as dotenv from 'dotenv';
import { google } from 'googleapis';

dotenv.config();

const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.gavra013.gavra_android';
const SERVICE_ACCOUNT_KEY_JSON = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;

async function authenticate() {
    if (!SERVICE_ACCOUNT_KEY_JSON) {
        throw new Error('GOOGLE_PLAY_SERVICE_ACCOUNT_KEY not set');
    }

    const serviceAccount = JSON.parse(SERVICE_ACCOUNT_KEY_JSON);

    const auth = new google.auth.GoogleAuth({
        credentials: serviceAccount,
        scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });

    return auth;
}

async function getAppInfo() {
    console.log(`📱 Provjera aplikacije: ${PACKAGE_NAME}\n`);

    const auth = await authenticate();
    const androidpublisher = google.androidpublisher({
        version: 'v3',
        auth: auth,
    });

    try {
        // Kreiraj edit
        const editResp = await androidpublisher.edits.insert({
            packageName: PACKAGE_NAME,
            requestBody: {},
        });

        const editId = editResp.data.id;
        console.log('✓ Edit sesija kreirana:', editId);

        // List releases
        const releasesResp = await androidpublisher.edits.tracks.list({
            packageName: PACKAGE_NAME,
            editId: editId,
        });

        console.log('\n📋 Dostupne verzije po track-u:\n');
        for (const track of releasesResp.data.tracks || []) {
            console.log(`${track.track.toUpperCase()}:`);
            if (track.releases) {
                for (const release of track.releases) {
                    console.log(`  - Verzija: ${release.versionCodes?.join(', ') || 'N/A'}`);
                    console.log(`    Status: ${release.status}`);
                    console.log(`    User Fraction: ${release.userFraction || 1}`);
                }
            } else {
                console.log('  - Nema releasa');
            }
            console.log();
        }

    } catch (error) {
        console.error('✗ Greška pri čitanju informacija:');
        console.error(error.message);
        if (error.errors) {
            console.error(error.errors);
        }
    }
}

// Run
getAppInfo().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});
