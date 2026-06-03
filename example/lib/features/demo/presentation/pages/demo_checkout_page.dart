import 'package:flutter/material.dart';

class DemoCheckoutPage extends StatelessWidget {
  const DemoCheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: const Center(
        child: Text('Breadcrumbs include this route on errors'),
      ),
    );
  }
}
