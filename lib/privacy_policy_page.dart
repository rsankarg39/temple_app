import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Temple Book Privacy Policy',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last updated: July 26, 2026',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This Privacy Policy explains how Temple Book collects, uses, and protects the personal information you provide when using our mobile application.',
              ),
              const SizedBox(height: 16),
              _PolicySection(
                title: '1. Information We Collect',
                body:
                    'We may collect information such as your name, email address, phone number, temple selection, profile details, and authentication information when you register or use the app. We also collect data needed to maintain your account and provide the app features.',
              ),
              _PolicySection(
                title: '2. How We Use Your Information',
                body:
                    'Your information is used to create and manage your account, authenticate you securely, provide temple-related features, communicate important updates, and improve app functionality and user experience.',
              ),
              _PolicySection(
                title: '3. Data Storage and Security',
                body:
                    'We use secure cloud services to store account and app data. We take reasonable technical and organizational measures to protect your information, although no method of transmission or electronic storage is completely secure.',
              ),
              _PolicySection(
                title: '4. Sharing of Information',
                body:
                    'We do not sell your personal data. We may share limited information with service providers that help us operate the app, such as hosting, authentication, or analytics platforms, only as necessary to provide the service.',
              ),
              _PolicySection(
                title: '5. Your Choices',
                body:
                    'You may access, update, or delete your account information by using the in-app account settings or by contacting us. You may also choose not to provide certain information, although this may limit some features of the app.',
              ),
              _PolicySection(
                title: '6. Children\'s Privacy',
                body:
                    'Temple Book is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13.',
              ),
              _PolicySection(
                title: '7. Changes to This Policy',
                body:
                    'We may update this Privacy Policy from time to time. Any changes will be posted in the app and reflected by the updated date above.',
              ),
              _PolicySection(
                title: '8. Contact Us',
                body:
                    'If you have any questions or concerns about this Privacy Policy or our data practices, please contact us at support@templebook.app.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(
                      'mailto:support@templebook.app?subject=Temple%20Book%20Privacy%20Policy',
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Unable to open email client.'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Contact Developer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
