import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAppName = 'Stylish Text Maker';
const String kWebsiteUrl = '';
const String kOcrSpaceApiKey = 'K8258483675268988957';

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
    final clean = text.trim();
    if (clean.isEmpty) return;
    final updated = List<String>.from(favorites);
    if (updated.contains(clean)) {
      updated.remove(clean);
    } else {
      updated.insert(0, clean);
      if (updated.length > 100) updated.removeRange(100, updated.length);
    }
    favorites = updated;
    notifyListeners();
    await _prefs.setStringList('favorites', updated);
  }

  Future<void> addToHistory(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final safeText = clean.length > 2000 ? clean.substring(0, 2000) : clean;
    final updated = List<String>.from(history);
    updated.remove(safeText);
    updated.insert(0, safeText);
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
    final safe = input.length > 500 ? input.substring(0, 500) : input;
    const up = ['\u030d', '\u030e', '\u0304', '\u0305', '\u033f', '\u0311', '\u0306', '\u0310', '\u0352'];
    const mid = ['\u0315', '\u031b', '\u0340', '\u0341', '\u0358', '\u0321', '\u0322', '\u0335', '\u0336'];
    const down = ['\u0316', '\u0317', '\u0318', '\u0319', '\u031c', '\u031d', '\u0320', '\u0324', '\u0329'];
    final rnd = Random(42);
    final buf = StringBuffer();
    for (final rune in safe.runes) {
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

// ============================================================================
// NEW FEATURE 1: EMOJI ART ENGINE
// ============================================================================

class EmojiArtEngine {
  static const Map<String, List<String>> _glyphs = {
    'A': ['01110', '10001', '11111', '10001', '10001'],
    'B': ['11110', '10001', '11110', '10001', '11110'],
    'C': ['01111', '10000', '10000', '10000', '01111'],
    'D': ['11110', '10001', '10001', '10001', '11110'],
    'E': ['11111', '10000', '11110', '10000', '11111'],
    'F': ['11111', '10000', '11110', '10000', '10000'],
    'G': ['01111', '10000', '10111', '10001', '01111'],
    'H': ['10001', '10001', '11111', '10001', '10001'],
    'I': ['11111', '00100', '00100', '00100', '11111'],
    'J': ['00111', '00010', '00010', '10010', '01100'],
    'K': ['10001', '10010', '11100', '10010', '10001'],
    'L': ['10000', '10000', '10000', '10000', '11111'],
    'M': ['10001', '11011', '10101', '10001', '10001'],
    'N': ['10001', '11001', '10101', '10011', '10001'],
    'O': ['01110', '10001', '10001', '10001', '01110'],
    'P': ['11110', '10001', '11110', '10000', '10000'],
    'Q': ['01110', '10001', '10101', '10010', '01101'],
    'R': ['11110', '10001', '11110', '10010', '10001'],
    'S': ['01111', '10000', '01110', '00001', '11110'],
    'T': ['11111', '00100', '00100', '00100', '00100'],
    'U': ['10001', '10001', '10001', '10001', '01110'],
    'V': ['10001', '10001', '10001', '01010', '00100'],
    'W': ['10001', '10001', '10101', '11011', '10001'],
    'X': ['10001', '01010', '00100', '01010', '10001'],
    'Y': ['10001', '01010', '00100', '00100', '00100'],
    'Z': ['11111', '00010', '00100', '01000', '11111'],
    '0': ['01110', '10011', '10101', '11001', '01110'],
    '1': ['00100', '01100', '00100', '00100', '01110'],
    '2': ['01110', '10001', '00110', '01000', '11111'],
    '3': ['11110', '00001', '01110', '00001', '11110'],
    '4': ['10010', '10010', '11111', '00010', '00010'],
    '5': ['11111', '10000', '11110', '00001', '11110'],
    '6': ['01110', '10000', '11110', '10001', '01110'],
    '7': ['11111', '00010', '00100', '01000', '01000'],
    '8': ['01110', '10001', '01110', '10001', '01110'],
    '9': ['01110', '10001', '01111', '00001', '01110'],
    '!': ['00100', '00100', '00100', '00000', '00100'],
    '?': ['01110', '10001', '00110', '00000', '00100'],
  };

  static String generate({
    required String text,
    required String fgEmoji,
    required String bgChar,
    required bool vertical,
  }) {
    final clean = text.toUpperCase().trim();
    if (clean.isEmpty) return '';
    final limited = clean.length > 12 ? clean.substring(0, 12) : clean;

    if (vertical) {
      final blocks = <String>[];
      for (final rune in limited.runes) {
        final ch = String.fromCharCode(rune);
        if (ch == ' ') {
          blocks.add('');
          continue;
        }
        final grid = _glyphs[ch];
        if (grid == null) continue;
        final lines = grid.map(
          (row) => row.split('').map((c) => c == '1' ? fgEmoji : bgChar).join(),
        );
        blocks.add(lines.join('\n'));
      }
      return blocks.join('\n\n');
    } else {
      final grids = <List<String>>[];
      for (final rune in limited.runes) {
        final ch = String.fromCharCode(rune);
        if (ch == ' ') {
          grids.add(['00', '00', '00', '00', '00']);
        } else if (_glyphs.containsKey(ch)) {
          grids.add(_glyphs[ch]!);
        }
      }
      if (grids.isEmpty) return '';
      final rows = <String>[];
      for (int r = 0; r < 5; r++) {
        final rowStr = grids
            .map((g) => g[r].split('').map((c) => c == '1' ? fgEmoji : bgChar).join())
            .join(bgChar);
        rows.add(rowStr);
      }
      return rows.join('\n');
    }
  }
}

// ============================================================================
// NEW FEATURE 2: OFFLINE STUDY PARAGRAPH SUMMARIZER (ENGLISH + BANGLA)
// ============================================================================

class SummaryResult {
  final String summaryText;
  final int originalWords;
  final int summaryWords;
  final int originalSentences;
  final int summarySentences;
  final int reductionPercent;
  final int readingMinutes;
  final List<String> keywords;

  const SummaryResult({
    required this.summaryText,
    required this.originalWords,
    required this.summaryWords,
    required this.originalSentences,
    required this.summarySentences,
    required this.reductionPercent,
    required this.readingMinutes,
    required this.keywords,
  });
}

class ParagraphSummaryEngine {
  static const Set<String> _stopWords = {
    // English stopwords
    'the', 'is', 'in', 'at', 'of', 'and', 'to', 'a', 'an', 'that', 'this',
    'it', 'for', 'on', 'with', 'as', 'was', 'were', 'are', 'be', 'by', 'or',
    'from', 'they', 'we', 'you', 'he', 'she', 'his', 'her', 'their', 'our',
    'which', 'who', 'what', 'when', 'where', 'how', 'can', 'will', 'has',
    'have', 'had', 'not', 'but', 'also', 'into', 'than', 'then', 'very',
    'more', 'most', 'some', 'such', 'these', 'those', 'been', 'being',
    // Bengali stopwords
    'এবং', 'ও', 'আর', 'কিন্তু', 'তবে', 'কারণ', 'যে', 'যা', 'এই', 'সেই',
    'একটি', 'কোনো', 'কোন', 'থেকে', 'দিয়ে', 'দিয়ে', 'করে', 'করা', 'হয়', 'হয়',
    'হয়ে', 'হয়ে', 'হয়েছে', 'হয়েছে', 'ছিল', 'আছে', 'না', 'নয়', 'নয়', 'কি',
    'কী', 'বা', 'জন্য', 'সাথে', 'মধ্যে', 'ওপর', 'পর', 'আগে', 'তার', 'তাদের',
    'আমাদের', 'আমরা', 'তুমি', 'সে', 'তারা', 'যখন', 'তখন', 'এটি', 'তা', 'হলো',
  };

  static const Set<String> _cueWords = {
    'important', 'conclusion', 'therefore', 'means', 'because', 'main', 'key',
    'result', 'summary', 'defined', 'কারণ', 'সুতরাং', 'অর্থাৎ', 'মূলত', 'ফলে',
    'গুরুত্বপূর্ণ', 'ফলাফল', 'বৈশিষ্ট্য', 'উপসংহার', 'প্রধান',
  };

  static List<String> _extractTokens(String text) {
    final matches = RegExp(r'[a-zA-Z0-9\u0980-\u09FF]+').allMatches(text);
    return matches.map((m) => m.group(0)!.toLowerCase()).toList();
  }

  static SummaryResult summarize(
    String rawText, {
    required int percent,
    required bool bulletPoints,
  }) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return const SummaryResult(
        summaryText: '',
        originalWords: 0,
        summaryWords: 0,
        originalSentences: 0,
        summarySentences: 0,
        reductionPercent: 0,
        readingMinutes: 0,
        keywords: [],
      );
    }

    final safeText = trimmed.length > 15000 ? trimmed.substring(0, 15000) : trimmed;
    final sentences = safeText
        .split(RegExp(r'(?<=[.!?।])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final allTokens = _extractTokens(safeText);
    final originalWords = allTokens.length;
    final readingMinutes = max(1, (originalWords / 180).ceil());

    final freq = <String, int>{};
    for (final w in allTokens) {
      if (w.length < 2 || _stopWords.contains(w)) continue;
      freq[w] = (freq[w] ?? 0) + 1;
    }

    final sortedKeys = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topKeywords = sortedKeys.take(6).map((e) => e.key).toList();

    if (sentences.length <= 1) {
      final out = bulletPoints ? '• ${sentences.join()}' : sentences.join();
      return SummaryResult(
        summaryText: out,
        originalWords: originalWords,
        summaryWords: originalWords,
        originalSentences: sentences.length,
        summarySentences: sentences.length,
        reductionPercent: 0,
        readingMinutes: readingMinutes,
        keywords: topKeywords,
      );
    }

    final scores = <int, double>{};
    for (int i = 0; i < sentences.length; i++) {
      final words = _extractTokens(sentences[i]);
      if (words.isEmpty) {
        scores[i] = 0;
        continue;
      }
      double sScore = 0;
      for (final w in words) {
        sScore += (freq[w] ?? 0);
        if (_cueWords.contains(w)) sScore += 2.5;
      }
      if (RegExp(r'\d').hasMatch(sentences[i])) sScore += 2.0;

      // Normalize softly by sentence length
      double normalized = sScore / sqrt(words.length + 1);
      if (i == 0) normalized *= 1.25; // Topic sentence boost
      if (i == sentences.length - 1) normalized *= 1.1; // Conclusion boost
      scores[i] = normalized;
    }

    final keepCount = max(1, (sentences.length * percent / 100).round())
        .clamp(1, sentences.length);

    final rankedIndices = scores.keys.toList()
      ..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    final selectedIndices = rankedIndices.take(keepCount).toList()..sort();

    final selectedSentences = selectedIndices.map((i) => sentences[i]).toList();
    final summaryText = bulletPoints
        ? selectedSentences.map((s) => '• $s').join('\n')
        : selectedSentences.join(' ');

    final summaryWords = _extractTokens(summaryText).length;
    final reduction = originalWords > 0
        ? (((originalWords - summaryWords) / originalWords) * 100).round().clamp(0, 99)
        : 0;

    return SummaryResult(
      summaryText: summaryText,
      originalWords: originalWords,
      summaryWords: summaryWords,
      originalSentences: sentences.length,
      summarySentences: selectedSentences.length,
      reductionPercent: reduction,
      readingMinutes: readingMinutes,
      keywords: topKeywords,
    );
  }
}
