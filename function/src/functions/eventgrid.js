// Live-check fixture: one Event Grid triggered function and an HTTP read-back.
//
// Both functions live in one module on purpose. The Functions worker loads this
// file once per process, and both share the one PostgreSQL pool from ../db - the
// Event Grid trigger INSERTs into it and the HTTP function reads it back. Nothing
// here knows it is running against Locally rather than Azure, and nothing holds a
// database password: see ../db.js for the managed-identity, passwordless access.
//
// The Event Grid trigger is what makes the Functions host provision the app's
// `eventgrid_extension` system key, which is the credential postie presents when
// it delivers to /runtime/webhooks/eventgrid.

const { app } = require("@azure/functions");
const { getPool } = require("../db");

app.eventGrid("EventGridReceiver", {
    handler: async (event, context) => {
        const pool = await getPool();
        await pool.query(
            `INSERT INTO events (id, event_type, subject, data, event)
             VALUES ($1, $2, $3, $4, $5)`,
            [
                event && event.id,
                event && event.eventType,
                event && event.subject,
                event && event.data,
                event,
            ]
        );
        const { rows } = await pool.query("SELECT count(*)::int AS total FROM events");
        context.log(
            `EventGridReceiver: id=${event && event.id} eventType=${event && event.eventType} subject=${event && event.subject} (total ${rows[0].total})`
        );
    },
});

// GET  /api/received -> every event the trigger has stored, oldest first
// DELETE /api/received -> empty the table, so a second publish is unambiguous
//
// authLevel is anonymous so the read-back needs no key of its own; the point of
// the fixture is the Event Grid path, not HTTP auth.
app.http("Received", {
    methods: ["GET", "DELETE"],
    authLevel: "anonymous",
    handler: async (request, context) => {
        const pool = await getPool();

        if (request.method === "DELETE") {
            const { rowCount } = await pool.query("DELETE FROM events");
            context.log(`Received: cleared ${rowCount} event(s)`);
            return { jsonBody: { cleared: rowCount } };
        }

        const { rows } = await pool.query(
            `SELECT id, event_type AS "eventType", subject, received_at AS "receivedAt", data, event
             FROM events
             ORDER BY seq`
        );
        return { jsonBody: { count: rows.length, events: rows } };
    },
});
