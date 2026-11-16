// One-off: gives every library book without a readingKey the same key the
// app works out (BookModel.readingKey), so search can find it in libraries.
// Safe to run more than once; books that already have the field are skipped.
//
// Run from the scripts folder:
//   npm install firebase-admin
//   set GOOGLE_APPLICATION_CREDENTIALS=path\to\service-account.json
//   node seed_reading_key.js            (dry run: prints, writes nothing)
//   node seed_reading_key.js --write
//
// The service account key stays outside git (see .gitignore).

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({
  credential: applicationDefault(),
  projectId: 'shelf-scan-28d17',
});
const db = getFirestore();
const write = process.argv.includes('--write');

// Letters the Dart diacritic package maps that NFD doesn't split
const special = { ø: 'o', æ: 'ae', œ: 'oe', ß: 'ss', ł: 'l', đ: 'd', ı: 'i' };

// Same steps as BookModel.normalize in Dart
function normalize(s) {
  let out = s
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{M}/gu, '') // "misérables" → "miserables"
    .replace(/[øæœßłđı]/g, (c) => special[c]);
  out = out.replace(/\(.*?\)|（.*?）/g, ''); // drop "(Book 1)"
  out = out.trim().replace(/^(the|a|an)\s+/, ''); // drop a leading article
  return out.replace(/[^\p{L}\p{M}\p{N}]/gu, ''); // letters, marks, digits only
}

// Same as BookModel.readingKey; null when there's no title or author
function readingKey(data) {
  const authors = Array.isArray(data.authors) ? data.authors : [];
  if (!data.title || data.title === 'Unknown Title' || authors.length === 0) {
    return null;
  }
  const t = normalize(data.title);
  const a = normalize(String(authors[0]));
  return t && a ? `${t}_${a}` : null;
}

async function main() {
  // collectionGroup('books') also matches any other "books" collection, so
  // only docs under libraries/{id}/books are touched
  const snap = await db.collectionGroup('books').get();
  const todo = snap.docs.filter(
    (d) =>
      d.ref.parent.parent?.parent.id === 'libraries' &&
      d.get('readingKey') === undefined,
  );

  console.log(`${snap.size} books, ${todo.length} need a readingKey`);

  if (!write) {
    for (const doc of todo.slice(0, 20)) {
      console.log(`${doc.get('title')} → ${readingKey(doc.data())}`);
    }
    console.log('Dry run; add --write to save');
    return;
  }

  // A batch holds at most 500 writes. Null keys are written too, so a
  // second run skips those books.
  for (let i = 0; i < todo.length; i += 500) {
    const batch = db.batch();
    for (const doc of todo.slice(i, i + 500)) {
      batch.update(doc.ref, { readingKey: readingKey(doc.data()) });
    }
    await batch.commit();
    console.log(`Updated ${Math.min(i + 500, todo.length)} of ${todo.length}`);
  }

  console.log('Done');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
