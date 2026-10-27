// Execute the actual template script with a mocked browser and prompt.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const template = fs.readFileSync('luci-app-passwall2/luasrc/view/passwall2/socks_auto_switch/btn.htm', 'utf8');
const script = template.match(/<script[^>]*>([\s\S]*?)<\/script>/)[1].replace(/<%[\s\S]*?%>/g, '/test');
for (const keyword of ['HK&IEPL', 'US+VIP', 'JP#01', '[', '.', '%', 'a*b', 'a b', '节点']) {
  for (const action of ['add_node_by_key', 'remove_node_by_key']) {
    const context = { window: { location: { pathname: '/socks_config/socks_test' } }, prompt: () => keyword };
    vm.createContext(context);
    vm.runInContext(script, context);
    context[action]();
    const result = new URL(context.window.location.href, 'https://example.invalid');
    assert.equal(result.searchParams.get('id'), 'socks_test');
    assert.equal(result.searchParams.get('key'), keyword);
    assert.equal(result.hash, '');
  }
}
console.log('SOCKS template query regressions passed');
