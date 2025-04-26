import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        elevation: 0,
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final packageInfo = snapshot.data!;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // App logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'lib/assets/images/logo.png',
                        scale: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // App name
                    Text(
                      packageInfo.appName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Version
                    Text(
                      'Version ${packageInfo.version} (${packageInfo.buildNumber})',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // App description
                    const Text(
                      'BomaTrack is a property management application designed to help landlords and property managers efficiently manage their properties, tenants, and payments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 40),
                    // Additional information
                    ListTile(
                      leading: const Icon(Icons.business),
                      title: const Text('Company'),
                      subtitle: const Text('BomaTrack Inc.'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('Contact'),
                      subtitle: const Text('support@bomatrack.com'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.web),
                      title: const Text('Website'),
                      subtitle: const Text('www.bomatrack.com'),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.policy),
                      title: const Text('Privacy Policy'),
                      onTap: () {
                        // Add navigation to privacy policy
                      },
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () {
                        showLicensePage(
                          context: context,
                          applicationName: 'BomaTrack',
                          applicationVersion: '1.0.0', // Your app version
                          applicationIcon: Image.asset('assets/app_icon.png', height: 48, width: 48),
                          applicationLegalese: '© 2023 Your Company Name',
                        );
                      },
                      child: const Text('Open Source Licenses'),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      '© ${DateTime.now().year} BomaTrack Inc. All rights reserved.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return const Center(child: Text('No app information available'));
          }
        },
      ),
    );
  }
}