import { createClient } from '@supabase/supabase-js';
import { corsHeaders } from '../_shared/cors.ts';

interface RequestBody {
    putnik_id: number;
    grad: string;
    dan: string;
    vreme_zelja: string;
}interface KapacitetRow {
    vreme: string;
    max_mesta: number;
    aktivan: boolean;
}

interface SlobodnaMesta {
    vreme: string;
    kapacitet: number;
    zauzeto: number;
    slobodno: number;
}

Deno.serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
        const supabase = createClient(supabaseUrl, supabaseKey); const { putnik_id, grad, dan, vreme_zelja }: RequestBody = await req.json();

        // 1. Get all active times for the city
        const { data: kapaciteti, error: kapError } = await supabase
            .from('kapacitet_polazaka')
            .select('vreme, max_mesta, aktivan')
            .eq('grad', grad.toUpperCase())
            .eq('aktivan', true);

        if (kapError || !kapaciteti || kapaciteti.length === 0) {
            return new Response(JSON.stringify({ error: 'No available times found' }), {
                status: 404,
                headers: { 'Content-Type': 'application/json' },
            });
        }

        // 2. Calculate occupied seats for each time
        const slobodnaMesta: SlobodnaMesta[] = [];

        for (const kap of kapaciteti) {
            const countFunction = grad.toUpperCase() === 'BC' ? 'count_bc_seats' : 'count_vs_seats';

            const { data: countData, error: countError } = await supabase.rpc(countFunction, {
                dan_param: dan,
                vreme_param: kap.vreme,
            });

            if (countError) {
                console.error(`Error counting seats for ${kap.vreme}:`, countError);
                continue;
            }

            const zauzeto = countData || 0;
            const slobodno = kap.max_mesta - zauzeto;

            if (slobodno > 0) {
                slobodnaMesta.push({
                    vreme: kap.vreme,
                    kapacitet: kap.max_mesta,
                    zauzeto,
                    slobodno,
                });
            }
        }

        if (slobodnaMesta.length === 0) {
            console.log('No available alternatives found');
            return new Response(JSON.stringify({ message: 'No alternatives available' }), {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
            });
        }

        // 3. Find nearest time to desired time
        const parseTime = (time: string): number => {
            const [hours, minutes] = time.split(':').map(Number);
            return hours * 60 + minutes;
        };

        const zeljeniMinuti = parseTime(vreme_zelja);

        let najblizeVreme: string | null = null;
        let najmanjaRazlika: number | null = null;

        for (const sm of slobodnaMesta) {
            const trenutniMinuti = parseTime(sm.vreme);
            const razlika = Math.abs(trenutniMinuti - zeljeniMinuti);

            if (najmanjaRazlika === null || razlika < najmanjaRazlika) {
                najmanjaRazlika = razlika;
                najblizeVreme = sm.vreme;
            }
        }

        if (!najblizeVreme) {
            return new Response(JSON.stringify({ message: 'No alternatives found' }), {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
            });
        }

        // 4. Update pending_resolution_queue with alternative time
        const { error: updateError } = await supabase
            .from('pending_resolution_queue')
            .update({ alternative_time: najblizeVreme })
            .eq('putnik_id', putnik_id)
            .eq('grad', grad.toUpperCase())
            .eq('dan', dan)
            .eq('vreme', vreme_zelja)
            .eq('new_status', 'rejected')
            .is('sent_at', null);

        if (updateError) {
            console.error('Error updating queue with alternative:', updateError);
            return new Response(JSON.stringify({ error: 'Failed to update queue' }), {
                status: 500,
                headers: { 'Content-Type': 'application/json' },
            });
        }

        // 5. Insert a second notification with alternative suggestion
        const msgTitle = '💡 Alternativno vreme';
        const msgBody = `Pokušajte sa ${najblizeVreme} - ima slobodnih mesta!`;

        const { error: insertError } = await supabase
            .from('pending_resolution_queue')
            .insert({
                putnik_id,
                grad: grad.toUpperCase(),
                dan,
                vreme: najblizeVreme,
                old_status: 'rejected',
                new_status: 'suggestion',
                message_title: msgTitle,
                message_body: msgBody,
                alternative_time: najblizeVreme,
            });

        if (insertError) {
            console.error('Error inserting alternative notification:', insertError);
            return new Response(JSON.stringify({ error: 'Failed to queue notification' }), {
                status: 500,
                headers: { 'Content-Type': 'application/json' },
            });
        }

        console.log(`Alternative found: ${najblizeVreme} for user ${putnik_id}`);

        return new Response(
            JSON.stringify({
                success: true,
                alternative_time: najblizeVreme,
                message: `Alternative notification queued`,
            }),
            {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
            }
        );
    } catch (error) {
        console.error('Edge function error:', error);
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
        });
    }
});
