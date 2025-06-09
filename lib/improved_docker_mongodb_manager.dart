// improved_docker_mongodb_manager.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:provider/provider.dart';

class ImprovedDockerMongoDBManager with ChangeNotifier {
  static String? _projectRoot;
  static mongo.Db? _database;
  static bool _isRunning = false;
  static bool _installing = false;
  static String _logData = "";

  // เหมือน control.dart
  bool get isInstalling => _installing;
  String get logData => _logData;

  // หาตำแหน่ง project root
  static Future<String> _getProjectRoot() async {
    if (_projectRoot != null) return _projectRoot!;

    // ใช้ current directory
    _projectRoot = Directory.current.path;

    // ตรวจสอบว่ามีโฟลเดอร์ docker หรือไม่
    final dockerDir = Directory(path.join(_projectRoot!, 'docker'));
    if (!await dockerDir.exists()) {
      // ถ้าไม่มี ให้สร้างไฟล์ Docker จาก assets
      await _createDockerFilesFromAssets();
    }

    return _projectRoot!;
  }

  // สร้างไฟล์ Docker จาก assets (เหมือน control.dart)
  static Future<void> _createDockerFilesFromAssets() async {
    try {
      final currentPath = Directory.current.path;
      final dockerDir = Directory(path.join(currentPath, 'docker'));

      if (!await dockerDir.exists()) {
        await dockerDir.create(recursive: true);
      }

      // สร้างไฟล์ docker-compose.yml
      const dockerComposeContent = '''
version: '3.8'
services:
  mongodb:
    image: mongo:7.0-jammy
    container_name: flutter_mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: admin123
      MONGO_INITDB_DATABASE: myapp
    ports:
      - "27018:27017"
    volumes:
      - mongodb_data:/data/db
      - ./init-mongo.js:/docker-entrypoint-initdb.d/init-mongo.js:ro
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  mongodb_data:
    driver: local
''';

      // สร้างไฟล์ init-mongo.js
      const initMongoContent = '''
// สร้าง database และ user สำหรับ app
db = db.getSiblingDB('myapp');

// สร้าง user สำหรับ application
db.createUser({
  user: 'appuser',
  pwd: 'apppass123',
  roles: [
    {
      role: 'readWrite',
      db: 'myapp'
    }
  ]
});

// สร้างข้อมูลตัวอย่าง
db.users.insertMany([
  {
    name: 'John Doe',
    email: 'john@example.com',
    age: 25,
    city: 'Bangkok',
    createdAt: new Date()
  },
  {
    name: 'Jane Smith', 
    email: 'jane@example.com',
    age: 30,
    city: 'Chiang Mai',
    createdAt: new Date()
  }
]);

print('✅ Database initialized with sample data');
''';

      // บันทึกไฟล์
      final composeFile = File(path.join(dockerDir.path, 'docker-compose.yml'));
      final initFile = File(path.join(dockerDir.path, 'init-mongo.js'));

      await composeFile.writeAsString(dockerComposeContent);
      await initFile.writeAsString(initMongoContent);

      print('✅ Docker files created successfully');
    } catch (e) {
      throw Exception('Failed to create Docker files: $e');
    }
  }

  // อัพเดท log (เหมือน control.dart)
  void updateLogData(String data) {
    _logData = data + _logData;
    notifyListeners();
  }

  // อัพเดท installing state
  Future<void> updateInstalling(bool data) async {
    _installing = data;
    notifyListeners();
  }

  // ตรวจสอบ Docker installation
  static Future<bool> checkDockerInstallation() async {
    try {
      final result = await Process.run('docker', ['--version']);
      if (result.exitCode == 0) {
        final composeResult =
            await Process.run('docker', ['compose', 'version']);
        return composeResult.exitCode == 0;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // เริ่ม MongoDB container (ปรับปรุงแบบ control.dart)
  Future<bool> startMongoDB(BuildContext context) async {
    await updateInstalling(true);

    try {
      final projectRoot = await _getProjectRoot();
      final dockerPath = path.join(projectRoot, 'docker');

      updateLogData('🚀 Starting MongoDB from: $dockerPath\n');

      // สร้าง batch script เหมือน control.dart
      await _createAndRunDockerStartScript(context, dockerPath);

      return true;
    } catch (e) {
      updateLogData('❌ Error starting MongoDB: $e\n');
      await updateInstalling(false);
      return false;
    }
  }

  // สร้างและรัน Docker start script (เหมือน control.dart)
  Future<void> _createAndRunDockerStartScript(
      BuildContext context, String dockerPath) async {
    try {
      // สร้าง batch script สำหรับ start Docker
      const batContent = '''
@echo off
echo Starting MongoDB Docker container...

REM Pull MongoDB image
docker compose pull

REM Start container
docker compose up -d

REM Check if container is running
timeout /t 5 >nul
docker compose ps

echo MongoDB startup completed successfully
''';

      String currentPath = Directory.current.path;
      final batFile = File('$currentPath/start_mongodb.bat');

      await batFile.writeAsString(batContent);

      // รัน batch script เหมือน control.dart
      await _runBatScript(context, batFile.path, dockerPath);
    } catch (e) {
      updateLogData('❌ Failed to create start script: $e\n');
      await updateInstalling(false);
    }
  }

  // รัน batch script (copy จาก control.dart)
  Future<void> _runBatScript(
      BuildContext context, String scriptPath, String workingDirectory) async {
    try {
      // Start the process with working directory
      var process = await Process.start(
        'cmd',
        ['/c', scriptPath],
        workingDirectory: workingDirectory,
      );

      // Listen to stdout
      process.stdout.transform(utf8.decoder).listen((data) {
        print('Docker output: $data');
        updateLogData(data);
      });

      // Listen to stderr
      process.stderr.transform(utf8.decoder).listen((data) {
        print('Docker error: $data');
        updateLogData(data);

        if (data.contains("MongoDB startup completed successfully")) {
          _finishStartup();
        }
      });

      // Wait for process to finish
      var exitCode = await process.exitCode;
      print('Docker script finished with exit code: $exitCode');

      // รอแล้วตรวจสอบสถานะ
      await Future.delayed(Duration(seconds: 3));
      await _finishStartup();
    } catch (e) {
      print('Failed to run Docker script: $e');
      updateLogData('❌ Failed to run script: $e\n');
      await updateInstalling(false);
    }
  }

  // เสร็จสิ้นการ startup
  Future<void> _finishStartup() async {
    try {
      // ตรวจสอบว่า MongoDB ทำงานหรือไม่
      await _waitForMongoDB();
      _isRunning = true;
      updateLogData('✅ MongoDB is ready!\n');
    } catch (e) {
      updateLogData('❌ MongoDB failed to start: $e\n');
    }

    await updateInstalling(false);
  }

  // หยุด MongoDB (ปรับปรุงแบบ control.dart)
  Future<bool> stopMongoDB(BuildContext context) async {
    await updateInstalling(true);

    try {
      final projectRoot = await _getProjectRoot();
      final dockerPath = path.join(projectRoot, 'docker');

      await _database?.close();
      _database = null;

      updateLogData('🛑 Stopping MongoDB...\n');

      // สร้าง batch script สำหรับ stop
      await _createAndRunDockerStopScript(context, dockerPath);

      return true;
    } catch (e) {
      updateLogData('❌ Error stopping MongoDB: $e\n');
      await updateInstalling(false);
      return false;
    }
  }

  // สร้างและรัน Docker stop script
  Future<void> _createAndRunDockerStopScript(
      BuildContext context, String dockerPath) async {
    try {
      const batContent = '''
@echo off
echo Stopping MongoDB Docker container...

REM Stop and remove containers
docker compose down

echo MongoDB stopped successfully
''';

      String currentPath = Directory.current.path;
      final batFile = File('$currentPath/stop_mongodb.bat');

      await batFile.writeAsString(batContent);

      // รัน batch script
      await _runStopBatScript(context, batFile.path, dockerPath);
    } catch (e) {
      updateLogData('❌ Failed to create stop script: $e\n');
      await updateInstalling(false);
    }
  }

  // รัน stop batch script
  Future<void> _runStopBatScript(
      BuildContext context, String scriptPath, String workingDirectory) async {
    try {
      var process = await Process.start(
        'cmd',
        ['/c', scriptPath],
        workingDirectory: workingDirectory,
      );

      process.stdout.transform(utf8.decoder).listen((data) {
        print('Docker stop output: $data');
        updateLogData(data);
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        print('Docker stop error: $data');
        updateLogData(data);
      });

      var exitCode = await process.exitCode;
      print('Docker stop script finished with exit code: $exitCode');

      _isRunning = false;
      updateLogData('✅ MongoDB stopped\n');
      await updateInstalling(false);
    } catch (e) {
      print('Failed to run Docker stop script: $e');
      updateLogData('❌ Failed to stop: $e\n');
      await updateInstalling(false);
    }
  }

  // รอให้ MongoDB พร้อม
  static Future<void> _waitForMongoDB() async {
    for (int i = 0; i < 30; i++) {
      try {
        final db =
            mongo.Db('mongodb://appuser:apppass123@localhost:27018/myapp');
        await db.open();
        await db.close();
        return;
      } catch (e) {
        print('Waiting for MongoDB... (${i + 1}/30)');
        await Future.delayed(Duration(seconds: 2));
      }
    }

    throw Exception('MongoDB failed to start within timeout');
  }

  // ตรวจสอบสถานะ
  static Future<bool> isRunning() async {
    try {
      final projectRoot = await _getProjectRoot();
      final dockerPath = path.join(projectRoot, 'docker');

      final result = await Process.run(
        'docker',
        ['compose', 'ps', '--services', '--filter', 'status=running'],
        workingDirectory: dockerPath,
      );

      return result.stdout.toString().contains('mongodb');
    } catch (e) {
      return false;
    }
  }

  // เชื่อมต่อ database
  static Future<mongo.Db> getDatabase() async {
    if (_database != null && _database!.isConnected) {
      return _database!;
    }

    _database = mongo.Db('mongodb://appuser:apppass123@localhost:27018/myapp');
    await _database!.open();
    return _database!;
  }

  // ตรวจสอบ network connection (จาก control.dart)
  Future<bool> checkInternetConnection(String ipAddress) async {
    try {
      final result = await Process.run(
        'ping',
        ['-n', '1', ipAddress], // Windows ใช้ -n แทน -c
        runInShell: true,
      );

      if (result.exitCode == 0) {
        print('✅ IP $ipAddress is reachable');
        return true;
      } else {
        print('❌ IP $ipAddress is not reachable');
      }
    } catch (e) {
      print('❗ Ping failed: $e');
    }
    return false;
  }

  static bool get containerRunning => _isRunning;
}

// User Repository (เหมือนเดิม)
class UserRepository {
  static Future<mongo.DbCollection> _getCollection() async {
    final db = await ImprovedDockerMongoDBManager.getDatabase();
    return db.collection('users');
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final collection = await _getCollection();
    final users = await collection.find().toList();
    return users.map((user) => user as Map<String, dynamic>).toList();
  }

  static Future<mongo.ObjectId> addUser(Map<String, dynamic> userData) async {
    final collection = await _getCollection();
    userData['createdAt'] = DateTime.now();
    final result = await collection.insertOne(userData);
    return result.id;
  }
}

// Main Widget (ปรับปรุงให้ใช้ Provider pattern เหมือน control.dart)
class ImprovedDockerMongoDBApp extends StatefulWidget {
  @override
  _ImprovedDockerMongoDBAppState createState() =>
      _ImprovedDockerMongoDBAppState();
}

class _ImprovedDockerMongoDBAppState extends State<ImprovedDockerMongoDBApp> {
  bool _dockerInstalled = false;
  bool _mongoRunning = false;
  List<Map<String, dynamic>> _users = [];

  late ImprovedDockerMongoDBManager _manager;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _manager = ImprovedDockerMongoDBManager();
    _checkDocker();
  }

  Future<void> _checkDocker() async {
    final installed =
        await ImprovedDockerMongoDBManager.checkDockerInstallation();
    setState(() => _dockerInstalled = installed);

    if (installed) {
      await _checkMongoStatus();
    }
  }

  Future<void> _checkMongoStatus() async {
    final running = await ImprovedDockerMongoDBManager.isRunning();
    setState(() => _mongoRunning = running);

    if (running) {
      await _loadUsers();
    }
  }

  Future<void> _startMongo() async {
    final success = await _manager.startMongoDB(context);
    if (success) {
      setState(() => _mongoRunning = true);
      await _loadUsers();
    }
  }

  Future<void> _stopMongo() async {
    final success = await _manager.stopMongoDB(context);
    if (success) {
      setState(() {
        _mongoRunning = false;
        _users.clear();
      });
    }
  }

  Future<void> _loadUsers() async {
    if (!_mongoRunning) return;

    try {
      final users = await UserRepository.getAllUsers();
      setState(() => _users = users);
    } catch (e) {
      print('Failed to load users: $e');
    }
  }

  Future<void> _addUser() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) return;

    try {
      await UserRepository.addUser({
        'name': _nameController.text,
        'email': _emailController.text,
        'city': 'Bangkok',
      });

      _nameController.clear();
      _emailController.clear();
      await _loadUsers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ User added successfully!')),
      );
    } catch (e) {
      print('Failed to add user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _manager,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Improved MongoDB Docker App'),
          backgroundColor: _mongoRunning ? Colors.green : Colors.orange,
        ),
        body: Consumer<ImprovedDockerMongoDBManager>(
          builder: (context, manager, child) {
            return Column(
              children: [
                // Status Card
                Card(
                  margin: EdgeInsets.all(16),
                  color: _dockerInstalled
                      ? (_mongoRunning ? Colors.green[50] : Colors.orange[50])
                      : Colors.red[50],
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _dockerInstalled
                                  ? Icons.check_circle
                                  : Icons.error,
                              color:
                                  _dockerInstalled ? Colors.green : Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text('Docker MongoDB Status',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            if (manager.isInstalling) ...[
                              SizedBox(width: 16),
                              SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Processing...'),
                            ],
                          ],
                        ),
                        Text(_dockerInstalled
                            ? 'Docker is installed'
                            : 'Docker not found'),
                        if (_dockerInstalled) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _mongoRunning
                                    ? Icons.play_circle
                                    : Icons.pause_circle,
                                color: _mongoRunning
                                    ? Colors.green
                                    : Colors.orange,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                _mongoRunning
                                    ? 'MongoDB running on :27018'
                                    : 'MongoDB stopped',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Controls
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (!_dockerInstalled) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Please install Docker Desktop first')),
                              );
                            },
                            icon: Icon(Icons.download),
                            label: Text('Install Docker'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: manager.isInstalling
                                ? null
                                : (_mongoRunning ? _stopMongo : _startMongo),
                            icon: Icon(
                                _mongoRunning ? Icons.stop : Icons.play_arrow),
                            label: Text(_mongoRunning
                                ? 'Stop MongoDB'
                                : 'Start MongoDB'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _mongoRunning ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _checkMongoStatus,
                          child: Text('Refresh'),
                        ),
                      ],
                    ],
                  ),
                ),

                // Add User Form
                if (_mongoRunning && !manager.isInstalling) ...[
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _addUser,
                          child: Text('Add User'),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 16),

                // Content
                Expanded(
                  child: Row(
                    children: [
                      // Users
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Text('Users (${_users.length})',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: _users.isEmpty
                                  ? Center(child: Text('No users'))
                                  : ListView.builder(
                                      itemCount: _users.length,
                                      itemBuilder: (context, index) {
                                        final user = _users[index];
                                        return Card(
                                          margin: EdgeInsets.all(4),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              child: Text(user['name'][0]),
                                            ),
                                            title: Text(user['name']),
                                            subtitle: Text(user['email']),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),

                      // Logs
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.all(8),
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('System Logs',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    manager.logData.isEmpty
                                        ? 'No logs yet...'
                                        : manager.logData,
                                    style: TextStyle(
                                      color: Colors.green[300],
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
