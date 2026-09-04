// Runs SQL against the project's Supabase database.
//
//   node tool/sql.mjs --file supabase/migrations/0001_split_schedule.sql
//   node tool/sql.mjs --query "select count(*) from workout_sets"
//
// There is no automated migration runner for this project — the remote schema
// is kept in step with the local one by hand, because every sync payload in
// sync_service.dart names its columns explicitly. This is that hand.
//
// The connection string lives in .secrets.env, which is gitignored. It is read
// here and never printed: errors are reported without the URL, so a failure
// cannot leak the password into a terminal log.
//
// Install once:  npm install postgres@3
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import postgres from 'postgres';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const secretsPath = path.join(root, '.secrets.env');

if (!fs.existsSync(secretsPath)) {
  console.error(
    'No .secrets.env. Put the Supabase session-pooler connection string in\n' +
      `  ${secretsPath}\n` +
      'as a single line: SUPABASE_DB_URL=postgresql://...',
  );
  process.exit(1);
}

const url = fs
  .readFileSync(secretsPath, 'utf8')
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line.startsWith('SUPABASE_DB_URL='))
  .map((line) => line.slice('SUPABASE_DB_URL='.length))[0];

if (!url) {
  console.error('SUPABASE_DB_URL not found in .secrets.env');
  process.exit(1);
}

// A password containing / or @ makes the string an invalid URL, which the
// client reports as a hang rather than as a parse error. Caught here so it is
// obvious what went wrong.
try {
  new URL(url);
} catch {
  console.error(
    'SUPABASE_DB_URL is not a valid URL. If the password contains / @ : ? # ' +
      'or %, percent-encode it.',
  );
  process.exit(1);
}

const args = process.argv.slice(2);
const fileAt = args.indexOf('--file');
const queryAt = args.indexOf('--query');

if (fileAt === -1 && queryAt === -1) {
  console.error('Usage: node tool/sql.mjs --file <path.sql> | --query "<sql>"');
  process.exit(1);
}

const text =
  fileAt !== -1
    ? fs.readFileSync(args[fileAt + 1], 'utf8')
    : args[queryAt + 1];

const sql = postgres(url, { ssl: 'require', max: 1, onnotice: () => {} });

try {
  const result = await sql.unsafe(text);

  // postgres@3 hands back the last statement's rows for a multi-statement
  // script, and an empty result for pure DDL.
  if (Array.isArray(result) && result.length > 0) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    console.log('ok');
  }
} catch (error) {
  // Deliberately not logging the error object: the client attaches the
  // connection options to it, password included.
  console.error('SQL FAILED:', error.message);
  if (error.position) console.error('  at character', error.position);
  process.exitCode = 1;
} finally {
  await sql.end({ timeout: 5 });
}
