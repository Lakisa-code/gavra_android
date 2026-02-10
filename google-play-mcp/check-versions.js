const { google } = require("googleapis");
const fs = require("fs");

const keyFile = "../../google-play-key.json";
const packageName = "com.gavra013.gavra_android";

async function getEditId() {
    const auth = new google.auth.GoogleAuth({
        keyFile: keyFile,
        scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });

    const androidpublisher = google.androidpublisher({
        version: "v3",
        auth: auth,
    });

    try {
        const response = await androidpublisher.edits.create({
            packageName: packageName,
        });
        return response.data.id;
    } catch (error) {
        console.error("Greška pri kreiranju edit-a:", error.message);
        throw error;
    }
}

async function checkVersions() {
    const editId = await getEditId();

    const auth = new google.auth.GoogleAuth({
        keyFile: keyFile,
        scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });

    const androidpublisher = google.androidpublisher({
        version: "v3",
        auth: auth,
    });

    try {
        // Dobijamo sve verzije
        const tracksResponse = await androidpublisher.edits.tracks.list({
            packageName: packageName,
            editId: editId,
        });

        console.log("\n📱 VERZIJE NA GOOGLE PLAY STORE:\n");

        for (const track of tracksResponse.data.tracks) {
            console.log(`\n🔷 Track: ${track.track.toUpperCase()}`);

            if (track.releases && track.releases.length > 0) {
                for (const release of track.releases) {
                    console.log(`   Version Code: ${release.versionCodes ? release.versionCodes.join(", ") : "N/A"}`);
                    console.log(`   Version Name: ${release.name || "N/A"}`);
                    console.log(`   Status: ${release.status}`);
                    console.log(`   Release Notes: ${release.releaseNotes ? release.releaseNotes[0]?.text : "Nema"}`);
                }
            } else {
                console.log("   Nema izdanja");
            }
        }

        // Zatvori edit bez sačuvavanja
        await androidpublisher.edits.delete({
            packageName: packageName,
            editId: editId,
        });

    } catch (error) {
        console.error("Greška pri preuzimanju verzija:", error.message);
    }
}

checkVersions();
