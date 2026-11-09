// One-off: marks every library book without a visibility as public.
// Safe to run more than once; books that already have one are skipped.
//
// Run from the scripts folder:
//   npm install firebase-admin
//   set GOOGLE_APPLICATION_CREDENTIALS=path\to\service-account.json
//   node seed_visibility.js
//
// The service account key stays outside git (see .gitignore).

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({
  credential: applicationDefault(),
  projectId: 'shelf-scan-28d17',
});
const db = getFirestore();

async function main() {
  // collectionGroup('books') also matches any other "books" collection, so
  // only docs under libraries/{id}/books are touched
  const snap = await db.collectionGroup('books').get();
  const todo = snap.docs.filter(
    (d) =>
      d.ref.parent.parent?.parent.id === 'libraries' &&
      d.get('visibility') === undefined,
  );

  console.log(`${snap.size} books, ${todo.length} need a visibility`);

  // A batch holds at most 500 writes
  for (let i = 0; i < todo.length; i += 500) {
    const batch = db.batch();
    for (const doc of todo.slice(i, i + 500)) {
      batch.update(doc.ref, { visibility: 'public' });
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
