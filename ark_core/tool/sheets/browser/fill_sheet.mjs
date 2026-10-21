// Fills tabs of the (anonymously editable) question Sheet from TSV files, driving
// Google Sheets in headless Chrome (no login; the Sheet must allow link editing):
//   npm i puppeteer-core && node fill_sheet.mjs <tsvDir> tab1 [tab2 ...]   ("Sheet1=>pricing" renames first)
// TSV: one file per tab, cells with newlines/quotes CSV-quoted (see doc/CONTENT_SHEETS.md).
// Per tab: select tab → select all → Format ▸ Number ▸ Plain text → Delete → A1 → paste TSV.
import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import path from 'node:path';

const URL = 'https://docs.google.com/spreadsheets/d/1hgSc4wg00QQhS-qJt7qhRSU5kuShRwj9UZXt9vjFyOE/edit';
const [tsvDir, ...tabs] = process.argv.slice(2);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const b = await puppeteer.launch({
  headless: true,
  executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  args: ['--no-sandbox', '--lang=en-US'],
});
await b.defaultBrowserContext().overridePermissions('https://docs.google.com', ['clipboard-read', 'clipboard-write', 'clipboard-sanitized-write']);
const p = await b.newPage();
await p.setViewport({ width: 1400, height: 900 });
const shot = (n) => p.screenshot({ path: `fill_${n}.png` });

await p.goto(URL, { waitUntil: 'networkidle2', timeout: 120000 });
await sleep(4000);

const tabNames = () => p.evaluate(() => [...document.querySelectorAll('.docs-sheet-tab-name')].map((e) => e.innerText.trim()));
const activeTab = () => p.evaluate(() => document.querySelector('.docs-sheet-active-tab .docs-sheet-tab-name')?.innerText.trim());

async function clickMenuItem(re) {
  const h = await p.evaluateHandle((src) => {
    const re = new RegExp(src);
    return [...document.querySelectorAll('.goog-menuitem')].find((e) => e.offsetParent && re.test(e.innerText.trim().split('\n')[0]));
  }, re.source);
  const el = h.asElement();
  if (!el) throw new Error('menu item not found: ' + re);
  await el.click();
  await sleep(600);
}

async function selectTab(name) {
  // "All sheets" button (bottom-left ≡) lists every tab.
  const btn = await p.$('#docs-sheet-menu, [aria-label="All sheets"], [aria-label="All Sheets"], .docs-sheet-sheets-button');
  if (!btn) throw new Error('no all-sheets button');
  await btn.click();
  await sleep(800);
  await clickMenuItem(new RegExp('^' + name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '$'));
  await sleep(1200);
  const a = await activeTab();
  if (a !== name) throw new Error(`tab select failed: wanted ${name}, active ${a}`);
}

async function renameActive(newName) {
  const tab = await p.$('.docs-sheet-active-tab');
  await tab.click({ button: 'right' });
  await sleep(800);
  await clickMenuItem(/^Rename/);
  await sleep(500);
  await p.keyboard.down('Control'); await p.keyboard.press('KeyA'); await p.keyboard.up('Control');
  await p.keyboard.type(newName);
  await p.keyboard.press('Enter');
  await sleep(1500);
}

async function gotoCell(ref) {
  await p.click('#t-name-box');
  await sleep(200);
  await p.keyboard.down('Control'); await p.keyboard.press('KeyA'); await p.keyboard.up('Control');
  await p.keyboard.type(ref);
  await p.keyboard.press('Enter');
  await sleep(500);
}

async function waitSaved() {
  for (let i = 0; i < 60; i++) {
    const t = await p.evaluate(() => document.querySelector('#docs-title-save-label-text, .docs-title-save-label-text')?.innerText || '');
    if (/Saved|保存しました/.test(t)) return;
    await sleep(500);
  }
  console.log('  (save state unknown)');
}

for (let spec of tabs) {
  let [name, renameTo] = spec.split('=>');
  const dataName = renameTo || name;
  const tsv = fs.readFileSync(path.join(tsvDir, dataName + '.tsv'), 'utf8');
  console.log(`== ${dataName} (${tsv.length} chars)`);
  await selectTab(name);
  if (renameTo) { await renameActive(renameTo); console.log('  renamed →', await activeTab()); }
  // select all → toolbar "123" (More formats) → Plain text
  await gotoCell('A:Z'); // whole columns, not just the current data region
  await sleep(300);
  const fmtBtn = await p.$('#numberFormatMenuButton, [aria-label="More formats"], [aria-label="More number formats"]');
  if (!fmtBtn) { await shot('nofmt'); throw new Error('no 123 button'); }
  await fmtBtn.click();
  await sleep(800);
  await clickMenuItem(/^Plain text/);
  await sleep(600);
  // clear
  await gotoCell('A1');
  await p.keyboard.down('Control'); await p.keyboard.press('KeyA'); await p.keyboard.up('Control');
  await sleep(200);
  await p.keyboard.press('Delete');
  await sleep(800);
  // paste
  await gotoCell('A1');
  await p.evaluate((t) => navigator.clipboard.writeText(t), tsv);
  await sleep(300);
  await p.keyboard.down('Control'); await p.keyboard.press('KeyV'); await p.keyboard.up('Control');
  await sleep(4000 + tsv.length / 20);
  await waitSaved();
  const a1 = await p.evaluate(() => document.querySelector('#t-formula-bar-input-container, .cell-input')?.innerText?.trim());
  console.log('  done; active tab', await activeTab(), '; A1 =', a1);
  await shot(dataName);
}
console.log('tabs:', (await tabNames()).join(','));
await b.close();
