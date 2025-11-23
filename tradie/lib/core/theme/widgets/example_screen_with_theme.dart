import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_toggle.dart';

class ExampleScreenWithTheme extends ConsumerWidget {
  const ExampleScreenWithTheme({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Demo'),
        actions: const [
          ThemeToggle(), // Dropdown menu for theme selection
          SizedBox(width: 8),
          ThemeToggleButton(), // Simple toggle button
          SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dark Mode Demo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'This screen demonstrates the dark mode functionality. Use the theme toggle buttons in the app bar to switch between light, dark, and system themes.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sample Card',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This card will automatically adapt to the selected theme.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Button pressed!')),
                );
              },
              child: const Text('Test Button'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Outlined Button'),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: () {}, child: const Text('Text Button')),
            const SizedBox(height: 24),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Sample Input',
                hintText: 'Enter some text',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
