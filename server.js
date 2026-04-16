/*const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const app = express();
app.use(cors());
app.use(express.json());

// ── Config ────────────────────────────────────────────────
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

pool.connect()
  .then(c => { console.log('✅ PostgreSQL connecté'); c.release(); })
  .catch(e => console.error('❌ DB:', e.message));

const JWT_SECRET  = process.env.JWT_SECRET  || 'agrismart_dev_secret';
const GROQ_KEY    = process.env.GROQ_API_KEY || process.env.GROQ_KEY;
const OWM_KEY     = process.env.OWM_API_KEY;
const N8N_URL     = (process.env.N8N_URL || 'https://anonyme878-n8n.hf.space').replace(/\/$/, '');

// ── Middleware JWT ────────────────────────────────────────
function auth(req, res, next) {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ message: 'Token manquant' });
  try {
    req.user = jwt.verify(header.replace('Bearer ', ''), JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ message: 'Token invalide ou expiré' });
  }
}

// ── Appel n8n ────────────────────────────────────────────
async function callN8n(webhookPath, body) {
  const url = `${N8N_URL}/webhook/${webhookPath}`;
  console.log(`📡 n8n → ${url}`);
  try {
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(10000)
    });
    const text = await r.text();
    try { return JSON.parse(text); }
    catch { return { raw: text }; }
  } catch (e) {
    console.error(`❌ n8n ${webhookPath}:`, e.message);
    return { error: e.message };
  }
}

// ── Outils n8n disponibles ───────────────────────────────
async function executeTool(name, args, userId) {
  console.log(`🔧 Outil: ${name}`, args);
  switch (name) {
    case 'get_weather':
      return callN8n('get-weather', { location: args.location || 'Tunis' });

    case 'get_farm_data':
      return callN8n('get_farm_data', { user_id: userId });

    case 'get_alerts':
      return callN8n('get_farm_data', { user_id: userId }); // réutilise ou crée un webhook dédié

    case 'create_alert': {
      // Insère directement en BD ET notifie via n8n
      try {
        await pool.query(
          'INSERT INTO alerts (user_id,farm_id,type,severity,message) VALUES ($1,$2,$3,$4,$5)',
          [userId, args.farm_id || null, args.type, args.severity, args.message]
        );
      } catch (e) { console.error('Alert BD:', e.message); }
      return callN8n('create_alert', { ...args, user_id: userId });
    }

    case 'get_tasks': {
      const r = await pool.query(
        'SELECT * FROM tasks WHERE user_id=$1 AND done=FALSE ORDER BY due_date ASC LIMIT 10',
        [userId]
      );
      return { tasks: r.rows };
    }

    case 'create_task': {
      const r = await pool.query(
        'INSERT INTO tasks (user_id,title,description,priority,due_date,category) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
        [userId, args.title, args.description||'', args.priority||'medium', args.due_date||null, args.category||'Autre']
      );
      return { task: r.rows[0], created: true };
    }

    case 'get_crops': {
      const r = await pool.query(
        `SELECT c.*,f.name as farm_name FROM crops c
         JOIN farms f ON c.farm_id=f.id
         WHERE f.user_id=$1 ORDER BY c.created_at DESC`,
        [userId]
      );
      return { crops: r.rows };
    }

    case 'get_livestock':
      return callN8n('get_farm_data', { user_id: userId, type: 'livestock' });

    case 'get_summary': {
      // Vue globale de l'exploitation
      const [farms, alerts, tasks, crops] = await Promise.all([
        pool.query('SELECT * FROM farms WHERE user_id=$1', [userId]),
        pool.query("SELECT * FROM alerts WHERE user_id=$1 AND is_read=FALSE ORDER BY created_at DESC LIMIT 5", [userId]),
        pool.query("SELECT * FROM tasks WHERE user_id=$1 AND done=FALSE ORDER BY due_date ASC LIMIT 5", [userId]),
        pool.query(`SELECT c.*,f.name as farm_name FROM crops c JOIN farms f ON c.farm_id=f.id WHERE f.user_id=$1 ORDER BY c.created_at DESC LIMIT 10`, [userId]),
      ]);
      return {
        farms: farms.rows,
        unread_alerts: alerts.rows,
        pending_tasks: tasks.rows,
        crops: crops.rows,
        summary: {
          farm_count: farms.rowCount,
          alert_count: alerts.rowCount,
          task_count: tasks.rowCount,
        }
      };
    }

    default:
      return { error: `Outil inconnu: ${name}` };
  }
}

// ── Définition des outils Groq ───────────────────────────
const GROQ_TOOLS = [
  {
    type: 'function',
    function: {
      name: 'get_summary',
      description: "Récupère un résumé complet de l'exploitation : fermes, alertes non lues, tâches en attente, cultures. Appelle cet outil en premier pour répondre aux questions générales.",
      parameters: { type: 'object', properties: {} }
    }
  },
  {
    type: 'function',
    function: {
      name: 'get_weather',
      description: "Obtient la météo actuelle pour une ville tunisienne. Appelle quand l'utilisateur mentionne météo, pluie, température, vent, soleil.",
      parameters: {
        type: 'object',
        properties: {
          location: { type: 'string', description: 'Ville ex: Tunis, Sfax, Sousse, Bizerte' }
        },
        required: ['location']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'get_farm_data',
      description: "Récupère fermes et parcelles de l'utilisateur. Appelle pour questions sur les fermes, parcelles, superficie.",
      parameters: { type: 'object', properties: {} }
    }
  },
  {
    type: 'function',
    function: {
      name: 'get_crops',
      description: "Récupère les cultures actuelles (tomate, blé, olive...). Appelle pour questions sur les cultures, récoltes, semis.",
      parameters: { type: 'object', properties: {} }
    }
  },
  {
    type: 'function',
    function: {
      name: 'get_tasks',
      description: "Récupère les tâches en attente de l'utilisateur. Appelle pour questions sur les tâches, planning, agenda.",
      parameters: { type: 'object', properties: {} }
    }
  },
  {
    type: 'function',
    function: {
      name: 'create_task',
      description: "Crée une nouvelle tâche agricole. Appelle quand l'utilisateur demande d'ajouter une tâche, programmer quelque chose.",
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Titre de la tâche' },
          description: { type: 'string', description: 'Description détaillée' },
          priority: { type: 'string', enum: ['high', 'medium', 'low'] },
          due_date: { type: 'string', description: 'Date ISO ex: 2025-04-20' },
          category: { type: 'string', description: 'Irrigation, Traitement, Récolte, Semis, Maintenance, Autre' }
        },
        required: ['title']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'create_alert',
      description: "Crée une alerte urgente. Appelle si tu détectes un problème grave : maladie, manque d'eau, température extrême, problème animal.",
      parameters: {
        type: 'object',
        properties: {
          type: { type: 'string', enum: ['water_stress', 'disease', 'temperature', 'weather', 'livestock'] },
          severity: { type: 'string', enum: ['low', 'medium', 'high', 'critical'] },
          message: { type: 'string', description: 'Description claire du problème' },
          farm_id: { type: 'number' }
        },
        required: ['type', 'severity', 'message']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'get_livestock',
      description: "Récupère les données du bétail. Appelle pour questions sur animaux, vaches, moutons, élevage.",
      parameters: { type: 'object', properties: {} }
    }
  }
];

// ════════════════════════════════════════════════════════════
// TEST
// ════════════════════════════════════════════════════════════
app.get('/', (req, res) => res.json({
  message: 'AgriSmart API ✅',
  version: '3.0',
  n8n: N8N_URL,
  groq: !!GROQ_KEY,
  owm: !!OWM_KEY
}));

// ════════════════════════════════════════════════════════════
// AUTH  — retourne un VRAI JWT maintenant
// ════════════════════════════════════════════════════════════
app.post('/api/auth/register', async (req, res) => {
  const { email, password, name, role, phone } = req.body;
  try {
    // Essaie de hasher (bcrypt) sinon stocke en clair (rétro-compatibilité)
    let hashed = password;
    try { hashed = await bcrypt.hash(password, 10); } catch {}
    const r = await pool.query(
      'INSERT INTO users (email,password,name,role,phone) VALUES ($1,$2,$3,$4,$5) RETURNING *',
      [email, hashed, name, role, phone]
    );
    const user = r.rows[0];
    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
    delete user.password;
    res.status(201).json({ user, token });
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ message: 'Email déjà utilisé' });
    res.status(500).json({ message: 'Erreur serveur', debug: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const r = await pool.query('SELECT * FROM users WHERE email=$1', [email]);
    if (!r.rows.length) return res.status(401).json({ message: 'Email ou mot de passe incorrect' });
    const user = r.rows[0];

    // Essaie bcrypt, sinon compare en clair (rétro-compatibilité anciens comptes)
    let valid = false;
    try {
      valid = await bcrypt.compare(password, user.password);
    } catch {
      valid = (password === user.password); // anciens comptes en clair
    }
    if (!valid) return res.status(401).json({ message: 'Email ou mot de passe incorrect' });

    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
    delete user.password;
    res.json({ user, token });
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur', debug: err.message });
  }
});

app.get('/api/auth/me', auth, async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT id,email,name,role,phone,created_at FROM users WHERE id=$1', [req.user.id]);
    if (!r.rows.length) return res.status(404).json({ message: 'Introuvable' });
    res.json(r.rows[0]);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

// ════════════════════════════════════════════════════════════
// FARMS
// ════════════════════════════════════════════════════════════
app.get('/api/farms', auth, async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM farms WHERE user_id=$1 ORDER BY created_at DESC', [req.user.id]);
    res.json(r.rows);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.post('/api/farms', auth, async (req, res) => {
  const { name, location, area_hectares, soil_type } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO farms (user_id,name,location,area_hectares,soil_type) VALUES ($1,$2,$3,$4,$5) RETURNING *',
      [req.user.id, name, location, area_hectares, soil_type]
    );
    res.status(201).json(r.rows[0]);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.delete('/api/farms/:id', auth, async (req, res) => {
  try {
    await pool.query('DELETE FROM farms WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
    res.json({ message: 'Ferme supprimée' });
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

// ════════════════════════════════════════════════════════════
// CROPS
// ════════════════════════════════════════════════════════════
app.get('/api/crops', auth, async (req, res) => {
  const { farm_id } = req.query;
  try {
    const q = farm_id
      ? 'SELECT * FROM crops WHERE farm_id=$1 ORDER BY created_at DESC'
      : 'SELECT c.*,f.name as farm_name FROM crops c JOIN farms f ON c.farm_id=f.id WHERE f.user_id=$1 ORDER BY c.created_at DESC';
    const r = await pool.query(q, [farm_id || req.user.id]);
    res.json(r.rows);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.post('/api/crops', auth, async (req, res) => {
  const { farm_id, crop_type, planting_date, expected_harvest, area_hectares } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO crops (farm_id,crop_type,planting_date,expected_harvest,area_hectares) VALUES ($1,$2,$3,$4,$5) RETURNING *',
      [farm_id, crop_type, planting_date, expected_harvest, area_hectares]
    );
    res.status(201).json(r.rows[0]);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

// ════════════════════════════════════════════════════════════
// ALERTS
// ════════════════════════════════════════════════════════════
app.get('/api/alerts', auth, async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM alerts WHERE user_id=$1 ORDER BY created_at DESC', [req.user.id]);
    res.json(r.rows);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.post('/api/alerts', auth, async (req, res) => {
  const { farm_id, type, severity, message } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO alerts (user_id,farm_id,type,severity,message) VALUES ($1,$2,$3,$4,$5) RETURNING *',
      [req.user.id, farm_id, type, severity, message]
    );
    res.status(201).json(r.rows[0]);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.patch('/api/alerts/:id/read', auth, async (req, res) => {
  try {
    await pool.query('UPDATE alerts SET is_read=TRUE WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
    res.json({ message: 'Lue' });
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

// ════════════════════════════════════════════════════════════
// TASKS
// ════════════════════════════════════════════════════════════
app.get('/api/tasks', auth, async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM tasks WHERE user_id=$1 ORDER BY created_at DESC', [req.user.id]);
    res.json(r.rows);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.post('/api/tasks', auth, async (req, res) => {
  const { title, description, priority, due_date, category } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO tasks (user_id,title,description,priority,due_date,category) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
      [req.user.id, title, description, priority, due_date, category]
    );
    res.status(201).json(r.rows[0]);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.patch('/api/tasks/:id/toggle', auth, async (req, res) => {
  try {
    const r = await pool.query(
      'UPDATE tasks SET done=NOT done WHERE id=$1 AND user_id=$2 RETURNING *',
      [req.params.id, req.user.id]
    );
    res.json(r.rows[0]);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.delete('/api/tasks/:id', auth, async (req, res) => {
  try {
    await pool.query('DELETE FROM tasks WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
    res.json({ message: 'Supprimée' });
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

// ════════════════════════════════════════════════════════════
// LIVESTOCK
// ════════════════════════════════════════════════════════════
app.get('/api/livestock', auth, async (req, res) => {
  const { farm_id } = req.query;
  try {
    const r = await pool.query('SELECT * FROM livestock WHERE farm_id=$1 ORDER BY created_at DESC', [farm_id]);
    res.json(r.rows);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.post('/api/livestock', auth, async (req, res) => {
  const { farm_id, tag_number, species, breed, birth_date, weight } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO livestock (farm_id,tag_number,species,breed,birth_date,weight) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
      [farm_id, tag_number, species, breed, birth_date, weight]
    );
    res.status(201).json(r.rows[0]);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

// ════════════════════════════════════════════════════════════
// MÉTÉO (proxy)
// ════════════════════════════════════════════════════════════
app.get('/api/weather', auth, async (req, res) => {
  const { city = 'Tunis' } = req.query;
  if (!OWM_KEY) return res.status(500).json({ message: 'Clé météo manquante' });
  try {
    const r = await fetch(
      `https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(city)}&appid=${OWM_KEY}&lang=fr&units=metric`
    );
    const d = await r.json();
    if (d.cod !== 200) return res.status(400).json({ message: `Ville introuvable: ${city}` });
    res.json({
      city: d.name, temp: Math.round(d.main.temp),
      feels_like: Math.round(d.main.feels_like), humidity: d.main.humidity,
      description: d.weather[0].description, icon: d.weather[0].icon,
      wind: Math.round(d.wind.speed * 3.6)
    });
  } catch (e) { res.status(500).json({ message: 'Erreur météo', debug: e.message }); }
});

// ════════════════════════════════════════════════════════════
// AGENT IA — GROQ + N8N (route unique, propre)
// ════════════════════════════════════════════════════════════
app.post('/api/agent/chat', auth, async (req, res) => {
  const message = req.body.message;
  const history = Array.isArray(req.body.history) ? req.body.history : [];
  const userId  = req.user.id;

  if (!message) return res.status(400).json({ error: 'Message manquant' });
  if (!GROQ_KEY) return res.status(500).json({ message: 'Clé Groq manquante — configure GROQ_API_KEY dans Railway' });

  const messages = [
    {
      role: 'system',
      content: `Tu es AgriBot, assistant agricole expert pour AgriSmart en Tunisie (user_id: ${userId}).
Tu as accès à des outils puissants pour agir sur l'application en temps réel.
RÈGLES IMPORTANTES :
1. Appelle TOUJOURS get_summary en premier pour connaître l'état de l'exploitation
2. Pour la météo, utilise get_weather avec la ville mentionnée
3. Si tu détectes un problème grave (maladie, sécheresse, temp >38°C), crée une alerte via create_alert
4. Tu peux créer des tâches directement via create_task si l'utilisateur le demande
5. Réponds en français, de façon concise et pratique
6. Mentionne les données réelles (noms des fermes, nombres de cultures, tâches en attente)`
    },
    ...history.slice(-10),
    { role: 'user', content: message }
  ];

  try {
    let response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${GROQ_KEY}` },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        max_tokens: 1024,
        tools: GROQ_TOOLS,
        tool_choice: 'auto',
        messages
      })
    });

    let data = await response.json();
    if (data.error) throw new Error(data.error.message);

    // Boucle agentique (max 6 itérations)
    let iter = 0;
    while (data.choices?.[0]?.finish_reason === 'tool_calls' && iter < 6) {
      iter++;
      const assistantMsg = data.choices[0].message;
      messages.push(assistantMsg);

      for (const call of (assistantMsg.tool_calls || [])) {
        let args = {};
        try { args = JSON.parse(call.function.arguments); } catch {}
        const result = await executeTool(call.function.name, args, userId);
        console.log(`✅ [${call.function.name}]`, JSON.stringify(result).slice(0, 300));
        messages.push({
          role: 'tool',
          tool_call_id: call.id,
          content: JSON.stringify(result)
        });
      }

      response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${GROQ_KEY}` },
        body: JSON.stringify({
          model: 'llama-3.3-70b-versatile',
          max_tokens: 1024,
          tools: GROQ_TOOLS,
          tool_choice: 'auto',
          messages
        })
      });
      data = await response.json();
      if (data.error) throw new Error(data.error.message);
    }

    const finalText = data.choices?.[0]?.message?.content || 'Je rencontre un problème, réessayez.';

    const updatedHistory = [
      ...history.slice(-10),
      { role: 'user', content: message },
      { role: 'assistant', content: finalText }
    ];

    res.json({ response: finalText, history: updatedHistory });

  } catch (err) {
    console.error('❌ Agent:', err.message);
    res.status(500).json({ message: 'Erreur agent IA', debug: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 AgriSmart v3 · port ${PORT} · n8n: ${N8N_URL}`));*/

const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const app = express();
app.use(cors());
app.use(express.json());

// ── Config ────────────────────────────────────────────────
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

pool.connect()
  .then(c => { console.log('✅ PostgreSQL connecté'); c.release(); })
  .catch(e => console.error('❌ DB:', e.message));

const JWT_SECRET = process.env.JWT_SECRET  || 'agrismart_dev_secret';
const GROQ_KEY   = process.env.GROQ_API_KEY || process.env.GROQ_KEY;
const OWM_KEY    = process.env.OWM_API_KEY;
const N8N_URL    = (process.env.N8N_URL || 'https://anonyme878-n8n.hf.space').replace(/\/$/, '');

// ── Middleware JWT ────────────────────────────────────────
function auth(req, res, next) {
  const header = req.headers['authorization'];
  if (!header) return res.status(401).json({ message: 'Token manquant' });
  try {
    req.user = jwt.verify(header.replace('Bearer ', ''), JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ message: 'Token invalide ou expiré' });
  }
}

// ── Appel n8n ────────────────────────────────────────────
async function callN8n(webhookPath, body) {
  const url = `${N8N_URL}/webhook/${webhookPath}`;
  console.log(`📡 n8n → ${url}`);
  try {
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(10000)
    });
    const text = await r.text();
    try { return JSON.parse(text); } catch { return { raw: text }; }
  } catch (e) {
    console.error(`❌ n8n ${webhookPath}:`, e.message);
    return { error: e.message };
  }
}

// ── Exécution des outils — ADAPTÉ à ta vraie BD ──────────
async function executeTool(name, args, userId) {
  console.log(`🔧 Outil: ${name}`, args);

  switch (name) {

    // Résumé global — utilise TES vraies colonnes
    case 'get_summary': {
      try {
        const [farms, alerts, tasks, fields, animals] = await Promise.all([
          pool.query('SELECT * FROM farms WHERE owner_id=$1', [userId]),
          pool.query("SELECT * FROM alerts WHERE user_id=$1 AND is_read=FALSE ORDER BY created_at DESC LIMIT 5", [userId]),
          pool.query("SELECT * FROM tasks WHERE user_id=$1 AND done=FALSE ORDER BY due_date ASC LIMIT 5", [userId]).catch(() => ({ rows: [] })),
          pool.query(`SELECT f.*, fa.name as farm_name FROM fields f JOIN farms fa ON f.farm_id=fa.id WHERE fa.owner_id=$1`, [userId]).catch(() => ({ rows: [] })),
          pool.query(`SELECT a.* FROM animals a JOIN farms fa ON a.farm_id=fa.id WHERE fa.owner_id=$1`, [userId]).catch(() => ({ rows: [] })),
        ]);
        return {
          farms: farms.rows,
          unread_alerts: alerts.rows,
          pending_tasks: tasks.rows,
          fields: fields.rows,
          animals: animals.rows,
          counts: {
            farms: farms.rowCount,
            alerts: alerts.rowCount,
            tasks: tasks.rowCount,
            fields: fields.rowCount,
            animals: animals.rowCount,
          }
        };
      } catch (e) {
        return { error: e.message };
      }
    }

    case 'get_weather':
      return callN8n('get-weather', { location: args.location || 'Tunis' });

    case 'get_farm_data': {
      try {
        const farms = await pool.query('SELECT * FROM farms WHERE owner_id=$1', [userId]);
        const fields = await pool.query(
          `SELECT f.*, fa.name as farm_name FROM fields f JOIN farms fa ON f.farm_id=fa.id WHERE fa.owner_id=$1`,
          [userId]
        ).catch(() => ({ rows: [] }));
        return { farms: farms.rows, fields: fields.rows };
      } catch (e) { return { error: e.message }; }
    }

    case 'get_tasks': {
      try {
        const r = await pool.query(
          'SELECT * FROM tasks WHERE user_id=$1 AND done=FALSE ORDER BY due_date ASC LIMIT 10',
          [userId]
        );
        return { tasks: r.rows };
      } catch (e) { return { error: e.message }; }
    }

    case 'create_task': {
      try {
        const r = await pool.query(
          'INSERT INTO tasks (user_id,title,description,priority,due_date,category) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
          [userId, args.title, args.description||'', args.priority||'medium', args.due_date||null, args.category||'Autre']
        );
        return { task: r.rows[0], created: true };
      } catch (e) { return { error: e.message }; }
    }

    // Alertes — utilise tes vraies colonnes (alert_type, title, message)
    case 'create_alert': {
      try {
        await pool.query(
          'INSERT INTO alerts (user_id, farm_id, alert_type, severity, title, message) VALUES ($1,$2,$3,$4,$5,$6)',
          [userId, args.farm_id||null, args.type, args.severity, args.title||args.type, args.message]
        );
        return { created: true, message: 'Alerte créée avec succès' };
      } catch (e) { return { error: e.message }; }
    }

    case 'get_animals': {
      try {
        const r = await pool.query(
          `SELECT a.* FROM animals a JOIN farms fa ON a.farm_id=fa.id WHERE fa.owner_id=$1`,
          [userId]
        );
        return { animals: r.rows };
      } catch (e) { return { error: e.message }; }
    }

    default:
      return { error: `Outil inconnu: ${name}` };
  }
}

// ── Outils Groq ───────────────────────────────────────────
const GROQ_TOOLS = [
  {
    type: 'function',
    function: {
      name: 'get_summary',
      description: "Récupère un résumé complet de l'exploitation : fermes, parcelles (fields), alertes, tâches, animaux. Appelle UNIQUEMENT si l'utilisateur pose une question sur ses données agricoles.",
      parameters: { type: 'object', properties: {} }
    }
  },
  {
    type: 'function',
    function: {
      name: 'get_weather',
      description: "Obtient la météo actuelle. Appelle UNIQUEMENT si l'utilisateur mentionne explicitement météo, pluie, température, vent, soleil.",
      parameters: {
        type: 'object',
        properties: {
          location: { type: 'string', description: 'Ville ex: Tunis, Sfax, Sousse' }
        },
        required: ['location']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'get_farm_data',
      description: "Récupère fermes et parcelles. Appelle si l'utilisateur demande ses fermes ou parcelles spécifiquement.",
      parameters: { type: 'object', properties: {} }
    }
  },
  {
    type: 'function',
    function: {
      name: 'get_tasks',
      description: "Récupère les tâches en attente. Appelle si l'utilisateur demande ses tâches ou planning.",
      parameters: { type: 'object', properties: {} }
    }
  },
  {
    type: 'function',
    function: {
      name: 'create_task',
      description: "Crée une tâche. Appelle si l'utilisateur demande explicitement d'ajouter/créer une tâche.",
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          description: { type: 'string' },
          priority: { type: 'string', enum: ['high', 'medium', 'low'] },
          due_date: { type: 'string', description: 'Format YYYY-MM-DD' },
          category: { type: 'string' }
        },
        required: ['title']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'create_alert',
      description: "Crée une alerte urgente. Appelle si tu détectes un vrai problème grave.",
      parameters: {
        type: 'object',
        properties: {
          type: { type: 'string', enum: ['water_stress', 'disease', 'temperature', 'weather', 'livestock', 'Meteo'] },
          severity: { type: 'string', enum: ['low', 'medium', 'high', 'critical'] },
          title: { type: 'string' },
          message: { type: 'string' },
          farm_id: { type: 'number' }
        },
        required: ['type', 'severity', 'message']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'get_animals',
      description: "Récupère les animaux/bétail. Appelle si l'utilisateur parle de ses animaux, bétail, élevage.",
      parameters: { type: 'object', properties: {} }
    }
  }
];

// ════════════════════════════════════════════════════════════
// ROUTES
// ════════════════════════════════════════════════════════════
app.get('/', (req, res) => res.json({
  message: 'AgriSmart API ✅',
  version: '4.0',
  n8n: N8N_URL,
  groq: !!GROQ_KEY,
  owm: !!OWM_KEY
}));

// ── AUTH ──────────────────────────────────────────────────
app.post('/api/auth/register', async (req, res) => {
  const { email, password, name, role, phone } = req.body;
  try {
    let hashed = password;
    try { hashed = await bcrypt.hash(password, 10); } catch {}
    const r = await pool.query(
      'INSERT INTO users (email,password,name,role,phone) VALUES ($1,$2,$3,$4,$5) RETURNING *',
      [email, hashed, name, role, phone]
    );
    const user = r.rows[0];
    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
    delete user.password;
    res.status(201).json({ user, token });
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ message: 'Email déjà utilisé' });
    res.status(500).json({ message: 'Erreur serveur', debug: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const r = await pool.query('SELECT * FROM users WHERE email=$1', [email]);
    if (!r.rows.length) return res.status(401).json({ message: 'Email ou mot de passe incorrect' });
    const user = r.rows[0];
    let valid = false;
    try { valid = await bcrypt.compare(password, user.password); } catch { valid = (password === user.password); }
    if (!valid) return res.status(401).json({ message: 'Email ou mot de passe incorrect' });
    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
    delete user.password;
    res.json({ user, token });
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur', debug: err.message });
  }
});

app.get('/api/auth/me', auth, async (req, res) => {
  try {
    const r = await pool.query('SELECT id,email,name,role,phone,created_at FROM users WHERE id=$1', [req.user.id]);
    if (!r.rows.length) return res.status(404).json({ message: 'Introuvable' });
    res.json(r.rows[0]);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

// ── FARMS (owner_id) ──────────────────────────────────────
app.get('/api/farms', auth, async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM farms WHERE owner_id=$1 ORDER BY created_at DESC', [req.user.id]);
    res.json(r.rows);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.post('/api/farms', auth, async (req, res) => {
  const { name, location, area_hectares, farm_type, latitude, longitude } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO farms (owner_id,name,location,area_hectares,farm_type,latitude,longitude) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *',
      [req.user.id, name, location, area_hectares, farm_type, latitude, longitude]
    );
    res.status(201).json(r.rows[0]);
  } catch (e) { res.status(500).json({ message: 'Erreur serveur', debug: e.message }); }
});

app.delete('/api/farms/:id', auth, async (req, res) => {
  try {
    await pool.query('DELETE FROM farms WHERE id=$1 AND owner_id=$2', [req.params.id, req.user.id]);
    res.json({ message: 'Ferme supprimée' });
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

// ── FIELDS (parcelles) ────────────────────────────────────
app.get('/api/fields', auth, async (req, res) => {
  const { farm_id } = req.query;
  try {
    const q = farm_id
      ? 'SELECT * FROM fields WHERE farm_id=$1 ORDER BY created_at DESC'
      : `SELECT f.*,fa.name as farm_name FROM fields f JOIN farms fa ON f.farm_id=fa.id WHERE fa.owner_id=$1 ORDER BY f.created_at DESC`;
    const r = await pool.query(q, [farm_id || req.user.id]);
    res.json(r.rows);
  } catch (e) { res.status(500).json({ message: 'Erreur serveur', debug: e.message }); }
});

app.post('/api/fields', auth, async (req, res) => {
  const { farm_id, name, area_hectares, soil_type, current_crop } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO fields (farm_id,name,area_hectares,soil_type,current_crop) VALUES ($1,$2,$3,$4,$5) RETURNING *',
      [farm_id, name, area_hectares, soil_type, current_crop]
    );
    res.status(201).json(r.rows[0]);
  } catch (e) { res.status(500).json({ message: 'Erreur serveur', debug: e.message }); }
});

// ── ALERTS (alert_type, title) ────────────────────────────
app.get('/api/alerts', auth, async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM alerts WHERE user_id=$1 ORDER BY created_at DESC', [req.user.id]);
    res.json(r.rows);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.post('/api/alerts', auth, async (req, res) => {
  const { farm_id, alert_type, severity, title, message } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO alerts (user_id,farm_id,alert_type,severity,title,message) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
      [req.user.id, farm_id, alert_type, severity, title||alert_type, message]
    );
    res.status(201).json(r.rows[0]);
  } catch (e) { res.status(500).json({ message: 'Erreur serveur', debug: e.message }); }
});

app.patch('/api/alerts/:id/read', auth, async (req, res) => {
  try {
    await pool.query('UPDATE alerts SET is_read=TRUE WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
    res.json({ message: 'Lue' });
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

// ── TASKS ─────────────────────────────────────────────────
app.get('/api/tasks', auth, async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM tasks WHERE user_id=$1 ORDER BY created_at DESC', [req.user.id]);
    res.json(r.rows);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.post('/api/tasks', auth, async (req, res) => {
  const { title, description, priority, due_date, category } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO tasks (user_id,title,description,priority,due_date,category) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
      [req.user.id, title, description, priority, due_date, category]
    );
    res.status(201).json(r.rows[0]);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.patch('/api/tasks/:id/toggle', auth, async (req, res) => {
  try {
    const r = await pool.query(
      'UPDATE tasks SET done=NOT done WHERE id=$1 AND user_id=$2 RETURNING *',
      [req.params.id, req.user.id]
    );
    res.json(r.rows[0]);
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

app.delete('/api/tasks/:id', auth, async (req, res) => {
  try {
    await pool.query('DELETE FROM tasks WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
    res.json({ message: 'Supprimée' });
  } catch { res.status(500).json({ message: 'Erreur serveur' }); }
});

// ── ANIMALS (table animals) ───────────────────────────────
app.get('/api/animals', auth, async (req, res) => {
  const { farm_id } = req.query;
  try {
    const q = farm_id
      ? 'SELECT * FROM animals WHERE farm_id=$1 ORDER BY created_at DESC'
      : `SELECT a.* FROM animals a JOIN farms fa ON a.farm_id=fa.id WHERE fa.owner_id=$1 ORDER BY a.created_at DESC`;
    const r = await pool.query(q, [farm_id || req.user.id]);
    res.json(r.rows);
  } catch (e) { res.status(500).json({ message: 'Erreur serveur', debug: e.message }); }
});

app.post('/api/animals', auth, async (req, res) => {
  const { farm_id, tag_number, species, breed, birth_date, gender, weight_kg, health_status } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO animals (farm_id,tag_number,species,breed,birth_date,gender,weight_kg,health_status) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *',
      [farm_id, tag_number, species, breed, birth_date, gender, weight_kg, health_status||'healthy']
    );
    res.status(201).json(r.rows[0]);
  } catch (e) { res.status(500).json({ message: 'Erreur serveur', debug: e.message }); }
});

// ── MÉTÉO (proxy) ─────────────────────────────────────────
app.get('/api/weather', auth, async (req, res) => {
  const { city = 'Tunis' } = req.query;
  if (!OWM_KEY) return res.status(500).json({ message: 'Clé météo manquante' });
  try {
    const r = await fetch(
      `https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(city)}&appid=${OWM_KEY}&lang=fr&units=metric`
    );
    const d = await r.json();
    if (d.cod !== 200) return res.status(400).json({ message: `Ville introuvable: ${city}` });
    res.json({
      city: d.name, temp: Math.round(d.main.temp),
      feels_like: Math.round(d.main.feels_like), humidity: d.main.humidity,
      description: d.weather[0].description, icon: d.weather[0].icon,
      wind: Math.round(d.wind.speed * 3.6)
    });
  } catch (e) { res.status(500).json({ message: 'Erreur météo', debug: e.message }); }
});

// ════════════════════════════════════════════════════════════
// AGENT IA — Groq + n8n
// ════════════════════════════════════════════════════════════
app.post('/api/agent/chat', auth, async (req, res) => {
  const message = req.body.message;
  const history = Array.isArray(req.body.history) ? req.body.history : [];
  const userId  = req.user.id;

  if (!message) return res.status(400).json({ error: 'Message manquant' });
  if (!GROQ_KEY) return res.status(500).json({ message: 'Clé Groq manquante' });

  const messages = [
    {
      role: 'system',
      content: `Tu es AgriBot, assistant agricole pour AgriSmart en Tunisie (user_id: ${userId}).

RÈGLES STRICTES :
- Pour les salutations (salut, bonjour, ça va...) → réponds directement SANS appeler d'outils
- Pour les questions générales sur l'agriculture → réponds directement SANS appeler d'outils  
- N'appelle les outils QUE si l'utilisateur demande EXPLICITEMENT ses données (fermes, météo, tâches, animaux)
- Exemples sans outils : "salut", "comment vas-tu", "qu'est-ce que la photosynthèse", "conseil irrigation"
- Exemples avec outils : "mes fermes", "météo tunis", "mes tâches", "créer une tâche"
- Réponds en français, de façon concise (max 2 paragraphes)
- Sois chaleureux et professionnel`
    },
    ...history.slice(-10),
    { role: 'user', content: message }
  ];

  try {
    let response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${GROQ_KEY}` },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        max_tokens: 800,
        tools: GROQ_TOOLS,
        tool_choice: 'auto',
        messages
      })
    });

    let data = await response.json();
    if (data.error) throw new Error(JSON.stringify(data.error));

    // Boucle agentique (max 5 itérations)
    let iter = 0;
    while (data.choices?.[0]?.finish_reason === 'tool_calls' && iter < 5) {
      iter++;
      const assistantMsg = data.choices[0].message;
      messages.push(assistantMsg);

      for (const call of (assistantMsg.tool_calls || [])) {
        let args = {};
        try { args = JSON.parse(call.function.arguments); } catch {}
        const result = await executeTool(call.function.name, args, userId);
        console.log(`✅ [${call.function.name}]`, JSON.stringify(result).slice(0, 200));
        messages.push({
          role: 'tool',
          tool_call_id: call.id,
          content: JSON.stringify(result)
        });
      }

      response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${GROQ_KEY}` },
        body: JSON.stringify({
          model: 'llama-3.3-70b-versatile',
          max_tokens: 800,
          tools: GROQ_TOOLS,
          tool_choice: 'auto',
          messages
        })
      });
      data = await response.json();
      if (data.error) throw new Error(JSON.stringify(data.error));
    }

    const finalText = data.choices?.[0]?.message?.content || 'Je rencontre un problème, réessayez.';

    const updatedHistory = [
      ...history.slice(-10),
      { role: 'user', content: message },
      { role: 'assistant', content: finalText }
    ];

    res.json({ response: finalText, history: updatedHistory });

  } catch (err) {
    console.error('❌ Agent:', err.message);
    res.status(500).json({ message: 'Erreur agent IA', debug: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 AgriSmart v4 · port ${PORT} · n8n: ${N8N_URL}`));