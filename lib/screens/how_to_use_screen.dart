import 'package:flutter/material.dart';

class HowToUseScreen extends StatefulWidget {
  const HowToUseScreen({super.key});

  @override
  State<HowToUseScreen> createState() => _HowToUseScreenState();
}

class _HowToUseScreenState extends State<HowToUseScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  // Step index (0-based)
  int _currentStep = 0;

  // Define steps metadata
  late final List<_HowToStep> _steps = [
    _HowToStep(
      id: 'getting_started',
      title: 'Getting Started',
      subtitle: 'Permissions & storage access',
    ),
    _HowToStep(
      id: 'home_navigation',
      title: 'Home & Navigation',
      subtitle: 'Main screen and menu',
    ),
    _HowToStep(
      id: 'select_files',
      title: 'Selecting Files',
      subtitle: 'Choosing what to wipe',
    ),
    _HowToStep(
      id: 'wiping_flow',
      title: 'Wiping Files',
      subtitle: 'Confirm and destroy data',
    ),
    _HowToStep(
      id: 'delete_or_keep',
      title: 'Delete or Keep',
      subtitle: 'What happens after wiping',
    ),
    _HowToStep(
      id: 'cert_immediate',
      title: 'Certificates (Immediate)',
      subtitle: 'Auto-generated when deleting now',
    ),
    _HowToStep(
      id: 'undeleted_delayed',
      title: 'Undeleted Files & Delayed Certificates',
      subtitle: 'Delete later with proof',
    ),
    _HowToStep(
      id: 'cert_management',
      title: 'Certificates & PDF',
      subtitle: 'View, share & securely delete',
    ),
    _HowToStep(
      id: 'cache_notice',
      title: 'Important Notice',
      subtitle: 'Gallery/Photos cache behavior',
    ),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // scroll to tob code below
  void _scrollToTop() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToStep(int index) {
    if (index < 0 || index >= _steps.length) return;
    setState(() {
      _currentStep = index;
    });
    _scrollToTop();
    Navigator.of(context).maybePop(); // close drawer if open
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _scrollToTop();
    } else {
      // Last step → go back to home
      Navigator.pop(context);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _scrollToTop();
    } else {
      // First step → back to home
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final totalSteps = _steps.length;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildGuideDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Home',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('How to Use'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Guide Sections',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Step ${_currentStep + 1} of $totalSteps',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

            // Title & subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (step.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      step.subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildStepContent(step.id),
              ),
            ),

            // Navigation buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(
                        _currentStep == 0 ? 'Back to Home' : 'Previous',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nextStep,
                      icon: Icon(
                        _currentStep == totalSteps - 1
                            ? Icons.check
                            : Icons.arrow_forward,
                      ),
                      label: Text(
                        _currentStep == totalSteps - 1 ? 'Finish' : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Drawer for guide steps
  // ─────────────────────────────────────────────────────────────

  Widget _buildGuideDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.menu_book, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'How to Use ZeroTrace',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quick guide to wiping data & certificates',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                final isCurrent = index == _currentStep;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                  title: Text(
                    step.title,
                    style: TextStyle(
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: step.subtitle != null
                      ? Text(
                          step.subtitle!,
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                  onTap: () => _goToStep(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Step content builder
  // ─────────────────────────────────────────────────────────────

  Widget _buildStepContent(String stepId) {
    switch (stepId) {
      case 'getting_started':
        return _buildGettingStartedContent();
      case 'home_navigation':
        return _buildHomeNavigationContent();
      case 'select_files':
        return _buildSelectFilesContent();
      case 'wiping_flow':
        return _buildWipingFlowContent();
      case 'delete_or_keep':
        return _buildDeleteOrKeepContent();
      case 'cert_immediate':
        return _buildCertImmediateContent();
      case 'undeleted_delayed':
        return _buildUndeletedDelayedContent();
      case 'cert_management':
        return _buildCertManagementContent();
      case 'cache_notice':
        return _buildCacheNoticeContent();
      default:
        return const SizedBox.shrink();
    }
  }
  // Below: Each section's textual guide.
  // You can later drop in Image.asset(...) widgets where comments indicate.

  Widget _buildGettingStartedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guideImage('assets/howto/ss_storage_access.jpg'),
        const SizedBox(height: 12),
        const Text(
          '1. Grant Storage Access',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'When you open ZeroTrace for the first time, you will see a '
          '“Storage Access Required” screen. This is necessary so the app can '
          'read and overwrite files on your device for secure wiping.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Tap the button to grant storage permission. On Android 11+ you may '
          'be taken to a system settings screen called “Allow access to manage all files”. '
          'Find “ZeroTrace” in that list and enable the toggle.',
        ),
        const SizedBox(height: 16),
        const Text(
          'If you ever deny permission, you can manually enable it later via:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _bullet('Open phone Settings'),
        _bullet('Apps / App Management → ZeroTrace'),
        _bullet('Permissions → Files and media / Storage'),
        _bullet('Allow access to manage all files'),
      ],
    );
  }

  Widget _buildCacheNoticeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '9. Important Notice – Gallery/Photos Cache',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'ZeroTrace securely wipes file contents and, if you choose, deletes the '
          'wiped files and their certificates. However, some gallery or Photos apps '
          'may still show old thumbnails of images that have been wiped. This is '
          'because those apps keep their own cached thumbnails.',
        ),
        const SizedBox(height: 12),
        const Text(
          'ZeroTrace cannot directly clear another app’s private cache due to Android security. '
          'If you still see old images in your gallery after wiping them:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _bullet('Open your phone’s Settings.'),
        _bullet('Go to Apps / App Management.'),
        _bullet(
          'Find your Gallery app (e.g. “Gallery”, “Google Photos”, etc.).',
        ),
        _bullet('Tap “Storage & cache” → “Clear cache”.'),
        const SizedBox(height: 8),
        const Text(
          'This only removes cached thumbnails inside the gallery app. '
          'Your original file data was already destroyed by ZeroTrace and cannot be recovered.',
        ),
      ],
    );
  }

  Widget _buildHomeNavigationContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guideImage('assets/howto/ss_home_screen.jpg'),
        const SizedBox(height: 12),
        const Text(
          '2. Home Screen & Navigation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'The home screen is where you choose the wipe method and select files.',
        ),
        const SizedBox(height: 12),
        _bullet(
          'Use the radio buttons to choose a wipe method:\n'
          '  • Quick Zero (1 pass)\n'
          '  • Standard Random (3 passes)\n'
          '  • DoD (7 passes)',
        ),
        const SizedBox(height: 8),
        _bullet('Tap “Browse & Select Files” to open the file browser.'),
        const SizedBox(height: 16),
        _guideImage('assets/howto/ss_drawer_menu.jpg'),
        const SizedBox(height: 12),
        const Text(
          'Hamburger Menu (Sidebar)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap the ☰ icon on the top-left to open the sidebar. From here you can access:',
        ),
        const SizedBox(height: 8),
        _bullet('Certificates – history of all generated certificates.'),
        _bullet('Undeleted Files – files that were wiped but not deleted.'),
        _bullet('How to Use – this guide.'),
      ],
    );
  }

  Widget _buildSelectFilesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guideImage('assets/howto/ss_select_files.jpg'),
        const SizedBox(height: 12),
        const Text(
          '3. Selecting Files to Wipe',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'After tapping “Browse & Select Files”, you will see a file browser. '
          'Navigate through folders like DCIM, Pictures, Download, Documents, etc. '
          'Tap on files to select them.',
        ),
        const SizedBox(height: 12),
        _bullet(
          'Selected files are listed on the home screen with their size.',
        ),
        _bullet('You can remove a file from the selection using the × icon.'),
        const SizedBox(height: 12),
        _guideImage('assets/howto/ss_files_selected.jpg'),
        const SizedBox(height: 12),
        const Text(
          'Once you have selected one or more files, a confirmation '
          'button will appear at the bottom.',
        ),
      ],
    );
  }

  Widget _buildWipingFlowContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guideImage('assets/howto/ss_confirm_wipe.jpg'),
        const SizedBox(height: 12),
        const Text(
          '4. Confirming & Destroying Data',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'When you tap the red “Wipe” button, ZeroTrace shows a confirmation dialog. '
          'This warns you that the action is permanent and unrecoverable.',
        ),
        const SizedBox(height: 12),
        _bullet(
          'Review the number of files, selected wipe method, and passes.',
        ),
        _bullet('If you are sure, tap “WIPE DATA” to begin.'),
        const SizedBox(height: 16),
        _guideImage('assets/howto/ss_destroying_data.jpg'),
        const SizedBox(height: 12),
        const Text(
          'Destroying Data',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'ZeroTrace overwrites each file multiple times. During this process you’ll see:',
        ),
        const SizedBox(height: 8),
        _bullet('Overall progress percentage'),
        _bullet('Current pass (e.g. Pass 2/3)'),
        _bullet('Which file is being wiped'),
      ],
    );
  }

  Widget _buildDeleteOrKeepContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guideImage('assets/howto/ss_data_destroyed.jpg'),
        const SizedBox(height: 12),
        const Text(
          '5. After Wipe: Delete or Keep',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'When wiping finishes, ZeroTrace confirms that the data has been destroyed. '
          'The original content is now unrecoverable.',
        ),
        const SizedBox(height: 12),
        _guideImage('assets/howto/ss_delete_or_keep.jpg'),
        const SizedBox(height: 12),
        const Text('You then choose what to do with the wiped files:'),
        const SizedBox(height: 8),
        _bullet(
          'Delete – removes the corrupted file from storage and generates a certificate.',
        ),
        _bullet(
          'Keep – keeps the corrupted file on disk (for verification or later deletion).',
        ),
        const SizedBox(height: 12),
        const Text(
          'Files that you keep (wiped but not deleted) will appear in the “Undeleted Files” section.',
        ),
      ],
    );
  }

  Widget _buildCertImmediateContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guideImage('assets/howto/ss_certificate_generated.jpg'),
        const SizedBox(height: 12),
        const Text(
          '6. Certificates – Immediate Deletion',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'If you choose to DELETE files right after wiping, ZeroTrace automatically '
          'generates a destruction certificate.',
        ),
        const SizedBox(height: 12),
        _bullet('The certificate includes:'),
        _indented('• Certificate ID'),
        _indented('• Wipe method and passes'),
        _indented('• Files destroyed and their sizes'),
        _indented('• Total data destroyed'),
        _indented('• SHA-256 digital signature'),
        const SizedBox(height: 12),
        _guideImage('assets/howto/ss_certificates_tab.jpg'),
        const SizedBox(height: 12),
        const Text(
          'These certificates are saved locally and listed under the “Certificates” tab '
          'in the sidebar. You can:',
        ),
        const SizedBox(height: 8),
        _bullet('Open a certificate and view its details.'),
        _bullet('Open the PDF version.'),
        _bullet('Share the certificate via any app (email, WhatsApp, etc.).'),
      ],
    );
  }

  Widget _buildUndeletedDelayedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guideImage('assets/howto/ss_undeleted_files.jpg'),
        const SizedBox(height: 12),
        const Text(
          '7. Undeleted Files & Delayed Certificates',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'If you chose to KEEP files after wiping, they appear in the “Undeleted Files” section '
          'of the sidebar. These files are already corrupted (data destroyed) but still take space.',
        ),
        const SizedBox(height: 12),
        _bullet('From the Undeleted Files screen you can:'),
        _indented('• Select one or more wiped files.'),
        _indented('• Delete them later.'),
        _indented('• Generate a certificate at deletion time.'),
        const SizedBox(height: 12),
        const Text('The delayed certificate records both:'),
        const SizedBox(height: 8),
        _bullet('When the data was wiped.'),
        _bullet(
          'When the file was actually deleted and certificate generated.',
        ),
        const SizedBox(height: 8),
        const Text(
          'It also shows the time difference (e.g. “2 minutes 51 seconds”) between wiping and deletion.',
        ),
      ],
    );
  }

  Widget _buildCertManagementContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guideImage('assets/howto/ss_delayed_delete.jpg'),
        const SizedBox(height: 12),
        const Text(
          '8. Managing Certificates & PDFs',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'In the Certificates section (from the sidebar), you can see a history of all '
          'data destruction certificates created by ZeroTrace.',
        ),
        const SizedBox(height: 12),
        _bullet('Tap any certificate in the list to open its details.'),
        _bullet(
          'Details include certificate ID, files destroyed, data size, '
          'and for delayed certificates: wiped time, deleted time, and the time difference.',
        ),
        const SizedBox(height: 12),
        _guideImage('assets/howto/ss_certificate_pdf.jpg'),
        const SizedBox(height: 12),
        const Text(
          'Opening the Certificate PDF',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'From the certificate details, you can open the PDF version. This PDF can be: ',
        ),
        const SizedBox(height: 8),
        _bullet('Viewed in any PDF viewer on your phone.'),
        _bullet('Shared over email, messaging apps, or cloud storage.'),
        const SizedBox(height: 16),
        const Text(
          'Securely Deleting Certificates',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'If you delete a certificate from the app, ZeroTrace overwrites the underlying PDF '
          'and JSON files with random data (triple-pass wiping) before removing them. '
          'This ensures the certificate itself cannot be recovered later.',
        ),
        const SizedBox(height: 8),
        _bullet(
          'When you tap “Delete” on a certificate, a confirmation dialog explains '
          'that it will be securely wiped before deletion.',
        ),
        _bullet(
          'Only confirm if you are sure you no longer need that proof of destruction.',
        ),
      ],
    );
  }
  // ─────────────────────────────────────────────────────────────
  // Small helper widgets
  // ─────────────────────────────────────────────────────────────

  static Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 13)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  static Widget _indented(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('– ', style: TextStyle(fontSize: 12)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _guideImage(String assetPath) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.black54, // thin border
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7.5),
        child: Image.asset(assetPath),
      ),
    );
  }
}

class _HowToStep {
  final String id;
  final String title;
  final String? subtitle;

  _HowToStep({required this.id, required this.title, this.subtitle});
}
