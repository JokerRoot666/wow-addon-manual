// run.js — прогон аддона на mock-клиенте (node + fengari).
// Использование: node run.js [папка_аддона]
// По умолчанию: ../starter

const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

const dir = path.resolve(__dirname, process.argv[2] || path.join(__dirname, '..', 'starter'));

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

// исходники аддона -> глобальная таблица FILES (Lua-код видит их как строки)
const files = {};
for (const f of fs.readdirSync(dir).filter(x => x.endsWith('.lua'))) {
  files[f] = fs.readFileSync(path.join(dir, f), 'utf8');
}
lua.lua_newtable(L);
for (const [name, src] of Object.entries(files)) {
  const b = to_luastring(src);
  lua.lua_pushlstring(L, b, b.length);
  lua.lua_setfield(L, -2, to_luastring(name));
}
lua.lua_setglobal(L, to_luastring('FILES'));

function run(file) {
  const st = lauxlib.luaL_dofile(L, to_luastring(path.join(__dirname, file)));
  if (st !== lua.LUA_OK) {
    console.error('LUA ERROR в ' + file + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
    dumpOut();
    process.exit(1);
  }
}

function dumpOut() {
  lua.lua_getglobal(L, to_luastring('MOCK'));
  if (lua.lua_isnil(L, -1)) { lua.lua_pop(L, 1); return 0; }
  lua.lua_getfield(L, -1, to_luastring('out'));
  let fails = 0;
  if (lua.lua_istable(L, -1)) {
    const n = lua.lua_rawlen(L, -1);
    for (let i = 1; i <= n; i++) {
      lua.lua_rawgeti(L, -1, i);
      const line = to_jsstring(lua.lua_tostring(L, -1));
      console.log(line);
      if (line.indexOf('FAIL') !== -1) fails++;
      lua.lua_pop(L, 1);
    }
  }
  lua.lua_pop(L, 1);
  lua.lua_getfield(L, -1, to_luastring('chat'));
  if (lua.lua_istable(L, -1)) {
    const n = lua.lua_rawlen(L, -1);
    for (let i = 1; i <= n; i++) {
      lua.lua_rawgeti(L, -1, i);
      console.log('  [чат] ' + to_jsstring(lua.lua_tostring(L, -1)));
      lua.lua_pop(L, 1);
    }
  }
  lua.lua_pop(L, 2);
  return fails;
}

run('mock.lua');
run('test_smoke.lua');
const fails = dumpOut();
console.log(fails === 0 ? 'ИТОГ: все проверки пройдены' : 'ИТОГ: провалов ' + fails);
process.exit(fails === 0 ? 0 : 1);
