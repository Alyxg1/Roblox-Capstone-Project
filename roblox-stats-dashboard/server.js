// roblox-stats-dashboard/server.js
const path = require("path");
const express = require("express");
const cors = require("cors");
const Database = require("better-sqlite3");

const app = express();
const PORT = process.env.PORT || 3020;
const SECRET = process.env.STATS_SECRET || "dev-secret";

// ---- middleware (must be before routes)
app.use(cors());
app.use(express.json({ limit: "1mb" }));

// ---- DB (creates stats.db next to this file)
const db = new Database(path.join(__dirname, "stats.db"));
db.pragma("journal_mode = wal");
db.prepare(`
  CREATE TABLE IF NOT EXISTS players (
    userId       INTEGER PRIMARY KEY,
    username     TEXT,
    highestRound INTEGER NOT NULL DEFAULT 0,
    updatedAt    INTEGER NOT NULL
  )
`).run();

// ---- simple logger so you can see traffic in the terminal
app.use((req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  next();
});

// ---- API
app.post("/api/event", (req, res) => {
  try {
    if (req.header("x-stats-secret") !== SECRET) {
      return res.status(401).json({ ok: false, error: "bad secret" });
    }
    const { userId, username, highestRound } = req.body || {};
    if (!userId || !username) {
      return res.status(400).json({ ok: false, error: "missing fields" });
    }

    const now = Math.floor(Date.now() / 1000);
    db.prepare(`
      INSERT INTO players (userId, username, highestRound, updatedAt)
      VALUES (@userId, @username, @highestRound, @updatedAt)
      ON CONFLICT(userId) DO UPDATE SET
        username=excluded.username,
        highestRound=MAX(players.highestRound, excluded.highestRound),
        updatedAt=excluded.updatedAt
    `).run({ userId, username, highestRound: Number(highestRound) || 0, updatedAt: now });

    return res.json({ ok: true });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ ok: false, error: "server error" });
  }
});

app.get("/api/latest", (req, res) => {
  const rows = db.prepare(`
    SELECT userId, username, highestRound, updatedAt
    FROM players
    ORDER BY highestRound DESC, updatedAt DESC
    LIMIT 100
  `).all();
  res.json({ ok: true, rows });
});

// health check (fast way to prove server responds)
app.get("/health", (_req, res) => res.type("text").send("ok"));

// ---- Static site
app.use(express.static(path.join(__dirname, "public")));
app.get("/", (_req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

// ---- start
app.listen(PORT, () => {
  console.log(`Roblox stats dashboard listening on http://127.0.0.1:${PORT}`);
  console.log(`DB: ${path.join(__dirname, "stats.db")}`);
  console.log(`SECRET: ${SECRET}`);
});
