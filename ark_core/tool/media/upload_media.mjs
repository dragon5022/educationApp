#!/usr/bin/env node
// Uploads a folder of media (mp3 / webp / png …) to Firebase Storage under
// media/, keeping the relative paths the question sheet refers to.
//
//   node upload_media.mjs <folder> --key service-account.json [--bucket <name>] [--dry-run]
//   (--bucket: the name shown at the top of Firebase console → Storage, e.g. gs://<name>)
//
//   <folder>/audio/voice/lis/g5_0_17.mp3  →  media/audio/voice/lis/g5_0_17.mp3
//
// Files that already exist with the same size are skipped. The console
// drag-and-drop works too; this script is for many files at once.
import { createReadStream, readFileSync, statSync } from 'node:fs';
import { readdir } from 'node:fs/promises';
import { join, relative, sep } from 'node:path';
import { createHash } from 'node:crypto';
import admin from 'firebase-admin';

const args = process.argv.slice(2);
const folder = args.find((a) => !a.startsWith('--'));
const opt = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : undefined; };
const keyPath = opt('--key');
const dry = args.includes('--dry-run');
if (!folder || !keyPath) {
  console.error('usage: node upload_media.mjs <folder> --key service-account.json [--bucket <name>] [--dry-run]');
  process.exit(64);
}

const key = JSON.parse(readFileSync(keyPath, 'utf8'));
// Projects created since late 2024 use <project>.firebasestorage.app; older ones .appspot.com.
const bucketName = opt('--bucket') ?? `${key.project_id}.firebasestorage.app`;
admin.initializeApp({ credential: admin.credential.cert(key), storageBucket: bucketName });
const bucket = admin.storage().bucket();

const types = { mp3: 'audio/mpeg', m4a: 'audio/mp4', wav: 'audio/wav', ogg: 'audio/ogg',
  webp: 'image/webp', png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif' };

async function* walk(dir) {
  for (const e of await readdir(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) yield* walk(p);
    else yield p;
  }
}

const md5 = (p) => createHash('md5').update(readFileSync(p)).digest('base64');

let uploaded = 0, skipped = 0, ignored = 0;
for await (const file of walk(folder)) {
  const ext = file.split('.').pop().toLowerCase();
  if (!types[ext]) { ignored++; continue; }
  const rel = relative(folder, file).split(sep).join('/');
  const dest = `media/${rel}`;
  const remote = bucket.file(dest);
  const [exists] = await remote.exists();
  if (exists) {
    const [meta] = await remote.getMetadata();
    if (meta.md5Hash === md5(file)) { skipped++; continue; }
  }
  if (dry) { console.log(`would upload ${rel}`); uploaded++; continue; }
  await new Promise((resolve, reject) => {
    createReadStream(file)
      .pipe(remote.createWriteStream({
        metadata: { contentType: types[ext], cacheControl: 'public, max-age=31536000, immutable' },
        resumable: statSync(file).size > 5 * 1024 * 1024,
      }))
      .on('finish', resolve)
      .on('error', reject);
  });
  console.log(`uploaded ${rel}`);
  uploaded++;
}
console.log(`${dry ? 'would upload' : 'uploaded'} ${uploaded}, unchanged ${skipped}, ignored ${ignored} (not media)`);
console.log(`bucket: ${bucketName}`);
