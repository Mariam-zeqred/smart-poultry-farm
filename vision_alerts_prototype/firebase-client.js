/**
 * Minimal Firebase Realtime Database REST client.
 *
 * Deliberately NOT using the Firebase Web SDK: the project's RTDB rules are
 * currently wide open (".read": true, ".write": true), the same access level
 * the Flutter app itself uses without auth (see alert_provider.dart comment
 * "no auth needed — hardcoded device ID"). Plain fetch() against the REST
 * endpoints avoids registering a new Firebase Web app just for this test
 * page, and avoids ever embedding the DB *secret* (an admin key that bypasses
 * all rules) in client-side code — that secret should never ship in the
 * Flutter app or this prototype, only used for one-off backend exploration.
 */

const DB_URL = 'https://poultrysystem-1e315-default-rtdb.firebaseio.com';

async function dbGet(path) {
  const res = await fetch(`${DB_URL}/${path}.json`);
  if (!res.ok) throw new Error(`GET ${path} failed: ${res.status}`);
  return res.json();
}

async function dbPut(path, value) {
  const res = await fetch(`${DB_URL}/${path}.json`, {
    method: 'PUT',
    body: JSON.stringify(value),
  });
  if (!res.ok) throw new Error(`PUT ${path} failed: ${res.status}`);
  return res.json();
}

async function dbPatch(path, value) {
  const res = await fetch(`${DB_URL}/${path}.json`, {
    method: 'PATCH',
    body: JSON.stringify(value),
  });
  if (!res.ok) throw new Error(`PATCH ${path} failed: ${res.status}`);
  return res.json();
}

async function dbPost(path, value) {
  const res = await fetch(`${DB_URL}/${path}.json`, {
    method: 'POST',
    body: JSON.stringify(value),
  });
  if (!res.ok) throw new Error(`POST ${path} failed: ${res.status}`);
  return res.json(); // { name: "<new key>" }
}

async function dbDelete(path) {
  const res = await fetch(`${DB_URL}/${path}.json`, { method: 'DELETE' });
  if (!res.ok) throw new Error(`DELETE ${path} failed: ${res.status}`);
}

/** Firebase server-timestamp sentinel, same shape the ESP32 firmware sends. */
function serverTimestamp() {
  return { '.sv': 'timestamp' };
}
