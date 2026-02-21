import { createHttpError } from "https://deno.land/std@0.168.0/http/http_errors.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

// 🔑 Tipovi podataka za zahtev
interface PushPayload {
    tokens: { token: string; provider: string }[]
    title: string
    body: string
    data?: Record<string, string>
}

// 🛡️ CORS Headers
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: any) => {
    // 🏁 Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const payload: PushPayload = await req.json()
        const { tokens, title, body, data } = payload

        // 🔐 DOBAVLJANJE TAJNI IZ BAZE (Umesto Dashboard-a)
        const supabaseClient = createClient(
            (Deno as any).env.get('SUPABASE_URL') ?? '',
            (Deno as any).env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const { data: secretsData } = await supabaseClient
            .from('server_secrets')
            .select('key, value')

        const secrets: Record<string, string> = {}
        secretsData?.forEach((s: any) => {
            secrets[s.key] = s.value
        })

        if (!tokens || tokens.length === 0) {
            throw createHttpError(400, "Nema tokena za slanje.")
        }

        const results = []

        // 🚀 RAZDVAJANJE PO PROVAJDERIMA (case-insensitive: 'fcm'/'FCM', 'huawei'/'hms'/'HMS')
        const fcmTokens = tokens.filter(t => t.provider?.toUpperCase() === 'FCM').map(t => t.token)
        const hmsTokens = tokens.filter(t => ['HMS', 'HUAWEI'].includes(t.provider?.toUpperCase())).map(t => t.token)

        // 1. 🟢 SLANJE PREKO FCM (Google/Apple)
        if (fcmTokens.length > 0) {
            const fcmResult = await sendToFCM(fcmTokens, title, body, data, secrets)
            results.push({ provider: 'FCM', ...fcmResult })
        }

        // 2. 🔴 SLANJE PREKO HMS (Huawei)
        if (hmsTokens.length > 0) {
            const hmsResult = await sendToHMS(hmsTokens, title, body, data, secrets, supabaseClient)
            results.push({ provider: 'HMS', ...hmsResult })
        }

        return new Response(
            JSON.stringify({ success: true, results }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error: any) {
        console.error("🔴 Error:", error.message)
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})

/**
 * 🟢 GOOGLE FCM V1 IMPLEMENTACIJA
 */
async function sendToFCM(tokens: string[], title: string, body: string, data?: any, secrets?: any) {
    const serviceAccount = JSON.parse(secrets?.FIREBASE_SERVICE_ACCOUNT || (Deno as any).env.get('FIREBASE_SERVICE_ACCOUNT') || '{}')

    if (!serviceAccount.project_id) {
        return { success: false, error: 'FCM Config Missing (FIREBASE_SERVICE_ACCOUNT)' }
    }

    try {
        const accessToken = await getGoogleAccessToken(serviceAccount)
        const projectId = serviceAccount.project_id
        const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

        const sendPromises = tokens.map(token => {
            const message = {
                message: {
                    token,
                    notification: { title, body },
                    data: data || {},
                    android: { priority: "high", notification: { sound: "default" } },
                    apns: { payload: { aps: { sound: "default" } } }
                }
            }

            return fetch(url, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(message),
            })
        })

        const responses = await Promise.all(sendPromises)
        return { success: true, sentCount: responses.filter(r => r.ok).length }
    } catch (e: any) {
        return { success: false, error: e.message }
    }
}

/**
 * 🔴 HUAWEI HMS IMPLEMENTACIJA
 */
async function sendToHMS(tokens: string[], title: string, body: string, data?: any, secrets?: any, supabase?: any) {
    const clientId = secrets?.HUAWEI_CLIENT_ID || (Deno as any).env.get('HUAWEI_CLIENT_ID')
    const clientSecret = secrets?.HUAWEI_CLIENT_SECRET || (Deno as any).env.get('HUAWEI_CLIENT_SECRET')
    const appId = secrets?.HUAWEI_APP_ID || (Deno as any).env.get('HUAWEI_APP_ID')

    if (!clientId || !clientSecret) {
        return { success: false, error: 'HMS Config Missing' }
    }

    try {
        const hmsToken = await getHMSAccessToken(clientId, clientSecret)
        const url = `https://push-api.cloud.huawei.com/v1/${appId}/messages:send`

        const message = {
            validate_only: false,
            message: {
                notification: { title, body },
                data: JSON.stringify(data || {}),
                android: {
                    notification: {
                        title,
                        body,
                        click_action: { type: 1, intent: "#Intent;com.gavra013.gavra_android;end" },
                        sound: "default",
                        default_sound: true,
                        importance: "HIGH",
                    }
                },
                token: tokens
            }
        }

        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${hmsToken}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(message),
        })

        const resData = await response.json()
        console.log('🔴 HMS full response:', JSON.stringify(resData))

        // Ako je token istekao/nevažeći, obriši ga iz baze
        if (resData.code === '80200003' || resData.code === '80300007') {
            console.log('⚠️ HMS token expired/invalid, deleting from DB...')
            if (supabase) {
                await supabase.from('push_tokens').delete().in('token', tokens)
            }
        }

        return { success: resData.code === '80000000', code: resData.code, msg: resData.msg }
    } catch (e: any) {
        return { success: false, error: e.message }
    }
}

// --- HELPER FUNKCIJE ZA TOKENE ---

async function getGoogleAccessToken(serviceAccount: any) {
    const iat = Math.floor(Date.now() / 1000)
    const exp = iat + 3600

    const header = { alg: 'RS256', typ: 'JWT' }
    const claimSet = {
        iss: serviceAccount.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        exp,
        iat,
    }

    const encode = (obj: any) => btoa(JSON.stringify(obj))
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

    const headerB64 = encode(header)
    const claimB64 = encode(claimSet)
    const signingInput = `${headerB64}.${claimB64}`

    // Učitaj private key (PEM → CryptoKey)
    const pemBody = serviceAccount.private_key
        .replace(/-----BEGIN PRIVATE KEY-----/, '')
        .replace(/-----END PRIVATE KEY-----/, '')
        .replace(/\s/g, '')
    const binaryDer = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0))

    const cryptoKey = await crypto.subtle.importKey(
        'pkcs8',
        binaryDer,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['sign']
    )

    const signature = await crypto.subtle.sign(
        'RSASSA-PKCS1-v1_5',
        cryptoKey,
        new TextEncoder().encode(signingInput)
    )

    const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

    const jwt = `${signingInput}.${signatureB64}`

    const response = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    })

    const data = await response.json()
    return data.access_token
}

async function getHMSAccessToken(clientId: string, clientSecret: string) {
    const response = await fetch("https://oauth-login.cloud.huawei.com/oauth2/v2/token", {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `grant_type=client_credentials&client_id=${clientId}&client_secret=${clientSecret}`,
    })
    const data = await response.json()
    return data.access_token
}
