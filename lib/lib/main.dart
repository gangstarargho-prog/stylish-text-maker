import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ওয়েবসাইট URL পরে এখানে বসাতে পারবেন (এখন ফাঁকা রাখা হয়েছে)
const String kWebsiteUrl = '';
const String kAppName = 'Stylish Text Maker';

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
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  bool _isDarkMode = false;
  List<String> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final dark = await _prefs.getBool('dark_mode') ?? false;
    final favs = await _prefs.getStringList('favorites') ?? <String>[];
    if (mounted) {
      setState(() {
        _isDarkMode = dark;
        _favorites = favs;
      });
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() => _isDarkMode = value);
    await _prefs.setBool('dark_mode', value);
  }

  Future<void> _toggleFavorite(String text) async {
    final updated = List<String>.from(_favorites);
    if (updated.contains(text)) {
      updated.remove(text);
    } else {
      updated.insert(0, text);
    }
    setState(() => _favorites = updated);
    await _prefs.setStringList('favorites', updated);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
      ),
      home: HomeNavigationScreen(
        isDarkMode: _isDarkMode,
        onToggleDarkMode: _toggleDarkMode,
        favorites: _favorites,
        onToggleFavorite: _toggleFavorite,
      ),
    );
  }
}

class HomeNavigationScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;
  final List<String> favorites;
  final ValueChanged<String> onToggleFavorite;

  const HomeNavigationScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    required this.favorites,
    required this.onToggleFavorite,
  });

  @override
  State<HomeNavigationScreen> createState() => _HomeNavigationScreenState();
}

class _HomeNavigationScreenState extends State<HomeNavigationScreen> {
  int _currentIndex = 0;
  final TextEditingController _sharedStylishController = TextEditingController();

  @override
  void dispose() {
    _sharedStylishController.dispose();
    super.dispose();
  }

  void _sendTextToStylishTab(String text) {
    _sharedStylishController.text = text;
    setState(() => _currentIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      StylishTextTab(
        controller: _sharedStylishController,
        favorites: widget.favorites,
        onToggleFavorite: widget.onToggleFavorite,
      ),
      const SymbolsTab(),
      ImageToTextTab(onSendToStylish: _sendTextToStylishTab),
      const ImageResizeTab(),
      SavedAndMoreTab(
        favorites: widget.favorites,
        onToggleFavorite: widget.onToggleFavorite,
        isDarkMode: widget.isDarkMode,
        onToggleDarkMode: widget.onToggleDarkMode,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          kAppName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: widget.isDarkMode ? 'Light Mode' : 'Dark Mode',
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => widget.onToggleDarkMode(!widget.isDarkMode),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.text_fields_outlined),
            selectedIcon: Icon(Icons.text_fields),
            label: 'Stylish',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Symbols',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Img2Text',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_size_select_large_outlined),
            selectedIcon: Icon(Icons.photo_size_select_large),
            label: 'Resize',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Saved',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// UTILITY HELPERS
// ============================================================================

void _copyToClipboard(BuildContext context, String text, {String? msg}) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg ?? 'Copied to clipboard!'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<void> _shareText(String text) async {
  await SharePlus.instance.share(ShareParams(text: text));
}

// ============================================================================
// TAB 1: STYLISH TEXT GENERATOR
// ============================================================================

class StylishTextTab extends StatefulWidget {
  final TextEditingController controller;
  final List<String> favorites;
  final ValueChanged<String> onToggleFavorite;

  const StylishTextTab({
    super.key,
    required this.controller,
    required this.favorites,
    required this.onToggleFavorite,
  });

  @override
  State<StylishTextTab> createState() => _StylishTextTabState();
}

class _StylishTextTabState extends State<StylishTextTab> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.controller.text.trim();
    final previewText = raw.isEmpty ? 'Stylish Text' : widget.controller.text;
    final styles = TextStyleEngine.generateAll(previewText);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: widget.controller,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'এখানে যেকোনো টেক্সট লিখুন...',
              prefixIcon: const Icon(Icons.edit_note),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => widget.controller.clear(),
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
              final isFav = widget.favorites.contains(item.value);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0.8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                            tooltip: 'Favorite',
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.redAccent : null,
                            ),
                            onPressed: () => widget.onToggleFavorite(item.value),
                          ),
                          IconButton(
                            tooltip: 'Share',
                            icon: const Icon(Icons.share_outlined),
                            onPressed: () => _shareText(item.value),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                _copyToClipboard(context, item.value),
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
  }
}

class StyledResult {
  final String name;
  final String value;
  const StyledResult(this.name, this.value);
}

class TextStyleEngine {
  static const String _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const String _digits = '0123456789';
  static const String _allNormal = '$_upper$_lower$_digits';

  static List<String> _split(String s) =>
      s.runes.map((r) => String.fromCharCode(r)).toList();

  static String _map(String input, String targetAll) {
    final targetList = _split(targetAll);
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final idx = _allNormal.indexOf(ch);
      if (idx != -1 && idx < targetList.length) {
        buf.write(targetList[idx]);
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  static String _mapAlphaOnly(String input, String targetAlpha) {
    const alpha = '$_upper$_lower';
    final targetList = _split(targetAlpha);
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final idx = alpha.indexOf(ch);
      if (idx != -1 && idx < targetList.length) {
        buf.write(targetList[idx]);
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  static String _combining(String input, String mark) {
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(ch);
      if (ch.trim().isNotEmpty) {
        buf.write(mark);
      }
    }
    return buf.toString();
  }

  static String _flip(String input) {
    const src =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890?!.,';
    const dst =
        'ɐqɔpǝɟƃɥᴉɾʞlɯuodbɹsʇnʌʍxʎz∀qƆpƎℲפHIſʞ˥WNOԀQɹS┴∩ΛMX⅄ZƖᄅƐㄣϛ9ㄥ860¿¡˙\'';
    final dstList = _split(dst);
    final chars = <String>[];
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final idx = src.indexOf(ch);
      chars.add((idx != -1 && idx < dstList.length) ? dstList[idx] : ch);
    }
    return chars.reversed.join();
  }

  static String _spaced(String input) {
    return input.runes.map((r) => String.fromCharCode(r)).join(' ');
  }

  static List<StyledResult> generateAll(String text) {
    final boldSans = _map(
      text,
      '𝗔𝗕𝗖𝗗𝗘𝗙𝗚𝗛𝗜𝗝𝗞𝗟𝗠𝗡𝗢𝗣𝗤𝗥𝗦𝗧𝗨𝗩𝗪𝗫𝗬𝗭𝗮𝗯𝗰𝗱𝗲𝗳𝗴𝗵𝗶𝗷𝗸𝗹𝗺𝗻𝗼𝗽𝗾𝗿𝘀𝘁𝘂𝘃𝘄𝘅𝘆𝘇𝟬𝟭𝟮𝟯𝟰𝟱𝟲𝟳𝟴𝟵',
    );
    final italicSans = _mapAlphaOnly(
      text,
      '𝘈𝘉𝘊𝘋𝘌𝘍𝘎𝘏𝘐𝘑𝘒𝘓𝘔𝘕𝘖𝘗𝘘𝘙𝘚𝘛𝘜𝘝𝘞𝘟𝘠𝘡𝘢𝘣𝘤𝘥𝘦𝘧𝘨𝘩𝘪𝘫𝘬𝘭𝘮𝘯𝘰𝘱𝘲𝘳𝘴𝘵𝘶𝘷𝘸𝘹𝘺𝘻',
    );
    final boldItalicSans = _mapAlphaOnly(
      text,
      '𝘼𝘽𝘾𝘿𝙀𝙁𝙂𝙃𝙄𝙅𝙆𝙇𝙈𝙉𝙊𝙋𝙌𝙍𝙎𝙏𝙐𝙑𝙒𝙓𝙔𝙕𝙖𝙗𝙘𝙙𝙚𝙛𝙜𝙝𝙞𝙟𝙠𝙡𝙢𝙣𝙤𝙥𝙦𝙧𝙨𝙩𝙪𝙫𝙬𝙭𝙮𝙯',
    );
    final boldSerif = _map(
      text,
      '𝐀𝐁𝐂𝐃𝐄𝐅𝐆𝐇𝐈𝐉𝐊𝐋𝐌𝐍𝐎𝐏𝐐𝐑𝐒𝐓𝐔𝐕𝐖𝐗𝐘𝐙𝐚𝐛𝐜𝐝𝐞𝐟𝐠𝐡𝐢𝐣𝐤𝐥𝐦𝐧𝐨𝐩𝐪𝐫𝐬𝐭𝐮𝐯𝐰𝐱𝐲𝐳𝟎𝟏𝟐𝟑𝟒𝟓𝟔𝟕𝟖𝟗',
    );
    final boldItalicSerif = _mapAlphaOnly(
      text,
      '𝑨𝑩𝑪𝑫𝑬𝑭𝑮𝑯𝑰𝑱𝑲𝑳𝑴𝑵𝑶𝑷𝑸𝑹𝑺𝑻𝑼𝑽𝑾𝑿𝒀𝒁𝒂𝒃𝒄𝒅𝒆𝒇𝒈𝒉𝒊𝒋𝒌𝒍𝒎𝒏𝒐𝒑𝒒𝒓𝒔𝒕𝒖𝒗𝒘𝒙𝒚𝒛',
    );
    final script = _mapAlphaOnly(
      text,
      '𝒜ℬ𝒞𝒟ℰℱ𝒢ℋℐ𝒥𝒦ℒℳ𝒩𝒪𝒫𝒬ℛ𝒮𝒯𝒰𝒱𝒲𝒳𝒴𝒵𝒶𝒷𝒸𝒹ℯ𝒻ℊ𝒽𝒾𝒿𝓀𝓁𝓂𝓃ℴ𝓅𝓆𝓇𝓈𝓉𝓊𝓋𝓌𝓍𝓎𝓏',
    );
    final boldScript = _mapAlphaOnly(
      text,
      '𝓐𝓑𝓒𝓓𝓔𝓕𝓖𝓗𝓘𝓙𝓚𝓛𝓜𝓝𝓞𝓟𝓠𝓡𝓢𝓣𝓤𝓥𝓦𝓧𝓨𝓩𝓪𝓫𝓬𝓭𝓮𝓯𝓰𝓱𝓲𝓳𝓴𝓵𝓶𝓷𝓸𝓹𝓺𝓻𝓼𝓽𝓾𝓿𝔀𝔁𝔂𝔃',
    );
    final gothic = _mapAlphaOnly(
      text,
      '𝔄𝔅ℭ𝔇𝔈𝔉𝔊ℌℑ𝔍𝔎𝔏𝔐𝔑𝔒𝔓𝔔ℜ𝔖𝔗𝔘𝔙𝔚𝔛𝔜ℨ𝔞𝔟𝔠𝔡𝔢𝔣𝔤𝔥𝔦𝔧𝔨𝔩𝔪𝔫𝔬𝔭𝔮𝔯𝔰𝔱𝔲𝔳𝔴𝔵𝔶𝔷',
    );
    final boldGothic = _mapAlphaOnly(
      text,
      '𝕬𝕭𝕮𝕯𝕰𝕱𝕲𝕳𝕴𝕵𝕶𝕷𝕸𝕹𝕺𝕻𝕼𝕽𝕾𝕿𝖀𝖁𝖂𝖃𝖄𝖅𝖆𝖇𝖈𝖉𝖊𝖋𝖌𝖍𝖎𝖏𝖐𝖑𝖒𝖓𝖔𝖕𝖖𝖗𝖘𝖙𝖚𝖛𝖜𝖝𝖞𝖟',
    );
    final doubleStruck = _map(
      text,
      '𝔸𝔹ℂ𝔻𝔼𝔽𝔾ℍ𝕀𝕁𝕂𝕃𝕄ℕ𝕆ℙℚℝ𝕊𝕋𝕌𝕍𝕎𝕏𝕐ℤ𝕒𝕓𝕔𝕕𝕖𝕗𝕘𝕙𝕚𝕛𝕜𝕝𝕞𝕟𝕠𝕡𝕢𝕣𝕤𝕥𝕦𝕧𝕨𝕩𝕪𝕫𝟘𝟙𝟚𝟛𝟜𝟝𝟞𝟟𝟠𝟡',
    );
    final mono = _map(
      text,
      '𝙰𝙱𝙲𝙳𝙴𝙵𝙶𝙷𝙸𝙹𝙺𝙻𝙼𝙽𝙾𝙿𝚀𝚁𝚂𝚃𝚄𝚅𝚆𝚇𝚈𝚉𝚊𝚋𝚌𝚍𝚎𝚏𝚐𝚑𝚒𝚓𝚔𝚕𝚖𝚗𝚘𝚙𝚚𝚛𝚜𝚝𝚞𝚟𝚠𝚡𝚢𝚣𝟶𝟷𝟸𝟹𝟺𝟻𝟼𝟽𝟾𝟿',
    );
    final bubble = _map(
      text,
      'ⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩ⓪①②③④⑤⑥⑦⑧⑨',
    );
    final darkBubble = _mapAlphaOnly(
      text,
      '🅐🅑🅒🅓🅔🅕🅖🅗🅘🅙🅚🅛🅜🅝🅞🅟🅠🅡🅢🅣🅤🅥🅦🅧🅨🅩🅐🅑🅒🅓🅔🅕🅖🅗🅘🅙🅚🅛🅜🅝🅞🅟🅠🅡🅢🅣🅤🅥🅦🅧🅨🅩',
    );
    final squared = _mapAlphaOnly(
      text,
      '🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉',
    );
    final darkSquared = _mapAlphaOnly(
      text,
      '🅰🅱🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾🅿🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉🅰🅱🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾🅿🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉',
    );
    final smallCaps = _mapAlphaOnly(
      text,
      'ABCDEFGHIJKLMNOPQRSTUVWXYZᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘǫʀsᴛᴜᴠᴡxʏᴢ',
    );
    final fullwidth = _map(
      text,
      'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ０１２３４５６７８９',
    );

    return [
      StyledResult('Bold Sans', boldSans),
      StyledResult('Bold Script', boldScript),
      StyledResult('Cursive / Script', script),
      StyledResult('Bold Gothic', boldGothic),
      StyledResult('Gothic / Fraktur', gothic),
      StyledResult('Double Struck', doubleStruck),
      StyledResult('Bubble / Circled', bubble),
      StyledResult('Dark Bubble', darkBubble),
      StyledResult('Squared Box', squared),
      StyledResult('Dark Squared', darkSquared),
      StyledResult('Small Caps', smallCaps),
      StyledResult('Bold Italic', boldItalicSans),
      StyledResult('Bold Serif', boldSerif),
      StyledResult('Bold Italic Serif', boldItalicSerif),
      StyledResult('Italic Sans', italicSans),
      StyledResult('Monospace', mono),
      StyledResult('Fullwidth / Vaporwave', fullwidth),
      StyledResult('Aesthetic Spaced', _spaced(smallCaps)),
      StyledResult('Underlined', _combining(text, '\u0332')),
      StyledResult('Double Underlined', _combining(text, '\u0333')),
      StyledResult('Strikethrough', _combining(text, '\u0336')),
      StyledResult('Slash Strike', _combining(text, '\u0338')),
      StyledResult('Wavy Underline', _combining(text, '\u0330')),
      StyledResult('Upside Down / Flip', _flip(text)),
      StyledResult('Crown Style', '👑 $boldScript 👑'),
      StyledResult('Sparkle Aesthetic', '✨『 $boldSans 』✨'),
      StyledResult('Heart Frame', '💖 ༺ $script ༻ 💖'),
      StyledResult('Gaming Tag', '◥◣ $boldGothic ◢◤'),
      StyledResult('Star Border', '★彡 $smallCaps 彡★'),
      StyledResult('Winged Name', '꧁༒☬ $boldSans ☬༒꧂'),
      StyledResult('Arrow Decor', '➳❥ $boldItalicSans ❥➳'),
      StyledResult('Bracket Pro', '【★ $doubleStruck ★】'),
    ];
  }
}

// ============================================================================
// TAB 2: STYLISH SYMBOLS & DECORATIONS
// ============================================================================

class SymbolsTab extends StatefulWidget {
  const SymbolsTab({super.key});

  @override
  State<SymbolsTab> createState() => _SymbolsTabState();
}

class _SymbolsTabState extends State<SymbolsTab> {
  String _selectedCategory = 'All';
  final TextEditingController _builderController = TextEditingController();

  static const Map<String, List<String>> _categories = {
    'Hearts': [
      '❤️', '💖', '💘', '💝', '💗', '💓', '💞', '💕', '❣️', '💔',
      '🖤', '🤍', '🤎', '💜', '💙', '💚', '💛', '🧡', '♡', '♥',
      '❥', 'ღ', '❣', 'დ', 'ლ', 'ও',
    ],
    'Stars': [
      '★', '☆', '✦', '✧', '✩', '✪', '✫', '✬', '✭', '✮',
      '✯', '✰', '✱', '✲', '✳', '✴', '✵', '✶', '✷', '✸',
      '✹', '✺', '✻', '✼', '✽', '✾', '✿', '❀', '❁', '✨', '🌟',
    ],
    'Crowns': [
      '👑', '♛', '♕', '♚', '♔', '♜', '♖', '♝', '♗', '♞',
      '♘', '⚜️', '🔱', '⚡', '🔥', '💎', '🏆', '🎖️',
    ],
    'Arrows': [
      '➔', '➜', '➝', '➞', '➟', '➠', '➡', '➢', '➣', '➤',
      '➥', '➦', '➧', '➨', '➳', '➴', '➵', '➶', '➷', '➸',
      '➹', '➺', '➻', '➼', '➽', '➾', '↳', '↱', '↺', '↻',
    ],
    'Brackets': [
      '『', '』', '「', '」', '【', '】', '〔', '〕', '《', '》',
      '〈', '〉', '꧁', '꧂', '༺', '༻', '༒', '☬', '◥', '◣',
      '◢', '◤', '︵', '︶', '︷', '︸',
    ],
    'Borders': [
      '★彡[  ]彡★',
      '꧁༒☬  ☬༒꧂',
      '•°¯`••  ••´¯°•',
      'ıllıllı  ıllıllı',
      '×º°”˜`”°º×  ×º°”˜`”°º×',
      '•._.••´¯``•.¸¸.•`  `•.¸¸.•´´¯`••._.•',
      '▂▃▅▇█▓▒░  ░▒▓█▇▅▃▂',
      '══════ ∘◦❁◦∘ ══════',
      '───── ⋆⋅☆⋅⋆ ─────',
      '· · ─────── ·𖥸· ─────── · ·',
      '｡･:*:･ﾟ★,｡･:*:･ﾟ☆',
    ],
    'Cute & Music': [
      '♪', '♫', '♬', '♩', '♭', '♮', '♯', '🎧', '🎤', '🦋',
      '🌸', '🌺', '🌻', '🌹', '🌷', '🍀', '🍁', '🌙', '☀️', '☁️',
      '🌈', '❄️', '🌊', '🕊️', '♾️', '☮️', '☯️', '☢️', '☣️',
    ],
  };

  @override
  void dispose() {
    _builderController.dispose();
    super.dispose();
  }

  List<String> _getDisplayedSymbols() {
    if (_selectedCategory == 'All') {
      return _categories.values.expand((e) => e).toList();
    }
    return _categories[_selectedCategory] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final categoryNames = ['All', ..._categories.keys];
    final items = _getDisplayedSymbols();

    return Column(
      children: [
        // Quick Symbol Builder Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _builderController,
                  decoration: InputDecoration(
                    hintText: 'ট্যাপ করলে কপি ও এখানে যুক্ত হবে...',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _builderController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _builderController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _builderController.text.isEmpty
                    ? null
                    : () => _copyToClipboard(context, _builderController.text),
                child: const Text('Copy'),
              ),
            ],
          ),
        ),
        // Category Chips
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categoryNames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = categoryNames[index];
              return ChoiceChip(
                label: Text(cat),
                selected: _selectedCategory == cat,
                onSelected: (_) => setState(() => _selectedCategory = cat),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((sym) {
                final isWide = sym.length > 4;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _builderController.text = '${_builderController.text}$sym';
                    });
                    _copyToClipboard(context, sym, msg: 'Copied: $sym');
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 14 : 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      sym,
                      style: TextStyle(fontSize: isWide ? 14 : 20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 3: IMAGE TO TEXT (OCR)
// ============================================================================

class ImageToTextTab extends StatefulWidget {
  final ValueChanged<String> onSendToStylish;

  const ImageToTextTab({super.key, required this.onSendToStylish});

  @override
  State<ImageToTextTab> createState() => _ImageToTextTabState();
}

class _ImageToTextTabState extends State<ImageToTextTab> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final TextEditingController _resultController = TextEditingController();

  File? _selectedImage;
  bool _isProcessing = false;

  @override
  void dispose() {
    _textRecognizer.close();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      setState(() {
        _selectedImage = File(picked.path);
        _isProcessing = true;
      });

      final inputImage = InputImage.fromFilePath(picked.path);
      final RecognizedText recognized =
          await _textRecognizer.processImage(inputImage);

      if (mounted) {
        setState(() {
          _resultController.text = recognized.text.trim();
          _isProcessing = false;
        });
        if (recognized.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ছবিতে কোনো স্পষ্ট লেখা পাওয়া যায়নি।'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সমস্যা হয়েছে: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text(
                    'ছবি থেকে লেখা (Text) বের করুন (অফলাইন)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () => _pickAndScan(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _isProcessing
                              ? null
                              : () => _pickAndScan(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Camera'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                _selectedImage!,
                height: 190,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          if (_isProcessing) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('ছবি স্ক্যান করা হচ্ছে...')),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _resultController,
            maxLines: 7,
            minLines: 4,
            decoration: InputDecoration(
              labelText: 'স্ক্যান করা লেখা (এডিট করতে পারবেন)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _resultController.text.isEmpty
                    ? null
                    : () => _shareText(_resultController.text),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              ),
              FilledButton.tonalIcon(
                onPressed: _resultController.text.isEmpty
                    ? null
                    : () => _copyToClipboard(context, _resultController.text),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
              FilledButton.icon(
                onPressed: _resultController.text.isEmpty
                    ? null
                    : () => widget.onSendToStylish(_resultController.text),
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('Make Stylish'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 4: IMAGE RESIZE TOOL
// ============================================================================

class _ResizeRequest {
  final Uint8List bytes;
  final int width;
  final int height;
  final bool asPng;
  final int jpgQuality;

  const _ResizeRequest({
    required this.bytes,
    required this.width,
    required this.height,
    required this.asPng,
    required this.jpgQuality,
  });
}

Uint8List? _runResizeInIsolate(_ResizeRequest req) {
  final decoded = img.decodeImage(req.bytes);
  if (decoded == null) return null;
  final resized = img.copyResize(
    decoded,
    width: req.width,
    height: req.height,
    interpolation: img.Interpolation.linear,
  );
  if (req.asPng) {
    return Uint8List.fromList(img.encodePng(resized));
  }
  return Uint8List.fromList(img.encodeJpg(resized, quality: req.jpgQuality));
}

(int, int)? _decodeDimensionsInIsolate(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return (decoded.width, decoded.height);
}

class ImageResizeTab extends StatefulWidget {
  const ImageResizeTab({super.key});

  @override
  State<ImageResizeTab> createState() => _ImageResizeTabState();
}

class _ImageResizeTabState extends State<ImageResizeTab> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  Uint8List? _originalBytes;
  int _origWidth = 0;
  int _origHeight = 0;

  Uint8List? _resizedBytes;
  String? _resizedTempPath;
  int _newWidth = 0;
  int _newHeight = 0;

  bool _keepAspectRatio = true;
  bool _asPng = false;
  int _jpgQuality = 85;
  bool _isBusy = false;
  bool _updatingFields = false;

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked =
          await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isBusy = true);
      final bytes = await picked.readAsBytes();
      final dims = await Isolate.run(() => _decodeDimensionsInIsolate(bytes));

      if (!mounted) return;
      if (dims == null) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ছবিটি পড়া সম্ভব হয়নি।')),
        );
        return;
      }

      setState(() {
        _originalBytes = bytes;
        _origWidth = dims.$1;
        _origHeight = dims.$2;
        _resizedBytes = null;
        _resizedTempPath = null;
        _updatingFields = true;
        _widthController.text = _origWidth.toString();
        _heightController.text = _origHeight.toString();
        _updatingFields = false;
        _isBusy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সমস্যা হয়েছে: $e')),
        );
      }
    }
  }

  void _onWidthChanged(String val) {
    if (_updatingFields || !_keepAspectRatio || _origWidth == 0) return;
    final w = int.tryParse(val);
    if (w == null || w <= 0) return;
    final h = ((w * _origHeight) / _origWidth).round().clamp(1, 10000);
    _updatingFields = true;
    _heightController.text = h.toString();
    _updatingFields = false;
  }

  void _onHeightChanged(String val) {
    if (_updatingFields || !_keepAspectRatio || _origHeight == 0) return;
    final h = int.tryParse(val);
    if (h == null || h <= 0) return;
    final w = ((h * _origWidth) / _origHeight).round().clamp(1, 10000);
    _updatingFields = true;
    _widthController.text = w.toString();
    _updatingFields = false;
  }

  void _applyScale(double factor) {
    if (_origWidth == 0 || _origHeight == 0) return;
    final w = (_origWidth * factor).round().clamp(1, 10000);
    final h = (_origHeight * factor).round().clamp(1, 10000);
    setState(() {
      _updatingFields = true;
      _widthController.text = w.toString();
      _heightController.text = h.toString();
      _updatingFields = false;
    });
  }

  void _applyMaxWidth(int targetWidth) {
    if (_origWidth == 0 || _origHeight == 0) return;
    final h = ((targetWidth * _origHeight) / _origWidth).round().clamp(1, 10000);
    setState(() {
      _updatingFields = true;
      _widthController.text = targetWidth.toString();
      _heightController.text = h.toString();
      _updatingFields = false;
    });
  }

  Future<void> _resizeImage() async {
    if (_originalBytes == null) return;
    final w = int.tryParse(_widthController.text.trim()) ?? 0;
    final h = int.tryParse(_heightController.text.trim()) ?? 0;
    if (w <= 0 || h <= 0 || w > 10000 || h > 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সঠিক Width এবং Height দিন (1 - 10000)')),
      );
      return;
    }

    setState(() => _isBusy = true);

    try {
      final req = _ResizeRequest(
        bytes: _originalBytes!,
        width: w,
        height: h,
        asPng: _asPng,
        jpgQuality: _jpgQuality,
      );
      final outBytes = await Isolate.run(() => _runResizeInIsolate(req));
      if (outBytes == null) {
        throw Exception('Resize failed');
      }

      final ext = _asPng ? 'png' : 'jpg';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${Directory.systemTemp.path}/resized_$ts.$ext';
      await File(tempPath).writeAsBytes(outBytes);

      if (mounted) {
        setState(() {
          _resizedBytes = outBytes;
          _resizedTempPath = tempPath;
          _newWidth = w;
          _newHeight = h;
          _isBusy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('রিসাইজ করতে সমস্যা হয়েছে: $e')),
        );
      }
    }
  }

  Future<void> _saveToGallery() async {
    if (_resizedTempPath == null) return;
    try {
      final hasPermission = await Gal.hasPermission();
      if (!hasPermission) {
        await Gal.requestPermission();
      }
      await Gal.putImage(_resizedTempPath!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ছবি গ্যালারিতে সেভ হয়েছে! ✅')),
        );
      }
    } on GalException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সেভ করা যায়নি: ${e.type.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e')),
        );
      }
    }
  }

  Future<void> _shareResized() async {
    if (_resizedTempPath == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(_resizedTempPath!)],
        text: 'Resized with $kAppName',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _isBusy ? null : _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _originalBytes == null
                  ? 'গ্যালারি থেকে ছবি বাছুন'
                  : 'অন্য ছবি পরিবর্তন করুন',
            ),
          ),
          if (_isBusy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_originalBytes != null && !_isBusy) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original: $_origWidth × $_origHeight px • ${_formatSize(_originalBytes!.length)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('25%'),
                          onPressed: () => _applyScale(0.25),
                        ),
                        ActionChip(
                          label: const Text('50%'),
                          onPressed: () => _applyScale(0.50),
                        ),
                        ActionChip(
                          label: const Text('75%'),
                          onPressed: () => _applyScale(0.75),
                        ),
                        ActionChip(
                          label: const Text('1080px'),
                          onPressed: () => _applyMaxWidth(1080),
                        ),
                        ActionChip(
                          label: const Text('720px'),
                          onPressed: () => _applyMaxWidth(720),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _widthController,
                            keyboardType: TextInputType.number,
                            onChanged: _onWidthChanged,
                            decoration: const InputDecoration(
                              labelText: 'Width (px)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('×', style: TextStyle(fontSize: 20)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            onChanged: _onHeightChanged,
                            decoration: const InputDecoration(
                              labelText: 'Height (px)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aspect Ratio লক রাখুন'),
                      value: _keepAspectRatio,
                      onChanged: (v) => setState(() => _keepAspectRatio = v),
                    ),
                    Row(
                      children: [
                        const Text('ফরম্যাট: '),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('JPG'),
                          selected: !_asPng,
                          onSelected: (_) => setState(() => _asPng = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('PNG'),
                          selected: _asPng,
                          onSelected: (_) => setState(() => _asPng = true),
                        ),
                      ],
                    ),
                    if (!_asPng) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Quality: $_jpgQuality%'),
                          Expanded(
                            child: Slider(
                              min: 10,
                              max: 100,
                              divisions: 18,
                              value: _jpgQuality.toDouble(),
                              onChanged: (v) =>
                                  setState(() => _jpgQuality = v.round()),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _resizeImage,
                        icon: const Icon(Icons.transform),
                        label: const Text('Resize Image'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_resizedBytes != null) ...[
            const SizedBox(height: 14),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      'New: $_newWidth × $_newHeight px • ${_formatSize(_resizedBytes!.length)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _resizedBytes!,
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saveToGallery,
                            icon: const Icon(Icons.download),
                            label: const Text('Save Gallery'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _shareResized,
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                          ),
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
    );
  }
}

// ============================================================================
// TAB 5: SAVED FAVORITES & MORE
// ============================================================================

class SavedAndMoreTab extends StatelessWidget {
  final List<String> favorites;
  final ValueChanged<String> onToggleFavorite;
  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;

  const SavedAndMoreTab({
    super.key,
    required this.favorites,
    required this.onToggleFavorite,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  Future<void> _openWebsite(BuildContext context) async {
    if (kWebsiteUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ওয়েবসাইট লিংক খুব শীঘ্রই যুক্ত করা হবে!'),
        ),
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0.5,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark Mode'),
                subtitle: const Text('চোখের আরামের জন্য ডার্ক থিম'),
                value: isDarkMode,
                onChanged: onToggleDarkMode,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('More Online Tools (Website)'),
                subtitle: Text(
                  kWebsiteUrl.isEmpty
                      ? 'ওয়েবসাইট লিংক শীঘ্রই আসছে'
                      : kWebsiteUrl,
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openWebsite(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Saved Favorites (${favorites.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (favorites.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'কোনো স্টাইল এখনো ❤️ দিয়ে সেভ করা হয়নি।',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...favorites.map(
            (text) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(text, style: const TextStyle(fontSize: 17)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () => _copyToClipboard(context, text),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      onPressed: () => _shareText(text),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      onPressed: () => onToggleFavorite(text),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
