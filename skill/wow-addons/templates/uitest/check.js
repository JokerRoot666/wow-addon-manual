// check.js — синтаксис всех .lua аддона (luaparse, Lua 5.1).
// Использование: node check.js [папка_аддона]

const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');

const dir = path.resolve(__dirname, process.argv[2] || path.join(__dirname, '..', 'starter'));
let bad = 0;

for (const f of fs.readdirSync(dir).filter(x => x.endsWith('.lua'))) {
  const p = path.join(dir, f);
  const src = fs.readFileSync(p, 'utf8');
  try {
    luaparse.parse(src, { luaVersion: '5.1', locations: true, comments: false });
    console.log('OK   ' + f + '  (' + src.split('\n').length + ' строк)');
  } catch (e) {
    bad++;
    console.log('FAIL ' + f + ': ' + e.message);
  }
}

process.exit(bad ? 1 : 0);
