import 'dart:convert';

import 'package:http/http.dart' as http;

Future<void> main() async {
  // FCM Server Key (Legacy HTTP protocol, jer je jednostavnije za skriptu)
  // Ako ovo ne radi (jer Firebase forsira v1 API), moracemo da koristimo service account.
  // Za sada probamo sa kljucem iz build.gradle ili google-services.json ako ga nadjemo.
  // Pošto ga nemam, koristiću verovatno neispravan placeholder,
  // ALI pošto nemam ključ, moram vas zamoliti za njega ili koristiti drugi pristup.

  // Čekaj! Video sam da se koristi 'send-push-notification' Supabase funkcija u kodu!
  // To znači da mogu da pozovem tu funkciju direktno preko HTTP-a!

  const supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

  // Lista SVIH tokena (putnika i vozača) koje smo našli
  final tokens = [
    // Putnici
    {
      'token':
          'dEbaHH7dSUGZcqpgbkrV6s:APA91bH_0hWmCzVIzOFM47nH5_WmCyrQq8QE77Dj3dFW_CTvdO-JlywWOfpPh-cve8ce0-1d90rcmZvdu0O_tbp0itpVoVbak8ITnyR1CZonALaPKCnfZd0',
      'provider': 'fcm'
    }, // Sofija Kozic
    {
      'token':
          'f-Gru0LQSn2hjS0YrwlSGg:APA91bGJ4cqFPbt4R4ewuyqamyw55hbMkHHorLc6DqVbsPp6CGajg2-vPlZA_GRjQhfnxHw_KRSgffDlbD64CcqPQfG153JeVQ0qo-C9SfdlwQ5H1ym5Uvc',
      'provider': 'fcm'
    }, // Maja Stojanovic (hladnjača)
    {
      'token':
          'dv8oDrpISAmelNPeg_iB0n:APA91bFWm5NlsRcE1uuEQ-cfHx8fd6m5_rDP0uzN3MqMmKKSG-48zckvljb6siFnDrEJp2CKzlbBzv8-73S08yd-QuqpxAmTV-4jKaA8cxskj4vrrKN5eBE',
      'provider': 'fcm'
    }, // Vincilov Ivana
    {
      'token':
          'cRdQL0V1RV-ENgSR1WdSbC:APA91bHs97CRYfjt8VILJS-34Oot7WJ7ncxgguez4aZ8VCDcZhjAVhDNMJD226txEUu_huQ23HCvcF9BnK2glDwfUupeYfsAIC6VTEC03tnLNi4-fr8Jbsc',
      'provider': 'fcm'
    }, // Beker Dragana
    {
      'token':
          'dgDEuajbSleGBRKka3TCCY:APA91bER4fj28dKnnGAFTknJVmLamfs4lbWvD_atlBI0nixhDAwfvhmrvU_RAtxXTlhWVOSLizyTp3FwKf7rablzouR3I3Bpf40s1Q4y-0UYT8E8r0_UBNM',
      'provider': 'fcm'
    }, // Daca Novotni
    {
      'token':
          'cV9AuNmsTHOR8-5dVIjbvU:APA91bFC5eySTHOLWWG2emnx7qQfNeSbD3pOEm2FihlNeNIaeNLsp0U936_81LmDVNsud6ffNeNzLJT6O13qT089dqJBDLyX0XgRJsj715fCypWpUrrCcUA',
      'provider': 'fcm'
    }, // Marin
    {
      'token':
          'cnW4lH_NS5GatXRva7UtIe:APA91bH8M4CCwkGPmtbdFqiZZA8jGEC0u60b-DK_LMu8wb3NvnVL6LsAIY4gUOY76f_n0OWN09AljZXqMTBpsZyu-85Pr46fYta3tLVX7EjqSdBFZlcTMkA',
      'provider': 'fcm'
    }, // Nikolina Milicev
    {
      'token':
          'cVA069eZT0WrFS9Ov8F55U:APA91bHpCsE9mHwXhSVlYlwyNpi63siF2M8I997OqnkYMWFFiV3v6PyVII1e3gkvdcQlqV33jQhDbcRWC4EvNKrJtef_JOGxRiFgRTXaCnECi4M6gRSFgr8',
      'provider': 'fcm'
    }, // AI Radnik Test
    {
      'token':
          'egWZI748SiuE0yLXLVmqPE:APA91bH6tvi4Ba8NEbZteiRPdiqTgT3U18mn5o4ABlpwmav3R6nvn85dQgH5iWDGMoyvl3nYDkQQWMC0zgkt4pjBaUd4ZSDHEllDUdHrmPlS_WEqQvz_PGM',
      'provider': 'fcm'
    }, // Mihajlo Trkalan
    {
      'token':
          'cuxAvJV7SC26y1eeFbMkWi:APA91bEwNunDnrbKO0nzbab5bMzkTqDGPjyW_XOVrXfzCxj6rN5yMcvm72R0FgUOf-ihjZzw9O3eQ5r5gP6YTwKMF9SGPhYubtLwzwAgvTbxeVH2_rIvuqw',
      'provider': 'fcm'
    }, // Dusica
    {
      'token':
          'dkA4qCN9QYymeqoj5I1W_5:APA91bGPDC82GfTVVTn_8ZC4C7peYBCH0NiXvo1sJBQbV_pgh3G6PHm8aQZbGSSEYVIWhhhRvEwzFZNdh325u-QKxMX1LahxKW-otmwvvYug5O_aIsa15Pw',
      'provider': 'fcm'
    }, // Sokolovic Maja
    {
      'token':
          'fKBNprmGTVqposlsNs7xWn:APA91bFNj_1WgPGkpI_RYAv0VgUpjyaWQfhNyzrQGEpOKv_aafgYH0bp2BBUWX2KUuDmzkC6zC7tx0qd_RLVYIo50Ju91W4bV8p_QVX8pCWIXlJ3IiJcDa0',
      'provider': 'fcm'
    }, // Dragana Mitrovic
    {
      'token':
          'eJt0SBrBSQWKTAIZKTRrDc:APA91bFoi2Cvl81rBva4s3SyfinZDMvdINB-JzjuOXZiPH7TxlRGyvuNaG9qwE6GWA9oz_vEpsJ4RvxkH033I8fKV60CDo8Z_1faOv9o9UaCiKtjb7qLUJ4',
      'provider': 'fcm'
    }, // Kad pitam kurac
    {
      'token':
          'fhbGOZFuRQmpVYARZfb-_h:APA91bEiW-Zpa_WFB-56grPWStFb9lBwcCUhN0vPeB2kxqvypDag7pgIdw5xXEREdq8bcgKVz-Su0_xOShZQqaOGPcNVkD8KI64ZKEIvnl1_jAWRN8N5Sls',
      'provider': 'fcm'
    }, // Jovan Todorovic
    {
      'token':
          'cCAtC5RMRMm0LV-EHG80Ra:APA91bHqA8teCFrAAkhMU6B8D2xmtjX4f65Ox4vVJL45itFJYSc4K8XyCatiNR97vYqP7Jq2eiN1QA-cBJp97AkAYR1FcDrLAeshMemW1rNSh1nP6X66UqI',
      'provider': 'fcm'
    }, // Ljilja Rakićević
    {
      'token':
          'casVashRTM2CUq5izS-e2y:APA91bHwZ7k0rywF1nvqW4V3vTd--ieWBeetbtvg3iPfEl6sKtdYipfk095_5BIMh9bKNYHHI4cEvQ58jHvJNCBIGmE3Rd2SH7ZiYtTCTcm2DJW_c8h8Ui0',
      'provider': 'fcm'
    }, // Jovana Jovanovic
    {
      'token':
          'cm80chnWSby4TwZbHI5hBt:APA91bHVBOm-4b2JFBiKRKe3YlLKNGHbD3PMd6gOXIwkw25IfKrXs4p9DwQV2ASI1UXaa5NR46ea0qFDbISCK2dUrSwd6xsXOeE9XyX6c7Qjxty-pI2j2Xc',
      'provider': 'fcm'
    }, // Marina Bihler

    // Vozači
    {
      'token':
          'eZH68ytKTbWNruDCRXyD1L:APA91bGpRWFMJ0Kf_1IpsYp45BpQJIpcfeneVvAz3LGnUwcudBvViPjwF4ZjBoWQ8KRCCIFddj8eRSqh24ufg51A-4surXclafp6qkgnC83G0hejuNJsj0E',
      'provider': 'fcm'
    }, // Ivan
    {
      'token':
          'eTESp-yQRXWbSarq_84m6J:APA91bGxpzK7uFReSRanTo1Z2jnTUVcM8ldswX22MWpIy2sErqv2sAx6BNSaIHs0EkCyGYW7OL5zRzoCy98jRHf0V-mk1GIhJ_E1Ea4lhmZVLhjs9WB1d8g',
      'provider': 'fcm'
    }, // Bilevski
    {
      'token':
          'e5s43PMxS5ql2T3LTTpTG0:APA91bEKpRc90tt-O5KjzAqEo1MzUExKsU01Z6uzuBAXhsxBy6NRc5KrZOD09QMcXueF3YzXkObl80xDKnBZWHEXxMNgN3QYC8MEZaSEVTo_S-dJuBSJjME',
      'provider': 'fcm'
    }, // Bojan
    {
      'token':
          'fhEIQVciRQOSmID2mTKg1P:APA91bFnuXmfMYNgi4KRMr5r4tEo3Z-QG3tsDNYmNpXxwqEtibpqkz3o7X8EcK35OI6qGdOm5Hgkt1aBoPRKq70qaF3JpljZ6eYA8RFiCPMb7U8-Obqcdrk',
      'provider': 'fcm'
    }, // Bruda

    // Nepoznati / Null user_id (dodajemo za svaki slučaj, možda su vozači/putnici pre re-login-a)
    {
      'token':
          'fp-mBkwFQ9WmmTAFezNSkI:APA91bG-ld5-PSo3jqyzLcqgCmEOLAFD0Z0JAyTRNX3q3FbaD4bwirkCbNbcQRau9klYhKhxui6xE2ftOJaqZq2HdjqZ1t3H23eESms3yxQ48f3Dt2mfSOI',
      'provider': 'fcm'
    },
    {
      'token':
          'e7bYsuwHQkqLo-vGIvfJEK:APA91bG66poga1mKe66-6Gy7YR6dmWmBGWn3wwrBhiNcLTIE2y0z31U0zJp5VTcmLpkbxYoE4AjbFcuZMPS0JVja3gKJl0zg9hrfmeAfY0lDYbOeO9f85v8',
      'provider': 'fcm'
    },
    {
      'token':
          'eYoegJ6eTwivxU38VkJ00C:APA91bFahOpTrC_iVqiin5sS-BHA9NVhZ_aURHQPcbzbotgqDUGNYmP6qi3bHQedUg9DOQI37PJ0yYbTWO99IQUJVlUbprq5Lv7cu4NjlLeMyn6a-JbJyZQ',
      'provider': 'fcm'
    },
    {
      'token':
          'efKxXKQVRqqJ-oadTD-UrT:APA91bF-HECvWcx7dMsAmjNzTybv3ZQYxg4FQsTdltDdISd4Fxb0UXqVsTUa_dYsVyi89nXwUOabB_SV1ev3FjKRyYVRRLrjKGvb813coZpb6QxQsY4dVFo',
      'provider': 'fcm'
    },
    {
      'token':
          'ea_2ehvoRvmbEur23Orymx:APA91bE1XSmzdW0RXS_FkToaBNOg87E2artNAUGkeA87npF0MEZRiqGBb_D61lq6lJvdv_C2o92kdWq-EhRRp-LMSMARrn5IDH3Gj5uSEZWNuGEXzRXr9SA',
      'provider': 'fcm'
    },
    {
      'token':
          'f_5RJKXJSIOIJZsOs21LME:APA91bHrYNjC4mXhDT1buapvyNY6DfVQ-dXRyUhQdj23_EOilBMht3yiz_5Xy3N2wd8Z-XVeS-CJnNxkPmLg1kWcJ0cas-GB9D2rBjdz1Gj4WG6zjkqH6UQ',
      'provider': 'fcm'
    },
    {
      'token':
          'eAVu0RcOTKube0PibsalYR:APA91bEf0XWkA2Gk2J4VgZiB1MhgM1LxaqlGGXoldA7ytXUUukb5vwy5PFbyuz6PJIsCb_-EsNr6WxpuN9KdZQNdxIkZcikOv3CeXDoyUgvZIgWb6y2W8rg',
      'provider': 'fcm'
    },
  ];

  print('🚀 Sending notifications to ${tokens.length} devices...');

  final url = Uri.parse('$supabaseUrl/functions/v1/send-push-notification');
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $supabaseAnonKey',
  };

  final body = jsonEncode({
    'tokens': tokens,
    'title': '🚀 Nova verzija je dostupna!',
    'body':
        'Izašla je važna nadogradnja aplikacije. Molimo vas ažurirajte aplikaciju na Google Play prodavnici radi stabilnijeg rada.',
    'data': {
      'type': 'app_update',
      'version': '2.0.0', // Primer, nije bitno
    }
  });

  try {
    final response = await http.post(url, headers: headers, body: body);

    print('Response Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      print('✅ Notification sent successfully!');
    } else {
      print('❌ Failed to send notification.');
    }
  } catch (e) {
    print('❌ creating request failed: $e');
  }
}
