import 'dart:math';

import 'package:flutter/material.dart';
import 'engines.dart';

// ============================================================================
// 1. STYLISH TEXT GENERATOR SCREEN
// ============================================================================

class StylishTextScreen extends StatefulWidget {
  final AppController app;
  final bool showAppBar;

  const StylishTextScreen({
    super.key,
    required this.app,
    this.showAppBar = false,
  });

  @override
  State<StylishTextScreen> createState() => _StylishTextScreenState();
}

class _StylishTextScreenState extends State<StylishTextScreen> {
  @override
  void initState() {
    super.initState();
    widget.app.stylishController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.app.stylishController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.app.stylishController.text.trim();
    final preview = raw.isEmpty ? 'Stylish Text' : widget.app.stylishController.text;
    final styles = TextStyleEngine.generateAll(preview);

    final body = ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: widget.app.stylishController,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'এখানে যেকোনো টেক্সট লিখুন...',
                  prefixIcon: const Icon(Icons.edit_note),
                  suffixIcon: widget.app.stylishController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => widget.app.stylishController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: styles.length,
                itemBuilder: (context, index) {
                  final item = styles[index];
                  final isFav = widget.app.favorites.contains(item.value);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0.8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            item.value,
                            style: const TextStyle(fontSize: 18, height: 1.35),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isFav ? Icons.favorite : Icons.favorite_border,
                                  color: isFav ? Colors.redAccent : null,
                                ),
                                onPressed: () => widget.app.toggleFavorite(item.value),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_outlined),
                                onPressed: () => shareText(item.value),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => copyAndRecord(context, widget.app, item.value),
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Copy'),
                              ),
                            ],
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
      },
    );

    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Stylish Text')),
      body: body,
    );
  }
}

// ============================================================================
// 2. PRO NICKNAME STUDIO SCREEN
// ============================================================================

class NicknameStudioScreen extends StatefulWidget {
  final AppController app;
  const NicknameStudioScreen({super.key, required this.app});

  @override
  State<NicknameStudioScreen> createState() => _NicknameStudioScreenState();
}

class _NicknameStudioScreenState extends State<NicknameStudioScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'PRO GAMER');
  int _leftIdx = 0;
  int _rightIdx = 0;
  int _fontIdx = 3;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _randomize() {
    final rnd = Random();
    setState(() {
      _leftIdx = rnd.nextInt(SymbolData.leftDecorations.length);
      _rightIdx = _leftIdx < SymbolData.rightDecorations.length
          ? _leftIdx
          : rnd.nextInt(SymbolData.rightDecorations.length);
      _fontIdx = 1 + rnd.nextInt(9);
    });
  }

  @override
  Widget build(BuildContext context) {
    final raw = _nameController.text.trim().isEmpty ? 'Player' : _nameController.text.trim();
    final fonts = TextStyleEngine.generateFontOnlyStyles(raw);
    final styledName = fonts[_fontIdx.clamp(0, fonts.length - 1)].value;
    final left = SymbolData.leftDecorations[_leftIdx];
    final right = SymbolData.rightDecorations[_rightIdx];
    final fullNickname = '$left$styledName$right';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pro Nickname Studio'),
        actions: [
          IconButton(
            tooltip: 'Random Style',
            icon: const Icon(Icons.casino_outlined),
            onPressed: _randomize,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) {
          final isFav = widget.app.favorites.contains(fullNickname);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live Gaming / Profile Preview Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'LIVE PROFILE PREVIEW',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        fullNickname,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () => copyAndRecord(context, widget.app, fullNickname),
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copy Name'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            onPressed: _randomize,
                            icon: const Icon(Icons.shuffle, size: 18),
                            label: const Text('Random'),
                          ),
                          IconButton(
                            onPressed: () => widget.app.toggleFavorite(fullNickname),
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.redAccent.shade100 : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'আপনার নাম লিখুন (যেমন: ARGHO)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('১. ফন্ট স্টাইল বাছুন:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(fonts.length, (i) {
                    return ChoiceChip(
                      label: Text(fonts[i].value),
                      selected: _fontIdx == i,
                      onSelected: (_) => setState(() => _fontIdx = i),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text('২. বাম পাশের সিম্বল:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(SymbolData.leftDecorations.length, (i) {
                    return ChoiceChip(
                      label: Text(SymbolData.leftDecorations[i].trim()),
                      selected: _leftIdx == i,
                      onSelected: (_) => setState(() => _leftIdx = i),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text('৩. ডান পাশের সিম্বল:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(SymbolData.rightDecorations.length, (i) {
                    return ChoiceChip(
                      label: Text(SymbolData.rightDecorations[i].trim()),
                      selected: _rightIdx == i,
                      onSelected: (_) => setState(() => _rightIdx = i),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 3. SYMBOLS & READY-MADE BIO ART SCREEN
// ============================================================================

class SymbolsAndBioScreen extends StatefulWidget {
  final AppController app;
  const SymbolsAndBioScreen({super.key, required this.app});

  @override
  State<SymbolsAndBioScreen> createState() => _SymbolsAndBioScreenState();
}

class _SymbolsAndBioScreenState extends State<SymbolsAndBioScreen> {
  int _mode = 0; // 0 = Symbols, 1 = Bio & Art
  String _selectedCat = 'All';
  final TextEditingController _builderController = TextEditingController();

  @override
  void dispose() {
    _builderController.dispose();
    super.dispose();
  }

  List<String> _symbols() {
    if (_selectedCat == 'All') {
      return SymbolData.categories.values.expand((e) => e).toList();
    }
    return SymbolData.categories[_selectedCat] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final cats = ['All', ...SymbolData.categories.keys];
    return Scaffold(
      appBar: AppBar(title: const Text('Symbols & Bio Art')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, icon: Icon(Icons.auto_awesome), label: Text('Symbols')),
                ButtonSegment(value: 1, icon: Icon(Icons.article_outlined), label: Text('Bio & Art')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          if (_mode == 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _builderController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'সিম্বলে ট্যাপ করলে এখানে যুক্ত হবে...',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: _builderController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _builderController.clear()),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _builderController.text.isEmpty
                        ? null
                        : () => copyAndRecord(context, widget.app, _builderController.text),
                    child: const Text('Copy'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(cats[i]),
                  selected: _selectedCat == cats[i],
                  onSelected: (_) => setState(() => _selectedCat = cats[i]),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _symbols().map((sym) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _builderController.text = '${_builderController.text}$sym');
                        copyAndRecord(context, widget.app, sym, msg: 'Copied: $sym');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(sym, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ] else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: SymbolData.bioTemplates.length,
                itemBuilder: (context, idx) {
                  final bio = SymbolData.bioTemplates[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Chip(
                                label: Text(bio.category),
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                bio.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(bio.content, style: const TextStyle(fontSize: 15, height: 1.4)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share_outlined),
                                onPressed: () => shareText(bio.content),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => copyAndRecord(context, widget.app, bio.content),
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Copy Bio'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. PRO TEXT TOOLS (REPEATER, GLITCH, CASE, BLANK MESSAGE)
// ============================================================================

class TextToolsScreen extends StatefulWidget {
  final AppController app;
  const TextToolsScreen({super.key, required this.app});

  @override
  State<TextToolsScreen> createState() => _TextToolsScreenState();
}

class _TextToolsScreenState extends State<TextToolsScreen> {
  int _toolMode = 0; // 0 = Repeater, 1 = Glitch & Case, 2 = Blank Msg

  // Repeater state
  final TextEditingController _repeatInput = TextEditingController(text: 'Love You ❤️');
  final TextEditingController _repeatCount = TextEditingController(text: '20');
  bool _newLine = true;
  String _repeatedOutput = '';

  // Glitch & Case state
  final TextEditingController _utilityInput = TextEditingController(text: 'Hello World');
  double _glitchLevel = 2;
  String _utilityOutput = '';

  @override
  void initState() {
    super.initState();
    _runRepeat();
    _utilityOutput = TextStyleEngine.generateGlitch(_utilityInput.text, 2);
  }

  @override
  void dispose() {
    _repeatInput.dispose();
    _repeatCount.dispose();
    _utilityInput.dispose();
    super.dispose();
  }

  void _runRepeat() {
    final count = (int.tryParse(_repeatCount.text.trim()) ?? 10).clamp(1, 500);
    final sep = _newLine ? '\n' : ' ';
    setState(() {
      _repeatedOutput = List.filled(count, _repeatInput.text).join(sep);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pro Text Tools')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Repeater')),
                ButtonSegment(value: 1, label: Text('Glitch/Case')),
                ButtonSegment(value: 2, label: Text('Blank Msg')),
              ],
              selected: {_toolMode},
              onSelectionChanged: (s) => setState(() => _toolMode = s.first),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _toolMode == 0
                  ? _buildRepeater(context)
                  : _toolMode == 1
                      ? _buildGlitchAndCase(context)
                      : _buildBlankMsg(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeater(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _repeatInput,
          decoration: InputDecoration(
            labelText: 'কী রিপিট করতে চান?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _repeatCount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'কতবার? (1 - 500)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('New Line'),
                value: _newLine,
                onChanged: (v) => setState(() => _newLine = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _runRepeat,
          icon: const Icon(Icons.repeat),
          label: const Text('Generate Repeat'),
        ),
        const SizedBox(height: 14),
        Container(
          constraints: const BoxConstraints(maxHeight: 230),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: SelectableText(_repeatedOutput),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _repeatedOutput.isEmpty
                    ? null
                    : () => copyAndRecord(context, widget.app, _repeatedOutput),
                icon: const Icon(Icons.copy),
                label: const Text('Copy All'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _repeatedOutput.isEmpty ? null : () => shareText(_repeatedOutput),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlitchAndCase(BuildContext context) {
    final txt = _utilityInput.text;
    final words = txt.trim().isEmpty ? 0 : txt.trim().split(RegExp(r'\s+')).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _utilityInput,
          maxLines: 3,
          minLines: 2,
          onChanged: (v) {
            setState(() {
              _utilityOutput = TextStyleEngine.generateGlitch(v, _glitchLevel.round());
            });
          },
          decoration: InputDecoration(
            labelText: 'টেক্সট লিখুন',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Characters: ${txt.length}  •  Words: $words',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('Glitch Level: ${_glitchLevel.round()}'),
            Expanded(
              child: Slider(
                min: 1,
                max: 5,
                divisions: 4,
                value: _glitchLevel,
                onChanged: (v) {
                  setState(() {
                    _glitchLevel = v;
                    _utilityOutput = TextStyleEngine.generateGlitch(txt, v.round());
                  });
                },
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Glitch Text'),
              onPressed: () => setState(() {
                _utilityOutput = TextStyleEngine.generateGlitch(txt, _glitchLevel.round());
              }),
            ),
            ActionChip(
              label: const Text('Reverse'),
              onPressed: () => setState(() => _utilityOutput = TextStyleEngine.reverseText(txt)),
            ),
            ActionChip(
              label: const Text('Flip'),
              onPressed: () => setState(() => _utilityOutput = TextStyleEngine.flipText(txt)),
            ),
            ActionChip(
              label: const Text('UPPERCASE'),
              onPressed: () => setState(() => _utilityOutput = txt.toUpperCase()),
            ),
            ActionChip(
              label: const Text('lowercase'),
              onPressed: () => setState(() => _utilityOutput = txt.toLowerCase()),
            ),
            ActionChip(
              label: const Text('Title Case'),
              onPressed: () => setState(() => _utilityOutput = TextStyleEngine.toTitleCase(txt)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Result:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText(_utilityOutput, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () => shareText(_utilityOutput),
                    ),
                    FilledButton.icon(
                      onPressed: () => copyAndRecord(context, widget.app, _utilityOutput),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlankMsg(BuildContext context) {
    const blankChar = '\u3164'; // Hangul Filler invisible message character
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.chat_bubble_outline, size: 48),
            const SizedBox(height: 10),
            const Text(
              'খালি মেসেজ (Blank / Invisible Message)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'বন্ধুদের চমকে দিতে WhatsApp, Messenger বা Instagram-এ খালি মেসেজ পাঠান!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => copyAndRecord(
                    context,
                    widget.app,
                    blankChar,
                    msg: 'খালি মেসেজ (1x) কপি হয়েছে! এখন পেস্ট করুন।',
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Small Blank'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => copyAndRecord(
                    context,
                    widget.app,
                    List.filled(6, blankChar).join('\n'),
                    msg: 'বড় খালি মেসেজ (6x) কপি হয়েছে!',
                  ),
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copy Big Blank'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
