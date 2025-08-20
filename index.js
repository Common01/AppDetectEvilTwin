const express = require('express');
const mysql = require('mysql2');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
require('dotenv').config();
const cors = require('cors');
const { expressjwt: jwtMiddleware } = require('express-jwt');

const app = express();
const port = process.env.PORT || 3000;

// 🔐 เช็คว่า roles เป็น Admin หรือไม่
function requireAdmin(req, res, next) {
  if (req.auth?.roles !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }
  next();
}



// Middleware
app.use(cors());
app.use(express.json());


// MySQL connection
const connection = mysql.createConnection({
  host: process.env.DB_HOST,      
  user: process.env.DB_USER,      
  password: process.env.DB_PASS,  
  database: process.env.DB_NAME,  
  connectTimeout: 10000,
});

connection.connect((err) => {
  if (err) {
    console.error("MySQL connection error:", err);
    return;
  }
  console.log("✅ Connected to MySQL");
});

// JWT TOKEN key ระบบ JWT Authentication (login ออก token, middleware ป้องกัน route)
const JWT_TOKEN = process.env.JWT_TOKEN || 'your_jwt_secret_key';

// Middleware ตรวจสอบ JWT
const authenticateJWT = jwtMiddleware({
  secret: JWT_TOKEN,
  algorithms: ['HS256'],
  credentialsRequired: true, // จำเป็นต้องมี token เสมอ
}).unless({
  path: ['/api/login', '/api/register'], // สามารถเข้าถึงโดยไม่ต้องใช้ token
});

// ----------------------------- ROUTES -----------------------------

app.post('/api/token', (req, res) => {
  console.log('Authorization header:', req.headers.authorization); // ดูว่าได้ header มาหรือยัง
  res.json({ message: 'Token generated successfully' });
});

// ตรวจสอบ server
app.get('/', (req, res) => {
  res.send('🚀 Server is running!');
});


app.get('/api/user', (req, res) => {
  // แบบง่ายสุด: ตรวจสอบจาก query หรือ header ชั่วคราว
  const query = "SELECT uid, username, email, roles FROM users";
  connection.query(query, (err, results) => {
    if (err) {
      console.error("Error fetching users:", err);
      return res.status(500).json({ error: "Internal Server Error" });
    }
    res.status(200).json(results);
  });
});


// ======================== Admin ========================== //

// 🔐 ดึงรายชื่อผู้ใช้ทั้งหมด (เฉพาะ Admin)
app.get('/api/users', (req, res) => {
  // แบบง่ายสุด: ตรวจสอบจาก query หรือ header ชั่วคราว
  const role = req.query.role || req.headers['x-role']; // หรือส่ง ?role=Admin

  if (role !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }

  const query = "SELECT uid, username, email, roles FROM users";
  connection.query(query, (err, results) => {
    if (err) {
      console.error("Error fetching users:", err);
      return res.status(500).json({ error: "Internal Server Error" });
    }
    res.status(200).json(results);
  });
});


// 🔐 แก้ไขบทบาทผู้ใช้
app.put('/api/users/:id', (req, res) => {
  const { id } = req.params;
  const { roles } = req.body;
  const role = req.query.role || req.headers['x-role'];

  if (role !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }

  if (!roles) {
    return res.status(400).json({ message: "Missing roles in request body" });
  }

  const query = `UPDATE users SET roles = ? WHERE uid = ?`;
  connection.query(query, [roles, id], (err, result) => {
    if (err) {
      console.error("Error updating user role:", err);
      return res.status(500).json({ message: "Internal Server Error" });
    }

    res.status(200).json({ message: "User role updated successfully" });
  });
});



// 🔐 ลบผู้ใช้
app.delete('/api/users/:id', (req, res) => {
  const { id } = req.params;
  const role = req.query.role || req.headers['x-role'];

  if (role !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }

  const query = `DELETE FROM users WHERE uid = ?`;
  connection.query(query, [id], (err, result) => {
    if (err) {
      console.error("Error deleting user:", err);
      return res.status(500).json({ message: "Internal Server Error" });
    }

    res.status(200).json({ message: "User deleted successfully" });
  });
});


//Manage User Get
// app.get('/api/users', (req, res) => {
//   const query = "SELECT id as uid, username, email, roles FROM users";
//   connection.query(query, (err, results) => {
//     if (err) {
//       console.error("Error fetching users:", err);
//       return res.status(500).json({ error: "Internal Server Error" });
//     }
//     res.json(results); // ส่ง list ตรงๆ
//   });
// });

// สมัครสมาชิก Admin
// ✅ REGISTER ROUTE แก้ไขแล้ว:
app.post('/api/registers', async (req, res) => {
  const { username, email, passwords } = req.body;
  const roles = "Admin"; // default role

  // ตรวจสอบว่ามีข้อมูลที่จำเป็นครบถ้วนหรือไม่
  if (!username || !email || !passwords) {
    return res.status(400).json({ success: false, message: "Missing required fields" });
  }

  try {
    // แฮชรหัสผ่าน
    const hashedPassword = await bcrypt.hash(passwords, 10);

    // คำสั่ง SQL สำหรับการเพิ่มผู้ใช้ใหม่
    const query = `INSERT INTO users (username, email, passwords, roles) VALUES (?, ?, ?, ?)`;

    connection.query(query, [username, email, hashedPassword, roles], (err, results) => {
      if (err) {
        console.error("❌ Error inserting user:", err);
        return res.status(500).json({ success: false, message: "Internal Server Error" });
      }

      // ส่ง response กลับเมื่อการสมัครสมาชิกสำเร็จ
      res.status(201).json({
        success: true,
        message: "User registered successfully",
        user: {
          username,
          email,
          roles
        }
      });
    });
  } catch (err) {
    console.error("Error hashing password:", err);s
    res.status(500).json({ success: false, message: "Failed to hash password" });
  }
});

app.post('/api/register', async (req, res) => {
  const { username, email, passwords } = req.body;
  const roles = "User"; // default role

  // ตรวจสอบว่ามีข้อมูลที่จำเป็นครบถ้วนหรือไม่
  if (!username || !email || !passwords) {
    return res.status(400).json({ success: false, message: "Missing required fields" });
  }

  try {
    // แฮชรหัสผ่าน
    const hashedPassword = await bcrypt.hash(passwords, 10);

    // คำสั่ง SQL สำหรับการเพิ่มผู้ใช้ใหม่
    const query = `INSERT INTO users (username, email, passwords, roles) VALUES (?, ?, ?, ?)`;

    connection.query(query, [username, email, hashedPassword, roles], (err, results) => {
      if (err) {
        console.error("❌ Error inserting user:", err);
        return res.status(500).json({ success: false, message: "Internal Server Error" });
      }

      // ส่ง response กลับเมื่อการสมัครสมาชิกสำเร็จ
      res.status(201).json({
        success: true,
        message: "User registered successfully",
        user: {
          username,
          email,
          roles
        }
      });
    });
  } catch (err) {
    console.error("Error hashing password:", err);
    res.status(500).json({ success: false, message: "Failed to hash password" });
  }
});


//==================== login ====================//

// ล็อกอิน + ออก JWT token
app.post('/api/login', (req, res) => {
  const { email, passwords } = req.body;
  if (!email || !passwords) {
    return res.status(400).json({ error: "กรุณากรอกอีเมลและรหัสผ่าน" });
  }

  const sql = `SELECT * FROM users WHERE email = ?`;
  connection.query(sql, [email], async (err, results) => {
    if (err) {
      console.error("Error fetching user:", err);
      return res.status(500).json({ error: "Internal Server Error" });
    }

    if (results.length === 0) {
      return res.status(401).json({ error: "อีเมลหรือรหัสผ่านผิด" });
    }

    const user = results[0];
    const match = await bcrypt.compare(passwords, user.passwords);

    if (!match) {
      return res.status(401).json({ error: "อีเมลหรือรหัสผ่านผิด" });
    }

    const { passwords: _, ...safeUser } = user;
    const token = jwt.sign(
      { uid: user.id, email: user.email, username: user.username, roles: user.roles },
      JWT_TOKEN,
      { expiresIn: '1d' }
    );

    res.status(200).json({ message: "เข้าสู่ระบบสำเร็จ", user: safeUser, token });
  });
});

//================= Log Wi-Fi ========================//

// --- API Wi-Fi Logs ---
// ดึง log พร้อม filter (ต้องใส่ token)
app.get('/api/wifi-logs', (req, res) => {
  const { ssid, startDate, endDate } = req.query;

  let query = "SELECT * FROM wifi_logs WHERE 1=1";
  const params = [];

  if (ssid) {
    query += " AND essid LIKE ?";
    params.push(`%${ssid}%`);
  }
  if (startDate) {
    query += " AND log_time >= ?";
    params.push(startDate);
  }
  if (endDate) {
    query += " AND log_time <= ?";
    params.push(endDate);
  }

  query += " ORDER BY log_time DESC";

  connection.query(query, params, (err, results) => {
    if (err) {
      console.error("Error fetching wifi logs:", err);
      return res.status(500).json({ error: "Internal Server Error" });
    }
    res.json({ msg: "Logs fetched successfully", data: results });
  });
});

// เพิ่ม log ใหม่ (ต้องใส่ token)
app.post('/api/wifi-logs', (req, res) => {
  const { hwid, bssid, essid, signals, chanel, frequency, secue } = req.body;
  if (!hwid || !bssid || !essid || !signals || !chanel || !frequency || !secue) {
    return res.status(400).json({ error: "Missing required fields" });
  }

  const query = `
    INSERT INTO wifi_logs 
    (hwid, bssid, essid, signals, chanel, frequency, secue, log_time)
    VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
  `;
  const params = [hwid, bssid, essid, signals, chanel, frequency, secue];

  connection.query(query, params, (err, results) => {
    if (err) {
      console.error("Error inserting wifi log:", err);
      return res.status(500).json({ error: "Internal Server Error" });
    }
    res.status(201).json({ message: "Log added successfully", insertedId: results.insertId });
  });
});

// ✅ เพิ่มข้อมูลประวัติการโจมตี (history log)
// API สำหรับ Insert ข้อมูลลงใน 'histry'
app.get('/api/histry', (req, res) => {
  const email = req.query.email;

  if (!email) {
    return res.status(400).json({ message: 'Missing email in query' });
  }

  const query = `
    SELECT 
      hid, bssid, essid, date_time, email, uid, classification 
    FROM histry 
    WHERE email = ?
    ORDER BY date_time DESC
  `;

  connection.query(query, [email], (err, results) => {
    if (err) {
      console.error('Error fetching histry logs:', err);
      return res.status(500).json({ message: 'Internal Server Error' });
    }

    res.status(200).json({ logs: results });
  });
});

app.post('/api/histry', (req, res) => {
  const { bssid, essid, email, uid, classification } = req.body;

  if (!bssid || !essid || !email) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const query = `
    INSERT INTO histry (bssid, essid, date_time, email, uid, classification)
    VALUES (?, ?, NOW(), ?, ?, ?)
  `;

  connection.query(query, [bssid, essid, email, uid, classification || ''], (err, results) => {
    if (err) {
      console.error("Error inserting into histry:", err);
      return res.status(500).json({ message: "Internal Server Error" });
    }
    res.status(201).json({ message: "Log saved successfully", id: results.insertId });
  });
});


//============================ Statistic ===========================//

//สถิติการถูกโจมตี
app.get('/api/histry/stats', (req, res) => {
  const { email } = req.query;

  if (!email) {
    return res.status(400).json({ message: "Missing email in query" });
  }

  const query = `
    SELECT 
      classification,
      COUNT(*) AS count,
      MIN(date_time) AS first_attack,
      MAX(date_time) AS last_attack
    FROM histry
    WHERE email = ?
    GROUP BY classification
  `;

  connection.query(query, [email], (err, results) => {
    if (err) {
      console.error("❌ Error fetching stats from histry:", err);
      return res.status(500).json({ message: "Internal Server Error" });
    }

    const stats = {
      rogue: {
        count: 0,
        first_attack: null,
        last_attack: null
      },
      eviltwin: {
        count: 0,
        first_attack: null,
        last_attack: null
      },
      unknown: {
        count: 0,
        first_attack: null,
        last_attack: null
      },
      raw: results // สำหรับ debug (จะลบออกภายหลังก็ได้)
    };

    results.forEach(row => {
      const type = (row.classification || 'unknown').toLowerCase();
      const stat = {
        count: row.count,
        first_attack: row.first_attack,
        last_attack: row.last_attack
      };

      if (type.includes('rogue')) {
        stats.rogue = stat;
      } else if (type.includes('evil twin')) {
        stats.eviltwin = stat;
      } else {
        stats.unknown = stat;
      }
    });

    res.status(200).json({
      message: "Stats with time range fetched successfully",
      stats,
    });
  });
});




// เพิ่มเส้นทางรับข้อมูล Wi‑Fi logs สู่ตาราง service
app.post('/api/service', (req, res) => {
  const { logs } = req.body;

  if (!logs || !Array.isArray(logs) || logs.length === 0) {
    return res.status(400).json({ error: "Missing logs data" });
  }

  const placeholders = logs.map(() => "(?, ?, ?, ?, ?, ?, ?, NOW())").join(", ");
  const query = `
    INSERT INTO access_point_service
      (hwid, bssid, essid, signals, chanel, frequency, secue, log_time)
    VALUES ${placeholders}
  `;

  // ✅ ใช้ flatMap (ไม่ใช่ expand)
  const params = logs.flatMap(log => [
    log.hwid || 0,                     // default เป็น 0 ถ้าไม่มี
    log.bssid || '',
    log.essid || '',
    log.signals || '',
    log.chanel || '',
    log.frequency || '',
    log.secue || '',                 
  ]);

  connection.query(query, params, (err, result) => {
    if (err) {
      console.error("Error inserting service logs:", err);
      return res.status(500).json({ error: "Internal Server Error" });
    }

    res.status(201).json({
      message: "Service logs added successfully",
      insertedCount: logs.length,
    });
  });
});

//hardware get
app.get('/api/access-point', (req, res) => {
  const { bssid } = req.query;
  if (!bssid) {
    return res.status(400).json({ error: "Missing BSSID in query" });
  }

    const query = `
    SELECT
      aps.apid,
      aps.bssid,
      aps.essid,
      aps.signals,
      aps.chanel,
      aps.frequency,
      aps.secue,
      hw.hwid,
      hw.equipment_code,
      hw.equipment_name,
      hw.location,
      hw.ieee_standard
    FROM access_point_service aps
    LEFT JOIN access_point_hw hw ON aps.hwid = hw.hwid
    WHERE aps.bssid = ?
    ORDER BY aps.log_time DESC
    LIMIT 1
  `;


  connection.query(query, [bssid], (err, results) => {
    if (err) {
      console.error("Error fetching access point:", err);
      return res.status(500).json({ error: "Internal Server Error" });
    }
    if (results.length === 0) {
      return res.status(404).json({ error: "No Access Point found for this BSSID" });
    }
    res.json(results[0]);
  });
});

const { getVendor } = require('mac-oui-lookup');

//======================= Rebuild BSSID to Name access ===================//

// API endpoint สำหรับดึง vendor จาก BSSID
app.get('/api/vendor-from-bssid', (req, res) => {
  const { bssid } = req.query;
  if (!bssid) {
    return res.status(400).json({ message: 'Missing bssid query parameter' });
  }
  const vendor = getVendor(bssid) || null;
  res.status(200).json({ vendor });
});

//hardware post
app.post('/api/access-point', (req, res) => {
  const {
    bssid,
    essid,
    signals,
    chanel,
    frequency,
    secue,  
    hwid,
    equipment_code,
    equipment_name,
    location,
    ieee_standard,
  } = req.body;

  if (!bssid) {
    return res.status(400).json({ error: "Missing BSSID in request body" });
  }

  // ขั้นตอนที่ 1: อัพเดตหรือเพิ่มข้อมูลใน access_point_hw (hardware) ก่อน (ถ้ามีข้อมูล hwid หรือข้อมูล hardware)
  const upsertHardware = `
    INSERT INTO access_point_hw (hwid, equipment_code, equipment_name, location, ieee_standard)
    VALUES (?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      equipment_code = VALUES(equipment_code),
      equipment_name = VALUES(equipment_name),
      location = VALUES(location),
      ieee_standard = VALUES(ieee_standard)
  `;

  connection.query(
    upsertHardware,
    [hwid, equipment_code, equipment_name, location, ieee_standard],
    (hwErr) => {
      if (hwErr) {
        console.error("Error upserting hardware:", hwErr);
        return res.status(500).json({ error: "Internal Server Error updating hardware" });
      }

      // ขั้นตอนที่ 2: เพิ่มข้อมูล access_point_service
      const insertAp = `
        INSERT INTO access_point_service
        (bssid, essid, signals, chanel, frequency, secue, hwid, log_time)
        VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
      `;

      connection.query(
        insertAp,
        [bssid, essid, signals, chanel, frequency, secue, hwid],
        (apErr, results) => {
          if (apErr) {
            console.error("Error inserting access point:", apErr);
            return res.status(500).json({ error: "Internal Server Error inserting access point" });
          }
          return res.status(201).json({ message: "Access point inserted successfully" });
        }
      );
    }
  );
});

// ประกาศฟังก์ชัน utility ไว้ด้านบน
function findHardwareByBssid(bssid) {
  return new Promise((resolve, reject) => {
    const query = `
      SELECT hw.*
      FROM access_point_service aps
      JOIN access_point_hw hw ON aps.hwid = hw.hwid
      WHERE aps.bssid = ?
      ORDER BY aps.log_time DESC
      LIMIT 1
    `;
    connection.query(query, [bssid], (err, results) => {
      if (err) {
        console.error("Error finding hardware by bssid:", err);
        return reject(err);
      }
      resolve(results[0] || null);
    });
  });
}


function insertHardware({ equipment_code, equipment_name, location, ieee_standard }) {
  return new Promise((resolve, reject) => {
    const query = `
      INSERT INTO access_point_hw
      (equipment_code, equipment_name, location, ieee_standard)
      VALUES (?, ?, ?, ?)
    `;
    connection.query(query, [equipment_code, equipment_name, location, ieee_standard], (err, result) => {
      if (err) return reject(err);
      resolve({
        hwid: result.insertId,
        equipment_code,
        equipment_name,
        location,
        ieee_standard,
      });
    });
  });
}


function insertServiceLog(log) {
  return new Promise((resolve, reject) => {
    // const query = `
    //   INSERT INTO access_point_service 
    //   (bssid, essid, signals, chanel, frequency, secue, hwid, log_time)
    //   VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    // `;

    const query = `
      INSERT INTO access_point_service 
      (bssid, essid, signals, chanel, frequency, secue, hwid, log_time)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        essid = VALUES(essid),
        signals = VALUES(signals),
        chanel = VALUES(chanel),
        frequency = VALUES(frequency),
        secue = VALUES(secue),
        hwid = VALUES(hwid),
        log_time = VALUES(log_time)
    `;

    connection.query(query, [
      log.bssid,
      log.essid,
      log.signals,
      log.chanel,
      log.frequency,
      log.secue,
      log.hwid,
      log.log_time || new Date(),
    ], (err, result) => {
      if (err) return reject(err);
      resolve(result);
    });
  });
}

// 🔧 Helper function: ตรวจว่า BSSID นี้ใหม่หรือเปล่า
function isNewBssid(bssid) {
  return new Promise((resolve, reject) => {
    const query = `SELECT 1 FROM access_point_service WHERE bssid = ? LIMIT 1`;
    connection.query(query, [bssid], (err, results) => {
      if (err) return reject(err);
      resolve(results.length === 0);
    });
  });
}

// 🔧 Helper function: ตรวจว่า ESSID เคยเจอกับ BSSID อื่นไหม
function hasEssidBeenSeenWithOtherBssid(essid, currentBssid) {
  return new Promise((resolve, reject) => {
    const query = `
      SELECT 1 FROM access_point_service 
      WHERE essid = ? AND bssid != ? 
      LIMIT 1
    `;
    connection.query(query, [essid, currentBssid], (err, results) => {
      if (err) return reject(err);
      resolve(results.length > 0);
    });
  });
}

// 🔧 Helper function: บันทึก log ที่ตรวจพบเป็น Rogue AP
function insertRogueLog({ bssid, essid, email, uid }) {
  return new Promise((resolve, reject) => {
    const query = `
      INSERT INTO histry (bssid, essid, date_time, email, uid, classification)
      VALUES (?, ?, NOW(), ?, ?, 'Suspected Evil Twin')
    `;
    connection.query(query, [bssid, essid, email, uid], (err, result) => {
      if (err) return reject(err);
      resolve(result.insertId);
    });
  });
}
app.post('/api/service-logss', (req, res) => {
  console.log(req.headers.authorization); // ดูว่าได้ header มาหรือยัง
});

// API สำหรับเช็คข้อมูลระหว่าง Access Point Service และ History
app.get('/check-access-point', (req, res) => {
  const { bssid, essid } = req.query;

  const query = `
    SELECT 
        aps.bssid,
        aps.essid,
        aps.signals,
        aps.chanel,
        aps.frequency,
        aps.secue,
        aps.log_time,
        h.date_time AS attack_time,
        h.email,
        h.classification
    FROM 
        AccessPointService aps
    LEFT JOIN 
        Histry h ON aps.bssid = h.bssid
    WHERE 
        aps.bssid = ? AND aps.essid = ? AND h.classification IS NOT NULL
  `;

  db.execute(query, [bssid, essid], (err, results) => {
    if (err) {
      console.error('Error fetching data: ', err);
      return res.status(500).json({ message: 'Error fetching data' });
    }

    if (results.length > 0) {
      // พบข้อมูลการโจมตีที่ตรงกับ BSSID และ ESSID
      return res.status(200).json({ message: 'Evil Twin / Rogue AP detected', data: results });
    } else {
      return res.status(404).json({ message: 'No attacks detected' });
    }
  });
});



// ✅ Main Route: รับ WiFi Logs และตรวจ Evil Twin
app.post('/api/service-logs', async (req, res) => {
  const logs = req.body.logs;

  if (!Array.isArray(logs)) {
    return res.status(400).json({ error: "Logs should be an array" });
  }

  try {
    for (const log of logs) {
      if (!log.bssid || !log.essid || !log.signals) {
        // ป้องกันการบันทึก log ที่ข้อมูลไม่ครบ
        console.warn(`⚠️ Missing required data in log: ${JSON.stringify(log)}`);
        continue;  // ข้าม log นี้
      }

      // 🔎 หา hardware จาก BSSID
      let hw = await findHardwareByBssid(log.bssid);

      if (!hw) {
        hw = await insertHardware({
          bssid: log.bssid,
          essid: log.essid,
          equipment_code: log.assetCode || '',
          equipment_name: log.deviceName || '',
          location: log.location || '',
          ieee_standard: log.standard || '',
        });
      }

      // 🔐 บันทึก service log
      await insertServiceLog({
        bssid: log.bssid,
        essid: log.essid,
        signals: log.signals,
        chanel: log.chanel,
        frequency: log.frequency,
        secue: log.secue,
        hwid: hw.hwid,
        log_time: new Date(),
      });

      // 🛡️ ตรวจจับ Rogue / Evil Twin AP
      const isNew = await isNewBssid(log.bssid);
      const essidSeen = await hasEssidBeenSeenWithOtherBssid(log.essid, log.bssid);

      if (isNew && essidSeen) {
        console.warn(`⚠️ Suspected Evil Twin Detected: ESSID "${log.essid}" กับ BSSID ใหม่ ${log.bssid}`);

        // บันทึกการตรวจจับ Rogue AP
        await insertRogueLog({
          bssid: log.bssid,
          essid: log.essid,
          email: 'unknown',  // เนื่องจากไม่ใช้ Token, ใช้ค่า default เป็น 'unknown'
          uid: null,         // เนื่องจากไม่ใช้ Token, ใช้ค่า default เป็น null
        });
      }
    }

    res.status(201).json({ message: "✅ Logs saved successfully" });
  } catch (err) {
    console.error("❌ Error processing logs:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// ----------------------------- START SERVER -----------------------------
app.listen(port, '0.0.0.0', () => {
  console.log(`🌐 Server is running on port: ${port}`);
});
