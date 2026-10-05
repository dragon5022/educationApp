#!/usr/bin/env node
// End-to-end check against the Firebase Emulator Suite (no real project):
//   1) start:  npm run emulator            (needs Java 11+)
//   2) run:    node emulator_check.mjs
// Verifies students.mjs (create / disable / delete), sign-in with ID+password,
// and firestore.rules (own document only, field whitelist, no delete).

import { execFileSync } from 'node:child_process';
import { writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const PROJECT = 'demo-ark-busters';
const AUTH = 'http://127.0.0.1:9099';
const FS = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`;
const DOMAIN = 'students.ark-busters.app';

let failed = 0;
const check = (name, ok, extra = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${extra ? '  ' + extra : ''}`);
  if (!ok) failed++;
};

function tool(...args) {
  try {
    return execFileSync('node', ['students.mjs', ...args, '--emulator'], {
      cwd: import.meta.dirname, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (e) {
    return e.stdout ?? '';
  }
}

async function signIn(id, password) {
  const r = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: `${id}@${DOMAIN}`, password, returnSecureToken: true }),
  });
  return r.json();
}

async function commit(token, path, fields, { serverTime = true } = {}) {
  const name = `projects/${PROJECT}/databases/(default)/documents/${path}`;
  const write = { update: { name, fields } };
  if (serverTime) {
    write.updateTransforms = [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }];
  }
  const r = await fetch(`${FS}:commit`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
    body: JSON.stringify({ writes: [write] }),
  });
  return r.status;
}

async function get(token, path) {
  const r = await fetch(`${FS}/${path}`, { headers: { authorization: `Bearer ${token}` } });
  return r.status;
}

async function del(token, path) {
  const r = await fetch(`${FS}/${path}`, { method: 'DELETE', headers: { authorization: `Bearer ${token}` } });
  return r.status;
}

const entries = {
  schema: { integerValue: '1' },
  entries: { mapValue: { fields: {
    ark_best_talk: { mapValue: { fields: { v: { integerValue: '42' }, t: { integerValue: '1000' } } } },
  } } },
};

// Clean emulator state.
await fetch(`${AUTH}/emulator/v1/projects/${PROJECT}/accounts`, { method: 'DELETE' });
await fetch(`http://127.0.0.1:8080/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });

const dir = mkdtempSync(join(tmpdir(), 'ark-students-'));
const csv = join(dir, 'students.csv');
writeFileSync(csv, '﻿id,password,display_name\r\nARK001,hoshi-2026,山田 たろう\r\nark002,umi-sora-77,"佐藤, はなこ"\r\nark003,,\r\nbad id,xxxxxx,\r\nark004,123,\r\n');

const out1 = tool('upsert', csv, '--out', join(dir, 'r1.csv'), '--generate-passwords');
console.log(out1.trim());
check('upsert creates ark001/ark002', /ark001,[^,]+,created,ok/.test(out1) && /ark002,[^,]+,created,ok/.test(out1));
const gen = /ark003,[^,]+,created,ok,,([a-z0-9]{10})/.exec(out1);
check('upsert generates a password for ark003', !!gen);
check('invalid id rejected', /bad id,,,error/.test(out1));
check('short password rejected', /ark004,,,error/.test(out1));
const out2 = tool('upsert', csv, '--out', join(dir, 'r2.csv'));
check('second upsert updates (idempotent)', /ark001,[^,]+,updated\(password\),ok/.test(out2) && /ark003,[^,]+,updated,ok/.test(out2));

const a = await signIn('ark001', 'hoshi-2026');
const b = await signIn('ark002', 'umi-sora-77');
check('sign in with ID + password', !!a.idToken && !!b.idToken);
const wrong = await signIn('ark001', 'nope');
check('wrong password rejected', !!wrong.error, wrong.error?.message);
if (gen) check('generated password works', !!(await signIn('ark003', gen[1])).idToken);

check('write own apps/kids', (await commit(a.idToken, `users/${a.localId}/apps/kids`, entries)) === 200);
check('read own apps/kids', (await get(a.idToken, `users/${a.localId}/apps/kids`)) === 200);
check('read other student denied', (await get(b.idToken, `users/${a.localId}/apps/kids`)) === 403);
check('write other student denied', (await commit(b.idToken, `users/${a.localId}/apps/kids`, entries)) === 403);
check('unknown field denied', (await commit(a.idToken, `users/${a.localId}/apps/kids`, { ...entries, extra: { stringValue: 'x' } })) === 403);
check('client timestamp denied (must be server time)', (await commit(a.idToken, `users/${a.localId}/apps/kids`, { ...entries, updatedAt: { integerValue: '1' } }, { serverTime: false })) === 403);
check('bad appId denied', (await commit(a.idToken, `users/${a.localId}/apps/Bad.App`, entries)) === 403);
check('client delete denied', (await del(a.idToken, `users/${a.localId}/apps/kids`)) === 403);
check('user root doc write denied', (await commit(a.idToken, `users/${a.localId}`, { schema: { integerValue: '1' } }, { serverTime: false })) === 403);

const one = join(dir, 'one.csv');
writeFileSync(one, 'id\nark001\n');
check('disable', /ark001,[^,]+,disabled,ok/.test(tool('disable', one, '--out', join(dir, 'r3.csv'))));
const dis = await signIn('ark001', 'hoshi-2026');
check('disabled account cannot sign in', dis.error?.message?.includes('USER_DISABLED'), dis.error?.message);
check('enable', /ark001,[^,]+,enabled,ok/.test(tool('enable', one, '--out', join(dir, 'r4.csv'))));
check('list', /ark001,/.test(tool('list', '--out', join(dir, 'r5.csv'))));
check('delete requires --yes', !/deleted/.test(tool('delete', one, '--out', join(dir, 'r6.csv'))));
check('delete', /ark001,[^,]+,deleted,ok/.test(tool('delete', one, '--yes', '--out', join(dir, 'r7.csv'))));
const gone = await signIn('ark001', 'hoshi-2026');
check('deleted account cannot sign in', !!gone.error, gone.error?.message);
const admin = await fetch(`${FS}/users/${a.localId}/apps/kids`, { headers: { authorization: 'Bearer owner' } });
check('deleted account progress removed', admin.status === 404, `status ${admin.status}`);

console.log(failed ? `\n${failed} check(s) FAILED` : '\nAll checks passed');
process.exit(failed ? 1 : 0);
