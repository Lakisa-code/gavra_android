const fn = require('./index');

// A minimal smoke test runner: supplies fake req/res objects and checks status codes
function makeReq(body) {
    return {
        json: async () => body
    };
}

function makeRes() {
    let status = 200;
    let payload = null;
    return {
        status: (s) => { status = s; return { json: (p) => { payload = p; return { status, payload }; } } },
        json: (p) => { payload = p; return { status, payload }; }
    };
}

async function run() {
    // Missing title -> should return 400
    const r1 = makeRes();
    await fn(makeReq({ body: null, tokens: [] }), r1);
    console.log('Test 1 result (expected 400):', r1.json());

    // Good shape but tokens not array -> 400
    const r2 = makeRes();
    await fn(makeReq({ title: 't', body: 'b', tokens: null }), r2);
    console.log('Test 2 result (expected 400):', r2.json());

    // Minimal valid payload but no server keys -> should return success:false or results
    const r3 = makeRes();
    await fn(makeReq({ title: 't', body: 'b', tokens: [] }), r3);
    console.log('Test 3 result (expected 200):', r3.json());
}

run().catch(e => { console.error(e); process.exit(1); });
