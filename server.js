const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());


// ... (votre code existant : imports, pool, register)

// NOUVELLE ROUTE : Connexion (Login)
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  
  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE email = $1 AND password = $2',
      [email, password]
    );

    if (result.rows.length > 0) {
      res.status(200).json({
        user: result.rows[0],
        token: 'fake-jwt-token-for-testing'
      });
    } else {
      res.status(401).json({ message: "Identifiants incorrects" });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Erreur serveur" });
  }
});


// Configuration de la connexion à PostgreSQL
/*const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'agrismart',
  password: 'admin', // À modifier
  port: 5432,
});*/

// Remplace l'ancienne configuration par celle-ci
const pool = new Pool({
  connectionString: 'postgresql://postgres:nGhcAFXJwvyRJpGELgDbPLsphtEoBYxJ@postgres.railway.internal:5432/railway',
  ssl: {
    rejectUnauthorized: false // Obligatoire pour se connecter aux DB cloud en mode sécurisé
  }
});

// Route d'inscription qui correspond à auth_service.dart
app.post('/api/auth/register', async (req, res) => {
  const { email, password, name, role, phone } = req.body;
  
  try {
    // Insertion dans PostgreSQL
    const result = await pool.query(
      'INSERT INTO users (email, password, name, role, phone, created_at) VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP) RETURNING *',
      [email, password, name, role, phone]
    );

    // Retourne l'utilisateur créé et un token fictif pour Flutter
    res.status(201).json({
      user: result.rows[0],
      token: 'fake-jwt-token-for-testing'
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Erreur lors de l'inscription" });
  }
});

app.listen(3000, () => {
  console.log('Serveur Backend AgriSmart lancé sur http://localhost:3000');
});

