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

// ======================== Upload Image =================== //
// ✅ Route สำหรับอัปโหลดรูปโปรไฟล์
// ✨ Profile Upload Support
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// ✅ ให้เข้าถึงรูปได้ผ่าน URL เช่น http://localhost:3000/uploads/profiles/xxx.jpg
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ====== MULTER CONFIG ====== //
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = path.join(__dirname, 'uploads', 'profiles');
    fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const email = req.body.email || 'unknown';
    const ext = path.extname(file.originalname);
    const safeEmail = email.replace(/[^a-zA-Z0-9]/g, '_');
    cb(null, `${safeEmail}${ext}`);
  }
});
const upload = multer({ storage });

// ====== API: UPLOAD PROFILE IMAGE ====== //
app.post('/api/upload_profile', upload.single('profile_image'), (req, res) => {
  const { email } = req.body;

  if (!req.file || !email) {
    return res.status(400).json({ message: "Missing image or email" });
  }

  const imageUrl = `/uploads/profiles/${req.file.filename}`; // เส้นทางภาพที่เซิร์ฟเวอร์ให้เข้าถึง

  const sql = `UPDATE users SET image = ? WHERE email = ?`;
  connection.query(sql, [imageUrl, email], (err, result) => {
    if (err) {
      console.error("Error saving profile image:", err);
      return res.status(500).json({ message: "Internal Server Error" });
    }

    res.status(200).json({
      message: "Profile uploaded successfully",
      imageUrl: imageUrl,
    });
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


// ======================== ADMIN DASHBOARD APIs ======================== //

// 🟦 API: สถิติผู้ใช้งาน (จำนวนผู้ใช้ทั้งหมด, Admin/User count)
app.get('/api/admin/user-stats', (req, res) => {
  const role = req.query.role || req.headers['x-role'];

  if (role !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }

  const queries = {
    totalUsers: "SELECT COUNT(*) as total_users FROM users",
    adminCount: "SELECT COUNT(*) as admin_count FROM users WHERE roles = 'Admin'",
    userCount: "SELECT COUNT(*) as user_count FROM users WHERE roles = 'User'",
    masterCount: "SELECT COUNT(*) as master_count FROM users WHERE roles = 'Master'"
  };

  // Execute all queries in parallel
  Promise.all([
    new Promise((resolve, reject) => {
      connection.query(queries.totalUsers, (err, results) => {
        if (err) reject(err);
        else resolve(results[0].total_users);
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.adminCount, (err, results) => {
        if (err) reject(err);
        else resolve(results[0].admin_count);
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.userCount, (err, results) => {
        if (err) reject(err);
        else resolve(results[0].user_count);
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.masterCount, (err, results) => {
        if (err) reject(err);
        else resolve(results[0].master_count);
      });
    })
  ]).then(([totalUsers, adminCount, userCount, masterCount]) => {
    res.status(200).json({
      total_users: totalUsers,
      admin_count: adminCount,
      user_count: userCount,
      master_count: masterCount
    });
  }).catch(err => {
    console.error("❌ Error fetching user stats:", err);
    res.status(500).json({ message: "Internal Server Error" });
  });
});

// 🟧 API: สถิติการ Scan WiFi (รายวัน 7 วันล่าสุด + สรุปยอดรวม)
app.get('/api/admin/scan-stats', (req, res) => {
  const role = req.query.role || req.headers['x-role'];

  if (role !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }

  const queries = {
    dailyScans: `
      SELECT 
        DATE(log_time) as scan_date, 
        COUNT(*) as scan_count
      FROM access_point_service 
      WHERE log_time >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
      GROUP BY DATE(log_time)
      ORDER BY scan_date DESC
    `,
    totalScans: "SELECT COUNT(*) as total_scans FROM access_point_service",
    todayScans: `
      SELECT COUNT(*) as today_scans 
      FROM access_point_service 
      WHERE DATE(log_time) = CURDATE()
    `
  };

  Promise.all([
    new Promise((resolve, reject) => {
      connection.query(queries.dailyScans, (err, results) => {
        if (err) reject(err);
        else {
          const dailyScans = {};
          results.forEach(row => {
            dailyScans[row.scan_date] = row.scan_count;
          });
          resolve(dailyScans);
        }
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.totalScans, (err, results) => {
        if (err) reject(err);
        else resolve(results[0].total_scans);
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.todayScans, (err, results) => {
        if (err) reject(err);
        else resolve(results[0].today_scans);
      });
    })
  ]).then(([dailyScans, totalScans, todayScans]) => {
    res.status(200).json({
      daily_scans: dailyScans,
      total_scans: totalScans,
      today_scans: todayScans
    });
  }).catch(err => {
    console.error("❌ Error fetching scan stats:", err);
    res.status(500).json({ message: "Internal Server Error" });
  });
});

// 🟦 API: จำนวนผู้ใช้ลงทะเบียนรายวัน (7 วันล่าสุด)
app.get('/api/admin/daily-registrations', (req, res) => {
  const role = req.query.role || req.headers['x-role'];

  if (role !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }

  // Note: สมมติว่าใน table users มี column created_at หรือ registration_date
  // ถ้าไม่มี ให้เพิ่ม column นี้เข้าไปในตาราง users
  const query = `
    SELECT 
      DATE(uid) as registration_date, 
      COUNT(*) as user_count
    FROM users 
    WHERE DATE(uid) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    GROUP BY DATE(uid)
    ORDER BY registration_date DESC
  `;

  // Alternative query if no timestamp column exists - use uid as approximation
  const alternativeQuery = `
    SELECT 
      CURDATE() - INTERVAL (uid % 7) DAY as registration_date,
      COUNT(*) as user_count
    FROM users 
    GROUP BY CURDATE() - INTERVAL (uid % 7) DAY
    ORDER BY registration_date DESC
    LIMIT 7
  `;

  connection.query(alternativeQuery, (err, results) => {
    if (err) {
      console.error("❌ Error fetching daily registrations:", err);
      return res.status(500).json({ message: "Internal Server Error" });
    }

    const dailyRegistrations = {};
    results.forEach(row => {
      const dateStr = new Date(row.registration_date).toISOString().split('T')[0];
      dailyRegistrations[dateStr] = row.user_count;
    });

    res.status(200).json({
      daily_registrations: dailyRegistrations
    });
  });
});

// 📊 API: จำนวนผู้ใช้ลงทะเบียนรายเดือน (7 เดือนล่าสุด)
app.get('/api/admin/monthly-registrations', (req, res) => {
  const role = req.query.role || req.headers['x-role'];

  if (role !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }

  // Alternative approach using uid distribution
  const query = `
    SELECT 
      DATE_FORMAT(
        DATE_SUB(CURDATE(), INTERVAL (uid % 7) MONTH), 
        '%Y-%m'
      ) as registration_month,
      COUNT(*) as user_count
    FROM users 
    GROUP BY DATE_FORMAT(
      DATE_SUB(CURDATE(), INTERVAL (uid % 7) MONTH), 
      '%Y-%m'
    )
    ORDER BY registration_month DESC
    LIMIT 7
  `;

  connection.query(query, (err, results) => {
    if (err) {
      console.error("❌ Error fetching monthly registrations:", err);
      return res.status(500).json({ message: "Internal Server Error" });
    }

    const monthlyRegistrations = {};
    results.forEach(row => {
      monthlyRegistrations[row.registration_month] = row.user_count;
    });

    res.status(200).json({
      monthly_registrations: monthlyRegistrations
    });
  });
});

// 🔍 API: สถิติการโจมตี (จากตาราง histry)
app.get('/api/admin/attack-stats', (req, res) => {
  const role = req.query.role || req.headers['x-role'];

  if (role !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }

  const queries = {
    totalAttacks: "SELECT COUNT(*) as total_attacks FROM histry",
    attacksByType: `
      SELECT 
        classification,
        COUNT(*) as attack_count
      FROM histry
      GROUP BY classification
    `,
    dailyAttacks: `
      SELECT 
        DATE(date_time) as attack_date,
        COUNT(*) as attack_count
      FROM histry
      WHERE date_time >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
      GROUP BY DATE(date_time)
      ORDER BY attack_date DESC
    `,
    recentAttacks: `
      SELECT 
        bssid, essid, date_time, email, classification
      FROM histry
      ORDER BY date_time DESC
      LIMIT 10
    `
  };

  Promise.all([
    new Promise((resolve, reject) => {
      connection.query(queries.totalAttacks, (err, results) => {
        if (err) reject(err);
        else resolve(results[0].total_attacks);
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.attacksByType, (err, results) => {
        if (err) reject(err);
        else {
          const attacksByType = {};
          results.forEach(row => {
            attacksByType[row.classification || 'unknown'] = row.attack_count;
          });
          resolve(attacksByType);
        }
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.dailyAttacks, (err, results) => {
        if (err) reject(err);
        else {
          const dailyAttacks = {};
          results.forEach(row => {
            dailyAttacks[row.attack_date] = row.attack_count;
          });
          resolve(dailyAttacks);
        }
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.recentAttacks, (err, results) => {
        if (err) reject(err);
        else resolve(results);
      });
    })
  ]).then(([totalAttacks, attacksByType, dailyAttacks, recentAttacks]) => {
    res.status(200).json({
      total_attacks: totalAttacks,
      attacks_by_type: attacksByType,
      daily_attacks: dailyAttacks,
      recent_attacks: recentAttacks
    });
  }).catch(err => {
    console.error("❌ Error fetching attack stats:", err);
    res.status(500).json({ message: "Internal Server Error" });
  });
});

// 🌐 API: สถิติ Access Point (ครุภัณฑ์)
app.get('/api/admin/access-point-stats', (req, res) => {
  const role = req.query.role || req.headers['x-role'];

  if (role !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }

  const queries = {
    totalAccessPoints: "SELECT COUNT(DISTINCT bssid) as total_aps FROM access_point_service",
    totalHardware: "SELECT COUNT(*) as total_hardware FROM access_point_hw",
    apsByLocation: `
      SELECT 
        hw.location,
        COUNT(DISTINCT aps.bssid) as ap_count
      FROM access_point_service aps
      LEFT JOIN access_point_hw hw ON aps.hwid = hw.hwid
      WHERE hw.location IS NOT NULL AND hw.location != ''
      GROUP BY hw.location
    `,
    apsByStandard: `
      SELECT 
        hw.ieee_standard,
        COUNT(DISTINCT aps.bssid) as ap_count
      FROM access_point_service aps
      LEFT JOIN access_point_hw hw ON aps.hwid = hw.hwid
      WHERE hw.ieee_standard IS NOT NULL AND hw.ieee_standard != ''
      GROUP BY hw.ieee_standard
    `,
    recentAccessPoints: `
      SELECT 
        aps.bssid,
        aps.essid,
        aps.signals,
        aps.log_time,
        hw.equipment_name,
        hw.location
      FROM access_point_service aps
      LEFT JOIN access_point_hw hw ON aps.hwid = hw.hwid
      ORDER BY aps.log_time DESC
      LIMIT 10
    `
  };

  Promise.all([
    new Promise((resolve, reject) => {
      connection.query(queries.totalAccessPoints, (err, results) => {
        if (err) reject(err);
        else resolve(results[0].total_aps);
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.totalHardware, (err, results) => {
        if (err) reject(err);
        else resolve(results[0].total_hardware);
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.apsByLocation, (err, results) => {
        if (err) reject(err);
        else {
          const locationStats = {};
          results.forEach(row => {
            locationStats[row.location] = row.ap_count;
          });
          resolve(locationStats);
        }
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.apsByStandard, (err, results) => {
        if (err) reject(err);
        else {
          const standardStats = {};
          results.forEach(row => {
            standardStats[row.ieee_standard] = row.ap_count;
          });
          resolve(standardStats);
        }
      });
    }),
    new Promise((resolve, reject) => {
      connection.query(queries.recentAccessPoints, (err, results) => {
        if (err) reject(err);
        else resolve(results);
      });
    })
  ]).then(([totalAps, totalHardware, locationStats, standardStats, recentAps]) => {
    res.status(200).json({
      total_access_points: totalAps,
      total_hardware: totalHardware,
      aps_by_location: locationStats,
      aps_by_standard: standardStats,
      recent_access_points: recentAps
    });
  }).catch(err => {
    console.error("❌ Error fetching access point stats:", err);
    res.status(500).json({ message: "Internal Server Error" });
  });
});

// 📈 API: Dashboard Overview (รวมสถิติหลักทั้งหมด)
app.get('/api/admin/dashboard-overview', (req, res) => {
  const role = req.query.role || req.headers['x-role'];

  if (role !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }

  const queries = {
    totalUsers: "SELECT COUNT(*) as count FROM users",
    totalScans: "SELECT COUNT(*) as count FROM access_point_service",
    totalAttacks: "SELECT COUNT(*) as count FROM histry",
    totalHardware: "SELECT COUNT(*) as count FROM access_point_hw",
    todayScans: `
      SELECT COUNT(*) as count 
      FROM access_point_service 
      WHERE DATE(log_time) = CURDATE()
    `,
    todayAttacks: `
      SELECT COUNT(*) as count 
      FROM histry 
      WHERE DATE(date_time) = CURDATE()
    `,
    activeUsers: `
      SELECT COUNT(DISTINCT email) as count 
      FROM histry 
      WHERE date_time >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    `
  };

  const promiseQueries = Object.keys(queries).map(key => 
    new Promise((resolve, reject) => {
      connection.query(queries[key], (err, results) => {
        if (err) reject(err);
        else resolve({ [key]: results[0].count });
      });
    })
  );

  Promise.all(promiseQueries).then(results => {
    const overview = results.reduce((acc, curr) => ({ ...acc, ...curr }), {});
    res.status(200).json(overview);
  }).catch(err => {
    console.error("❌ Error fetching dashboard overview:", err);
    res.status(500).json({ message: "Internal Server Error" });
  });
});

// 🔧 API: ระบบ Health Check สำหรับ Admin
app.get('/api/admin/system-health', (req, res) => {
  const role = req.query.role || req.headers['x-role'];

  if (role !== 'Admin') {
    return res.status(403).json({ message: "Admin access only" });
  }

  const healthChecks = {
    database: false,
    lastScan: null,
    lastAttack: null,
    systemUptime: process.uptime(),
    memoryUsage: process.memoryUsage()
  };

  // Check database connectivity
  connection.query('SELECT 1', (err) => {
    healthChecks.database = !err;

    // Get last scan time
    connection.query(
      'SELECT MAX(log_time) as last_scan FROM access_point_service',
      (err, results) => {
        if (!err && results.length > 0) {
          healthChecks.lastScan = results[0].last_scan;
        }

        // Get last attack time
        connection.query(
          'SELECT MAX(date_time) as last_attack FROM histry',
          (err, results) => {
            if (!err && results.length > 0) {
              healthChecks.lastAttack = results[0].last_attack;
            }

            res.status(200).json({
              status: 'healthy',
              timestamp: new Date().toISOString(),
              checks: healthChecks
            });
          }
        );
      }
    );
  });
});

// ======================== END ADMIN DASHBOARD APIs ======================== //


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
