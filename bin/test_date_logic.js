// Test date filtering logic to debug StatistikaService issue
const testPaymentDate = new Date('2025-09-15');
const weekStart = new Date('2025-09-12');
const weekEnd = new Date('2025-09-19');
const monthStart = new Date('2025-08-31');
const monthEnd = new Date('2025-09-30');

console.log('🔍 TESTING DATE FILTERING LOGIC');
console.log('===============================');

console.log(`Payment Date: ${testPaymentDate.toISOString().split('T')[0]}`);
console.log(`Week Range: ${weekStart.toISOString().split('T')[0]} to ${weekEnd.toISOString().split('T')[0]}`);
console.log(`Month Range: ${monthStart.toISOString().split('T')[0]} to ${monthEnd.toISOString().split('T')[0]}`);

// Current Flutter logic (with the bug)
function jeUVremenskomOpseguBuggy(paymentDate, fromDate, toDate) {
  // Simulate _normalizeDateTime - strips time part completely now
  const normalized = new Date(paymentDate.getFullYear(), paymentDate.getMonth(), paymentDate.getDate());
  const normalizedFrom = new Date(fromDate.getFullYear(), fromDate.getMonth(), fromDate.getDate());
  const normalizedTo = new Date(toDate.getFullYear(), toDate.getMonth(), toDate.getDate());
  
  // The old buggy logic from Flutter
  const fromCondition = normalized > new Date(normalizedFrom.getTime() - 1000); // subtract 1 second
  const toCondition = normalized < new Date(normalizedTo.getTime() + 24*60*60*1000); // add 1 day
  
  return fromCondition && toCondition;
}

// New fixed logic (from latest edit)
function jeUVremenskomOpseguFixed(paymentDate, fromDate, toDate) {
  const normalized = new Date(paymentDate.getFullYear(), paymentDate.getMonth(), paymentDate.getDate());
  const normalizedFrom = new Date(fromDate.getFullYear(), fromDate.getMonth(), fromDate.getDate());
  const normalizedTo = new Date(toDate.getFullYear(), toDate.getMonth(), toDate.getDate());
  
  return normalized.getTime() === normalizedFrom.getTime() ||
         normalized.getTime() === normalizedTo.getTime() ||
         (normalized.getTime() > normalizedFrom.getTime() && normalized.getTime() < normalizedTo.getTime());
}

console.log('\n🐛 OLD FLUTTER LOGIC (BUGGY):');
console.log(`Week filter result: ${jeUVremenskomOpseguBuggy(testPaymentDate, weekStart, weekEnd)}`);
console.log(`Month filter result: ${jeUVremenskomOpseguBuggy(testPaymentDate, monthStart, monthEnd)}`);

console.log('\n✅ NEW FIXED LOGIC:');
console.log(`Week filter result: ${jeUVremenskomOpseguFixed(testPaymentDate, weekStart, weekEnd)}`);
console.log(`Month filter result: ${jeUVremenskomOpseguFixed(testPaymentDate, monthStart, monthEnd)}`);

// Test edge cases with new logic
console.log('\n🔍 EDGE CASE TESTING WITH NEW LOGIC:');
const edgePayment1 = new Date('2025-09-12'); // First day of week
console.log(`Payment on first day of week: ${jeUVremenskomOpseguFixed(edgePayment1, weekStart, weekEnd)} (should be true)`);

const edgePayment2 = new Date('2025-09-19'); // Last day of week
console.log(`Payment on last day of week: ${jeUVremenskomOpseguFixed(edgePayment2, weekStart, weekEnd)} (should be true)`);

const edgePayment3 = new Date('2025-09-11'); // Day before week
console.log(`Payment before week start: ${jeUVremenskomOpseguFixed(edgePayment3, weekStart, weekEnd)} (should be false)`);

const edgePayment4 = new Date('2025-09-20'); // Day after week
console.log(`Payment after week end: ${jeUVremenskomOpseguFixed(edgePayment4, weekStart, weekEnd)} (should be false)`);

// Test with actual payment dates from debug
console.log('\n🔍 ACTUAL PAYMENT DATES TEST:');
const payment1 = new Date('2025-09-11');
const payment2 = new Date('2025-09-14');
const payment3 = new Date('2025-09-15');

console.log(`2025-09-11 in week (2025-09-12 to 2025-09-19): ${jeUVremenskomOpseguFixed(payment1, weekStart, weekEnd)}`);
console.log(`2025-09-14 in week (2025-09-12 to 2025-09-19): ${jeUVremenskomOpseguFixed(payment2, weekStart, weekEnd)}`);
console.log(`2025-09-15 in week (2025-09-12 to 2025-09-19): ${jeUVremenskomOpseguFixed(payment3, weekStart, weekEnd)}`);

console.log(`2025-09-11 in month (2025-08-31 to 2025-09-30): ${jeUVremenskomOpseguFixed(payment1, monthStart, monthEnd)}`);
console.log(`2025-09-14 in month (2025-08-31 to 2025-09-30): ${jeUVremenskomOpseguFixed(payment2, monthStart, monthEnd)}`);
console.log(`2025-09-15 in month (2025-08-31 to 2025-09-30): ${jeUVremenskomOpseguFixed(payment3, monthStart, monthEnd)}`);