const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Utilise DATABASE_URL (variable Railway) en priorité
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:nGhcAFXJwvyRJpGELgDbPLsphtEoBYxJ@shortline.proxy.rlwy.net:32275/railway',
  ssl: { rejectUnauthorized: false }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE email = $1 AND password = $2',
      [email, password]
    );
    if (result.rows.length > 0) {
      res.status(200).json({ user: result.rows[0], token: 'fake-jwt-token-for-testing' });
    } else {
      res.status(401).json({ message: "Identifiants incorrects" });
    }
  } catch (err) {
    res.status(500).json({ message: "Erreur serveur" });
  }
});

app.post('/api/auth/register', async (req, res) => {
  const { email, password, name, role, phone } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO users (email, password, name, role, phone, created_at) VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP) RETURNING *',
      [email, password, name, role, phone]
    );
    res.status(201).json({ user: result.rows[0], token: 'fake-jwt-token-for-testing' });
  } catch (err) {
    res.status(500).json({ message: "Erreur lors de l'inscription" });
  }
});

// ⚠️ PORT dynamique obligatoire pour Railway
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Serveur lancé sur port ${PORT}`));