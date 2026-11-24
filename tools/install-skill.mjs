// install-skill.mjs — копирует скилл wow-addons из репозитория в каталог скиллов DSH.
// Запуск: node tools/install-skill.mjs  (из корня репозитория)
// Результат: ~/.dsh/skills/wow-addons (старая копия заменяется целиком).

import { cpSync, existsSync, mkdirSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = join(root, 'skill', 'wow-addons');
const target = join(homedir(), '.dsh', 'skills', 'wow-addons');

if (!existsSync(join(source, 'SKILL.md'))) {
  console.error(`FAIL: нет ${join(source, 'SKILL.md')} — запускать из корня репозитория`);
  process.exit(1);
}

mkdirSync(dirname(target), { recursive: true });
rmSync(target, { recursive: true, force: true });
cpSync(source, target, { recursive: true });
console.log(`готово: ${target}`);
