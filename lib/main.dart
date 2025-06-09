import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'improved_docker_mongodb_manager.dart';
import 'direct_docker_mongodb_manager.dart';



void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ImprovedDockerMongoDBManager()),
      ],
      child: MaterialApp(
        title: 'MongoDB Docker App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: DirectDockerMongoDBApp(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
