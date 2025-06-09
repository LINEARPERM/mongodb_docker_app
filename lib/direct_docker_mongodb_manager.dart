// direct_docker_mongodb_manager.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class DirectDockerMongoDBManager with ChangeNotifier {
  static String? _projectRoot;
  static mongo.Db? _database;
  static bool _isRunning = false;
  static bool _installing = false;
  static String _logData = "";

  bool get isInstalling => _installing;
  String get logData => _logData;

  // หาตำแหน่ง project root
  static Future<String> _getProjectRoot() async {
    if (_projectRoot != null) return _projectRoot!;
    
    // สำหรับ Windows build (.exe) ใช้ path ของ executable
    String currentPath = Directory.current.path;
    
    // ถ้าอยู่ใน build directory ให้ขึ้นไปหา project root
    if (currentPath.contains('build\\windows\\x64\\runner')) {
      // ขึ้นไป 5 ระดับจาก build/windows/x64/runner/Release หรือ Debug
      var projectDir = Directory(currentPath);
      for (int i = 0; i < 5; i++) {
        projectDir = projectDir.parent;
      }
      _projectRoot = projectDir.path;
    } else {
      _projectRoot = currentPath;
    }
    
    print('📁 Project root: $_projectRoot');
    
    final dockerDir = Directory(path.join(_projectRoot!, 'docker'));
    if (!await dockerDir.exists()) {
      await _createDockerFilesFromAssets();
    }
    
    return _projectRoot!;
  }

  // สร้างไฟล์ Docker จาก assets
  static Future<void> _createDockerFilesFromAssets() async {
    try {
      final currentPath = Directory.current.path;
      final dockerDir = Directory(path.join(currentPath, 'docker'));
      
      if (!await dockerDir.exists()) {
        await dockerDir.create(recursive: true);
      }

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

      const initMongoContent = '''
db = db.getSiblingDB('myapp');

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

      final composeFile = File(path.join(dockerDir.path, 'docker-compose.yml'));
      final initFile = File(path.join(dockerDir.path, 'init-mongo.js'));
      
      await composeFile.writeAsString(dockerComposeContent);
      await initFile.writeAsString(initMongoContent);

      print('✅ Docker files created successfully');
    } catch (e) {
      throw Exception('Failed to create Docker files: $e');
    }
  }

  void updateLogData(String data) {
    _logData = data + _logData;
    notifyListeners();
  }

  Future<void> updateInstalling(bool data) async {
    _installing = data;
    notifyListeners();
  }

  static Future<bool> checkDockerInstallation() async {
    try {
      final result = await Process.run('docker', ['--version']);
      if (result.exitCode == 0) {
        final composeResult = await Process.run('docker', ['compose', 'version']);
        return composeResult.exitCode == 0;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // เริ่ม MongoDB container - รัน commands โดยตรง
  Future<bool> startMongoDB(BuildContext context) async {
    await updateInstalling(true);
    
    try {
      final projectRoot = await _getProjectRoot();
      final dockerPath = path.join(projectRoot, 'docker');
      
      updateLogData('🚀 Starting MongoDB from: $dockerPath\n');

      // รัน Docker commands โดยตรงแทนการสร้าง .bat file
      await _runDockerCommands(dockerPath, isStart: true);
      
      return true;
    } catch (e) {
      updateLogData('❌ Error starting MongoDB: $e\n');
      await updateInstalling(false);
      return false;
    }
  }

  // รัน Docker commands โดยตรง
  Future<void> _runDockerCommands(String dockerPath, {required bool isStart}) async {
    try {
      // ตรวจสอบว่า docker directory มีอยู่จริง
      final dockerDir = Directory(dockerPath);
      if (!await dockerDir.exists()) {
        updateLogData('❌ Docker directory not found: $dockerPath\n');
        await updateInstalling(false);
        return;
      }

      updateLogData('📁 Using docker directory: $dockerPath\n');

      if (isStart) {
        updateLogData('📥 Pulling MongoDB image...\n');
        
        // Pull image
        var pullProcess = await Process.start(
          'docker',
          ['compose', 'pull'],
          workingDirectory: dockerPath,
        );
        
        await _listenToProcess(pullProcess, 'Pull');

        updateLogData('🚀 Starting containers...\n');
        
        // Start containers
        var startProcess = await Process.start(
          'docker',
          ['compose', 'up', '-d'],
          workingDirectory: dockerPath,
        );
        
        await _listenToProcess(startProcess, 'Start');
        
        // Check status
        await Future.delayed(Duration(seconds: 3));
        var statusProcess = await Process.start(
          'docker',
          ['compose', 'ps'],
          workingDirectory: dockerPath,
        );
        
        await _listenToProcess(statusProcess, 'Status');
        
        await _finishStartup();
        
      } else {
        updateLogData('🛑 Stopping MongoDB...\n');
        
        // Stop containers
        var stopProcess = await Process.start(
          'docker',
          ['compose', 'down'],
          workingDirectory: dockerPath,
        );
        
        await _listenToProcess(stopProcess, 'Stop');
        
        _isRunning = false;
        updateLogData('✅ MongoDB stopped\n');
        await updateInstalling(false);
      }
      
    } catch (e) {
      updateLogData('❌ Docker command failed: $e\n');
      await updateInstalling(false);
    }
  }

  // ฟัง output จาก process
  Future<void> _listenToProcess(Process process, String operation) async {
    // Listen to stdout
    process.stdout.transform(utf8.decoder).listen((data) {
      updateLogData('[$operation] $data');
    });

    // Listen to stderr
    process.stderr.transform(utf8.decoder).listen((data) {
      updateLogData('[$operation Error] $data');
    });

    // Wait for completion
    var exitCode = await process.exitCode;
    updateLogData('[$operation] Completed with exit code: $exitCode\n');
  }

  // หยุด MongoDB
  Future<bool> stopMongoDB(BuildContext context) async {
    await updateInstalling(true);
    
    try {
      final projectRoot = await _getProjectRoot();
      final dockerPath = path.join(projectRoot, 'docker');

      await _database?.close();
      _database = null;

      await _runDockerCommands(dockerPath, isStart: false);
      
      return true;
    } catch (e) {
      updateLogData('❌ Error stopping MongoDB: $e\n');
      await updateInstalling(false);
      return false;
    }
  }

  // เสร็จสิ้นการ startup
  Future<void> _finishStartup() async {
    try {
      await _waitForMongoDB();
      _isRunning = true;
      updateLogData('✅ MongoDB is ready!\n');
    } catch (e) {
      updateLogData('❌ MongoDB failed to start: $e\n');
    }
    
    await updateInstalling(false);
  }

  // รอให้ MongoDB พร้อม
  static Future<void> _waitForMongoDB() async {
    for (int i = 0; i < 30; i++) {
      try {
        final db = mongo.Db('mongodb://appuser:apppass123@localhost:27018/myapp');
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

      // ตรวจสอบว่า docker directory มีอยู่จริง
      final dockerDir = Directory(dockerPath);
      if (!await dockerDir.exists()) {
        print('❌ Docker directory not found: $dockerPath');
        return false;
      }

      final result = await Process.run(
        'docker', 
        ['compose', 'ps', '--services', '--filter', 'status=running'],
        workingDirectory: dockerPath,
      );

      return result.stdout.toString().contains('mongodb');
    } catch (e) {
      print('❌ Error checking Docker status: $e');
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

  static bool get dbRunning => _isRunning;
}

// User Repository
class UserRepository {
  static Future<mongo.DbCollection> _getCollection() async {
    final db = await DirectDockerMongoDBManager.getDatabase();
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
class DirectDockerMongoDBApp extends StatefulWidget {
  @override
  _DirectDockerMongoDBAppState createState() => _DirectDockerMongoDBAppState();
}

class _DirectDockerMongoDBAppState extends State<DirectDockerMongoDBApp> {
  bool _dockerInstalled = false;
  bool _mongoRunning = false;
  List<Map<String, dynamic>> _users = [];
  
  late DirectDockerMongoDBManager _manager;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _manager = DirectDockerMongoDBManager();
    _checkDocker();
  }

  Future<void> _checkDocker() async {
    final installed = await DirectDockerMongoDBManager.checkDockerInstallation();
    setState(() => _dockerInstalled = installed);

    if (installed) {
      await _checkMongoStatus();
    }
  }

  Future<void> _checkMongoStatus() async {
    final running = await DirectDockerMongoDBManager.isRunning();
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
      _manager.updateLogData('📄 Loaded ${users.length} users\n');
    } catch (e) {
      _manager.updateLogData('❌ Failed to load users: $e\n');
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
      _manager.updateLogData('❌ Failed to add user: $e\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Direct MongoDB Docker App'),
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
                          Text('Docker MongoDB Status', 
                               style: TextStyle(fontWeight: FontWeight.bold)),
                          if (_manager.isInstalling) ...[
                            SizedBox(width: 16),
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Processing...'),
                          ],
                        ],
                      ),
                      Text(_dockerInstalled ? 'Docker is installed' : 'Docker not found'),
                      if (_dockerInstalled) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _mongoRunning ? Icons.play_circle : Icons.pause_circle,
                              color: _mongoRunning ? Colors.green : Colors.orange,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _mongoRunning ? 'MongoDB running on :27018' : 'MongoDB stopped',
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
                              SnackBar(content: Text('Please install Docker Desktop first')),
                            );
                          },
                          icon: Icon(Icons.download),
                          label: Text('Install Docker'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _manager.isInstalling ? null : (_mongoRunning ? _stopMongo : _startMongo),
                          icon: Icon(_mongoRunning ? Icons.stop : Icons.play_arrow),
                          label: Text(_mongoRunning ? 'Stop MongoDB' : 'Start MongoDB'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mongoRunning ? Colors.red : Colors.green,
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
              if (_mongoRunning && !_manager.isInstalling) ...[
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
                                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                reverse: true,
                                child: Text(
                                  _manager.logData.isEmpty ? 'No logs yet...' : _manager.logData,
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
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}