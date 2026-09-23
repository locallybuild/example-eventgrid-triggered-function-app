// Passwordless PostgreSQL access for the Function App.
//
// Nothing here holds a database password. The app authenticates with its own
// Microsoft Entra managed identity: it asks the identity for a token scoped to
// the Azure Database for PostgreSQL resource, and presents that token as the
// password. `pg` calls the `password` function on every new connection, so the
// pool always dials with a fresh, unexpired token.
//
// The identity is registered as the server's Entra administrator (see the
// Terraform module), and an Entra admin can CREATE DATABASE, so on first use the
// app creates and OWNS its own `events` database — no admin login, and no
// separate migration step, ever runs. Nothing here knows it is talking to Locally
// rather than Azure.

const { ManagedIdentityCredential } = require("@azure/identity");
const { Client, Pool } = require("pg");

// The audience an Entra token must carry to log in to a flexible server. Client
// libraries hardcode this exact value; `az account get-access-token
// --resource-type oss-rdbms` mints tokens against it. It is an identity claim,
// never a host that is dialed.
const OSSRDBMS_SCOPE = "https://ossrdbms-aad.database.windows.net/.default";

// The flexible server's fqdn arrives as "host:port" (the port is embedded), so
// split it into the two pieces `pg` wants.
const [PGHOST, PGPORT] = (process.env.PGHOST || "").split(":");
const PGUSER = process.env.PGUSER;
const PGDATABASE = process.env.PGDATABASE || "events";

const credential = new ManagedIdentityCredential();

async function accessToken() {
    const token = await credential.getToken(OSSRDBMS_SCOPE);
    return token.token;
}

// Locally's data-plane certificate is not chained to a public root, so this
// example does not verify it. Against real Azure you would drop `ssl` (Npgsql/pg
// verify the Azure-issued certificate by default) or pin the Microsoft root.
const SSL = { rejectUnauthorized: false };

function quoteIdent(name) {
    return '"' + String(name).replace(/"/g, '""') + '"';
}

// The Event Grid trigger and the HTTP read-back share one pool. `initPool` runs
// at most once — the memoised promise below serialises concurrent first calls.
let poolPromise;

async function initPool() {
    // 1. Ensure our own database exists. We connect to the default `postgres`
    //    database (an Entra admin may connect to it) and CREATE DATABASE, which
    //    makes this identity the owner — that ownership is what later lets it
    //    create tables without any extra grant. CREATE DATABASE cannot run in a
    //    transaction, so it goes through a plain Client, not the pool.
    const admin = new Client({
        host: PGHOST,
        port: Number(PGPORT),
        database: "postgres",
        user: PGUSER,
        password: accessToken,
        ssl: SSL,
    });
    await admin.connect();
    try {
        await admin.query(`CREATE DATABASE ${quoteIdent(PGDATABASE)}`);
    } catch (err) {
        // 42P04 = duplicate_database: another instance won the race, which is fine.
        if (err.code !== "42P04") {
            throw err;
        }
    } finally {
        await admin.end();
    }

    // 2. A pool onto our database, re-tokening on every new connection.
    const pool = new Pool({
        host: PGHOST,
        port: Number(PGPORT),
        database: PGDATABASE,
        user: PGUSER,
        password: accessToken,
        ssl: SSL,
        max: 4,
    });

    // 3. The table the events land in. We own the database, so this needs no grant.
    await pool.query(`
        CREATE TABLE IF NOT EXISTS events (
            seq          bigserial PRIMARY KEY,
            id           text,
            event_type   text,
            subject      text,
            received_at  timestamptz NOT NULL DEFAULT now(),
            data         jsonb,
            event        jsonb
        )
    `);

    return pool;
}

function getPool() {
    if (!poolPromise) {
        poolPromise = initPool().catch((err) => {
            // Let the next call retry a failed bootstrap rather than caching the failure.
            poolPromise = undefined;
            throw err;
        });
    }
    return poolPromise;
}

module.exports = { getPool };
