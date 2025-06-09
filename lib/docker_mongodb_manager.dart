import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class DockerMongoDBManager {
  static String? _projectRoot;
  static mongo.Db? _database;
  static bool _isRunning = false;

  // หาตำแหน่ง project root
  static Future<String> _getProjectRoot() async {
    if (_projectRoot != null) return _projectRoot!;

    // เริ่มจาก current directory
    String currentPath = Directory.current.path;

    // ถ้าอยู่ใน build directory (เมื่อรันจาก exe) ต้องขึ้นไปหา project root
    if (currentPath.contains('build\\windows\\x64\\runner\\Release') ||
        currentPath.contains('build/windows/x64/runner/Release')) {
      // ย้ายไป project root (5 levels up)
      final projectRoot =
          Directory(currentPath).parent.parent.parent.parent.parent.path;
      currentPath = projectRoot;
    }

    _projectRoot = currentPath;

    // ตรวจสอบว่ามีโฟลเดอร์ docker หรือไม่ ถ้าไม่มีให้สร้าง
    final dockerDir = Directory(path.join(_projectRoot!, 'docker'));
    if (!await dockerDir.exists()) {
      print('Creating docker directory at: ${dockerDir.path}');
      await dockerDir.create(recursive: true);
      await _createDockerFiles();
    }

    return _projectRoot!;
  }

  // สร้างไฟล์ Docker configuration
  static Future<void> _createDockerFiles() async {
    final dockerDir = Directory(path.join(_projectRoot!, 'docker'));

    // สร้าง docker-compose.yml
    const dockerComposeContent =
        '''version: '3.8'
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

    // สร้าง init-mongo.js
    const initMongoContent =
        '''db = db.getSiblingDB('myapp');

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

db.users.insertMany([
  {
    name: 'John Doe',
    email: 'john@example.com',
    age: 30,
    createdAt: new Date()
  },
  {
    name: 'Jane Smith',
    email: 'jane@example.com',
    age: 25,
    createdAt: new Date()
  },
  {
    name: 'Bob Johnson',
    email: 'bob@example.com',
    age: 35,
    createdAt: new Date()
  },
  {
    name: 'Alice Wilson',
    email: 'alice@example.com',
    age: 28,
    createdAt: new Date()
  },
  {
    name: 'Charlie Brown',
    email: 'charlie@example.com',
    age: 32,
    createdAt: new Date()
  }
]);
''';

    // บันทึกไฟล์
    final composeFile = File(path.join(dockerDir.path, 'docker-compose.yml'));
    final initFile = File(path.join(dockerDir.path, 'init-mongo.js'));

    await composeFile.writeAsString(dockerComposeContent);
    await initFile.writeAsString(initMongoContent);

    print('✅ Docker files created successfully');
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

  // เริ่ม MongoDB container
  static Future<bool> startMongoDB() async {
    try {
      final projectRoot = await _getProjectRoot();
      final dockerPath = path.join(projectRoot, 'docker');

      print('🚀 Starting MongoDB from: $dockerPath');

      // Pull image ก่อน
      await Process.run('docker', ['compose', 'pull'],
          workingDirectory: dockerPath);

      // Start container
      final result = await Process.run(
        'docker',
        ['compose', 'up', '-d'],
        workingDirectory: dockerPath,
      );

      if (result.exitCode == 0) {
        print('✅ MongoDB container started');
        _isRunning = true;

        // รอให้ MongoDB พร้อม
        await _waitForMongoDB();
        return true;
      } else {
        print('❌ Failed to start MongoDB: ${result.stderr}');
        return false;
      }
    } catch (e) {
      print('❌ Error starting MongoDB: $e');
      return false;
    }
  }

  // รอให้ MongoDB พร้อม
  static Future<void> _waitForMongoDB() async {
    print('⏳ Waiting for MongoDB to be ready...');

    for (int i = 0; i < 30; i++) {
      try {
        final db =
            mongo.Db('mongodb://appuser:apppass123@localhost:27018/myapp');
        await db.open();
        await db.close();
        print('✅ MongoDB is ready!');
        return;
      } catch (e) {
        print('⏳ Attempt ${i + 1}/30...');
        await Future.delayed(Duration(seconds: 2));
      }
    }

    throw Exception('MongoDB failed to start within timeout');
  }

  // หยุด MongoDB
  static Future<bool> stopMongoDB() async {
    try {
      final projectRoot = await _getProjectRoot();
      final dockerPath = path.join(projectRoot, 'docker');

      await _database?.close();
      _database = null;

      final result = await Process.run(
        'docker',
        ['compose', 'down'],
        workingDirectory: dockerPath,
      );

      if (result.exitCode == 0) {
        _isRunning = false;
        print('✅ MongoDB stopped');
        return true;
      } else {
        print('❌ Failed to stop MongoDB: ${result.stderr}');
        return false;
      }
    } catch (e) {
      print('❌ Error stopping MongoDB: $e');
      return false;
    }
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

  static bool get mongoContainerRunning => _isRunning;
}

// User Repository
class UserRepository {
  static Future<mongo.DbCollection> _getCollection() async {
    final db = await DockerMongoDBManager.getDatabase();
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

// Main Widget
class DockerMongoDBPage extends StatefulWidget {
  @override
  _DockerMongoDBPageState createState() => _DockerMongoDBPageState();
}

class _DockerMongoDBPageState extends State<DockerMongoDBPage> {
  bool _dockerInstalled = false;
  bool _mongoRunning = false;
  bool _isLoading = false;
  List<String> _logs = [];
  List<Map<String, dynamic>> _users = [];

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkDocker();
  }

  Future<void> _checkDocker() async {
    setState(() => _isLoading = true);
    _addLog('🔍 Checking Docker...');

    final installed = await DockerMongoDBManager.checkDockerInstallation();
    setState(() => _dockerInstalled = installed);

    if (installed) {
      _addLog('✅ Docker is installed');
      await _checkMongoStatus();
    } else {
      _addLog('❌ Docker not found');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _checkMongoStatus() async {
    final running = await DockerMongoDBManager.isRunning();
    setState(() => _mongoRunning = running);

    if (running) {
      _addLog('✅ MongoDB is running');
      await _loadUsers();
    } else {
      _addLog('⏸️ MongoDB is stopped');
    }
  }

  Future<void> _startMongo() async {
    setState(() => _isLoading = true);
    _addLog('🚀 Starting MongoDB...');

    try {
      final success = await DockerMongoDBManager.startMongoDB();
      if (success) {
        setState(() => _mongoRunning = true);
        _addLog('✅ MongoDB started!');
        await _loadUsers();
      } else {
        _addLog('❌ Failed to start MongoDB');
      }
    } catch (e) {
      _addLog('❌ Error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _stopMongo() async {
    setState(() => _isLoading = true);
    _addLog('🛑 Stopping MongoDB...');

    final success = await DockerMongoDBManager.stopMongoDB();
    if (success) {
      setState(() {
        _mongoRunning = false;
        _users.clear();
      });
      _addLog('✅ MongoDB stopped');
    } else {
      _addLog('❌ Failed to stop MongoDB');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadUsers() async {
    if (!_mongoRunning) return;

    try {
      final users = await UserRepository.getAllUsers();
      setState(() => _users = users);
      _addLog('📄 Loaded ${users.length} users');
    } catch (e) {
      _addLog('❌ Failed to load users: $e');
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
      _addLog('✅ User added');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ User added successfully!')),
      );
    } catch (e) {
      _addLog('❌ Failed to add user: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(
          0, '${DateTime.now().toString().substring(11, 19)} - $message');
      if (_logs.length > 20) _logs.removeLast();
    });
    print(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MongoDB Docker App'),
        backgroundColor: _mongoRunning ? Colors.green : Colors.orange,
      ),
      body: Column(
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
                        _dockerInstalled ? Icons.check_circle : Icons.error,
                        color: _dockerInstalled ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text('Docker Status',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                          color: _mongoRunning ? Colors.green : Colors.orange,
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
                        // Open Docker download page
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Please install Docker Desktop first')),
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
                      onPressed: _isLoading
                          ? null
                          : (_mongoRunning ? _stopMongo : _startMongo),
                      icon: _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_mongoRunning ? Icons.stop : Icons.play_arrow),
                      label: Text(
                          _mongoRunning ? 'Stop MongoDB' : 'Start MongoDB'),
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
          if (_mongoRunning) ...[
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
                        Text('Logs',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              final log = _logs[index];
                              Color color = Colors.white70;
                              if (log.contains('❌'))
                                color = Colors.red[300]!;
                              else if (log.contains('✅'))
                                color = Colors.green[300]!;
                              else if (log.contains('🚀'))
                                color = Colors.blue[300]!;

                              return Text(
                                log,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontFamily: 'monospace'),
                              );
                            },
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
