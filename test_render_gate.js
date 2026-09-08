// Self-check for the Atlas render gate: max N renders in flight, the rest wait.
const assert = require('assert');
const src = require('fs').readFileSync(__dirname + '/lib/charts.js', 'utf8');
const gate = src.slice(src.indexOf('const MAX_PIXELS'), src.indexOf('function badInput'));
const m = {}; new Function('process', 'module', gate + ';module.x={acquire,release,MAX_CONCURRENT,MAX_PIXELS}')({env:{CHART_MAX_CONCURRENT:'2'}}, m);
const {acquire, release} = m.x;
(async () => {
  let active = 0, peak = 0;
  await Promise.all([...Array(10)].map(async () => {
    await acquire(); active++; peak = Math.max(peak, active);
    await new Promise(r => setTimeout(r, 5));
    active--; release();
  }));
  assert.strictEqual(peak, 2, 'gate must cap at 2');
  assert.strictEqual(active, 0);
  assert.ok(1040 * 300 * 8 * 8 > m.x.MAX_PIXELS && 1040 * 420 * 3 * 3 <= m.x.MAX_PIXELS);
  console.log('gate ok, peak =', peak);
})();
