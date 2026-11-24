// run.js — прогон аддона на заглушке клиента (node + fengari, Lua 5.1).
// Использование: node run.js <папка_аддона>
//
// Читает .toc, загружает файлы в том же порядке и передаёт каждому
// (addonName, namespace) — ровно как клиент WoW.

const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

const dir = path.resolve(__dirname, process.argv[2] || '../../examples/hello');
const tocFile = fs.readdirSync(dir).find((f) => f.endsWith('.toc'));
if (!tocFile) {
  console.error('FAIL: в папке нет .toc');
  process.exit(1);
}
const addonName = path.basename(tocFile, '.toc');

// --- разбор .toc: только строки-файлы, директивы и комментарии пропускаем ---
const files = fs
  .readFileSync(path.join(dir, tocFile), 'utf8')
  .split(/\r?\n/)
  .map((l) => l.trim())
  .filter((l) => l && !l.startsWith('#'))
  .filter((l) => /\.(lua|xml)$/i.test(l));

if (!files.length) {
  console.error('FAIL: .toc не перечисляет ни одного файла');
  process.exit(1);
}

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

const out = [];
let fails = 0;

function fail(msg) {
  console.log('FAIL: ' + msg);
  fails++;
}

function runFile(file) {
  const full = path.isAbsolute(file) ? file : path.join(dir, file);
  const src = fs.readFileSync(full, 'utf8');
  if (lauxlib.luaL_loadbuffer(L, to_luastring(src), to_luastring('@' + path.basename(file))) !== lua.LUA_OK) {
    fail(`синтаксис в ${file}: ${to_jsstring(lua.lua_tostring(L, -1))}`);
    return false;
  }
  // те же два vararg, что даёт клиент: local ADDON, ns = ...
  lua.lua_pushstring(L, to_luastring(addonName));
  lua.lua_newtable(L);
  if (lua.lua_pcall(L, 2, 0, 0) !== lua.LUA_OK) {
    fail(`ошибка при загрузке ${file}: ${to_jsstring(lua.lua_tostring(L, -1))}`);
    return false;
  }
  return true;
}

// заглушка клиента грузится первой
if (!runFile(path.join(__dirname, 'mock.lua'))) {
  console.log('ИТОГ: провал на заглушке');
  process.exit(1);
}

let ok = true;
for (const f of files) ok = runFile(f) && ok;
if (!ok) {
  console.log('ИТОГ: провал загрузки');
  process.exit(1);
}

// --- сценарий: вход в мир, потом слэш-команды ---
function call(fn, ...args) {
  lua.lua_getglobal(L, to_luastring('MOCK'));
  lua.lua_getfield(L, -1, to_luastring(fn));
  lua.lua_remove(L, -2);
  for (const a of args) lua.lua_pushstring(L, to_luastring(String(a)));
  if (lua.lua_pcall(L, args.length, 0, 0) !== lua.LUA_OK) {
    fail(`${fn}: ${to_jsstring(lua.lua_tostring(L, -1))}`);
  }
}

// ADDON_LOADED приходит на каждый аддон — проверим оба имени
call('dispatch', 'ADDON_LOADED', 'SomeOtherAddon');
call('dispatch', 'ADDON_LOADED', addonName);
// Проверяем, что SavedVariables не подменились дефолтами при втором заходе
lua.lua_getglobal(L, to_luastring('HelloWorldDB'));
if (!lua.lua_istable(L, -1)) fail('HelloWorldDB не создана в ADDON_LOADED');
else {
  lua.lua_getfield(L, -1, to_luastring('count'));
  if (!lua.lua_isnumber(L, -1)) fail('HelloWorldDB.count не число');
  lua.lua_pop(L, 1);
}
lua.lua_pop(L, 1);

call('dispatch', 'PLAYER_LOGIN');
call('slashcmd', '/hello');
call('slashcmd', '/hw count');
call('slashcmd', '/hw count');
call('slashcmd', '/hw reset');
call('slashcmd', '/hw бред');

// --- вывод ---
lua.lua_getglobal(L, to_luastring('MOCK'));
lua.lua_getfield(L, -1, to_luastring('out'));
const n = lua.lua_rawlen(L, -1);
for (let i = 1; i <= n; i++) {
  lua.lua_rawgeti(L, -1, i);
  const line = to_jsstring(lua.lua_tostring(L, -1));
  console.log(line);
  out.push(line);
  lua.lua_pop(L, 1);
}
lua.lua_pop(L, 2);

// --- проверки ---
function expect(label, cond) {
  if (cond) console.log('ok: ' + label);
  else fail(label);
}

expect('приветствие после PLAYER_LOGIN', out.some((l) => l.includes('загружен, счётчик = 0')));
expect('справка по /hello', out.some((l) => l.includes('/hello help')));
expect('инкремент счётчика', out.some((l) => l.includes('счётчик = 1')) && out.some((l) => l.includes('счётчик = 2')));
expect('сброс счётчика', out.some((l) => l.includes('счётчик обнулён')));
expect('ругань на неизвестную команду', out.some((l) => l.includes('неизвестная команда')));
expect('чужой ADDON_LOADED проигнорирован', !out.some((l) => l.includes('SomeOtherAddon')));

console.log(fails === 0 ? 'ИТОГ: все проверки пройдены' : `ИТОГ: провалов ${fails}`);
process.exit(fails === 0 ? 0 : 1);
