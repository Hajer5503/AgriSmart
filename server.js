const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:nGhcAFXJwvyRJpGELgDbPLsphtEoBYxJ@shortline.proxy.rlwy.net:32275/railway',
  ssl: { rejectUnauthorized: false }
});

// Test de connexion au démarrage (sans crasher)
pool.connect()
  .then(client => {
    console.log('✅ Connecté à PostgreSQL');
    client.release();
  })
  .catch(err => {
    console.error('❌ Erreur DB:', err.message);
    // Ne pas crasher, le serveur continue
  });

// ✅ Test
app.get('/', (req, res) => res.json({ message: 'AgriSmart API ✅' }));

// ========== AUTH ==========
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1 AND password = $2', [email, password]);
    if (result.rows.length > 0) {
      res.status(200).json({ user: result.rows[0], token: 'fake-jwt-token-for-testing' });
    } else {
      res.status(401).json({ message: "Identifiants incorrects" });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Erreur serveur" });
  }
});

app.post('/api/auth/register', async (req, res) => {
  const { email, password, name, role, phone } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO users (email, password, name, role, phone) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [email, password, name, role, phone]
    );
    res.status(201).json({ user: result.rows[0], token: 'fake-jwt-token-for-testing' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Erreur lors de l'inscription" });
  }
});

// ========== FARMS ==========
app.get('/api/farms', async (req, res) => {
  const userId = req.query.user_id;
  try {
    const result = await pool.query('SELECT * FROM farms WHERE user_id = $1 ORDER BY created_at DESC', [userId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: "Erreur serveur" });
  }
});

app.post('/api/farms', async (req, res) => {
  const { user_id, name, location, area_hectares, soil_type } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO farms (user_id, name, location, area_hectares, soil_type) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [user_id, name, location, area_hectares, soil_type]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ message: "Erreur serveur" });
  }
});

app.delete('/api/farms/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM farms WHERE id = $1', [req.params.id]);
    res.json({ message: 'Ferme supprimée' });
  } catch (err) {
    res.status(500).json({ message: "Erreur serveur" });
  }
});

// ========== CROPS ==========
app.get('/api/crops', async (req, res) => {
  const farmId = req.query.farm_id;
  try {
    const query = farmId
      ? 'SELECT * FROM crops WHERE farm_id = $1 ORDER BY created_at DESC'
      : 'SELECT c.*, f.name as farm_name FROM crops c JOIN farms f ON c.farm_id = f.id ORDER BY c.created_at DESC';
    const result = farmId ? await pool.query(query, [farmId]) : await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: "Erreur serveur" });
  }
});

app.post('/api/crops', async (req, res) => {
  const { farm_id, crop_type, planting_date, expected_harvest, area_hectares } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO crops (farm_id, crop_type, planting_date, expected_harvest, area_hectares) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [farm_id, crop_type, planting_date, expected_harvest, area_hectares]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ message: "Erreur serveur" });
  }
});

// ========== ALERTS ==========
app.get('/api/alerts', async (req, res) => {
  const userId = req.query.user_id;
  try {
    const result = await pool.query(
      'SELECT * FROM alerts WHERE user_id = $1 ORDER BY created_at DESC',
      [userId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: "Erreur serveur" });
  }
});

app.patch('/api/alerts/:id/read', async (req, res) => {
  try {
    await pool.query('UPDATE alerts SET is_read = TRUE WHERE id = $1', [req.params.id]);
    res.json({ message: 'Alerte marquée comme lue' });
  } catch (err) {
    res.status(500).json({ message: "Erreur serveur" });
  }
});

app.post('/api/alerts', async (req, res) => {
  const { user_id, farm_id, type, severity, message } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO alerts (user_id, farm_id, type, severity, message) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [user_id, farm_id, type, severity, message]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ message: "Erreur serveur" });
  }
});

// ========== LIVESTOCK ==========
app.get('/api/livestock', async (req, res) => {
  const farmId = req.query.farm_id;
  try {
    const result = await pool.query('SELECT * FROM livestock WHERE farm_id = $1 ORDER BY created_at DESC', [farmId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: "Erreur serveur" });
  }
});

app.post('/api/livestock', async (req, res) => {
  const { farm_id, tag_number, species, breed, birth_date, weight } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO livestock (farm_id, tag_number, species, breed, birth_date, weight) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [farm_id, tag_number, species, breed, birth_date, weight]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ message: "Erreur serveur" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Serveur AgriSmart lancé sur port ${PORT}`));