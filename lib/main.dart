import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MachineTranslatorApp());
}

enum Mode { textToBinary, binaryToText, textToHex, hexToText }

class MachineTranslatorApp extends StatefulWidget {
  @override
  State<MachineTranslatorApp> createState() => _MachineTranslatorAppState();
}

class _MachineTranslatorAppState extends State<MachineTranslatorApp>
    with SingleTickerProviderStateMixin {
  bool isEnglish = true;

  // Simple animated gradient controller
  late AnimationController _bgController;
  late Animation<Color?> _bgAnim1;
  late Animation<Color?> _bgAnim2;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 8),
    )..repeat(reverse: true);

    _bgAnim1 = ColorTween(
      begin: Color(0xFF121212), // dark charcoal
      end: Color(0xFF1E1B1E), // slightly lighter
    ).animate(
        CurvedAnimation(parent: _bgController, curve: Curves.easeInOutQuad));

    _bgAnim2 = ColorTween(
      begin: Color(0xFF111213),
      end: Color(0xFF232023),
    ).animate(
        CurvedAnimation(parent: _bgController, curve: Curves.easeInOutQuart));
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Machine Code Translator',
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: _bgAnim1.value,
            cardColor: Color(0xFF1A1A1A),
            colorScheme: ColorScheme.dark(
              primary: Colors.tealAccent,
              secondary: Colors.tealAccent, // ovo zamenjuje accentColor
            ),
            splashColor: Colors.white12,
            textTheme: ThemeData.dark().textTheme.copyWith(
                  titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  bodyMedium: TextStyle(fontSize: 14),
                ),
          ),

          home: TranslatorHome(
            isEnglishInitial: isEnglish,
            onLocaleToggle: (val) => setState(() => isEnglish = val),
            bgColorTop: _bgAnim1.value ?? Color(0xFF121212),
            bgColorBottom: _bgAnim2.value ?? Color(0xFF111213),
          ),
        );
      },
    );
  }
}

class TranslatorHome extends StatefulWidget {
  final bool isEnglishInitial;
  final ValueChanged<bool> onLocaleToggle;
  final Color bgColorTop;
  final Color bgColorBottom;

  TranslatorHome({
    required this.isEnglishInitial,
    required this.onLocaleToggle,
    required this.bgColorTop,
    required this.bgColorBottom,
  });

  @override
  State<TranslatorHome> createState() => _TranslatorHomeState();
}

class _TranslatorHomeState extends State<TranslatorHome>
    with TickerProviderStateMixin  {
  late bool isEnglish;
  Mode _mode = Mode.textToBinary;
  final TextEditingController _inputController = TextEditingController();
  String _output = '';
  bool _busy = false;
  bool _copied = false;

  // animation for convert button
  late AnimationController _btnController;
  late Animation<double> _btnScale;

  // For animated output card
  late AnimationController _cardController;
  late Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    isEnglish = widget.isEnglishInitial;

    _btnController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 200));
    _btnScale = Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _btnController, curve: Curves.easeOut));

    _cardController = AnimationController(
        vsync: this, duration: Duration(milliseconds: 350));
    _cardFade = CurvedAnimation(
        parent: _cardController, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _btnController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Map<String, Map<String, String>> localized = {
    'en': {
      'title': 'Machine Code Translator',
      'hint': 'Enter text, binary, or hex here',
      'convert': 'Convert',
      'copy': 'Copy',
      'clear': 'Clear',
      'mode': 'Mode',
      'textToBinary': 'Text → Binary',
      'binaryToText': 'Binary → Text',
      'textToHex': 'Text → Hex',
      'hexToText': 'Hex → Text',
      'emptyInput': 'Please provide input first',
      'invalidBinary': 'Invalid binary input',
      'invalidHex': 'Invalid hex input',
      'copied': 'Copied to clipboard',
      'help': 'Tip: You can paste binary or hex to decode quickly',
      'lastUpdated': 'Last updated',
    },
    'sr': {
      'title': 'Prevodilac mašinskog koda',
      'hint': 'Unesi tekst, binarni kod ili heks ovde',
      'convert': 'Prevedi',
      'copy': 'Kopiraj',
      'clear': 'Obriši',
      'mode': 'Rezim',
      'textToBinary': 'Tekst → Binarno',
      'binaryToText': 'Binarno → Tekst',
      'textToHex': 'Tekst → Heks',
      'hexToText': 'Heks → Tekst',
      'emptyInput': 'Najpre unesi podatak',
      'invalidBinary': 'Neispravan binarni unos',
      'invalidHex': 'Neispravan heks unos',
      'copied': 'Kopirano u clipboard',
      'help': 'Savet: Nalepi binarni ili heks da brzo dekodiraš',
      'lastUpdated': 'Poslednja izmena',
    }
  };

  String t(String key) {
    return localized[isEnglish ? 'en' : 'sr']![key] ?? key;
  }

  void _toggleLanguage() {
    setState(() {
      isEnglish = !isEnglish;
      widget.onLocaleToggle(isEnglish);
    });
  }

  Future<void> _doConvert() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      _showSnack(t('emptyInput'));
      return;
    }
    setState(() {
      _busy = true;
      _output = '';
      _copied = false;
    });

    // simple delay for UX and animation
    await Future.delayed(Duration(milliseconds: 300));

    String result;
    try {
      switch (_mode) {
        case Mode.textToBinary:
          result = _textToBinary(input);
          break;
        case Mode.binaryToText:
          result = _binaryToText(input);
          break;
        case Mode.textToHex:
          result = _textToHex(input);
          break;
        case Mode.hexToText:
          result = _hexToText(input);
          break;
      }
      setState(() {
        _output = result;
      });
      _cardController.forward(from: 0.0);
      await Future.delayed(Duration(milliseconds: 150));
      _btnController.reverse();
    } catch (e) {
      _showSnack(e.toString());
      setState(() {
        _output = '';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  String _textToBinary(String text) {
    final bytes = utf8.encode(text);
    return bytes.map((b) => b.toRadixString(2).padLeft(8, '0')).join(' ');
  }

  String _binaryToText(String bin) {
    // Accept spaced or continuous binaries
    bin = bin.replaceAll(RegExp(r'[^01]'), ' ');
    final parts = bin.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    try {
      final bytes = parts.map((p) {
        if (p.length > 8) {
          // Maybe continuous stream like 011000010110...
          // Attempt to split into 8-bit chunks
          if (p.length % 8 != 0) {
            throw Exception(t('invalidBinary'));
          }
          final chunks = p
              .split('')
              .join()
              .replaceAllMapped(RegExp(r'.{8}'), (m) => '${m.group(0)} ');
          final subparts =
              chunks.split(' ').where((s) => s.isNotEmpty).map((s) {
            return int.parse(s, radix: 2);
          }).toList();
          return subparts;
        } else {
          return [int.parse(p, radix: 2)];
        }
      }).expand((e) => e).toList();
      return utf8.decode(bytes);
    } catch (e) {
      throw Exception(t('invalidBinary'));
    }
  }

  String _textToHex(String text) {
    final bytes = utf8.encode(text);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  String _hexToText(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), ' ');
    final parts = cleaned.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    try {
      final bytes = parts.map((p) {
        if (p.length > 2) {
          if (p.length % 2 != 0) throw Exception(t('invalidHex'));
          final list = <int>[];
          for (var i = 0; i < p.length; i += 2) {
            list.add(int.parse(p.substring(i, i + 2), radix: 16));
          }
          return list;
        } else {
          return [int.parse(p, radix: 16)];
        }
      }).expand((e) => e).toList();
      return utf8.decode(bytes);
    } catch (e) {
      throw Exception(t('invalidHex'));
    }
  }

  void _showSnack(String message) {
    final ctx = context;
    ScaffoldMessenger.of(ctx).clearSnackBars();
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _copyOutput() async {
    if (_output.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _output));
    setState(() => _copied = true);
    _showSnack(t('copied'));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Colors.tealAccent.shade200;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(t('title')),
        actions: [
          IconButton(
            tooltip: isEnglish ? 'Switch to Serbian' : 'Prebaci na engleski',
            icon: Row(
              children: [
                Text(isEnglish ? 'EN' : 'SR',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(width: 6),
                Icon(Icons.translate, size: 20),
              ],
            ),
            onPressed: _toggleLanguage,
          ),
          SizedBox(width: 8),
        ],
      ),
      body: AnimatedContainer(
        duration: Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.bgColorTop, widget.bgColorBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          children: [
            _buildModeSelector(),
            SizedBox(height: 12),
            _buildInputCard(),
            SizedBox(height: 12),
            _buildActionRow(accent),
            SizedBox(height: 14),
            FadeTransition(opacity: _cardFade, child: _buildOutputCard()),
            Spacer(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(Icons.swap_horiz),
            SizedBox(width: 10),
            Text('${t('mode')}:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 6,
                children: [
                  _chip(Mode.textToBinary, t('textToBinary')),
                  _chip(Mode.binaryToText, t('binaryToText')),
                  _chip(Mode.textToHex, t('textToHex')),
                  _chip(Mode.hexToText, t('hexToText')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(Mode m, String label) {
    final selected = _mode == m;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() {
          _mode = m;
        });
      },
      selectedColor: Colors.tealAccent.shade200.withOpacity(0.18),
      backgroundColor: Colors.white10,
    );
  }

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _inputController,
              maxLines: 6,
              style: TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: t('hint'),
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onSubmitted: (_) {
                _btnController.forward(from: 0.0);
                _doConvert();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _inputController.clear();
                    setState(() {
                      _output = '';
                    });
                  },
                  icon: Icon(Icons.clear),
                  label: Text(t('clear')),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(Color accent) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTapDown: (_) => _btnController.forward(),
            onTapUp: (_) => _btnController.reverse(),
            onTapCancel: () => _btnController.reverse(),
            onTap: () {
              _doConvert();
            },
            child: AnimatedBuilder(
              animation: _btnController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _btnScale.value,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade200, Colors.purple.shade200],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: Center(
                      child: _busy
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    )),
                                SizedBox(width: 12),
                                Text(t('convert'),
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                              ],
                            )
                          : Text(t('convert'),
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(width: 10),
        Card(
          child: IconButton(
            tooltip: t('copy'),
            icon: Icon(Icons.copy),
            onPressed: _copyOutput,
          ),
        ),
      ],
    );
  }

  Widget _buildOutputCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _output.isEmpty ? t('help') : '',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
            ),
            SizedBox(height: 6),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 400),
              transitionBuilder: (child, anim) {
                return FadeTransition(opacity: anim, child: SlideTransition(
                  position:
                      Tween<Offset>(begin: Offset(0, 0.05), end: Offset.zero)
                          .animate(anim),
                  child: child,
                ));
              },
              child: _output.isEmpty
                  ? Container(
                      key: ValueKey('placeholder'),
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          isEnglish
                              ? 'Output will appear here'
                              : 'Ovde će se pojaviti rezultat',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  : SelectableText(
                      _output,
                      key: ValueKey('output'),
                      style: TextStyle(fontSize: 14, height: 1.45),
                    ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                if (_output.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _output));
                      _showSnack(t('copied'));
                    },
                    icon: Icon(Icons.copy),
                    label: Text(t('copy')),
                  ),
                Spacer(),
                Text('${t('lastUpdated')}: ${DateTime.now().toLocal().toString().split('.')[0]}',
                    style: TextStyle(fontSize: 12, color: Colors.white38)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            isEnglish
                ? 'UI · Fast conversions · Professional animations'
                : 'UI · Brzi prevodi · Profesionalne animacije',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Made for learning', style: TextStyle(color: Colors.white24)),
              SizedBox(width: 8),
              Icon(Icons.memory, size: 14, color: Colors.white24),
            ],
          ),
        ],
      ),
    );
  }
}