import 'package:flutter/material.dart';

class DemoDetailsPage extends StatelessWidget {
  const DemoDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product details')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).pushNamed('/checkout'),
          child: const Text('Go to checkout'),
        ),
      ),
    );
  }
}
