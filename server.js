/*const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
pool.connect().then(c => { console.log('✅ DB connectée'); c.release(); }).catch(e => console.error('❌ DB:', e.message));

const JWT_SECRET = process.env.JWT_SECRET || 'agrismart_dev_secret';
const GROQ_KEY   = process.env.GROQ_API_KEY || process.env.GROQ_KEY;
const OWM_KEY    = process.env.OWM_API_KEY;
const N8N_URL    = (process.env.N8N_URL || 'https://anonyme878-n8n.hf.space').replace(/\/$/, '');

function auth(req, res, next) {
  const h = req.headers['authorization'];
  if (!h) return res.status(401).json({ message: 'Token manquant' });
  try { req.user = jwt.verify(h.replace('Bearer ', ''), JWT_SECRET); next(); }
  catch { res.status(401).json({ message: 'Token invalide' }); }
}

async function callN8n(path, body) {
  try {
    const r = await fetch(`${N8N_URL}/webhook/${path}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body), signal: AbortSignal.timeout(10000)
    });
    const t = await r.text();
    try { return JSON.parse(t); } catch { return { raw: t }; }
  } catch (e) { return { error: e.message }; }
}

// ════════ EXÉCUTION OUTILS — adapté à ta vraie BD ════════
async function executeTool(name, args, userId) {
  console.log(`🔧 ${name}`, JSON.stringify(args));
  try {
    switch (name) {

      case 'get_app_info':
        // L'agent décrit l'application à l'utilisateur
        return {
          app_name: 'AgriSmart',
          description: 'Plateforme agricole intelligente mobile-first',
          tabs: ['Accueil (météo, résumé)', 'Parcelles (fermes + champs)', 'Alertes', 'Tâches'],
          actions_possibles: [
            'Voir/créer/supprimer fermes',
            'Voir/créer/supprimer parcelles (champs)',
            'Voir/créer/marquer alertes comme lues',
            'Voir/créer/cocher/supprimer tâches',
            'Consulter météo en temps réel',
            'Voir animaux (bétail)',
            'Résumé complet de l\'exploitation'
          ],
          user_id: userId
        };

      case 'get_summary': {
        const [farms, alerts, tasks, fields, animals] = await Promise.all([
          pool.query('SELECT id,name,location,area_hectares,farm_type FROM farms WHERE owner_id=$1', [userId]),
          pool.query("SELECT id,alert_type,severity,title,message,is_read,created_at FROM alerts WHERE user_id=$1 AND is_read=FALSE ORDER BY created_at DESC LIMIT 5", [userId]),
          pool.query("SELECT id,title,priority,due_date,category,done FROM tasks WHERE user_id=$1 AND done=FALSE ORDER BY due_date ASC LIMIT 5", [userId]).catch(() => ({ rows: [], rowCount: 0 })),
          pool.query('SELECT f.id,f.name,f.area_hectares,f.current_crop,f.soil_type,fa.name as farm_name FROM fields f JOIN farms fa ON f.farm_id=fa.id WHERE fa.owner_id=$1', [userId]).catch(() => ({ rows: [], rowCount: 0 })),
          pool.query('SELECT a.id,a.tag_number,a.species,a.breed,a.health_status FROM animals a JOIN farms fa ON a.farm_id=fa.id WHERE fa.owner_id=$1', [userId]).catch(() => ({ rows: [], rowCount: 0 })),
        ]);
        return { farms: farms.rows, unread_alerts: alerts.rows, pending_tasks: tasks.rows, fields: fields.rows, animals: animals.rows,
          counts: { farms: farms.rowCount, alerts: alerts.rowCount, tasks: tasks.rowCount, fields: fields.rowCount, animals: animals.rowCount } };
      }

      case 'get_weather':
        return callN8n('get-weather', { location: args.location || 'Tunis' });

      case 'get_farms': {
        const r = await pool.query('SELECT * FROM farms WHERE owner_id=$1 ORDER BY created_at DESC', [userId]);
        return { farms: r.rows, count: r.rowCount };
      }

      case 'create_farm': {
        // Vérifie que les champs obligatoires sont là
        if (!args.name) return { error: 'Le nom de la ferme est obligatoire', missing_fields: ['name'] };
        const r = await pool.query(
          'INSERT INTO farms (owner_id,name,location,area_hectares,farm_type) VALUES ($1,$2,$3,$4,$5) RETURNING *',
          [userId, args.name, args.location || null, args.area_hectares || null, args.farm_type || 'Polyculture']
        );
        return { success: true, farm: r.rows[0], message: `Ferme "${args.name}" créée avec succès !` };
      }

      case 'delete_farm': {
        if (!args.farm_id) return { error: 'farm_id manquant' };
        await pool.query('DELETE FROM farms WHERE id=$1 AND owner_id=$2', [args.farm_id, userId]);
        return { success: true, message: 'Ferme supprimée' };
      }

      case 'get_fields': {
        const r = await pool.query(
          'SELECT f.*,fa.name as farm_name FROM fields f JOIN farms fa ON f.farm_id=fa.id WHERE fa.owner_id=$1 ORDER BY f.created_at DESC',
          [userId]
        );
        return { fields: r.rows, count: r.rowCount };
      }

      case 'create_field': {
        if (!args.farm_id) return { error: 'farm_id manquant — demandez d\'abord à l\'utilisateur à quelle ferme appartient ce champ', missing_fields: ['farm_id'] };
        if (!args.name) return { error: 'name manquant', missing_fields: ['name'] };
        const r = await pool.query(
          'INSERT INTO fields (farm_id,name,area_hectares,soil_type,current_crop) VALUES ($1,$2,$3,$4,$5) RETURNING *',
          [args.farm_id, args.name, args.area_hectares || null, args.soil_type || null, args.current_crop || null]
        );
        return { success: true, field: r.rows[0], message: `Parcelle "${args.name}" créée avec succès !` };
      }

      case 'get_tasks': {
        const r = await pool.query('SELECT * FROM tasks WHERE user_id=$1 ORDER BY done ASC, due_date ASC', [userId]);
        return { tasks: r.rows, count: r.rowCount };
      }

      case 'create_task': {
        if (!args.title) return { error: 'Titre obligatoire', missing_fields: ['title'] };
        const r = await pool.query(
          'INSERT INTO tasks (user_id,title,description,priority,due_date,category) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
          [userId, args.title, args.description || '', args.priority || 'medium', args.due_date || null, args.category || 'Autre']
        );
        return { success: true, task: r.rows[0], message: `Tâche "${args.title}" créée !` };
      }

      case 'toggle_task': {
        if (!args.task_id) return { error: 'task_id manquant' };
        const r = await pool.query('UPDATE tasks SET done=NOT done WHERE id=$1 AND user_id=$2 RETURNING *', [args.task_id, userId]);
        const t = r.rows[0];
        return { success: true, task: t, message: t.done ? `Tâche "${t.title}" marquée comme terminée ✅` : `Tâche "${t.title}" remise en attente` };
      }

      case 'delete_task': {
        if (!args.task_id) return { error: 'task_id manquant' };
        const r = await pool.query('SELECT title FROM tasks WHERE id=$1 AND user_id=$2', [args.task_id, userId]);
        await pool.query('DELETE FROM tasks WHERE id=$1 AND user_id=$2', [args.task_id, userId]);
        return { success: true, message: `Tâche "${r.rows[0]?.title}" supprimée` };
      }

      case 'get_alerts': {
        const r = await pool.query('SELECT * FROM alerts WHERE user_id=$1 ORDER BY created_at DESC', [userId]);
        return { alerts: r.rows, count: r.rowCount };
      }

      case 'create_alert': {
        if (!args.alert_type || !args.severity || !args.message)
          return { error: 'Champs obligatoires manquants', missing_fields: ['alert_type', 'severity', 'message'].filter(f => !args[f]) };
        const r = await pool.query(
          'INSERT INTO alerts (user_id,farm_id,alert_type,severity,title,message) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
          [userId, args.farm_id || null, args.alert_type, args.severity, args.title || args.alert_type, args.message]
        );
        return { success: true, alert: r.rows[0], message: `Alerte "${args.title || args.alert_type}" créée !` };
      }

      case 'mark_alert_read': {
        if (!args.alert_id) return { error: 'alert_id manquant' };
        await pool.query('UPDATE alerts SET is_read=TRUE WHERE id=$1 AND user_id=$2', [args.alert_id, userId]);
        return { success: true, message: 'Alerte marquée comme lue' };
      }

      case 'get_animals': {
        const r = await pool.query(
          'SELECT a.*,fa.name as farm_name FROM animals a JOIN farms fa ON a.farm_id=fa.id WHERE fa.owner_id=$1 ORDER BY a.created_at DESC',
          [userId]
        );
        return { animals: r.rows, count: r.rowCount };
      }

      case 'create_animal': {
        if (!args.farm_id || !args.species) return { error: 'farm_id et species obligatoires', missing_fields: ['farm_id', 'species'].filter(f => !args[f]) };
        const r = await pool.query(
          'INSERT INTO animals (farm_id,tag_number,species,breed,birth_date,gender,weight_kg,health_status) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *',
          [args.farm_id, args.tag_number || null, args.species, args.breed || null, args.birth_date || null, args.gender || null, args.weight_kg || null, args.health_status || 'healthy']
        );
        return { success: true, animal: r.rows[0], message: `Animal ajouté avec succès !` };
      }

      default:
        return { error: `Outil inconnu: ${name}` };
    }
  } catch (e) {
    console.error(`❌ ${name}:`, e.message);
    return { error: e.message };
  }
}

// ════════ OUTILS GROQ — définition complète ════════
const GROQ_TOOLS = [
  { type:'function', function:{ name:'get_app_info', description:"Décrit l'application AgriSmart et toutes ses fonctionnalités disponibles. Appelle si l'utilisateur demande ce qu'il peut faire ou comment utiliser l'app.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'get_summary', description:"Résumé complet : fermes, champs, alertes non lues, tâches en attente, animaux. Appelle pour questions générales sur l'exploitation.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'get_weather', description:"Météo en temps réel. Appelle si météo/température/pluie/vent mentionné.", parameters:{ type:'object', properties:{ location:{ type:'string', description:'Ville tunisienne' } }, required:['location'] } } },
  { type:'function', function:{ name:'get_farms', description:"Liste les fermes de l'utilisateur.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'create_farm', description:"Crée une nouvelle ferme. Demande TOUJOURS nom, localisation et surface à l'utilisateur AVANT d'appeler cet outil.", parameters:{ type:'object', properties:{ name:{ type:'string' }, location:{ type:'string' }, area_hectares:{ type:'number' }, farm_type:{ type:'string', enum:['Polyculture','Maraîchage','Céréales','Élevage','Arboriculture','Autre'] } }, required:['name'] } } },
  { type:'function', function:{ name:'delete_farm', description:"Supprime une ferme. Demande confirmation à l'utilisateur.", parameters:{ type:'object', properties:{ farm_id:{ type:'number' } }, required:['farm_id'] } } },
  { type:'function', function:{ name:'get_fields', description:"Liste les parcelles/champs de l'utilisateur.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'create_field', description:"Crée une parcelle/champ. Demande nom, ferme concernée, surface, type de sol et culture actuelle.", parameters:{ type:'object', properties:{ farm_id:{ type:'number' }, name:{ type:'string' }, area_hectares:{ type:'number' }, soil_type:{ type:'string', enum:['Argileux','Sableux','Limoneux','Calcaire','Humifère','Autre'] }, current_crop:{ type:'string', description:'Culture actuelle ex: Tomate, Blé, Olive' } }, required:['farm_id','name'] } } },
  { type:'function', function:{ name:'get_tasks', description:"Liste toutes les tâches de l'utilisateur.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'create_task', description:"Crée une tâche agricole. Demande titre, priorité, date et catégorie.", parameters:{ type:'object', properties:{ title:{ type:'string' }, description:{ type:'string' }, priority:{ type:'string', enum:['high','medium','low'] }, due_date:{ type:'string', description:'YYYY-MM-DD' }, category:{ type:'string', enum:['Irrigation','Traitement','Récolte','Semis','Maintenance','Approvisionnement','Autre'] } }, required:['title'] } } },
  { type:'function', function:{ name:'toggle_task', description:"Marque une tâche comme terminée ou la remet en attente.", parameters:{ type:'object', properties:{ task_id:{ type:'number' } }, required:['task_id'] } } },
  { type:'function', function:{ name:'delete_task', description:"Supprime une tâche.", parameters:{ type:'object', properties:{ task_id:{ type:'number' } }, required:['task_id'] } } },
  { type:'function', function:{ name:'get_alerts', description:"Liste toutes les alertes de l'utilisateur.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'create_alert', description:"Crée une alerte. Demande type, urgence, titre et description à l'utilisateur.", parameters:{ type:'object', properties:{ alert_type:{ type:'string', enum:['water_stress','disease','temperature','weather','livestock','Meteo','Arrosage','recolte','semis','traitement','fertilisation','Autre'] }, severity:{ type:'string', enum:['low','medium','high','critical'] }, title:{ type:'string' }, message:{ type:'string' }, farm_id:{ type:'number' } }, required:['alert_type','severity','message'] } } },
  { type:'function', function:{ name:'mark_alert_read', description:"Marque une alerte comme lue.", parameters:{ type:'object', properties:{ alert_id:{ type:'number' } }, required:['alert_id'] } } },
  { type:'function', function:{ name:'get_animals', description:"Liste les animaux/bétail de l'utilisateur.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'create_animal', description:"Ajoute un animal. Demande ferme, espèce, race, numéro de tag.", parameters:{ type:'object', properties:{ farm_id:{ type:'number' }, tag_number:{ type:'string' }, species:{ type:'string', description:'Bovin, Ovin, Caprin, Volaille...' }, breed:{ type:'string' }, birth_date:{ type:'string' }, gender:{ type:'string', enum:['male','female'] }, weight_kg:{ type:'number' }, health_status:{ type:'string', enum:['healthy','sick','critical'] } }, required:['farm_id','species'] } } },
];

// ════════ ROUTES ════════
app.get('/', (req, res) => res.json({ message:'AgriSmart API ✅', version:'5.0', groq:!!GROQ_KEY, owm:!!OWM_KEY, n8n:N8N_URL }));

// AUTH
app.post('/api/auth/register', async (req, res) => {
  const { email, password, name, role, phone } = req.body;
  try {
    let h = password; try { h = await bcrypt.hash(password, 10); } catch {}
    const r = await pool.query('INSERT INTO users (email,password,name,role,phone) VALUES ($1,$2,$3,$4,$5) RETURNING *', [email,h,name,role,phone]);
    const user = r.rows[0];
    const token = jwt.sign({ id:user.id, role:user.role }, JWT_SECRET, { expiresIn:'7d' });
    delete user.password;
    res.status(201).json({ user, token });
  } catch (e) {
    if (e.code==='23505') return res.status(409).json({ message:'Email déjà utilisé' });
    res.status(500).json({ message:'Erreur serveur', debug:e.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const r = await pool.query('SELECT * FROM users WHERE email=$1', [email]);
    if (!r.rows.length) return res.status(401).json({ message:'Identifiants incorrects' });
    const user = r.rows[0];
    let valid = false;
    try { valid = await bcrypt.compare(password, user.password); } catch { valid = (password === user.password); }
    if (!valid) return res.status(401).json({ message:'Identifiants incorrects' });
    const token = jwt.sign({ id:user.id, role:user.role }, JWT_SECRET, { expiresIn:'7d' });
    delete user.password;
    res.json({ user, token });
  } catch (e) { res.status(500).json({ message:'Erreur serveur', debug:e.message }); }
});

app.get('/api/auth/me', auth, async (req, res) => {
  try {
    const r = await pool.query('SELECT id,email,name,role,phone,created_at FROM users WHERE id=$1', [req.user.id]);
    if (!r.rows.length) return res.status(404).json({ message:'Introuvable' });
    res.json(r.rows[0]);
  } catch { res.status(500).json({ message:'Erreur serveur' }); }
});

// FARMS
app.get('/api/farms', auth, async (req,res) => { try { const r=await pool.query('SELECT * FROM farms WHERE owner_id=$1 ORDER BY created_at DESC',[req.user.id]); res.json(r.rows); } catch { res.status(500).json({message:'Erreur'}); } });
app.post('/api/farms', auth, async (req,res) => {
  const { name,location,area_hectares,farm_type,latitude,longitude } = req.body;
  try { const r=await pool.query('INSERT INTO farms (owner_id,name,location,area_hectares,farm_type,latitude,longitude) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *',[req.user.id,name,location,area_hectares,farm_type,latitude,longitude]); res.status(201).json(r.rows[0]); }
  catch(e) { res.status(500).json({message:'Erreur',debug:e.message}); }
});
app.delete('/api/farms/:id', auth, async (req,res) => { try { await pool.query('DELETE FROM farms WHERE id=$1 AND owner_id=$2',[req.params.id,req.user.id]); res.json({message:'Supprimée'}); } catch { res.status(500).json({message:'Erreur'}); } });

// FIELDS
app.get('/api/fields', auth, async (req,res) => {
  const { farm_id } = req.query;
  try {
    const q = farm_id ? 'SELECT * FROM fields WHERE farm_id=$1 ORDER BY created_at DESC'
      : 'SELECT f.*,fa.name as farm_name FROM fields f JOIN farms fa ON f.farm_id=fa.id WHERE fa.owner_id=$1 ORDER BY f.created_at DESC';
    const r = await pool.query(q, [farm_id||req.user.id]);
    res.json(r.rows);
  } catch(e) { res.status(500).json({message:'Erreur',debug:e.message}); }
});
app.post('/api/fields', auth, async (req,res) => {
  const { farm_id,name,area_hectares,soil_type,current_crop } = req.body;
  try { const r=await pool.query('INSERT INTO fields (farm_id,name,area_hectares,soil_type,current_crop) VALUES ($1,$2,$3,$4,$5) RETURNING *',[farm_id,name,area_hectares,soil_type,current_crop]); res.status(201).json(r.rows[0]); }
  catch(e) { res.status(500).json({message:'Erreur',debug:e.message}); }
});
app.delete('/api/fields/:id', auth, async (req,res) => { try { await pool.query('DELETE FROM fields WHERE id=$1',[req.params.id]); res.json({message:'Supprimée'}); } catch { res.status(500).json({message:'Erreur'}); } });

// ALERTS
app.get('/api/alerts', auth, async (req,res) => { try { const r=await pool.query('SELECT * FROM alerts WHERE user_id=$1 ORDER BY created_at DESC',[req.user.id]); res.json(r.rows); } catch { res.status(500).json({message:'Erreur'}); } });
app.post('/api/alerts', auth, async (req,res) => {
  const { farm_id,alert_type,severity,title,message } = req.body;
  try { const r=await pool.query('INSERT INTO alerts (user_id,farm_id,alert_type,severity,title,message) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',[req.user.id,farm_id,alert_type,severity,title||alert_type,message]); res.status(201).json(r.rows[0]); }
  catch(e) { res.status(500).json({message:'Erreur',debug:e.message}); }
});
app.put('/api/alerts/:id/read', auth, async (req,res) => { try { await pool.query('UPDATE alerts SET is_read=TRUE WHERE id=$1 AND user_id=$2',[req.params.id,req.user.id]); res.json({message:'Lue'}); } catch { res.status(500).json({message:'Erreur'}); } });
app.patch('/api/alerts/:id/read', auth, async (req,res) => { try { await pool.query('UPDATE alerts SET is_read=TRUE WHERE id=$1 AND user_id=$2',[req.params.id,req.user.id]); res.json({message:'Lue'}); } catch { res.status(500).json({message:'Erreur'}); } });

// TASKS
app.get('/api/tasks', auth, async (req,res) => { try { const r=await pool.query('SELECT * FROM tasks WHERE user_id=$1 ORDER BY created_at DESC',[req.user.id]); res.json(r.rows); } catch { res.status(500).json({message:'Erreur'}); } });
app.post('/api/tasks', auth, async (req,res) => {
  const { title,description,priority,due_date,category } = req.body;
  try { const r=await pool.query('INSERT INTO tasks (user_id,title,description,priority,due_date,category) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',[req.user.id,title,description,priority,due_date,category]); res.status(201).json(r.rows[0]); }
  catch { res.status(500).json({message:'Erreur'}); }
});
app.patch('/api/tasks/:id/toggle', auth, async (req,res) => { try { const r=await pool.query('UPDATE tasks SET done=NOT done WHERE id=$1 AND user_id=$2 RETURNING *',[req.params.id,req.user.id]); res.json(r.rows[0]); } catch { res.status(500).json({message:'Erreur'}); } });
app.put('/api/tasks/:id/toggle', auth, async (req,res) => { try { const r=await pool.query('UPDATE tasks SET done=NOT done WHERE id=$1 AND user_id=$2 RETURNING *',[req.params.id,req.user.id]); res.json(r.rows[0]); } catch { res.status(500).json({message:'Erreur'}); } });
app.delete('/api/tasks/:id', auth, async (req,res) => { try { await pool.query('DELETE FROM tasks WHERE id=$1 AND user_id=$2',[req.params.id,req.user.id]); res.json({message:'Supprimée'}); } catch { res.status(500).json({message:'Erreur'}); } });

// ANIMALS
app.get('/api/animals', auth, async (req,res) => {
  const { farm_id } = req.query;
  try {
    const q = farm_id ? 'SELECT * FROM animals WHERE farm_id=$1 ORDER BY created_at DESC'
      : 'SELECT a.*,fa.name as farm_name FROM animals a JOIN farms fa ON a.farm_id=fa.id WHERE fa.owner_id=$1 ORDER BY a.created_at DESC';
    const r = await pool.query(q, [farm_id||req.user.id]);
    res.json(r.rows);
  } catch(e) { res.status(500).json({message:'Erreur',debug:e.message}); }
});
app.post('/api/animals', auth, async (req,res) => {
  const { farm_id,tag_number,species,breed,birth_date,gender,weight_kg,health_status } = req.body;
  try { const r=await pool.query('INSERT INTO animals (farm_id,tag_number,species,breed,birth_date,gender,weight_kg,health_status) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *',[farm_id,tag_number,species,breed,birth_date,gender,weight_kg,health_status||'healthy']); res.status(201).json(r.rows[0]); }
  catch(e) { res.status(500).json({message:'Erreur',debug:e.message}); }
});

// MÉTÉO
app.get('/api/weather', auth, async (req,res) => {
  const { city='Tunis' } = req.query;
  if (!OWM_KEY) return res.status(500).json({message:'Clé météo manquante'});
  try {
    const r = await fetch(`https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(city)}&appid=${OWM_KEY}&lang=fr&units=metric`);
    const d = await r.json();
    if (d.cod!==200) return res.status(400).json({message:`Ville introuvable: ${city}`});
    res.json({ city:d.name, temp:Math.round(d.main.temp), feels_like:Math.round(d.main.feels_like), humidity:d.main.humidity, description:d.weather[0].description, icon:d.weather[0].icon, wind:Math.round(d.wind.speed*3.6) });
  } catch(e) { res.status(500).json({message:'Erreur météo',debug:e.message}); }
});

// ════════ AGENT IA ════════
app.post('/api/agent/chat', auth, async (req,res) => {
  const message = req.body.message;
  const history = Array.isArray(req.body.history) ? req.body.history : [];
  const userId  = req.user.id;

  if (!message) return res.status(400).json({error:'Message manquant'});
  if (!GROQ_KEY) return res.status(500).json({message:'Clé Groq manquante'});

  const messages = [
    {
      role: 'system',
      content: `Tu es AgriBot, assistant agricole complet pour AgriSmart (Tunisie). user_id: ${userId}.

PERSONNALITÉ : Tu es chaleureux, professionnel et proactif. Tu guides l'utilisateur étape par étape.

RÈGLES STRICTES :
1. Salutations/questions générales → réponds DIRECTEMENT sans outils (max 2 phrases)
2. Avant de créer quoi que ce soit, DEMANDE les informations manquantes à l'utilisateur
3. Pour create_farm : demande nom, localisation, surface en ha, type de ferme
4. Pour create_field : demande à quelle ferme, le nom, surface, type de sol, culture actuelle  
5. Pour create_task : demande titre, priorité (haute/moyenne/basse), date, catégorie
6. Pour create_alert : demande type, urgence, titre, description
7. Pour create_animal : demande ferme, espèce, race, tag
8. Après chaque action réussie, confirme à l'utilisateur et propose la prochaine étape logique
9. Si l'utilisateur manque d'infos, liste clairement ce qu'il faut fournir
10. Réponds en français, de façon concise et pratique

CAPACITÉS (tu peux faire TOUT ça) :
- Consulter/créer/supprimer des fermes
- Consulter/créer/supprimer des parcelles (champs)
- Consulter/créer/marquer comme lues des alertes
- Consulter/créer/cocher/supprimer des tâches
- Consulter/ajouter des animaux
- Météo en temps réel
- Résumé complet de l'exploitation`
    },
    ...history.slice(-12),
    { role:'user', content:message }
  ];

  try {
    let response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method:'POST',
      headers:{ 'Content-Type':'application/json', 'Authorization':`Bearer ${GROQ_KEY}` },
      body:JSON.stringify({ model:'llama-3.3-70b-versatile', max_tokens:1024, tools:GROQ_TOOLS, tool_choice:'auto', messages })
    });
    let data = await response.json();
    if (data.error) throw new Error(JSON.stringify(data.error));

    let iter = 0;
    while (data.choices?.[0]?.finish_reason==='tool_calls' && iter<6) {
      iter++;
      const aMsg = data.choices[0].message;
      messages.push(aMsg);
      for (const call of (aMsg.tool_calls||[])) {
        let args = {};
        try { args = JSON.parse(call.function.arguments); } catch {}
        const result = await executeTool(call.function.name, args, userId);
        console.log(`✅ [${call.function.name}]`, JSON.stringify(result).slice(0,300));
        messages.push({ role:'tool', tool_call_id:call.id, content:JSON.stringify(result) });
      }
      response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method:'POST',
        headers:{ 'Content-Type':'application/json', 'Authorization':`Bearer ${GROQ_KEY}` },
        body:JSON.stringify({ model:'llama-3.3-70b-versatile', max_tokens:1024, tools:GROQ_TOOLS, tool_choice:'auto', messages })
      });
      data = await response.json();
      if (data.error) throw new Error(JSON.stringify(data.error));
    }

    const finalText = data.choices?.[0]?.message?.content || 'Je rencontre un problème, réessayez.';
    const updatedHistory = [...history.slice(-12), {role:'user',content:message}, {role:'assistant',content:finalText}];
    res.json({ response:finalText, history:updatedHistory });

  } catch(e) {
    console.error('❌ Agent:', e.message);
    res.status(500).json({ message:'Erreur agent IA', debug:e.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 AgriSmart v5 · port ${PORT}`));*/

require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false });
pool.connect().then(c => { console.log('✅ DB connectée'); c.release(); }).catch(e => console.error('❌ DB:', e.message));

const JWT_SECRET     = process.env.JWT_SECRET || 'agrismart_dev_secret';
const GROQ_KEY       = process.env.GROQ_API_KEY || process.env.GROQ_KEY;
const OWM_KEY        = process.env.OWM_API_KEY;
const N8N_URL        = (process.env.N8N_URL || 'https://anonyme878-n8n.hf.space').replace(/\/$/, '');
// URL du microservice Python LangGraph (Gemma-2-2b-it + Double DQN + FAO-56 RAG)
// Déployer agrismart_langgraph_final.ipynb en API FastAPI sur HuggingFace Spaces ou Railway,
// puis définir IRRIGATION_URL dans les variables d'environnement Railway.
const IRRIGATION_URL = (process.env.IRRIGATION_URL || '').replace(/\/$/, '');

function auth(req, res, next) {
  const h = req.headers['authorization'];
  if (!h) return res.status(401).json({ message: 'Token manquant' });
  try { req.user = jwt.verify(h.replace('Bearer ', ''), JWT_SECRET); next(); }
  catch { res.status(401).json({ message: 'Token invalide' }); }
}

async function callN8n(path, body) {
  try {
    const r = await fetch(`${N8N_URL}/webhook/${path}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body), signal: AbortSignal.timeout(10000)
    });
    const t = await r.text();
    try { return JSON.parse(t); } catch { return { raw: t }; }
  } catch (e) { return { error: e.message }; }
}

// ════════ EXÉCUTION OUTILS — adapté à ta vraie BD ════════
async function executeTool(name, args, userId) {
  console.log(`🔧 ${name}`, JSON.stringify(args));
  try {
    switch (name) {

      case 'get_app_info':
        // L'agent décrit l'application à l'utilisateur
        return {
          app_name: 'AgriSmart',
          description: 'Plateforme agricole intelligente mobile-first',
          tabs: ['Accueil (météo, résumé)', 'Parcelles (fermes + champs)', 'Alertes', 'Tâches'],
          actions_possibles: [
            'Voir/créer/supprimer fermes',
            'Voir/créer/supprimer parcelles (champs)',
            'Voir/créer/marquer alertes comme lues',
            'Voir/créer/cocher/supprimer tâches',
            'Consulter météo en temps réel',
            'Voir animaux (bétail)',
            'Résumé complet de l\'exploitation'
          ],
          user_id: userId
        };

      case 'get_summary': {
        const [farms, alerts, tasks, fields, animals] = await Promise.all([
          pool.query('SELECT id,name,location,area_hectares,farm_type FROM farms WHERE owner_id=$1', [userId]),
          pool.query("SELECT id,alert_type,severity,title,message,is_read,created_at FROM alerts WHERE user_id=$1 AND is_read=FALSE ORDER BY created_at DESC LIMIT 5", [userId]),
          pool.query("SELECT id,title,priority,due_date,category,done FROM tasks WHERE user_id=$1 AND done=FALSE ORDER BY due_date ASC LIMIT 5", [userId]).catch(() => ({ rows: [], rowCount: 0 })),
          pool.query('SELECT f.id,f.name,f.area_hectares,f.current_crop,f.soil_type,fa.name as farm_name FROM fields f JOIN farms fa ON f.farm_id=fa.id WHERE fa.owner_id=$1', [userId]).catch(() => ({ rows: [], rowCount: 0 })),
          pool.query('SELECT a.id,a.tag_number,a.species,a.breed,a.health_status FROM animals a JOIN farms fa ON a.farm_id=fa.id WHERE fa.owner_id=$1', [userId]).catch(() => ({ rows: [], rowCount: 0 })),
        ]);
        return { farms: farms.rows, unread_alerts: alerts.rows, pending_tasks: tasks.rows, fields: fields.rows, animals: animals.rows,
          counts: { farms: farms.rowCount, alerts: alerts.rowCount, tasks: tasks.rowCount, fields: fields.rowCount, animals: animals.rowCount } };
      }

      case 'get_weather':
        return callN8n('get-weather', { location: args.location || 'Tunis' });

      case 'get_farms': {
        const r = await pool.query('SELECT * FROM farms WHERE owner_id=$1 ORDER BY created_at DESC', [userId]);
        return { farms: r.rows, count: r.rowCount };
      }

      case 'create_farm': {
        if (!args.name) return { error: 'Le nom de la ferme est obligatoire', missing_fields: ['name'] };
        // Normalise farm_type pour respecter la contrainte CHECK de la BD
        const FARM_TYPES = ['Polyculture','Maraichage','Cereales','Elevage','Arboriculture','Autre'];
        const normalizeType = (t) => {
          if (!t) return 'Polyculture';
          const n = (t||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'');
          const match = FARM_TYPES.find(ft => ft.toLowerCase() === n.toLowerCase());
          return match || 'Autre';
        };
        const farmType = normalizeType(args.farm_type);
        const r = await pool.query(
          'INSERT INTO farms (owner_id,name,location,area_hectares,farm_type) VALUES ($1,$2,$3,$4,$5) RETURNING *',
          [userId, args.name, args.location || null, args.area_hectares || null, farmType]
        );
        return { success: true, farm: r.rows[0], message: `Ferme "${args.name}" créée avec succès ! (type: ${farmType})` };
      }

      case 'delete_farm': {
        if (!args.farm_id) return { error: 'farm_id manquant' };
        await pool.query('DELETE FROM farms WHERE id=$1 AND owner_id=$2', [args.farm_id, userId]);
        return { success: true, message: 'Ferme supprimée' };
      }

      case 'get_fields': {
        const r = await pool.query(
          'SELECT f.*,fa.name as farm_name FROM fields f JOIN farms fa ON f.farm_id=fa.id WHERE fa.owner_id=$1 ORDER BY f.created_at DESC',
          [userId]
        );
        return { fields: r.rows, count: r.rowCount };
      }

      case 'create_field': {
        if (!args.farm_id) return { error: 'farm_id manquant — demandez d\'abord à l\'utilisateur à quelle ferme appartient ce champ', missing_fields: ['farm_id'] };
        if (!args.name) return { error: 'name manquant', missing_fields: ['name'] };
        const r = await pool.query(
          'INSERT INTO fields (farm_id,name,area_hectares,soil_type,current_crop) VALUES ($1,$2,$3,$4,$5) RETURNING *',
          [args.farm_id, args.name, args.area_hectares || null, args.soil_type || null, args.current_crop || null]
        );
        return { success: true, field: r.rows[0], message: `Parcelle "${args.name}" créée avec succès !` };
      }

      case 'get_tasks': {
        const r = await pool.query('SELECT * FROM tasks WHERE user_id=$1 ORDER BY done ASC, due_date ASC', [userId]);
        return { tasks: r.rows, count: r.rowCount };
      }

      case 'create_task': {
        if (!args.title) return { error: 'Titre obligatoire', missing_fields: ['title'] };
        const r = await pool.query(
          'INSERT INTO tasks (user_id,title,description,priority,due_date,category) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
          [userId, args.title, args.description || '', args.priority || 'medium', args.due_date || null, args.category || 'Autre']
        );
        return { success: true, task: r.rows[0], message: `Tâche "${args.title}" créée !` };
      }

      case 'toggle_task': {
        if (!args.task_id) return { error: 'task_id manquant' };
        const r = await pool.query('UPDATE tasks SET done=NOT done WHERE id=$1 AND user_id=$2 RETURNING *', [args.task_id, userId]);
        const t = r.rows[0];
        return { success: true, task: t, message: t.done ? `Tâche "${t.title}" marquée comme terminée ✅` : `Tâche "${t.title}" remise en attente` };
      }

      case 'delete_task': {
        if (!args.task_id) return { error: 'task_id manquant' };
        const r = await pool.query('SELECT title FROM tasks WHERE id=$1 AND user_id=$2', [args.task_id, userId]);
        await pool.query('DELETE FROM tasks WHERE id=$1 AND user_id=$2', [args.task_id, userId]);
        return { success: true, message: `Tâche "${r.rows[0]?.title}" supprimée` };
      }

      case 'get_alerts': {
        const r = await pool.query('SELECT * FROM alerts WHERE user_id=$1 ORDER BY created_at DESC', [userId]);
        return { alerts: r.rows, count: r.rowCount };
      }

      case 'create_alert': {
        if (!args.alert_type || !args.severity || !args.message)
          return { error: 'Champs obligatoires manquants', missing_fields: ['alert_type', 'severity', 'message'].filter(f => !args[f]) };
        const r = await pool.query(
          'INSERT INTO alerts (user_id,farm_id,alert_type,severity,title,message) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
          [userId, args.farm_id || null, args.alert_type, args.severity, args.title || args.alert_type, args.message]
        );
        return { success: true, alert: r.rows[0], message: `Alerte "${args.title || args.alert_type}" créée !` };
      }

      case 'mark_alert_read': {
        if (!args.alert_id) return { error: 'alert_id manquant' };
        await pool.query('UPDATE alerts SET is_read=TRUE WHERE id=$1 AND user_id=$2', [args.alert_id, userId]);
        return { success: true, message: 'Alerte marquée comme lue' };
      }

      case 'get_animals': {
        const r = await pool.query(
          'SELECT a.*,fa.name as farm_name FROM animals a JOIN farms fa ON a.farm_id=fa.id WHERE fa.owner_id=$1 ORDER BY a.created_at DESC',
          [userId]
        );
        return { animals: r.rows, count: r.rowCount };
      }

      case 'create_animal': {
        if (!args.farm_id || !args.species) return { error: 'farm_id et species obligatoires', missing_fields: ['farm_id', 'species'].filter(f => !args[f]) };
        const r = await pool.query(
          'INSERT INTO animals (farm_id,tag_number,species,breed,birth_date,gender,weight_kg,health_status) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *',
          [args.farm_id, args.tag_number || null, args.species, args.breed || null, args.birth_date || null, args.gender || null, args.weight_kg || null, args.health_status || 'healthy']
        );
        return { success: true, animal: r.rows[0], message: `Animal ajouté avec succès !` };
      }


      // ════════ AGENT IRRIGATION IA (PyTorch DQN Ensemble + FAO-56) ════════
      case 'irrigation_advisor': {
        const { field_id, soil_moisture, location } = args;
        const SM_OPTIMAL_LOW  = 0.208;
        const SM_OPTIMAL_HIGH = 0.28;
        const ACTIONS_MM      = [0, 5, 10, 15, 20];

        let fieldInfo = {};
        if (field_id) {
          try {
            const fr = await pool.query(
              'SELECT f.*, fa.name AS farm_name, fa.location AS farm_location FROM fields f JOIN farms fa ON f.farm_id=fa.id WHERE f.id=$1 AND fa.owner_id=$2',
              [field_id, userId]
            );
            if (fr.rows.length) fieldInfo = fr.rows[0];
          } catch(e) { /* champ optionnel */ }
        }

        const loc  = location || fieldInfo.farm_location || 'Tunis';
        const smVal = parseFloat(soil_moisture);
        if (isNaN(smVal) || smVal < 0 || smVal > 1)
          return { error: 'soil_moisture invalide — valeur entre 0 et 1 (ex: 0.25 pour 25%)' };

        // Bilan hydrique FAO-56 (fallback si HF Space indisponible)
        const SM_TARGET  = (SM_OPTIMAL_LOW + SM_OPTIMAL_HIGH) / 2;
        const SOIL_DEPTH = 300;
        const deficit_mm = Math.max(0, (SM_TARGET - smVal) * SOIL_DEPTH);
        const faoMm = ACTIONS_MM.reduce((p, c) =>
          Math.abs(c - deficit_mm) < Math.abs(p - deficit_mm) ? c : p);

        function faoResult(mm) {
          let status, advice;
          if (smVal >= SM_OPTIMAL_HIGH) {
            mm = 0; status = 'surplus';
            advice = `Sol saturé (${(smVal*100).toFixed(1)}%), aucune irrigation nécessaire.`;
          } else if (smVal >= SM_OPTIMAL_LOW) {
            mm = 0; status = 'optimal';
            advice = `Humidité optimale FAO-56 (${(smVal*100).toFixed(1)}%). Aucune irrigation requise.`;
          } else if (smVal >= 0.19) {
            mm = Math.min(mm, 5); status = 'sous_optimal';
            advice = `Légère baisse (${(smVal*100).toFixed(1)}%). Apport : ${mm} mm.`;
          } else if (smVal >= 0.15) {
            status = 'sous_optimal';
            advice = `Humidité basse (${(smVal*100).toFixed(1)}%). Déficit ~${Math.round(deficit_mm)} mm — Irrigation : ${mm} mm.`;
          } else if (smVal >= 0.10) {
            mm = Math.max(mm, 15); status = 'faible';
            advice = `Stress hydrique (${(smVal*100).toFixed(1)}%). Irrigation urgente : ${mm} mm.`;
          } else {
            mm = 20; status = 'critique';
            advice = `Stress sévère (${(smVal*100).toFixed(1)}%) ! Irrigation immédiate : 20 mm.`;
          }
          return { mm, status, advice };
        }

        // Appel HF Space — le DQN PyTorch fournit la recommandation principale
        if (IRRIGATION_URL) {
          try {
            const resp = await fetch(`${IRRIGATION_URL}/irrigate`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                soil_moisture: smVal, location: loc,
                crop:      fieldInfo.current_crop || null,
                soil_type: fieldInfo.soil_type    || null,
                field_id:  field_id               || null,
              }),
              signal: AbortSignal.timeout(20000)
            });
            if (resp.ok) {
              const py = await resp.json();
              // Garder la recommandation DQN mais appliquer les bornes de sécurité FAO-56
              let dqnMm = py.recommended_irrigation_mm ?? faoMm;
              // Borne haute : sol saturé → 0 mm impératif
              if (smVal >= SM_OPTIMAL_HIGH) dqnMm = 0;
              // Borne basse : stress sévère → minimum 15 mm
              if (smVal < 0.10) dqnMm = Math.max(dqnMm, 20);
              else if (smVal < 0.15) dqnMm = Math.max(dqnMm, 15);
              const { status, advice } = faoResult(dqnMm);
              console.log(`🌿 DQN: ${py.recommended_irrigation_mm}mm → final: ${dqnMm}mm (sm=${(smVal*100).toFixed(1)}%)`);
              return {
                ...py,
                recommended_irrigation_mm: dqnMm,
                status, advice,
                field: fieldInfo,
                source: 'pytorch_dqn_ensemble+fao56',
              };
            }
          } catch(e) {
            console.warn('⚠️ HF Space indisponible, fallback FAO-56:', e.message);
          }
        }

        // ── Fallback pur FAO-56 ───────────────────────────────────────────────
        const { mm: recommended_mm, status, advice } = faoResult(faoMm);
        return {
          field: fieldInfo, soil_moisture: smVal,
          optimal_band: [SM_OPTIMAL_LOW, SM_OPTIMAL_HIGH],
          status, recommended_irrigation_mm: recommended_mm,
          available_actions_mm: ACTIONS_MM, advice,
          source: 'rules_fao56',
          note: IRRIGATION_URL ? null : 'Définir IRRIGATION_URL pour activer le modèle DQN PyTorch.',
        };
      }
      default:
        return { error: `Outil inconnu: ${name}` };
    }
  } catch (e) {
    console.error(`❌ ${name}:`, e.message);
    return { error: e.message };
  }
}

// ════════ OUTILS GROQ — définition complète ════════
const GROQ_TOOLS = [
  { type:'function', function:{ name:'get_app_info', description:"Décrit l'application AgriSmart et toutes ses fonctionnalités disponibles. Appelle si l'utilisateur demande ce qu'il peut faire ou comment utiliser l'app.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'get_summary', description:"Résumé complet : fermes, champs, alertes non lues, tâches en attente, animaux. Appelle pour questions générales sur l'exploitation.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'get_weather', description:"Météo en temps réel. Appelle si météo/température/pluie/vent mentionné.", parameters:{ type:'object', properties:{ location:{ type:'string', description:'Ville tunisienne' } }, required:['location'] } } },
  { type:'function', function:{ name:'get_farms', description:"Liste les fermes de l'utilisateur.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'create_farm', description:"Crée une nouvelle ferme. Demande TOUJOURS nom, localisation et surface à l'utilisateur AVANT d'appeler cet outil.", parameters:{ type:'object', properties:{ name:{ type:'string' }, location:{ type:'string' }, area_hectares:{ type:'number' }, farm_type:{ type:'string', enum:['Polyculture','Maraichage','Cereales','Elevage','Arboriculture','Autre'] } }, required:['name'] } } },
  { type:'function', function:{ name:'delete_farm', description:"Supprime une ferme. Demande confirmation à l'utilisateur.", parameters:{ type:'object', properties:{ farm_id:{ type:'number' } }, required:['farm_id'] } } },
  { type:'function', function:{ name:'get_fields', description:"Liste les parcelles/champs de l'utilisateur.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'create_field', description:"Crée une parcelle/champ. Demande nom, ferme concernée, surface, type de sol et culture actuelle.", parameters:{ type:'object', properties:{ farm_id:{ type:'number' }, name:{ type:'string' }, area_hectares:{ type:'number' }, soil_type:{ type:'string', enum:['Argileux','Sableux','Limoneux','Calcaire','Humifère','Autre'] }, current_crop:{ type:'string', description:'Culture actuelle ex: Tomate, Blé, Olive' } }, required:['farm_id','name'] } } },
  { type:'function', function:{ name:'get_tasks', description:"Liste toutes les tâches de l'utilisateur.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'create_task', description:"Crée une tâche agricole. Demande titre, priorité, date et catégorie.", parameters:{ type:'object', properties:{ title:{ type:'string' }, description:{ type:'string' }, priority:{ type:'string', enum:['high','medium','low'] }, due_date:{ type:'string', description:'YYYY-MM-DD' }, category:{ type:'string', enum:['Irrigation','Traitement','Récolte','Semis','Maintenance','Approvisionnement','Autre'] } }, required:['title'] } } },
  { type:'function', function:{ name:'toggle_task', description:"Marque une tâche comme terminée ou la remet en attente.", parameters:{ type:'object', properties:{ task_id:{ type:'number' } }, required:['task_id'] } } },
  { type:'function', function:{ name:'delete_task', description:"Supprime une tâche.", parameters:{ type:'object', properties:{ task_id:{ type:'number' } }, required:['task_id'] } } },
  { type:'function', function:{ name:'get_alerts', description:"Liste toutes les alertes de l'utilisateur.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'create_alert', description:"Crée une alerte. Demande type, urgence, titre et description à l'utilisateur.", parameters:{ type:'object', properties:{ alert_type:{ type:'string', enum:['water_stress','disease','temperature','weather','livestock','Meteo','Arrosage','recolte','semis','traitement','fertilisation','Autre'] }, severity:{ type:'string', enum:['low','medium','high','critical'] }, title:{ type:'string' }, message:{ type:'string' }, farm_id:{ type:'number' } }, required:['alert_type','severity','message'] } } },
  { type:'function', function:{ name:'mark_alert_read', description:"Marque une alerte comme lue.", parameters:{ type:'object', properties:{ alert_id:{ type:'number' } }, required:['alert_id'] } } },
  { type:'function', function:{ name:'get_animals', description:"Liste les animaux/bétail de l'utilisateur.", parameters:{ type:'object', properties:{} } } },
  { type:'function', function:{ name:'create_animal', description:"Ajoute un animal. Demande ferme, espèce, race, numéro de tag.", parameters:{ type:'object', properties:{ farm_id:{ type:'number' }, tag_number:{ type:'string' }, species:{ type:'string', description:'Bovin, Ovin, Caprin, Volaille...' }, breed:{ type:'string' }, birth_date:{ type:'string' }, gender:{ type:'string', enum:['male','female'] }, weight_kg:{ type:'number' }, health_status:{ type:'string', enum:['healthy','sick','critical'] } }, required:['farm_id','species'] } } },
  { type:'function', function:{ name:'irrigation_advisor', description:"Recommande la quantité d'irrigation optimale pour une parcelle basée sur l'humidité du sol et les conditions météo. Utilise un modèle Double DQN entraîné sur FAO-56. Appelle quand l'utilisateur demande combien arroser, irrigation, humidité du sol.", parameters:{ type:'object', properties:{ field_id:{ type:'number', description:'ID de la parcelle (optionnel)' }, soil_moisture:{ type:'number', description:"Humidité du sol actuelle entre 0 et 1 (ex: 0.25 = 25%)" }, location:{ type:'string', description:"Ville pour la météo (ex: Tunis)" } }, required:['soil_moisture'] } } },
];

// ════════ ROUTES ════════
app.get('/', (req, res) => res.json({ message:'AgriSmart API ✅', version:'5.0', groq:!!GROQ_KEY, owm:!!OWM_KEY, n8n:N8N_URL }));

// AUTH
app.post('/api/auth/register', async (req, res) => {
  const { email, password, name, role, phone } = req.body;
  if (!email || !password)
    return res.status(400).json({ message: 'Email et mot de passe requis' });
  const phoneVal = phone != null && String(phone).trim() !== '' ? String(phone).trim() : null;
  try {
    let h = password; try { h = await bcrypt.hash(password, 10); } catch {}
    let r;
    try {
      r = await pool.query(
        'INSERT INTO users (email,password,name,role,phone) VALUES ($1,$2,$3,$4,$5) RETURNING id,email,name,role,phone,created_at',
        [email, h, name, role, phoneVal]
      );
    } catch (insErr) {
      if (insErr.code === '42703' && String(insErr.message || '').toLowerCase().includes('phone')) {
        r = await pool.query(
          'INSERT INTO users (email,password,name,role) VALUES ($1,$2,$3,$4) RETURNING id,email,name,role,created_at',
          [email, h, name, role]
        );
      } else throw insErr;
    }
    const user = r.rows[0];
    const token = jwt.sign({ id:user.id, role:user.role }, JWT_SECRET, { expiresIn:'7d' });
    res.status(201).json({ user, token });
  } catch (e) {
    console.error('❌ POST /api/auth/register', e.code || '', e.message, e.detail || '');
    if (e.code==='23505') return res.status(409).json({ message:'Email déjà utilisé' });
    if (e.code==='23514') return res.status(400).json({ message:'Rôle ou données invalides', debug:e.message });
    res.status(500).json({
      message: 'Erreur serveur',
      debug: e.message,
      detail: e.detail || undefined,
      code: e.code || undefined,
    });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const r = await pool.query('SELECT * FROM users WHERE email=$1', [email]);
    if (!r.rows.length) return res.status(401).json({ message:'Identifiants incorrects' });
    const user = r.rows[0];
    let valid = false;
    try { valid = await bcrypt.compare(password, user.password); } catch { valid = (password === user.password); }
    if (!valid) return res.status(401).json({ message:'Identifiants incorrects' });
    const token = jwt.sign({ id:user.id, role:user.role }, JWT_SECRET, { expiresIn:'7d' });
    delete user.password;
    res.json({ user, token });
  } catch (e) { res.status(500).json({ message:'Erreur serveur', debug:e.message }); }
});

app.get('/api/auth/me', auth, async (req, res) => {
  try {
    const r = await pool.query('SELECT id,email,name,role,phone,created_at FROM users WHERE id=$1', [req.user.id]);
    if (!r.rows.length) return res.status(404).json({ message:'Introuvable' });
    res.json(r.rows[0]);
  } catch { res.status(500).json({ message:'Erreur serveur' }); }
});

// FARMS
app.get('/api/farms', auth, async (req,res) => { try { const r=await pool.query('SELECT * FROM farms WHERE owner_id=$1 ORDER BY created_at DESC',[req.user.id]); res.json(r.rows); } catch { res.status(500).json({message:'Erreur'}); } });
app.post('/api/farms', auth, async (req,res) => {
  const { name,location,area_hectares,farm_type,latitude,longitude } = req.body;
  // Normalise farm_type : retire les accents pour respecter la contrainte BD
  const FARM_TYPES = ['Polyculture','Maraichage','Cereales','Elevage','Arboriculture','Autre'];
  const normalizeType = (t) => {
    if (!t) return 'Polyculture';
    // Retire accents
    const n = t.normalize('NFD').replace(/[\u0300-\u036f]/g,'');
    // Trouve le type le plus proche
    const match = FARM_TYPES.find(ft => ft.toLowerCase() === n.toLowerCase());
    return match || 'Autre';
  };
  try {
    const r=await pool.query(
      'INSERT INTO farms (owner_id,name,location,area_hectares,farm_type,latitude,longitude) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *',
      [req.user.id,name,location,area_hectares,normalizeType(farm_type),latitude||null,longitude||null]
    );
    res.status(201).json(r.rows[0]);
  }
  catch(e) { res.status(500).json({message:'Erreur création ferme',debug:e.message}); }
});
app.delete('/api/farms/:id', auth, async (req,res) => { try { await pool.query('DELETE FROM farms WHERE id=$1 AND owner_id=$2',[req.params.id,req.user.id]); res.json({message:'Supprimée'}); } catch { res.status(500).json({message:'Erreur'}); } });

// FIELDS
app.get('/api/fields', auth, async (req,res) => {
  const { farm_id } = req.query;
  try {
    const q = farm_id ? 'SELECT * FROM fields WHERE farm_id=$1 ORDER BY created_at DESC'
      : 'SELECT f.*,fa.name as farm_name FROM fields f JOIN farms fa ON f.farm_id=fa.id WHERE fa.owner_id=$1 ORDER BY f.created_at DESC';
    const r = await pool.query(q, [farm_id||req.user.id]);
    res.json(r.rows);
  } catch(e) { res.status(500).json({message:'Erreur',debug:e.message}); }
});
app.post('/api/fields', auth, async (req,res) => {
  const { farm_id,name,area_hectares,soil_type,current_crop } = req.body;
  try { const r=await pool.query('INSERT INTO fields (farm_id,name,area_hectares,soil_type,current_crop) VALUES ($1,$2,$3,$4,$5) RETURNING *',[farm_id,name,area_hectares,soil_type,current_crop]); res.status(201).json(r.rows[0]); }
  catch(e) { res.status(500).json({message:'Erreur',debug:e.message}); }
});
app.delete('/api/fields/:id', auth, async (req,res) => { try { await pool.query('DELETE FROM fields WHERE id=$1',[req.params.id]); res.json({message:'Supprimée'}); } catch { res.status(500).json({message:'Erreur'}); } });

// ALERTS
app.get('/api/alerts', auth, async (req,res) => { try { const r=await pool.query('SELECT * FROM alerts WHERE user_id=$1 ORDER BY created_at DESC',[req.user.id]); res.json(r.rows); } catch { res.status(500).json({message:'Erreur'}); } });
app.post('/api/alerts', auth, async (req,res) => {
  const { farm_id,alert_type,severity,title,message } = req.body;
  try { const r=await pool.query('INSERT INTO alerts (user_id,farm_id,alert_type,severity,title,message) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',[req.user.id,farm_id,alert_type,severity,title||alert_type,message]); res.status(201).json(r.rows[0]); }
  catch(e) { res.status(500).json({message:'Erreur',debug:e.message}); }
});
app.put('/api/alerts/:id/read', auth, async (req,res) => { try { await pool.query('UPDATE alerts SET is_read=TRUE WHERE id=$1 AND user_id=$2',[req.params.id,req.user.id]); res.json({message:'Lue'}); } catch { res.status(500).json({message:'Erreur'}); } });
app.patch('/api/alerts/:id/read', auth, async (req,res) => { try { await pool.query('UPDATE alerts SET is_read=TRUE WHERE id=$1 AND user_id=$2',[req.params.id,req.user.id]); res.json({message:'Lue'}); } catch { res.status(500).json({message:'Erreur'}); } });

// TASKS
app.get('/api/tasks', auth, async (req,res) => { try { const r=await pool.query('SELECT * FROM tasks WHERE user_id=$1 ORDER BY created_at DESC',[req.user.id]); res.json(r.rows); } catch { res.status(500).json({message:'Erreur'}); } });
app.post('/api/tasks', auth, async (req,res) => {
  const { title,description,priority,due_date,category } = req.body;
  try { const r=await pool.query('INSERT INTO tasks (user_id,title,description,priority,due_date,category) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',[req.user.id,title,description,priority,due_date,category]); res.status(201).json(r.rows[0]); }
  catch { res.status(500).json({message:'Erreur'}); }
});
app.patch('/api/tasks/:id/toggle', auth, async (req,res) => { try { const r=await pool.query('UPDATE tasks SET done=NOT done WHERE id=$1 AND user_id=$2 RETURNING *',[req.params.id,req.user.id]); res.json(r.rows[0]); } catch { res.status(500).json({message:'Erreur'}); } });
app.put('/api/tasks/:id/toggle', auth, async (req,res) => { try { const r=await pool.query('UPDATE tasks SET done=NOT done WHERE id=$1 AND user_id=$2 RETURNING *',[req.params.id,req.user.id]); res.json(r.rows[0]); } catch { res.status(500).json({message:'Erreur'}); } });
app.delete('/api/tasks/:id', auth, async (req,res) => { try { await pool.query('DELETE FROM tasks WHERE id=$1 AND user_id=$2',[req.params.id,req.user.id]); res.json({message:'Supprimée'}); } catch { res.status(500).json({message:'Erreur'}); } });

// ANIMALS
app.get('/api/animals', auth, async (req,res) => {
  const { farm_id } = req.query;
  try {
    const q = farm_id ? 'SELECT * FROM animals WHERE farm_id=$1 ORDER BY created_at DESC'
      : 'SELECT a.*,fa.name as farm_name FROM animals a JOIN farms fa ON a.farm_id=fa.id WHERE fa.owner_id=$1 ORDER BY a.created_at DESC';
    const r = await pool.query(q, [farm_id||req.user.id]);
    res.json(r.rows);
  } catch(e) { res.status(500).json({message:'Erreur',debug:e.message}); }
});
app.post('/api/animals', auth, async (req,res) => {
  const { farm_id,tag_number,species,breed,birth_date,gender,weight_kg,health_status } = req.body;
  try { const r=await pool.query('INSERT INTO animals (farm_id,tag_number,species,breed,birth_date,gender,weight_kg,health_status) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *',[farm_id,tag_number,species,breed,birth_date,gender,weight_kg,health_status||'healthy']); res.status(201).json(r.rows[0]); }
  catch(e) { res.status(500).json({message:'Erreur',debug:e.message}); }
});

// MÉTÉO
app.get('/api/weather', auth, async (req,res) => {
  const { city='Tunis' } = req.query;
  if (!OWM_KEY) return res.status(500).json({message:'Clé météo manquante'});
  try {
    const r = await fetch(`https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(city)}&appid=${OWM_KEY}&lang=fr&units=metric`);
    const d = await r.json();
    if (d.cod!==200) return res.status(400).json({message:`Ville introuvable: ${city}`});
    res.json({ city:d.name, temp:Math.round(d.main.temp), feels_like:Math.round(d.main.feels_like), humidity:d.main.humidity, description:d.weather[0].description, icon:d.weather[0].icon, wind:Math.round(d.wind.speed*3.6) });
  } catch(e) { res.status(500).json({message:'Erreur météo',debug:e.message}); }
});

// ════════ AGENT IA ════════
app.post('/api/agent/chat', auth, async (req,res) => {
  const message = req.body.message;
  const history = Array.isArray(req.body.history) ? req.body.history : [];
  const userId  = req.user.id;

  if (!message) return res.status(400).json({error:'Message manquant'});
  if (!GROQ_KEY) return res.status(500).json({message:'Clé Groq manquante'});

  const messages = [
    {
      role: 'system',
      content: `Tu es AgriBot, assistant agricole complet pour AgriSmart (Tunisie). user_id: ${userId}.

PERSONNALITÉ : Tu es chaleureux, professionnel et proactif. Tu guides l'utilisateur étape par étape.

RÈGLES STRICTES :
1. Salutations/questions générales → réponds DIRECTEMENT sans outils (max 2 phrases)
2. Avant de créer quoi que ce soit, DEMANDE les informations manquantes à l'utilisateur
3. Pour create_farm : demande nom, localisation, surface en ha, type de ferme
4. Pour create_field : demande à quelle ferme, le nom, surface, type de sol, culture actuelle  
5. Pour create_task : demande titre, priorité (haute/moyenne/basse), date, catégorie
6. Pour create_alert : demande type, urgence, titre, description
7. Pour create_animal : demande ferme, espèce, race, tag
8. Après chaque action réussie, confirme à l'utilisateur et propose la prochaine étape logique
9. Si l'utilisateur manque d'infos, liste clairement ce qu'il faut fournir
10. Réponds en français, de façon concise et pratique

CAPACITÉS (tu peux faire TOUT ça) :
- Consulter/créer/supprimer des fermes
- Consulter/créer/supprimer des parcelles (champs)
- Consulter/créer/marquer comme lues des alertes
- Consulter/créer/cocher/supprimer des tâches
- Consulter/ajouter des animaux
- Météo en temps réel
- Résumé complet de l'exploitation
- Recommandation d'irrigation (Double DQN + FAO-56) : si l'utilisateur mentionne l'humidité du sol ou demande combien arroser, appelle irrigation_advisor avec soil_moisture entre 0 et 1`
    },
    ...history.slice(-12),
    { role:'user', content:message }
  ];

  try {
    let response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method:'POST',
      headers:{ 'Content-Type':'application/json', 'Authorization':`Bearer ${GROQ_KEY}` },
      body:JSON.stringify({ model:'llama-3.3-70b-versatile', max_tokens:1024, tools:GROQ_TOOLS, tool_choice:'auto', messages })
    });
    let data = await response.json();
    if (data.error) throw new Error(JSON.stringify(data.error));

    let iter = 0;
    while (data.choices?.[0]?.finish_reason==='tool_calls' && iter<6) {
      iter++;
      const aMsg = data.choices[0].message;
      messages.push(aMsg);
      for (const call of (aMsg.tool_calls||[])) {
        let args = {};
        try { args = JSON.parse(call.function.arguments); } catch {}
        const result = await executeTool(call.function.name, args, userId);
        console.log(`✅ [${call.function.name}]`, JSON.stringify(result).slice(0,300));
        messages.push({ role:'tool', tool_call_id:call.id, content:JSON.stringify(result) });
      }
      response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method:'POST',
        headers:{ 'Content-Type':'application/json', 'Authorization':`Bearer ${GROQ_KEY}` },
        body:JSON.stringify({ model:'llama-3.3-70b-versatile', max_tokens:1024, tools:GROQ_TOOLS, tool_choice:'auto', messages })
      });
      data = await response.json();
      if (data.error) throw new Error(JSON.stringify(data.error));
    }

    const finalText = data.choices?.[0]?.message?.content || 'Je rencontre un problème, réessayez.';
    const updatedHistory = [...history.slice(-12), {role:'user',content:message}, {role:'assistant',content:finalText}];
    res.json({ response:finalText, history:updatedHistory });

  } catch(e) {
    console.error('❌ Agent:', e.message);
    res.status(500).json({ message:'Erreur agent IA', debug:e.message });
  }
});

// ════════ ENDPOINT DIRECT IRRIGATION IA ════════
// Permet à Flutter d'appeler directement le conseiller irrigation sans passer par le chatbot.
// POST /api/agent/irrigation  { field_id?, soil_moisture, location? }
app.post('/api/agent/irrigation', auth, async (req, res) => {
  const { field_id, soil_moisture, location } = req.body;
  if (soil_moisture === undefined || soil_moisture === null)
    return res.status(400).json({ error: 'soil_moisture requis (0 à 1, ex: 0.25 pour 25%)' });
  const result = await executeTool('irrigation_advisor', { field_id, soil_moisture, location }, req.user.id);
  if (result.error) return res.status(400).json(result);
  res.json(result);
});

// Migration : normalise les contraintes au démarrage
pool.connect().then(async c => {
  try {
    await c.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        name TEXT,
        role TEXT NOT NULL DEFAULT 'farmer',
        phone TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    await c.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT`);
    await c.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS name TEXT`);
    await c.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT`);
    await c.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW()`);
    await c.query(`ALTER TABLE users ALTER COLUMN password TYPE TEXT USING password::TEXT`);
    console.log('✅ Colonnes table users OK');
  } catch(e) { console.error('⚠️ Migration users DDL:', e.message); }

  try {
    await c.query(`
      ALTER TABLE farms DROP CONSTRAINT IF EXISTS farms_farm_type_check;
      ALTER TABLE farms ADD CONSTRAINT farms_farm_type_check
        CHECK (farm_type IN ('Polyculture','Maraichage','Cereales','Elevage','Arboriculture','Autre'));
    `);
    console.log('✅ Contrainte farm_type OK');
  } catch(e) { console.error('⚠️ Migration farm_type:', e.message); }

  try {
    // Trouve et supprime uniquement les contraintes CHECK portant sur la colonne 'role'
    const res = await c.query(`
      SELECT c.conname
      FROM pg_constraint c
      JOIN pg_class t ON c.conrelid = t.oid
      WHERE t.relname = 'users'
        AND c.contype = 'c'
        AND pg_get_constraintdef(c.oid) ILIKE '%role%'
    `);
    for (const row of res.rows) {
      await c.query(`ALTER TABLE users DROP CONSTRAINT IF EXISTS "${row.conname}"`);
    }
    await c.query(`
      ALTER TABLE users ADD CONSTRAINT users_role_check
        CHECK (role IN ('farmer','breeder','vet','agronomist','admin'))
    `);
    console.log('✅ Contrainte users.role OK');
  } catch(e) { console.error('⚠️ Migration users.role:', e.message); }

  c.release();
}).catch(e => console.error('⚠️ Migration:', e.message));

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 AgriSmart v6 · http://0.0.0.0:${PORT} (téléphone → IP du PC:${PORT})`);
});
