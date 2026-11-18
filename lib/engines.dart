import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAppName = 'Stylish Text Maker';
const String kWebsiteUrl = '';
const String kOcrSpaceApiKey = 'helloworld';

class ThemeOption {
  final String name;
  final Color color;
  const ThemeOption(this.name, this.color);
}

const List<ThemeOption> kThemeOptions = [
  ThemeOption('Royal Purple', Color(0xFF6C63FF)),
  ThemeOption('Ocean Blue', Color(0xFF0284C7)),
  ThemeOption('Emerald', Color(0xFF059669)),
  ThemeOption('Sunset', Color(0xFFEA580C)),
  ThemeOption('Rose Pink', Color(0xFFE11D48)),
];

// ============================================================================
// APP CONTROLLER (STATE & PREFERENCES)
// ============================================================================

class AppController extends ChangeNotifier {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  bool isDarkMode = false;
  int themeIndex = 0;
  int currentTab = 0;
  List<String> favorites = [];
  List<String> history = [];
  final TextEditingController stylishController = TextEditingController();

  Color get seedColor => kThemeOptions[themeIndex.clamp(0, kThemeOptions.length - 1)].color;

  Future<void> loadPrefs() async {
    isDarkMode = await _prefs.getBool('dark_mode') ?? false;
    themeIndex = await _prefs.getInt('theme_index') ?? 0;
    favorites = await _prefs.getStringList('favorites') ?? <String>[];
    history = await _prefs.getStringList('copy_history') ?? <String>[];
    notifyListeners();
  }

  void setTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  void sendToStylish(String text) {
    stylishController.text = text;
    currentTab = 1;
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    isDarkMode = value;
    notifyListeners();
    await _prefs.setBool('dark_mode', value);
  }

  Future<void> setThemeIndex(int index) async {
    themeIndex = index;
    notifyListeners();
    await _prefs.setInt('theme_index', index);
  }

  Future<void> toggleFavorite(String text) async {
    final updated = List<String>.from(favorites);
    if (updated.contains(text)) {
      updated.remove(text);
    } else {
      updated.insert(0, text);
    }
    favorites = updated;
    notifyListeners();
    await _prefs.setStringList('favorites', updated);
  }

  Future<void> addToHistory(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final updated = List<String>.from(history);
    updated.remove(clean);
    updated.insert(0, clean);
    if (updated.length > 40) {
      updated.removeRange(40, updated.length);
    }
    history = updated;
    notifyListeners();
    await _prefs.setStringList('copy_history', updated);
  }

  Future<void> clearHistory() async {
    history = [];
    notifyListeners();
    await _prefs.remove('copy_history');
  }

  @override
  void dispose() {
    stylishController.dispose();
    super.dispose();
  }
}

void copyAndRecord(
  BuildContext context,
  AppController app,
  String text, {
  String? msg,
}) {
  Clipboard.setData(ClipboardData(text: text));
  app.addToHistory(text);
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

Future<void> shareText(String text) async {
  await SharePlus.instance.share(ShareParams(text: text));
}

// ============================================================================
// TOP-LEVEL IMAGE ISOLATE FUNCTIONS
// ============================================================================

class ResizeRequest {
  final Uint8List bytes;
  final int width;
  final int height;
  final bool asPng;
  final int jpgQuality;

  const ResizeRequest({
    required this.bytes,
    required this.width,
    required this.height,
    required this.asPng,
    required this.jpgQuality,
  });
}

class TargetKbRequest {
  final Uint8List bytes;
  final int targetKb;
  const TargetKbRequest({required this.bytes, required this.targetKb});
}

class TargetKbResult {
  final Uint8List bytes;
  final int width;
  final int height;
  final int quality;

  const TargetKbResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.quality,
  });
}

List<int>? decodeDimensionsTopLevel(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return [decoded.width, decoded.height];
}

Uint8List? rotate90TopLevel(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final rotated = img.copyRotate(decoded, angle: 90);
  return Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
}

Uint8List? runResizeTopLevel(ResizeRequest req) {
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

TargetKbResult? compressToTargetKbTopLevel(TargetKbRequest req) {
  final decoded = img.decodeImage(req.bytes);
  if (decoded == null) return null;

  final targetBytes = req.targetKb * 1024;
  img.Image current = decoded;

  if (req.targetKb <= 200 && (current.width > 1600 || current.height > 1600)) {
    current = current.width >= current.height
        ? img.copyResize(current, width: 1600)
        : img.copyResize(current, height: 1600);
  }

  Uint8List bestBytes = Uint8List.fromList(img.encodeJpg(current, quality: 85));
  int bestW = current.width;
  int bestH = current.height;
  int bestQ = 85;

  if (bestBytes.length <= targetBytes) {
    return TargetKbResult(bytes: bestBytes, width: bestW, height: bestH, quality: bestQ);
  }

  for (int scaleStep = 0; scaleStep < 5; scaleStep++) {
    for (final q in [80, 65, 50, 35, 22]) {
      final encoded = Uint8List.fromList(img.encodeJpg(current, quality: q));
      bestBytes = encoded;
      bestW = current.width;
      bestH = current.height;
      bestQ = q;
      if (encoded.length <= targetBytes) {
        return TargetKbResult(bytes: encoded, width: bestW, height: bestH, quality: q);
      }
    }
    final nextW = (current.width * 0.72).round();
    if (nextW < 120) break;
    current = img.copyResize(current, width: nextW);
  }

  return TargetKbResult(bytes: bestBytes, width: bestW, height: bestH, quality: bestQ);
}

Uint8List prepareOcrImageTopLevel(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  img.Image target = decoded;
  const maxDim = 1600;
  if (decoded.width > maxDim || decoded.height > maxDim) {
    target = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxDim)
        : img.copyResize(decoded, height: maxDim);
  }
  var jpg = Uint8List.fromList(img.encodeJpg(target, quality: 85));
  if (jpg.length > 900 * 1024) {
    jpg = Uint8List.fromList(img.encodeJpg(target, quality: 65));
  }
  return jpg;
}

// ============================================================================
// TEXT STYLE, GLITCH & NICKNAME ENGINES
// ============================================================================

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
      buf.write((idx != -1 && idx < targetList.length) ? targetList[idx] : ch);
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
      buf.write((idx != -1 && idx < targetList.length) ? targetList[idx] : ch);
    }
    return buf.toString();
  }

  static String _combining(String input, String mark) {
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(ch);
      if (ch.trim().isNotEmpty) buf.write(mark);
    }
    return buf.toString();
  }

  static String flipText(String input) {
    const src = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890?!.,';
    const dst = 'ɐqɔpǝɟƃɥᴉɾʞlɯuodbɹsʇnʌʍxʎz∀qƆpƎℲפHIſʞ˥WNOԀQɹS┴∩ΛMX⅄ZƖᄅƐㄣϛ9ㄥ860¿¡˙\'';
    final dstList = _split(dst);
    final chars = <String>[];
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final idx = src.indexOf(ch);
      chars.add((idx != -1 && idx < dstList.length) ? dstList[idx] : ch);
    }
    return chars.reversed.join();
  }

  static String reverseText(String input) {
    return input.runes.map((r) => String.fromCharCode(r)).toList().reversed.join();
  }

  static String toTitleCase(String input) {
    return input
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String generateGlitch(String input, int intensity) {
    const up = ['\u030d', '\u030e', '\u0304', '\u0305', '\u033f', '\u0311', '\u0306', '\u0310', '\u0352'];
    const mid = ['\u0315', '\u031b', '\u0340', '\u0341', '\u0358', '\u0321', '\u0322', '\u0335', '\u0336'];
    const down = ['\u0316', '\u0317', '\u0318', '\u0319', '\u031c', '\u031d', '\u0320', '\u0324', '\u0329'];
    final rnd = Random(42);
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(ch);
      if (ch.trim().isEmpty) continue;
      for (int i = 0; i < intensity; i++) {
        buf.write(up[rnd.nextInt(up.length)]);
        if (i.isEven) buf.write(mid[rnd.nextInt(mid.length)]);
        buf.write(down[rnd.nextInt(down.length)]);
      }
    }
    return buf.toString();
  }

  static List<StyledResult> generateFontOnlyStyles(String text) {
    return [
      StyledResult('Normal', text),
      StyledResult('Bold Sans', _map(text, '𝗔𝗕𝗖𝗗𝗘𝗙𝗚𝗛𝗜𝗝𝗞𝗟𝗠𝗡𝗢𝗣𝗤𝗥𝗦𝗧𝗨𝗩𝗪𝗫𝗬𝗭𝗮𝗯𝗰𝗱𝗲𝗳𝗴𝗵𝗶𝗷𝗸𝗹𝗺𝗻𝗼𝗽𝗾𝗿𝘀𝘁𝘂𝘃𝘄𝘅𝘆𝘇𝟬𝟭𝟮𝟯𝟰𝟱𝟲𝟳𝟴𝟵')),
      StyledResult('Bold Script', _mapAlphaOnly(text, '𝓐𝓑𝓒𝓓𝓔𝓕𝓖𝓗𝓘𝓙𝓚𝓛𝓜𝓝𝓞𝓟𝓠𝓡𝓢𝓣𝓤𝓥𝓦𝓧𝓨𝓩𝓪𝓫𝓬𝓭𝓮𝓯𝓰𝓱𝓲𝓳𝓴𝓵𝓶𝓷𝓸𝓹𝓺𝓻𝓼𝓽𝓾𝓿𝔀𝔁𝔂𝔃')),
      StyledResult('Bold Gothic', _mapAlphaOnly(text, '𝕬𝕭𝕮𝕯𝕰𝕱𝕲𝕳𝕴𝕵𝕶𝕷𝕸𝕹𝕺𝕻𝕼𝕽𝕾𝕿𝖀𝖁𝖂𝖃𝖄𝖅𝖆𝖇𝖈𝖉𝖊𝖋𝖌𝖍𝖎𝖏𝖐𝖑𝖒𝖓𝖔𝖕𝖖𝖗𝖘𝖙𝖚𝖛𝖜𝖝𝖞𝖟')),
      StyledResult('Double Struck', _map(text, '𝔸𝔹ℂ𝔻𝔼𝔽𝔾ℍ𝕀𝕁𝕂𝕃𝕄ℕ𝕆ℙℚℝ𝕊𝕋𝕌𝕍𝕎𝕏𝕐ℤ𝕒𝕓𝕔𝕕𝕖𝕗𝕘𝕙𝕚𝕛𝕜𝕝𝕞𝕟𝕠𝕡𝕢𝕣𝕤𝕥𝕦𝕧𝕨𝕩𝕪𝕫𝟘𝟙𝟚𝟛𝟜𝟝𝟞𝟟𝟠𝟡')),
      StyledResult('Small Caps', _mapAlphaOnly(text, 'ABCDEFGHIJKLMNOPQRSTUVWXYZᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘǫʀsᴛᴜᴠᴡxʏᴢ')),
      StyledResult('Bubble', _map(text, 'ⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩ⓪①②③④⑤⑥⑦⑧⑨')),
      StyledResult('Dark Bubble', _mapAlphaOnly(text, '🅐🅑🅒🅓🅔🅕🅖🅗🅘🅙🅚🅛🅜🅝🅞🅟🅠🅡🅢🅣🅤🅥🅦🅧🅨🅩🅐🅑🅒🅓🅔🅕🅖🅗🅘🅙🅚🅛🅜🅝🅞🅟𝅘𝅥𝅮🅡🅢🅣🅤🅥🅦🅧🅨🅩')),
      StyledResult('Dark Squared', _mapAlphaOnly(text, '🅰🅱🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾🅿🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉🅰🅱🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾🅿🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉')),
      StyledResult('Monospace', _map(text, '𝙰𝙱𝙲𝙳𝙴𝙵𝙶𝙷𝙸𝙹𝙺𝙻𝙼𝙽𝙾𝙿𝚀𝚁𝚂𝚃𝚄𝚅𝚆𝚇𝚈𝚉𝚊𝚋𝚌𝚍𝚎𝚏𝚐𝚑𝚒𝚓𝚔𝚕𝚖𝚗𝚘𝚙𝚚𝚛𝚜𝚝𝚞𝚟𝚠𝚡𝚢𝚣𝟶𝟷𝟸𝟹𝟺𝟻𝟼𝟽𝟾𝟿')),
    ];
  }

  static List<StyledResult> generateAll(String text) {
    final fonts = generateFontOnlyStyles(text);
    final boldSans = fonts[1].value;
    final boldScript = fonts[2].value;
    final boldGothic = fonts[3].value;
    final doubleStruck = fonts[4].value;
    final smallCaps = fonts[5].value;

    final italicSans = _mapAlphaOnly(text, '𝘈𝘉𝘊𝘋𝘌𝘍𝘎𝘏𝘐𝘑𝘒𝘓𝘔𝘕𝘖𝘗𝘘𝘙𝘚𝘛𝘜𝘝𝘞𝘟𝘠𝘡𝘢𝘣𝘤𝘥𝘦𝘧𝘨𝘩𝘪𝘫𝘬𝘭𝘮𝘯𝘰𝘱𝘲𝘳𝘴𝘵𝘶𝘷𝘸𝘹𝘺𝘻');
    final boldItalicSans = _mapAlphaOnly(text, '𝘼𝘽𝘾𝘿𝙀𝙁𝙂𝙃𝙄𝙅𝙆𝙇𝙈𝙉𝙊𝙋𝙌𝙍𝙎𝙏𝙐𝙑𝙒𝙓𝙔𝙕𝙖𝙗𝙘𝙙𝙚𝙛𝙜𝙝𝙞𝙟𝙠𝙡𝙢𝙣𝙤𝙥𝙦𝙧𝙨𝙩𝙪𝙫𝙬𝙭𝙮𝙯');
    final boldSerif = _map(text, '𝐀𝐁𝐂𝐃𝐄𝐅𝐆𝐇𝐈𝐉𝐊𝐋𝐌𝐍𝐎𝐏𝐐𝐑𝐒𝐓𝐔𝐕𝐖𝐗𝐘𝐙𝐚𝐛𝐜𝐝𝐞𝐟𝐠𝐡𝐢𝐣𝐤𝐥𝐦𝐧𝐨𝐩𝐪𝐫𝐬𝐭𝐮𝐯𝐰𝐱𝐲𝐳𝟎𝟏𝟐𝟑𝟒𝟓𝟔𝟕𝟖𝟗');
    final boldItalicSerif = _mapAlphaOnly(text, '𝑨𝑩𝑪𝑫𝑬𝑭𝑮𝑯𝑰𝑱𝑲𝑳𝑴𝑵𝑶𝑷𝑸𝑹𝑺𝑻𝑼𝑽𝑾𝑿𝒀𝒁𝒂𝒃𝒄𝒅𝒆𝒇𝒈𝒉𝒊𝒋𝒌𝒍𝒎𝒏𝒐𝒑𝒒𝒓𝒔𝒕𝒖𝒗𝒘𝒙𝒚𝒛');
    final script = _mapAlphaOnly(text, '𝒜ℬ𝒞𝒟ℰℱ𝒢ℋℐ𝒥𝒦ℒℳ𝒩𝒪𝒫𝒬ℛ𝒮𝒯𝒰𝒱𝒲𝒳𝒴𝒵𝒶𝒷𝒸𝒹ℯ𝒻ℊ𝒽𝒾𝒿𝓀𝓁𝓂𝓃ℴ𝓅𝓆𝓇𝓈𝓉𝓊𝓋𝓌𝓍𝓎𝓏');
    final gothic = _mapAlphaOnly(text, '𝔄𝔅ℭ𝔇𝔈𝔉𝔊ℌℑ𝔍𝔎𝔏𝔐𝔑𝔒𝔓𝔔ℜ𝔖𝔗𝔘𝔙𝔚𝔛𝔜ℨ𝔞𝔟𝔠𝔡𝔢𝔣𝔤𝔥𝔦𝔧𝔨𝔩𝔪𝔫𝔬𝔭𝔮𝔯𝔰𝔱𝔲𝔳𝔴𝔵𝔶𝔷');
    final squared = _mapAlphaOnly(text, '🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉');
    final fullwidth = _map(text, 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ０１２３４５６７８９');
    final spaced = smallCaps.runes.map((r) => String.fromCharCode(r)).join(' ');

    return [
      ...fonts.skip(1),
      StyledResult('Cursive / Script', script),
      StyledResult('Gothic / Fraktur', gothic),
      StyledResult('Squared Box', squared),
      StyledResult('Bold Italic', boldItalicSans),
      StyledResult('Bold Serif', boldSerif),
      StyledResult('Bold Italic Serif', boldItalicSerif),
      StyledResult('Italic Sans', italicSans),
      StyledResult('Fullwidth / Vaporwave', fullwidth),
      StyledResult('Aesthetic Spaced', spaced),
      StyledResult('Underlined', _combining(text, '\u0332')),
      StyledResult('Double Underlined', _combining(text, '\u0333')),
      StyledResult('Strikethrough', _combining(text, '\u0336')),
      StyledResult('Slash Strike', _combining(text, '\u0338')),
      StyledResult('Wavy Underline', _combining(text, '\u0330')),
      StyledResult('Upside Down / Flip', flipText(text)),
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

class BioTemplate {
  final String category;
  final String title;
  final String content;
  const BioTemplate(this.category, this.title, this.content);
}

class SymbolData {
  static const List<String> leftDecorations = [
    '꧁༒☬ ', '★彡 ', '◥◣ ', '『 ', '【★ ', '⚡ ', '👑 ', '🔥 ', '✨ ', '➳❥ ', '•°¯`•• ', '༺ ',
  ];

  static const List<String> rightDecorations = [
    ' ☬༒꧂', ' 彡★', ' ◢◤', ' 』', ' ★】', ' ⚡', ' 👑', ' 🔥', ' ✨', ' ❥➳', ' ••´¯°•', ' ༻',
  ];

  static const Map<String, List<String>> categories = {
    'Hearts': [
      '❤️', '💖', '💘', '💝', '💗', '💓', '💞', '💕', '❣️', '💔',
      '🖤', '🤍', '💜', '💙', '💚', '💛', '♡', '♥', '❥', 'ღ', '❣', 'დ',
    ],
    'Stars': [
      '★', '☆', '✦', '✧', '✩', '✪', '✫', '✬', '✭', '✮', '✯', '✰',
      '✱', '✴', '✵', '✶', '✷', '✸', '✿', '❀', '❁', '✨', '🌟',
    ],
    'Crowns & Gaming': [
      '👑', '♛', '♕', '♚', '♔', '⚜️', '🔱', '⚡', '🔥', '💎', '🏆', '☠️', '⚔️', '🛡️', '🎯', '🎮',
    ],
    'Arrows': [
      '➔', '➜', '➝', '➞', '➡', '➢', '➣', '➤', '➳', '➴', '➵', '➸', '➹', '➻', '➼', '➽', '↳', '↱',
    ],
    'Brackets': [
      '『', '』', '「', '」', '【', '】', '〔', '〕', '《', '》', '꧁', '꧂', '༺', '༻', '༒', '☬', '◥', '◣', '◢', '◤',
    ],
    'Cute & Music': [
      '♪', '♫', '♬', '🎧', '🦋', '🌸', '🌺', '🌹', '🍀', '🌙', '☀️', '🌈', '❄️', '🕊️', '♾️', '☯️',
    ],
  };

  static const List<BioTemplate> bioTemplates = [
    BioTemplate(
      'Attitude',
      'VIP Attitude Bio',
      '👑 𝖂𝖊𝖑𝖈𝖔𝖒𝖊 𝕿𝖔 𝕸𝖞 𝕻𝖗𝖔𝖋𝖎𝖑𝖊 👑\n🔥 𝐒𝐭𝐲𝐥𝐞 𝐢𝐬 𝐚 𝐫𝐞𝐟𝐥𝐞𝐜𝐭𝐢𝐨𝐧 𝐨𝐟 𝐚𝐭𝐭𝐢𝐭𝐮𝐝𝐞\n⚡ 𝐍𝐨 𝐋𝐢𝐦𝐢𝐭𝐬 • 𝐎𝐧𝐥𝐲 𝐆𝐨𝐚𝐥𝐬 💯',
    ),
    BioTemplate(
      'Gaming',
      'Pro Gamer Tag',
      '꧁༒☬ 𝐏𝐑𝐎 𝐆𝐀𝐌𝐄𝐑 ☬༒꧂\n🎯 𝐇𝐞𝐚𝐝𝐬𝐡𝐨𝐭 𝐊𝐢𝐧𝐠 🔥\n🏆 𝐍𝐞𝐯𝐞𝐫 𝐆𝐢𝐯𝐞 𝐔𝐩 ⚡',
    ),
    BioTemplate(
      'Love',
      'Aesthetic Love Bio',
      '✨『 𝐋𝐨𝐯𝐞 𝐘𝐨𝐮𝐫𝐬𝐞𝐥𝐟 𝐅𝐢𝐫𝐬𝐭 』✨\n💖 𝐒𝐦𝐢𝐥𝐞 • 𝐃𝐫𝐞𝐚𝐦 • 𝐒𝐡𝐢𝐧𝐞 🌸\n🦋 𝐇𝐚𝐩𝐩𝐲 𝐒𝐨𝐮𝐥 💫',
    ),
    BioTemplate(
      'Greeting',
      'Good Morning Art',
      '☀️══════ ∘◦❁◦∘ ══════☀️\n   ✨ 𝐆𝐨𝐨𝐝 𝐌𝐨𝐫𝐧𝐢𝐧𝐠 ✨\n🌸 𝐇𝐚𝐯𝐞 𝐚 𝐁𝐥𝐞𝐬𝐬𝐞𝐝 𝐃𝐚𝐲! 🌸\n☀️══════ ∘◦❁◦∘ ══════☀️',
    ),
    BioTemplate(
      'Greeting',
      'Birthday Wish Art',
      '🎂✨🎉━━━━━━━━━━━━🎉✨🎂\n   💖 𝐇𝐀𝐏𝐏𝐘 𝐁𝐈𝐑𝐓𝐇𝐃𝐀𝐘 💖\n  🌟 𝐒𝐭𝐚𝐲 𝐇𝐚𝐩𝐩𝐲 𝐀𝐥𝐰𝐚𝐲𝐬 🌟\n🎂✨🎉━━━━━━━━━━━━🎉✨🎂',
    ),
    BioTemplate(
      'Divider',
      'Profile Dividers',
      '───── ⋆⋅☆⋅⋆ ─────\n· · ─────── ·𖥸· ─────── · ·\n•°¯`••   ••´¯°•',
    ),
  ];
}
