import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'engines.dart';
import 'extra_screens.dart';
import 'image_screens.dart';
import 'text_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StylishTextMakerApp());
}

class StylishTextMakerApp extends StatefulWidget {
  const StylishTextMakerApp({super.key});

  @override
  State<StylishTextMakerApp> createState() => _StylishTextMakerAppState();
}

class _StylishTextMakerAppState extends State<StylishTextMakerApp> {
  final AppController _app = AppController();

  @override
  void initState() {
    super.initState();
    _app.loadPrefs();
  }

  @override
  void dispose() {
    _app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _app,
      builder: (context, _) {
        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          themeMode: _app.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: _app.seedColor,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: _app.seedColor,
              brightness: Brightness.dark,
            ),
          ),
          home: MainShellScreen(app: _app),
        );
      },
    );
  }
}

class MainShellScreen extends StatelessWidget {
  final AppController app;
  const MainShellScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final pages = [
          DashboardHomeTab(app: app),
          StylishTextScreen(app: app),
          SavedAndHistoryTab(app: app),
          SettingsTab(app: app),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              kAppName,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                tooltip: app.isDarkMode ? 'Light Mode' : 'Dark Mode',
                icon: Icon(app.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => app.toggleDarkMode(!app.isDarkMode),
              ),
            ],
          ),
          body: IndexedStack(index: app.currentTab, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: app.currentTab,
            onDestinationSelected: app.setTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.text_fields_outlined),
                selectedIcon: Icon(Icons.text_fields),
                label: 'Stylish',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmarks_outlined),
                selectedIcon: Icon(Icons.bookmarks),
                label: 'Saved',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: 'Themes',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// TAB 0: PRO DASHBOARD HOME (WITH FIXED DARK-MODE BANNER)
// ============================================================================

class DashboardHomeTab extends StatelessWidget {
  final AppController app;
  const DashboardHomeTab({super.key, required this.app});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bannerStart = app.seedColor;
    final bannerEnd = Color.lerp(app.seedColor, const Color(0xFF0F172A), 0.58)!;

    final tools = [
      _ToolCardData(
        title: 'Stylish Text',
        subtitle: '৩০+ ইউনিক ফন্ট স্টাইল',
        icon: Icons.text_fields,
        color: cs.primary,
        onTap: () => app.setTab(1),
      ),
      _ToolCardData(
        title: 'Nickname Studio',
        subtitle: 'গেমিং ও প্রোফাইল নাম',
        icon: Icons.sports_esports_outlined,
        color: Colors.deepOrange,
        onTap: () => _open(context, NicknameStudioScreen(app: app)),
      ),
      _ToolCardData(
        title: 'Symbols & Bio',
        subtitle: 'সিম্বল ও রেডিমেড বায়ো',
        icon: Icons.auto_awesome,
        color: Colors.pink,
        onTap: () => _open(context, SymbolsAndBioScreen(app: app)),
      ),
      _ToolCardData(
        title: 'Repeater & Glitch',
        subtitle: 'রিপিটার, গ্লিচ ও ব্ল্যাংক মেসেজ',
        icon: Icons.bolt,
        color: Colors.teal,
        onTap: () => _open(context, TextToolsScreen(app: app)),
      ),
      _ToolCardData(
        title: 'Emoji Text Art',
        subtitle: 'ইমোজি দিয়ে বড় নাম ও আর্ট',
        icon: Icons.emoji_emotions_outlined,
        color: Colors.amber.shade800,
        onTap: () => _open(context, EmojiArtScreen(app: app)),
      ),
      _ToolCardData(
        title: 'Study Summary',
        subtitle: 'প্যারাগ্রাফ সামারি (বাংলা/Eng)',
        icon: Icons.summarize_outlined,
        color: Colors.blue.shade700,
        onTap: () => _open(context, ParagraphSummaryScreen(app: app)),
      ),
      _ToolCardData(
        title: 'Image to Text',
        subtitle: 'ছবি থেকে লেখা স্ক্যান',
        icon: Icons.document_scanner_outlined,
        color: Colors.indigo,
        onTap: () => _open(context, ImageToTextScreen(app: app)),
      ),
      _ToolCardData(
        title: 'Smart Resize',
        subtitle: 'রিসাইজ, রোটেট ও KB কমপ্রেস',
        icon: Icons.photo_size_select_large,
        color: Colors.green.shade700,
        onTap: () => _open(context, const ImageResizeScreen()),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bannerStart, bannerEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: bannerStart.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✨ All-in-One Creative Studio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'স্টাইলিশ ফন্ট, ইমোজি আর্ট, স্টাডি সামারি, সিম্বল ও স্মার্ট ইমেজ রিসাইজার এখন এক জায়গায়!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: bannerEnd,
                  ),
                  onPressed: () => app.setTab(1),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text(
                    'Start Typing Stylish Text',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Pro Tools',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tools.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.18,
            ),
            itemBuilder: (context, i) {
              final t = tools[i];
              return Card(
                elevation: 0.6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: t.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: t.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(t.icon, color: t.color, size: 26),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (app.history.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Copies',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => app.setTab(2),
                  child: const Text('See All'),
                ),
              ],
            ),
            ...app.history.take(3).map(
                  (h) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(h, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () => copyAndRecord(context, app, h),
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _ToolCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ToolCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

// ============================================================================
// TAB 2: SAVED FAVORITES & COPY HISTORY
// ============================================================================

class SavedAndHistoryTab extends StatefulWidget {
  final AppController app;
  const SavedAndHistoryTab({super.key, required this.app});

  @override
  State<SavedAndHistoryTab> createState() => _SavedAndHistoryTabState();
}

class _SavedAndHistoryTabState extends State<SavedAndHistoryTab> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final items = _segment == 0 ? widget.app.favorites : widget.app.history;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      icon: const Icon(Icons.favorite_outline),
                      label: Text('Favorites (${widget.app.favorites.length})'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: const Icon(Icons.history),
                      label: Text('History (${widget.app.history.length})'),
                    ),
                  ],
                  selected: {_segment},
                  onSelectionChanged: (s) => setState(() => _segment = s.first),
                ),
              ),
              if (_segment == 1 && widget.app.history.isNotEmpty)
                IconButton(
                  tooltip: 'Clear History',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: widget.app.clearHistory,
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    _segment == 0
                        ? 'এখনো কোনো স্টাইল ❤️ দিয়ে সেভ করা হয়নি।'
                        : 'সম্প্রতি কপি করা কোনো লেখা নেই।',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, idx) {
                    final txt = items[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(txt, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () => copyAndRecord(context, widget.app, txt),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share_outlined, size: 20),
                              onPressed: () => shareText(txt),
                            ),
                            if (_segment == 0)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () => widget.app.toggleFavorite(txt),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 3: PRO THEMES, PRIVACY & SETTINGS
// ============================================================================

class SettingsTab extends StatelessWidget {
  final AppController app;
  const SettingsTab({super.key, required this.app});

  Future<void> _openWebsite(BuildContext context) async {
    if (kWebsiteUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ওয়েবসাইট লিংক খুব শীঘ্রই যুক্ত করা হবে!')),
      );
      return;
    }
    final uri = Uri.parse(kWebsiteUrl.trim());
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('লিংক ওপেন করা যায়নি।')),
        );
      }
    }
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacy & Data Safety'),
        content: const Text(
          '• Stylish Text, Emoji Art, Study Summary, English OCR এবং Image Resize আপনার ফোনের ভেতরেই (Offline) কাজ করে।\n\n'
          '• আপনার Favorites ও Copy History কেবল আপনার ফোনের লোকাল স্টোরেজে নিরাপদ থাকে—কোনো সার্ভারে পাঠানো হয় না।\n\n'
          '• Camera ও Gallery পারমিশন শুধুমাত্র আপনি যখন ছবি বাছাই বা স্ক্যান করেন তখনই ব্যবহার করা হয়।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'অ্যাপের রঙ (Theme Color)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: List.generate(kThemeOptions.length, (i) {
                    final opt = kThemeOptions[i];
                    final selected = app.themeIndex == i;
                    return GestureDetector(
                      onTap: () => app.setThemeIndex(i),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: opt.color,
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: selected
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(opt.name, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0.5,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark Mode'),
                subtitle: const Text('চোখের আরামের জন্য ডার্ক থিম'),
                value: app.isDarkMode,
                onChanged: app.toggleDarkMode,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Privacy & Data Safety'),
                subtitle: const Text('অ্যাপের নিরাপত্তা ও তথ্যের সুরক্ষা নীতি'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPrivacyDialog(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('More Online Tools (Website)'),
                subtitle: Text(
                  kWebsiteUrl.isEmpty ? 'ওয়েবসাইট লিংক শীঘ্রই আসছে' : kWebsiteUrl,
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openWebsite(context),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.verified_outlined),
                title: Text(kAppName),
                subtitle: Text('Pro Studio Edition • Version 2.1 (Secured)'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
