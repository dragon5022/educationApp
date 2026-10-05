#!/usr/bin/env node
// ARK BUSTERS — student account tool (Firebase Admin SDK, no server code).
//
//   node students.mjs upsert  students.csv --key service-account.json [--out result.csv]
//   node students.mjs disable students.csv --key service-account.json
//   node students.mjs enable  students.csv --key service-account.json
//   node students.mjs delete  students.csv --key service-account.json --yes
//   node students.mjs list               --key service-account.json
//
// Options:
//   --key <file>            service-account JSON (or set GOOGLE_APPLICATION_CREDENTIALS)
//   --project <id>          Firebase project id (default: from the key file)
//   --domain <domain>       login-ID email domain (default students.ark-busters.app;
//                           must match ArkAuthConfig.idDomain in the apps)
//   --out <file>            result CSV path (default: result-<command>-<time>.csv)
//   --generate-passwords    upsert: make a random password for NEW students
//                           whose password column is empty (written to the result CSV)
//   --emulator              use the local Firebase Emulator Suite (project demo-ark-busters)
//   --yes                   required for delete
//
// Input CSV (UTF-8, header row; Excel "CSV UTF-8" is fine):
//   id,password,display_name      (aliases: ID / パスワード / 名前 / 表示名)
// - upsert: creates missing students; for existing ones updates the password
//   (only if given) and display name, and re-enables them.
// - disable / enable / delete / list only use the id column.
//
// The result CSV never contains passwords, except generated ones.

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { randomInt } from 'node:crypto';
import process from 'node:process';

const DEFAULT_DOMAIN = 'students.ark-busters.app';
const ID_RE = /^[a-z0-9][a-z0-9._-]{0,63}$/;

// ---------------------------------------------------------------- arguments
function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const k = a.slice(2);
      const flag = ['emulator', 'yes', 'generate-passwords', 'help'].includes(k);
      out[k] = flag ? true : argv[++i];
    } else {
      out._.push(a);
    }
  }
  return out;
}

// ---------------------------------------------------------------------- CSV
export function parseCsv(text) {
  text = text.replace(/^﻿/, '');
  const rows = [];
  let row = [];
  let field = '';
  let q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) {
      if (c === '"') {
        if (text[i + 1] === '"') { field += '"'; i++; } else { q = false; }
      } else { field += c; }
    } else if (c === '"') { q = true; }
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field); field = '';
      if (row.some((f) => f.trim() !== '')) rows.push(row);
      row = [];
    } else { field += c; }
  }
  row.push(field);
  if (row.some((f) => f.trim() !== '')) rows.push(row);
  return rows;
}

function csvCell(v) {
  const s = v == null ? '' : String(v);
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function toCsv(rows) {
  // BOM so Excel (Japanese) opens it as UTF-8.
  return '﻿' + rows.map((r) => r.map(csvCell).join(',')).join('\r\n') + '\r\n';
}

const HEADER_ALIASES = {
  id: ['id', 'login_id', 'ログインid', 'ｉｄ'],
  password: ['password', 'pass', 'パスワード'],
  display_name: ['display_name', 'name', 'displayname', '名前', '氏名', '表示名'],
};

export function readStudents(text) {
  const rows = parseCsv(text);
  if (rows.length === 0) return [];
  const header = rows[0].map((h) => h.trim().toLowerCase());
  const col = {};
  for (const [k, names] of Object.entries(HEADER_ALIASES)) {
    col[k] = header.findIndex((h) => names.includes(h));
  }
  if (col.id < 0) throw new Error('CSV に id 列がありません (header: id,password,display_name)');
  return rows.slice(1).map((r, i) => ({
    line: i + 2,
    id: normalizeId(r[col.id] ?? ''),
    password: col.password >= 0 ? (r[col.password] ?? '') : '',
    displayName: col.display_name >= 0 ? (r[col.display_name] ?? '').trim() : '',
  }));
}

/** Same normalization as the app (ArkAuth.normalizeId). */
export function normalizeId(id) {
  return id
    .trim()
    .replace(/[！-～]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0xfee0))
    .replace(/　/g, ' ')
    .trim()
    .toLowerCase();
}

export function generatePassword(len = 10) {
  // No look-alikes (0/O, 1/l/I) so children can type it from a printout.
  const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
  let s = '';
  for (let i = 0; i < len; i++) s += chars[randomInt(chars.length)];
  return s;
}

// ------------------------------------------------------------------- admin
async function initAdmin(args) {
  const { initializeApp, cert, applicationDefault } = await import('firebase-admin/app');
  const { getAuth } = await import('firebase-admin/auth');
  const { getFirestore } = await import('firebase-admin/firestore');
  let options;
  if (args.emulator) {
    process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
    process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
    options = { projectId: args.project ?? 'demo-ark-busters' };
  } else if (args.key) {
    if (!existsSync(args.key)) throw new Error(`鍵ファイルが見つかりません: ${args.key}`);
    const sa = JSON.parse(readFileSync(args.key, 'utf8'));
    options = { credential: cert(sa), projectId: args.project ?? sa.project_id };
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    options = { credential: applicationDefault(), projectId: args.project };
  } else {
    throw new Error('--key <service-account.json> を指定してください（または --emulator）');
  }
  const app = initializeApp(options);
  return { auth: getAuth(app), db: getFirestore(app) };
}

async function findUser(auth, email) {
  try {
    return await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code === 'auth/user-not-found') return null;
    throw e;
  }
}

function jaError(e) {
  const map = {
    'auth/invalid-password': 'パスワードは6文字以上にしてください',
    'auth/email-already-exists': 'このIDは既に使われています',
    'auth/invalid-email': 'IDに使えない文字があります',
    'auth/invalid-display-name': '表示名が不正です',
    'auth/configuration-not-found': 'Authentication（メール/パスワード）が有効になっていません',
  };
  return map[e.code] ?? `${e.code ?? ''} ${e.message ?? e}`.trim();
}

async function run(cmd, args) {
  const domain = (args.domain ?? DEFAULT_DOMAIN).toLowerCase();
  const emailOf = (id) => `${id}@${domain}`;
  const results = [];
  let students = [];
  if (cmd !== 'list') {
    const file = args._[1];
    if (!file) throw new Error('CSV ファイルを指定してください');
    students = readStudents(readFileSync(file, 'utf8'));
  }
  if (cmd === 'delete' && !args.yes) {
    throw new Error('delete はアカウントと記録を完全に消します。確認のため --yes を付けてください');
  }
  const { auth, db } = await initAdmin(args);

  if (cmd === 'list') {
    let token;
    do {
      const page = await auth.listUsers(1000, token);
      for (const u of page.users) {
        if (!u.email?.endsWith(`@${domain}`)) continue;
        results.push({
          id: u.email.slice(0, -(domain.length + 1)),
          uid: u.uid,
          display_name: u.displayName ?? '',
          disabled: u.disabled ? 'yes' : 'no',
          created: u.metadata.creationTime ?? '',
          last_sign_in: u.metadata.lastSignInTime ?? '',
        });
      }
      token = page.pageToken;
    } while (token);
    return results;
  }

  const seen = new Set();
  for (const s of students) {
    const r = { line: s.line, id: s.id, uid: '', action: '', status: 'ok', message: '' };
    const fail = (m) => { r.status = 'error'; r.message = m; };
    try {
      if (!ID_RE.test(s.id)) { fail('IDは半角英数字（と . _ -）で、先頭は英数字にしてください'); continue; }
      if (seen.has(s.id)) { fail('同じIDがCSV内で重複しています'); continue; }
      seen.add(s.id);
      const email = emailOf(s.id);
      const user = await findUser(auth, email);
      r.uid = user?.uid ?? '';

      if (cmd === 'upsert') {
        let password = s.password;
        if (!user && !password && args['generate-passwords']) {
          password = generatePassword();
          r.generated_password = password;
        }
        if (password && password.length < 6) { fail('パスワードは6文字以上にしてください'); continue; }
        if (!user) {
          if (!password) { fail('新しい生徒にはパスワードが必要です（または --generate-passwords）'); continue; }
          const u = await auth.createUser({
            email,
            password,
            displayName: s.displayName || undefined,
            emailVerified: true,
            disabled: false,
          });
          r.uid = u.uid;
          r.action = 'created';
        } else {
          const update = { disabled: false };
          if (password) update.password = password;
          if (s.displayName) update.displayName = s.displayName;
          await auth.updateUser(user.uid, update);
          r.action = password ? 'updated(password)' : 'updated';
          if (user.disabled) r.message = '無効→有効に戻しました';
        }
      } else if (cmd === 'disable' || cmd === 'enable') {
        if (!user) { fail('見つかりません'); continue; }
        await auth.updateUser(user.uid, { disabled: cmd === 'disable' });
        if (cmd === 'disable') await auth.revokeRefreshTokens(user.uid);
        r.action = cmd === 'disable' ? 'disabled' : 'enabled';
      } else if (cmd === 'delete') {
        if (!user) { fail('見つかりません'); continue; }
        // Cloud progress first (users/{uid} and users/{uid}/apps/*), then the login.
        await db.recursiveDelete(db.collection('users').doc(user.uid));
        await auth.deleteUser(user.uid);
        r.action = 'deleted';
      } else {
        throw new Error(`不明なコマンド: ${cmd}`);
      }
    } catch (e) {
      fail(jaError(e));
    } finally {
      results.push(r);
    }
  }
  return results;
}

function usage() {
  console.log(`使い方:
  node students.mjs upsert  <students.csv> --key <service-account.json> [--generate-passwords]
  node students.mjs disable <students.csv> --key <service-account.json>
  node students.mjs enable  <students.csv> --key <service-account.json>
  node students.mjs delete  <students.csv> --key <service-account.json> --yes
  node students.mjs list                   --key <service-account.json>
共通: [--domain students.ark-busters.app] [--out result.csv] [--project <id>] [--emulator]
詳しくは README.md を見てください。`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const cmd = args._[0];
  if (!cmd || args.help || !['upsert', 'disable', 'enable', 'delete', 'list'].includes(cmd)) {
    usage();
    process.exit(cmd ? 1 : 0);
  }
  const results = await run(cmd, args);
  const headers = results.length
    ? [...new Set(results.flatMap((r) => Object.keys(r)))]
    : ['id'];
  const csv = toCsv([headers, ...results.map((r) => headers.map((h) => r[h] ?? ''))]);
  const out = args.out ?? `result-${cmd}-${new Date().toISOString().replace(/[:.]/g, '-')}.csv`;
  writeFileSync(out, csv);
  process.stdout.write(csv.replace(/^﻿/, ''));
  const errors = results.filter((r) => r.status === 'error').length;
  console.error(`\n${results.length} 件処理 / エラー ${errors} 件 → ${out}`);
  if (results.some((r) => r.generated_password)) {
    console.error('※ 結果CSVに生成したパスワードが含まれます。配布後は安全に削除してください。');
  }
  process.exit(errors ? 2 : 0);
}

const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/').split('/').pop());
if (isMain) {
  main().catch((e) => {
    console.error(`エラー: ${e.message ?? e}`);
    process.exit(1);
  });
}
