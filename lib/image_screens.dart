import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'engines.dart';

// ============================================================================
// 1. IMAGE TO TEXT SCREEN (OFFLINE ENGLISH + FIXED ONLINE BANGLA)
// ============================================================================

class ImageToTextScreen extends StatefulWidget {
  final AppController app;
  const ImageToTextScreen({super.key, required this.app});

  @override
  State<ImageToTextScreen> createState() => _ImageToTextScreenState();
}

class _ImageToTextScreenState extends State<ImageToTextScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final TextEditingController _resultController = TextEditingController();

  File? _selectedImage;
  bool _isProcessing = false;
  bool _useOnlineBangla = false;

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
      setState(() => _selectedImage = File(picked.path));
      await _scanCurrentImage();
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ছবি নিতে সমস্যা হয়েছে: $e')),
        );
      }
    }
  }

  Future<void> _scanCurrentImage() async {
    if (_selectedImage == null) return;
    setState(() => _isProcessing = true);

    try {
      String extracted;
      if (_useOnlineBangla) {
        extracted = await _scanWithOnlineBangla(_selectedImage!);
      } else {
        final inputImage = InputImage.fromFilePath(_selectedImage!.path);
        final RecognizedText recognized =
            await _textRecognizer.processImage(inputImage);
        extracted = recognized.text.trim();
      }

      if (mounted) {
        setState(() {
          _resultController.text = extracted;
          _isProcessing = false;
        });
        if (extracted.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ছবিতে কোনো স্পষ্ট লেখা পাওয়া যায়নি।')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), duration: const Duration(seconds: 4)),
        );
      }
    }
  }

  Future<String> _scanWithOnlineBangla(File imageFile) async {
    try {
      final rawBytes = await imageFile.readAsBytes();
      final uploadBytes = await compute(prepareOcrImageTopLevel, rawBytes);
      final base64Str = 'data:image/jpeg;base64,${base64Encode(uploadBytes)}';

      final response = await http
          .post(
            Uri.parse('https://api.ocr.space/parse/image'),
            headers: {
              'apikey': kOcrSpaceApiKey,
            },
            body: {
              'base64Image': base64Str,
              'OCREngine': '3',
              'language': 'auto',
              'scale': 'true',
              'isOverlayRequired': 'false',
            },
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception(
          'সার্ভার এরর (${response.statusCode}): ${response.reasonPhrase ?? 'Failed'}',
        );
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (data['IsErroredOnProcessing'] == true) {
        final errList = data['ErrorMessage'];
        throw Exception(
          errList is List && errList.isNotEmpty
              ? errList.join(', ')
              : 'অনলাইন OCR-এ সমস্যা হয়েছে।',
        );
      }
      final parsed = data['ParsedResults'] as List<dynamic>?;
      if (parsed == null || parsed.isEmpty) return '';
      return parsed
          .map((e) => (e['ParsedText'] ?? '').toString())
          .join('\n')
          .trim();
    } on SocketException {
      throw Exception('ইন্টারনেট সংযোগ নেই! বাংলা OCR-এর জন্য নেট চালু করুন।');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image to Text (OCR)')),
      body: SingleChildScrollView(
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
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.offline_bolt_outlined),
                          label: Text('Offline (English)'),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.cloud_outlined),
                          label: Text('Online (বাংলা + Eng)'),
                        ),
                      ],
                      selected: {_useOnlineBangla},
                      onSelectionChanged: _isProcessing
                          ? null
                          : (s) {
                              setState(() => _useOnlineBangla = s.first);
                              if (_selectedImage != null) _scanCurrentImage();
                            },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _useOnlineBangla
                          ? 'বাংলা ও ইংরেজি মিক্সড ছবির জন্য (ইন্টারনেট প্রয়োজন)'
                          : 'শুধু ইংরেজি ছবির জন্য (অফলাইনে চলবে)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
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
                child: Image.file(_selectedImage!, height: 180, fit: BoxFit.contain),
              ),
            if (_isProcessing) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _useOnlineBangla
                      ? 'অনলাইনে বাংলা লেখা স্ক্যান হচ্ছে...'
                      : 'অফলাইনে ইংরেজি লেখা স্ক্যান হচ্ছে...',
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _resultController,
              maxLines: 8,
              minLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'স্ক্যান করা লেখা',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                      : () => shareText(_resultController.text),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _resultController.text.isEmpty
                      ? null
                      : () => copyAndRecord(context, widget.app, _resultController.text),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
                FilledButton.icon(
                  onPressed: _resultController.text.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          widget.app.sendToStylish(_resultController.text);
                        },
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('Make Stylish'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2. SMART IMAGE RESIZE + ROTATE + FORMAT CONVERTER (JPG / PNG / WEBP) + TARGET KB
// ============================================================================

class ImageResizeScreen extends StatefulWidget {
  const ImageResizeScreen({super.key});

  @override
  State<ImageResizeScreen> createState() => _ImageResizeScreenState();
}

class _ImageResizeScreenState extends State<ImageResizeScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _targetKbController = TextEditingController(text: '100');

  Uint8List? _originalBytes;
  int _origWidth = 0;
  int _origHeight = 0;

  Uint8List? _resizedBytes;
  String? _resizedTempPath;
  int _newWidth = 0;
  int _newHeight = 0;
  String _resultExt = 'jpg';

  bool _targetKbMode = false;
  bool _keepAspectRatio = true;
  String _outputFormat = 'jpg'; // 'jpg', 'png', 'webp'
  int _quality = 85;
  bool _isBusy = false;
  bool _updatingFields = false;

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _targetKbController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isBusy = true);
      final bytes = await picked.readAsBytes();
      final dims = await compute(decodeDimensionsTopLevel, bytes);
      if (!mounted) return;
      if (dims == null || dims.length < 2) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ছবিটি পড়া সম্ভব হয়নি।')),
        );
        return;
      }

      setState(() {
        _originalBytes = bytes;
        _origWidth = dims[0];
        _origHeight = dims[1];
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('সমস্যা হয়েছে: $e')));
      }
    }
  }

  Future<void> _rotate90() async {
    if (_originalBytes == null) return;
    setState(() => _isBusy = true);
    try {
      final rotated = await compute(rotate90TopLevel, _originalBytes!);
      if (rotated == null) throw Exception('Rotate failed');
      final dims = await compute(decodeDimensionsTopLevel, rotated);
      if (!mounted || dims == null) return;
      setState(() {
        _originalBytes = rotated;
        _origWidth = dims[0];
        _origHeight = dims[1];
        _resizedBytes = null;
        _resizedTempPath = null;
        _updatingFields = true;
        _widthController.text = _origWidth.toString();
        _heightController.text = _origHeight.toString();
        _updatingFields = false;
        _isBusy = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isBusy = false);
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
    if (_origWidth == 0) return;
    setState(() {
      _updatingFields = true;
      _widthController.text = (_origWidth * factor).round().clamp(1, 10000).toString();
      _heightController.text = (_origHeight * factor).round().clamp(1, 10000).toString();
      _updatingFields = false;
    });
  }

  Future<void> _processImage() async {
    if (_originalBytes == null) return;
    setState(() => _isBusy = true);

    try {
      Uint8List outBytes;
      int outW;
      int outH;
      String ext;

      if (_targetKbMode) {
        final kb = (int.tryParse(_targetKbController.text.trim()) ?? 100).clamp(10, 5000);
        final res = await compute(
          compressToTargetKbTopLevel,
          TargetKbRequest(bytes: _originalBytes!, targetKb: kb),
        );
        if (res == null) throw Exception('Compression failed');
        outBytes = res.bytes;
        outW = res.width;
        outH = res.height;
        ext = 'jpg';
      } else {
        final w = int.tryParse(_widthController.text.trim()) ?? 0;
        final h = int.tryParse(_heightController.text.trim()) ?? 0;
        if (w <= 0 || h <= 0 || w > 10000 || h > 10000) {
          throw Exception('সঠিক Width এবং Height দিন (1 - 10000)');
        }

        if (_outputFormat == 'webp') {
          Uint8List sourceForWebp = _originalBytes!;
          if (w != _origWidth || h != _origHeight) {
            final resizedPng = await compute(
              runResizeTopLevel,
              ResizeRequest(
                bytes: _originalBytes!,
                width: w,
                height: h,
                asPng: true,
                jpgQuality: 100,
              ),
            );
            if (resizedPng == null) throw Exception('Resize failed');
            sourceForWebp = resizedPng;
          }
          outBytes = await FlutterImageCompress.compressWithList(
            sourceForWebp,
            minWidth: w,
            minHeight: h,
            quality: _quality,
            format: CompressFormat.webp,
          );
          ext = 'webp';
        } else {
          final bytes = await compute(
            runResizeTopLevel,
            ResizeRequest(
              bytes: _originalBytes!,
              width: w,
              height: h,
              asPng: _outputFormat == 'png',
              jpgQuality: _quality,
            ),
          );
          if (bytes == null) throw Exception('Resize failed');
          outBytes = bytes;
          ext = _outputFormat;
        }
        outW = w;
        outH = h;
      }

      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${tempDir.path}/converted_$ts.$ext';
      await File(tempPath).writeAsBytes(outBytes);

      if (mounted) {
        setState(() {
          _resizedBytes = outBytes;
          _resizedTempPath = tempPath;
          _newWidth = outW;
          _newHeight = outH;
          _resultExt = ext.toUpperCase();
          _isBusy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _saveToGallery() async {
    if (_resizedTempPath == null) return;
    try {
      if (!await Gal.hasPermission()) await Gal.requestPermission();
      await Gal.putImage(_resizedTempPath!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_resultExt ছবি গ্যালারিতে সেভ হয়েছে! ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('সেভ করা যায়নি: $e')));
      }
    }
  }

  Future<void> _shareResized() async {
    if (_resizedTempPath == null) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(_resizedTempPath!)], text: 'Converted with $kAppName'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resize & Format Converter'),
        actions: [
          if (_originalBytes != null && !_isBusy)
            IconButton(
              tooltip: 'Rotate 90°',
              icon: const Icon(Icons.rotate_right),
              onPressed: _rotate90,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _isBusy ? null : _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_originalBytes == null ? 'গ্যালারি থেকে ছবি বাছুন' : 'অন্য ছবি বাছুন'),
            ),
            if (_isBusy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('প্রসেস করা হচ্ছে...')),
            ],
            if (_originalBytes != null && !_isBusy) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Original: $_origWidth × $_origHeight px • ${_formatSize(_originalBytes!.length)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Resize / Convert')),
                          ButtonSegment(value: true, label: Text('Target KB')),
                        ],
                        selected: {_targetKbMode},
                        onSelectionChanged: (s) => setState(() => _targetKbMode = s.first),
                      ),
                      const SizedBox(height: 12),
                      if (_targetKbMode) ...[
                        const Text(
                          'চাকরি বা ফর্মের জন্য নির্দিষ্ট KB-এর নিচে ছবি কমান:',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ['50', '100', '200', '500'].map((kb) {
                            return ActionChip(
                              label: Text('$kb KB'),
                              onPressed: () => setState(() => _targetKbController.text = kb),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _targetKbController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'সর্বোচ্চ সাইজ (KB)',
                            suffixText: 'KB',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ] else ...[
                        Wrap(
                          spacing: 8,
                          children: [
                            ActionChip(label: const Text('25%'), onPressed: () => _applyScale(0.25)),
                            ActionChip(label: const Text('50%'), onPressed: () => _applyScale(0.50)),
                            ActionChip(label: const Text('75%'), onPressed: () => _applyScale(0.75)),
                            ActionChip(label: const Text('100%'), onPressed: () => _applyScale(1.0)),
                          ],
                        ),
                        const SizedBox(height: 10),
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
                        const Text('আউটপুট ফরম্যাট (Convert to):', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('JPG'),
                              selected: _outputFormat == 'jpg',
                              onSelected: (_) => setState(() => _outputFormat = 'jpg'),
                            ),
                            ChoiceChip(
                              label: const Text('PNG'),
                              selected: _outputFormat == 'png',
                              onSelected: (_) => setState(() => _outputFormat = 'png'),
                            ),
                            ChoiceChip(
                              label: const Text('WEBP'),
                              selected: _outputFormat == 'webp',
                              onSelected: (_) => setState(() => _outputFormat = 'webp'),
                            ),
                          ],
                        ),
                        if (_outputFormat != 'png')
                          Row(
                            children: [
                              Text('Quality: $_quality%'),
                              Expanded(
                                child: Slider(
                                  min: 10,
                                  max: 100,
                                  divisions: 18,
                                  value: _quality.toDouble(),
                                  onChanged: (v) => setState(() => _quality = v.round()),
                                ),
                              ),
                            ],
                          ),
                      ],
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _processImage,
                        icon: const Icon(Icons.transform),
                        label: Text(
                          _targetKbMode
                              ? 'Compress to Target KB'
                              : 'Convert to ${_outputFormat.toUpperCase()} & Resize',
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
                        '$_resultExt • $_newWidth × $_newHeight px • ${_formatSize(_resizedBytes!.length)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_resizedBytes!, height: 180, fit: BoxFit.contain),
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
      ),
    );
  }
}

// ============================================================================
// 3. YOUTUBE THUMBNAIL DOWNLOADER SCREEN
// ============================================================================

class _ThumbItem {
  final String label;
  final String resolution;
  final String url;
  final Uint8List bytes;
  const _ThumbItem({
    required this.label,
    required this.resolution,
    required this.url,
    required this.bytes,
  });
}

class YoutubeThumbnailScreen extends StatefulWidget {
  const YoutubeThumbnailScreen({super.key});

  @override
  State<YoutubeThumbnailScreen> createState() => _YoutubeThumbnailScreenState();
}

class _YoutubeThumbnailScreenState extends State<YoutubeThumbnailScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  List<_ThumbItem> _thumbnails = [];
  String? _videoId;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String? _extractVideoId(String input) {
    final trimmed = input.trim();
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
      return trimmed;
    }
    final match = RegExp(
      r'(?:youtube\.com/(?:watch\?(?:.*&)?v=|shorts/|embed/|live/)|youtu\.be/)([a-zA-Z0-9_-]{11})',
    ).firstMatch(trimmed);
    return match?.group(1);
  }

  Future<void> _fetchThumbnails() async {
    final id = _extractVideoId(_urlController.text);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সঠিক YouTube ভিডিও বা Shorts লিংক দিন!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _thumbnails = [];
      _videoId = id;
    });

    final candidates = [
      ('Max HD', '1280 × 720', 'https://img.youtube.com/vi/$id/maxresdefault.jpg'),
      ('Standard SD', '640 × 480', 'https://img.youtube.com/vi/$id/sddefault.jpg'),
      ('High HQ', '480 × 360', 'https://img.youtube.com/vi/$id/hqdefault.jpg'),
      ('Medium MQ', '320 × 180', 'https://img.youtube.com/vi/$id/mqdefault.jpg'),
    ];

    try {
      final results = await Future.wait(
        candidates.map((c) async {
          try {
            final res = await http
                .get(Uri.parse(c.$3))
                .timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 && res.bodyBytes.length > 1500) {
              return _ThumbItem(
                label: c.$1,
                resolution: c.$2,
                url: c.$3,
                bytes: res.bodyBytes,
              );
            }
          } catch (_) {}
          return null;
        }),
      );

      if (!mounted) return;
      final available = results.whereType<_ThumbItem>().toList();
      setState(() {
        _thumbnails = available;
        _isLoading = false;
      });

      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('থাম্বনেইল পাওয়া যায়নি। ইন্টারনেট ও লিংক চেক করুন।')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    }
  }

  Future<void> _saveThumb(_ThumbItem item) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${tempDir.path}/yt_thumb_${_videoId}_$ts.jpg';
      await File(path).writeAsBytes(item.bytes);

      if (!await Gal.hasPermission()) await Gal.requestPermission();
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.label} থাম্বনেইল গ্যালারিতে সেভ হয়েছে! ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('সেভ হয়নি: $e')));
      }
    }
  }

  Future<void> _shareThumb(_ThumbItem item) async {
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '${tempDir.path}/yt_thumb_share_$ts.jpg';
    await File(path).writeAsBytes(item.bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'YouTube Thumbnail (${item.resolution})'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Thumbnail Downloader')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'YouTube ভিডিও বা Shorts লিংক পেস্ট করুন',
                hintText: 'https://youtu.be/... বা watch?v=...',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _urlController.clear();
                          _thumbnails = [];
                        }),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _isLoading ? null : _fetchThumbnails,
              icon: const Icon(Icons.download_for_offline_outlined),
              label: const Text('Get Thumbnails'),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('থাম্বনেইল খোঁজা হচ্ছে...')),
            ],
            if (_thumbnails.isNotEmpty) ...[
              const SizedBox(height: 16),
              ..._thumbnails.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.memory(item.bytes, height: 190, fit: BoxFit.cover),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  '${item.resolution} • ${(item.bytes.length / 1024).toStringAsFixed(0)} KB',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.share_outlined),
                                  onPressed: () => _shareThumb(item),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () => _saveThumb(item),
                                  icon: const Icon(Icons.download, size: 18),
                                  label: const Text('Save'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'দ্রষ্টব্য: এই টুলটি কেবল পাবলিক YouTube ভিডিওর থাম্বনেইল ছবি প্রিভিউ ও সেভ করে, কোনো ভিডিও ডাউনলোড করে না। কপিরাইট নীতিমালা মেনে ব্যবহার করুন।',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
