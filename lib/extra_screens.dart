import 'package:flutter/material.dart';
import 'engines.dart';

// ============================================================================
// 1. EMOJI ART GENERATOR SCREEN
// ============================================================================

class EmojiArtScreen extends StatefulWidget {
  final AppController app;
  const EmojiArtScreen({super.key, required this.app});

  @override
  State<EmojiArtScreen> createState() => _EmojiArtScreenState();
}

class _EmojiArtScreenState extends State<EmojiArtScreen> {
  final TextEditingController _textController = TextEditingController(text: 'LOVE');
  String _fgEmoji = '❤️';
  String _bgChar = '⬛';
  bool _vertical = true;

  static const List<String> _fgOptions = [
    '❤️', '🔥', '⭐', '💎', '🌸', '😎', '👑', '🦋', '⚡', '🎉',
  ];

  static const Map<String, String> _bgOptions = {
    '⬛ Dark': '⬛',
    '⬜ Light': '⬜',
    '▫️ Dots': '▫️',
    '⠀ Blank': '⠀',
  };

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = EmojiArtEngine.generate(
      text: _textController.text,
      fgEmoji: _fgEmoji,
      bgChar: _bgChar,
      vertical: _vertical,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Emoji Text Art')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              maxLength: 12,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'ইংরেজি অক্ষর বা সংখ্যা লিখুন (A-Z, 0-9)',
                hintText: 'যেমন: HI, LOVE, ARGHO',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                prefixIcon: const Icon(Icons.emoji_emotions_outlined),
              ),
            ),
            const SizedBox(height: 8),
            const Text('১. ইমোজি বাছুন:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _fgOptions.map((e) {
                return ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 18)),
                  selected: _fgEmoji == e,
                  onSelected: (_) => setState(() => _fgEmoji = e),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text('২. ব্যাকগ্রাউন্ড ও লেআউট:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _bgOptions.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.key),
                  selected: _bgChar == entry.value,
                  onSelected: (_) => setState(() => _bgChar = entry.value),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Vertical (নিচে নিচে)')),
                ButtonSegment(value: false, label: Text('Horizontal (পাশাপাশি)')),
              ],
              selected: {_vertical},
              onSelectionChanged: (s) => setState(() => _vertical = s.first),
            ),
            const SizedBox(height: 14),
            Card(
              elevation: 0.6,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share_outlined),
                              onPressed: art.isEmpty ? null : () => shareText(art),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: art.isEmpty
                                  ? null
                                  : () => copyAndRecord(context, widget.app, art),
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy Art'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(
                        art.isEmpty ? 'এখানে ইমোজি আর্ট দেখাবে...' : art,
                        style: TextStyle(
                          fontSize: _vertical ? 18 : 13,
                          height: 1.15,
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
    );
  }
}

// ============================================================================
// 2. STUDY PARAGRAPH SUMMARIZER SCREEN (OFFLINE ENGLISH + BANGLA)
// ============================================================================

class ParagraphSummaryScreen extends StatefulWidget {
  final AppController app;
  const ParagraphSummaryScreen({super.key, required this.app});

  @override
  State<ParagraphSummaryScreen> createState() => _ParagraphSummaryScreenState();
}

class _ParagraphSummaryScreenState extends State<ParagraphSummaryScreen> {
  final TextEditingController _inputController = TextEditingController();
  int _percent = 40;
  bool _bulletPoints = true;
  SummaryResult? _result;

  static const String _sampleBangla =
      'শিক্ষা মানুষের জীবনের সবচেয়ে গুরুত্বপূর্ণ সম্পদ। প্রকৃত শিক্ষা মানুষকে ভালো ও মন্দের পার্থক্য বুঝতে শেখায় এবং সমাজের কল্যাণে কাজ করতে উৎসাহিত করে। '
      'বর্তমান যুগে প্রযুক্তি শিক্ষার ধরনকে অনেক সহজ ও আধুনিক করে তুলেছে। শিক্ষার্থীরা এখন ঘরে বসেই অনলাইন ক্লাস, ডিজিটাল বই এবং বিভিন্ন শিক্ষামূলক অ্যাপের মাধ্যমে নতুন জ্ঞান অর্জন করতে পারে। '
      'তবে শুধু বই মুখস্থ করা প্রকৃত শিক্ষা নয়, বরং অর্জিত জ্ঞান বাস্তব জীবনে প্রয়োগ করাই মূল লক্ষ্য হওয়া উচিত। '
      'তাই নিয়মিত অধ্যবসায়, সৃজনশীল চিন্তা এবং প্রযুক্তির সঠিক ব্যবহারের মাধ্যমে প্রতিটি শিক্ষার্থী নিজেকে যোগ্য নাগরিক হিসেবে গড়ে তুলতে পারে।';

  static const String _sampleEnglish =
      'Time management is one of the most important skills for students to succeed in academics and life. '
      'When students plan their daily study schedule, they can complete assignments on time and reduce exam stress. '
      'Breaking large chapters into smaller sections makes learning easier and improves memory retention. '
      'Avoiding distractions like excessive social media during study hours helps maintain deep focus. '
      'Therefore, building consistent daily study habits leads to better grades and long-term confidence.';

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _runSummary() {
    if (_inputController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('দয়া করে একটি প্যারাগ্রাফ লিখুন বা পেস্ট করুন!')),
      );
      return;
    }
    setState(() {
      _result = ParagraphSummaryEngine.summarize(
        _inputController.text,
        percent: _percent,
        bulletPoints: _bulletPoints,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Paragraph Summary'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sample Text',
            icon: const Icon(Icons.library_books_outlined),
            onSelected: (val) {
              _inputController.text = val == 'bn' ? _sampleBangla : _sampleEnglish;
              _runSummary();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'bn', child: Text('নমুনা প্যারাগ্রাফ (বাংলা)')),
              PopupMenuItem(value: 'en', child: Text('Sample Paragraph (English)')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _inputController,
              maxLines: 7,
              minLines: 4,
              maxLength: 15000,
              decoration: InputDecoration(
                labelText: 'পড়াশোনার প্যারাগ্রাফ / রচনা লিখুন বা পেস্ট করুন (বাংলা/English)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                suffixIcon: _inputController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _inputController.clear();
                          setState(() => _result = null);
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 30, label: Text('Short (30%)')),
                ButtonSegment(value: 50, label: Text('Medium (50%)')),
                ButtonSegment(value: 70, label: Text('Detailed (70%)')),
              ],
              selected: {_percent},
              onSelectionChanged: (s) {
                setState(() => _percent = s.first);
                if (_inputController.text.trim().isNotEmpty) _runSummary();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bullet Points আকারে সাজান (নোটের জন্য সেরা)'),
              value: _bulletPoints,
              onChanged: (v) {
                setState(() => _bulletPoints = v);
                if (_inputController.text.trim().isNotEmpty) _runSummary();
              },
            ),
            FilledButton.icon(
              onPressed: _runSummary,
              icon: const Icon(Icons.summarize),
              label: const Text('Summarize Now (Offline)'),
            ),
            if (_result != null && _result!.summaryText.isNotEmpty) ...[
              const SizedBox(height: 16),
              // Study Stats Bar
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('মূল শব্দ: ${_result!.originalWords}')),
                  Chip(label: Text('সামারি শব্দ: ${_result!.summaryWords}')),
                  Chip(label: Text('${_result!.reductionPercent}% ছোট হয়েছে')),
                  Chip(label: Text('পড়তে ~${_result!.readingMinutes} মি.')),
                ],
              ),
              if (_result!.keywords.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('মূল শব্দগুলো (Keywords):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _result!.keywords
                      .map((k) => ActionChip(
                            label: Text(k),
                            onPressed: () => copyAndRecord(context, widget.app, k),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'সংক্ষিপ্ত নোট / Summary:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Divider(),
                      SelectableText(
                        _result!.summaryText,
                        style: const TextStyle(fontSize: 15.5, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Save Favorite',
                            icon: const Icon(Icons.favorite_border),
                            onPressed: () {
                              widget.app.toggleFavorite(_result!.summaryText);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Favorites-এ সেভ হয়েছে! ❤️')),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'Share',
                            icon: const Icon(Icons.share_outlined),
                            onPressed: () => shareText(_result!.summaryText),
                          ),
                          FilledButton.icon(
                            onPressed: () => copyAndRecord(
                              context,
                              widget.app,
                              _result!.summaryText,
                            ),
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copy Summary'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
