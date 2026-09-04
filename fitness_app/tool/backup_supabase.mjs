// Dumps every row of the Supabase database to JSON before a destructive
// change.
//
//   node tool/backup_supabase.mjs [outputDirectory]
//
// Writes one file per table plus a manifest of row counts, so a restore can be
// checked against what was taken rather than hoped about. Defaults to
// ../backups/supabase-<timestamp>, outside the app directory and gitignored —
// this contains real user data, including email addresses, and must never be
// committed.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import postgres from 'postgres';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

const url = fs
  .readFileSync(path.join(root, '.secrets.env'), 'utf8')
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line.startsWith('SUPABASE_DB_URL='))
  .map((line) => line.slice('SUPABASE_DB_URL='.length))[0];

if (!url) {
  console.error('SUPABASE_DB_URL not found in .secrets.env');
  process.exit(1);
}

/// Application tables, plus the accounts they belong to.
///
/// `auth.users` is included because the workout rows are keyed on `user_id`
/// and are meaningless without knowing whose they were. Only the columns that
/// identify an account are taken — never the password hashes or tokens.
const TABLES = [
  'public.workout_splits',
  'public.workout_routines',
  'public.routine_exercises',
  'public.workout_sessions',
  'public.workout_sets',
  'public.personal_bests',
  'public.exercises',
  'public.badges',
];

const stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
const outDir =
  process.argv[2] ?? path.join(root, '..', 'backups', `supabase-${stamp}`);

fs.mkdirSync(outDir, { recursive: true });

const sql = postgres(url, { ssl: 'require', max: 1, onnotice: () => {} });
const manifest = { takenAt: new Date().toISOString(), tables: {} };

try {
  for (const qualified of TABLES) {
    const rows = await sql.unsafe(`select * from ${qualified}`);
    const name = qualified.split('.')[1];
    fs.writeFileSync(
      path.join(outDir, `${name}.json`),
      JSON.stringify(rows, null, 2),
    );
    manifest.tables[name] = rows.length;
    console.log(`${String(rows.length).padStart(6)}  ${name}`);
  }

  const users = await sql.unsafe(
    'select id, email, created_at, last_sign_in_at from auth.users order by created_at',
  );
  fs.writeFileSync(
    path.join(outDir, 'auth_users.json'),
    JSON.stringify(users, null, 2),
  );
  manifest.tables['auth.users'] = users.length;
  console.log(`${String(users.length).padStart(6)}  auth.users`);

  fs.writeFileSync(
    path.join(outDir, 'manifest.json'),
    JSON.stringify(manifest, null, 2),
  );

  console.log(`\nwritten to ${path.resolve(outDir)}`);
} catch (error) {
  // Not logging the error object: the client attaches its connection options,
  // password included.
  console.error('BACKUP FAILED:', error.message);
  process.exitCode = 1;
} finally {
  await sql.end({ timeout: 5 });
}
