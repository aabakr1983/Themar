import bcrypt from 'bcryptjs';
import { q, pool } from './src/db.js';

// usage: node mkadmin.js <username> "<full name>" <admin|gate|floor> [floors]
//   node mkadmin.js ahmad "Ahmad" admin
//   node mkadmin.js gate1 "مشرفة البوابة" gate
//   node mkadmin.js floor2 "مشرفة الدور الثاني" floor 2
//   node mkadmin.js floor13 "مشرفة الأدوار 1 و3" floor 1,3

const [, , username, fullName, role = 'admin', floorsArg = ''] = process.argv;

if (!username || !fullName) {
  console.error('usage: node mkadmin.js <username> "<full name>" <admin|gate|floor> [floors]');
  process.exit(1);
}
if (!['admin', 'gate', 'floor'].includes(role)) {
  console.error('role must be one of: admin, gate, floor');
  process.exit(1);
}

const floors = floorsArg
  .split(',')
  .map(s => Number(s.trim()))
  .filter(n => Number.isInteger(n) && n >= 0 && n <= 9);

if (role === 'floor' && !floors.length) {
  console.error('a floor account needs at least one floor, e.g. ... floor 2');
  process.exit(1);
}

const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
const pass = [...crypto.getRandomValues(new Uint8Array(24))]
  .map(b => alphabet[b % alphabet.length]).join('').slice(0, 16);

const hash = await bcrypt.hash(pass, 10);

await q(
  `INSERT INTO staff (full_name, username, password_hash, role, floors)
   VALUES ($1,$2,$3,$4,$5)
   ON CONFLICT (username) DO UPDATE
     SET password_hash = EXCLUDED.password_hash,
         full_name     = EXCLUDED.full_name,
         role          = EXCLUDED.role,
         floors        = EXCLUDED.floors,
         active        = true`,
  [fullName, username, hash, role, floors]);

console.log('username: ' + username);
console.log('password: ' + pass);
console.log('role:     ' + role + (floors.length ? ' (floors: ' + floors.join(', ') + ')' : ''));
console.log('');
console.log('Staff sign in at /staff — save this password now, it is not shown again.');

await pool.end();
