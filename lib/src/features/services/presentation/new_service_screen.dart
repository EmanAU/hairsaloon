import 'package:flutter/material.dart';

class NewServiceScreen extends StatelessWidget {
  const NewServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Service')),
      body: const Center(child: Text('New service form placeholder')),
    );
  }
}
