import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';

import '../core/fx200_constants.dart';
import '../models/ir_wav.dart';
import '../models/nam_model.dart';
import '../services/fx200_protocol.dart';
import '../services/usb_transport.dart';

class Fx200HomePage extends StatefulWidget {
  const Fx200HomePage({super.key});

  @override
  State<Fx200HomePage> createState() => _Fx200HomePageState();
}

class _Fx200HomePageState extends State<Fx200HomePage> {
  final Fx200UsbTransport _usb = Fx200UsbTransport();
  final Fx200FrameAssembler _assembler = Fx200FrameAssembler();
  final TextEditingController _namJsonController = TextEditingController();

  UsbScanResult? _scanResult;
  Fx200HidSession? _hidSession;
  Timer? _hidPollTimer;
  String? _hidStatusMessage;
  final List<String> _hidLog = <String>[];
  final Map<int, Fx200ModuleState> _moduleStates = <int, Fx200ModuleState>{};
  final Map<int, String> _presetNames = <int, String>{};
  NamModel? _parsedNam;

  Future<void> _pickNamFile() async {
    const typeGroup = XTypeGroup(
      label: 'NAM Capture',
      extensions: <String>['nam', 'json'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return;
    final content = await file.readAsString();
    _namJsonController.text = content;
    _parseNamJson();
  }
  String? _namParseError;
  double _slimRatio = 1.0;
  String? _exportMessage;
  IrWavFile? _loadedIr;
  String? _loadedIrName;
  String? _irError;
  int _selectedModuleIndex = 2; // AMP (NAM A2)

  Future<void> _pickIrFile() async {
    const typeGroup = XTypeGroup(
      label: 'Impulse Response WAV',
      extensions: <String>['wav'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final parsed = IrWavFile.fromBytes(bytes);
      setState(() {
        _loadedIr = parsed;
        _loadedIrName = file.name;
        _irError = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _loadedIr = null;
        _loadedIrName = null;
        _irError = e.message;
      });
    }
  }

  Future<void> _exportConvertedIr() async {
    final ir = _loadedIr;
    if (ir == null) return;
    final base = (_loadedIrName ?? 'ir')
        .replaceAll(RegExp(r'\.wav$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final location = await getSaveLocation(
      suggestedName: '${base}_fx200_44k_1024.wav',
    );
    if (location == null) return;
    final bytes = ir.toFx200WavBytes();
    await XFile.fromData(bytes, mimeType: 'audio/wav').saveTo(location.path);
    setState(() {
      _exportMessage = 'Exported IR (${bytes.length}B) -> ${location.path}';
    });
  }
  int _selectedPresetIndex = 0x8b; // Preset 139

  Future<void> _exportNam7() async {
    final nam = _parsedNam;
    if (nam == null) return;
    final safeName = nam.displayName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .toLowerCase();
    final location = await getSaveLocation(
      suggestedName: '${safeName}_slim${(_slimRatio * 100).round()}.nam7',
    );
    if (location == null) return;
    final bytes = nam.exportNam7Binary(slimRatio: _slimRatio);
    await XFile.fromData(
      bytes,
      mimeType: 'application/octet-stream',
    ).saveTo(location.path);
    setState(() {
      _exportMessage = 'Exported ${bytes.length} bytes -> ${location.path}';
    });
  }

  void _readPreset(int index) {
    final clamped = index.clamp(0, Fx200Constants.presetPatchCount - 1);
    setState(() {
      _selectedPresetIndex = clamped;
    });
    _sendProbeFrame(
      'Read #$clamped',
      Fx200Protocol.buildPresetReadPacket(clamped),
    );
  }

  void _updateModuleState(Fx200ModuleState updated) {
    setState(() {
      _moduleStates[updated.slotIndex] = updated;
    });
    _sendProbeFrame(
      'Write ${updated.name}',
      Fx200Protocol.encodeModuleFrame(updated),
    );
  }

  static const String _sampleNamJson = '''
{
  "version": "0.5.4",
  "architecture": "LSTM",
  "sample_rate": 48000,
  "metadata": {
    "name": "TONE3000 Demo Crunch A2",
    "modeled_by": "FX200 Studio",
    "gear": "Tube Amp Clean/Crunch"
  },
  "config": {
    "hidden_size": 12,
    "num_layers": 1
  },
  "weights": [0.12, -0.04, 0.31, 0.08, -0.19, 0.05]
}
''';

  @override
  void initState() {
    super.initState();
    _namJsonController.text = _sampleNamJson.trim();
    _parseNamJson();
  }

  @override
  void dispose() {
    _hidPollTimer?.cancel();
    _hidSession?.close();
    _namJsonController.dispose();
    super.dispose();
  }

  void _scanUsb() {
    final result = _usb.scanForFx200();
    setState(() {
      _scanResult = result;
    });
  }

  void _appendHidLog(String line) {
    _hidLog.insert(0, line);
    if (_hidLog.length > 4) {
      _hidLog.removeLast();
    }
  }

  void _toggleHidSession() {
    if (_hidSession != null) {
      _hidPollTimer?.cancel();
      _hidPollTimer = null;
      _hidSession?.close();
      _hidSession = null;
      setState(() {
        _hidStatusMessage = 'HID session closed.';
      });
      return;
    }

    final res = _usb.openHidSession();
    if (res.session == null) {
      setState(() {
        _hidStatusMessage = res.error ?? 'Failed to open HID session.';
      });
      return;
    }

    final session = res.session!;
    _hidSession = session;
    _assembler.reset();
    _hidPollTimer = Timer.periodic(const Duration(milliseconds: 25), (_) {
      for (var i = 0; i < 16; i++) {
        final polled = session.pollIn(timeoutMs: 5);
        if (polled.data == null) break;
        final frames = _assembler.feedPacket(polled.data!);
        for (final frame in frames) {
          final mod = Fx200Protocol.decodeModuleFrame(frame.opcode, frame.body);
          final presetDump =
              Fx200Protocol.decodePresetDumpFrame(frame.opcode, frame.body);
          setState(() {
            if (mod != null) {
              _moduleStates[mod.slotIndex] = mod;
              _appendHidLog(
                'MOD ${mod.name}: ${mod.enabled ? "ON" : "OFF"} M=${mod.modelId} P=${mod.params}',
              );
            } else if (presetDump != null) {
              if (presetDump.name.isNotEmpty) {
                _presetNames[presetDump.index] = presetDump.name;
              }
              _appendHidLog(
                'PRESET #${presetDump.index}: ${presetDump.name.isEmpty ? "(empty)" : presetDump.name}',
              );
            } else {
              _appendHidLog(
                'RX 0x${frame.opcode.toRadixString(16)} (${frame.body.length}B CRC OK)',
              );
            }
          });
        }
      }
    });

    setState(() {
      _hidStatusMessage = 'HID connected (IF 3 open, polling EP 0x84).';
    });
  }

  void _sendProbeFrame(String label, List<int> rawFrame) {
    final session = _hidSession;
    if (session == null || !session.isOpen) return;
    final rc = session.sendRaw(rawFrame);
    setState(() {
      _appendHidLog(
        rc == 0
            ? 'TX $label: ${HidExchangeResult.formatHex(rawFrame, maxBytes: 12)}'
            : 'TX $label error ($rc)',
      );
    });
  }

  void _parseNamJson() {
    try {
      final parsed = NamModel.fromJsonString(_namJsonController.text);
      setState(() {
        _parsedNam = parsed;
        _namParseError = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _parsedNam = null;
        _namParseError = e.message;
      });
    } catch (e) {
      setState(() {
        _parsedNam = null;
        _namParseError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: const Text('FX200 Studio · NAM A2'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _scanUsb,
              icon: const Icon(Icons.usb, size: 18),
              label: const Text('Scan FX200 USB'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          if (isWide) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildUsbCard(colorScheme),
                        const SizedBox(height: 10),
                        _buildSignalChainCard(colorScheme),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 6, child: _buildNamInspectorCard(colorScheme)),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildUsbCard(colorScheme),
              const SizedBox(height: 10),
              _buildSignalChainCard(colorScheme),
              const SizedBox(height: 10),
              _buildNamInspectorCard(colorScheme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUsbCard(ColorScheme colorScheme) {
    final scan = _scanResult;
    final connected = _hidSession?.isOpen ?? false;
    String statusText =
        'Not scanned yet. Connect FX200 via USB-C and click "Scan FX200 USB".';
    if (scan != null) {
      if (scan.errorMessage != null) {
        statusText = 'USB error: ${scan.errorMessage}';
      } else if (scan.devices.isEmpty) {
        statusText =
            'No devices found with VID 0x${Fx200Constants.usbVendorId.toRadixString(16).padLeft(4, '0')}.';
      } else {
        final summary = scan.devices
            .map(
              (d) => '${d.hexVidPid} (bcd 0x${d.bcdDevice.toRadixString(16)})',
            )
            .join(', ');
        statusText = 'Detected: $summary';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cable, color: colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'USB Hardware Connection (libusb-1.0)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _toggleHidSession,
                  child: Text(connected ? 'Disconnect' : 'Connect HID'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(statusText, style: Theme.of(context).textTheme.bodySmall),
            if (_hidStatusMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                _hidStatusMessage!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: connected ? colorScheme.primary : colorScheme.error,
                ),
              ),
            ],
            if (connected) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  OutlinedButton(
                    onPressed: () => _sendProbeFrame(
                      '0x00',
                      Fx200Protocol.buildHidPacket(
                        payload: const <int>[Fx200Protocol.opProbe00],
                      ),
                    ),
                    child: const Text('Send 0x00'),
                  ),
                  OutlinedButton(
                    onPressed: () => _sendProbeFrame(
                      '0xE0',
                      Fx200Protocol.buildHidPacket(
                        payload: const <int>[Fx200Protocol.opCmdE0],
                      ),
                    ),
                    child: const Text('Send 0xE0'),
                  ),
                  OutlinedButton(
                    onPressed: () => _sendProbeFrame(
                      '0xA6',
                      Fx200Protocol.buildHidPacket(
                        payload: <int>[
                          Fx200Protocol.opPresetRead,
                          0x8b,
                          ...List<int>.filled(15, 0),
                        ],
                      ),
                    ),
                    child: const Text('Read 0xA6'),
                  ),
                ],
              ),
            ],
            if (_hidLog.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final line in _hidLog)
                Text(
                  line,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignalChainCard(ColorScheme colorScheme) {
    final activeModule = _moduleStates[_selectedModuleIndex];
    final connected = _hidSession?.isOpen ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Signal Chain · Preset #$_selectedPresetIndex'
                    '${(_presetNames[_selectedPresetIndex]?.isNotEmpty ?? false) ? ' (${_presetNames[_selectedPresetIndex]})' : ''}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: connected
                      ? () => _readPreset(_selectedPresetIndex - 1)
                      : null,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: connected
                      ? () => _readPreset(_selectedPresetIndex + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List<Widget>.generate(
                Fx200Constants.defaultSignalChain.length,
                (index) {
                  final baseLabel = Fx200Constants.defaultSignalChain[index];
                  final state = _moduleStates[index];
                  final label = state == null
                      ? baseLabel
                      : '${state.name} ${state.enabled ? "●" : "○"}';
                  final selected = index == _selectedModuleIndex;
                  return ChoiceChip(
                    label: Text(label),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedModuleIndex = index;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (activeModule != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${activeModule.name} · Model ${activeModule.modelId}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  Switch(
                    value: activeModule.enabled,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: connected
                        ? (val) => _updateModuleState(
                            activeModule.copyWith(enabled: val),
                          )
                        : null,
                  ),
                ],
              ),
              for (var i = 0; i < activeModule.params.length && i < 6; i++)
                Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        'P$i: ${activeModule.params[i]}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: activeModule.params[i]
                              .toDouble()
                              .clamp(0, activeModule.params[i] > 100 ? 500 : 100),
                          min: 0,
                          max: activeModule.params[i] > 100 ? 500 : 100,
                          onChanged: connected
                              ? (val) {
                                  final next = List<int>.from(activeModule.params);
                                  next[i] = val.round();
                                  _updateModuleState(
                                    activeModule.copyWith(params: next),
                                  );
                                }
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _irError != null
                          ? 'IR Error: $_irError'
                          : _loadedIr != null
                              ? 'IR $_loadedIrName: ${_loadedIr!.sampleRate} Hz · '
                                  '${_loadedIr!.bitsPerSample}-bit · ${_loadedIr!.sampleCount} pts'
                                  '${_loadedIr!.needsConversion ? ' (needs 44.1k/24b/1024)' : ' (FX200 OK)'}'
                              : 'IR Spec: ${Fx200Constants.irSampleRateHz} Hz · '
                                  '${Fx200Constants.irBitDepth}-bit · '
                                  '${Fx200Constants.irSamplePoints} pts',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _irError != null ? colorScheme.error : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: _pickIrFile,
                    child: const Text('Load IR .wav'),
                  ),
                  if (_loadedIr != null) ...[
                    const SizedBox(width: 6),
                    FilledButton.tonal(
                      onPressed: _exportConvertedIr,
                      child: const Text('Convert IR'),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamInspectorCard(ColorScheme colorScheme) {
    final nam = _parsedNam;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'NAM A2 / TONE3000 Capture Inspector',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _pickNamFile,
                  child: const Text('Load .nam'),
                ),
                const SizedBox(width: 6),
                FilledButton.tonal(
                  onPressed: _parseNamJson,
                  child: const Text('Validate'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _namJsonController,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Paste .nam JSON content',
              ),
            ),
            const SizedBox(height: 8),
            if (_namParseError != null)
              Text(
                'Parse error: $_namParseError',
                style: TextStyle(color: colorScheme.error),
              )
            else if (nam != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('Name: ${nam.displayName}'),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('Arch: ${nam.architecture}'),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'Weights: ${nam.effectiveWeightCount(_slimRatio)}'
                      '${_slimRatio < 0.999 ? ' / ${nam.weightCount}' : ''}',
                    ),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'Rate: ${nam.sampleRate?.round() ?? 'unspecified'} Hz'
                      '${nam.needsSampleRateConversion ? ' (resample -> 44.1k)' : ''}',
                    ),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'M7 @600MHz: ${nam.effectiveCompatibility(_slimRatio).name.toUpperCase()} '
                      '(~${nam.effectiveM7CpuPercent(_slimRatio).toStringAsFixed(1)}% CPU)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Slim:', style: TextStyle(fontSize: 12)),
                  for (final r in const <double>[1.0, 0.5, 0.35, 0.25])
                    ChoiceChip(
                      label: Text('${(r * 100).round()}%'),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selected: (_slimRatio - r).abs() < 0.01,
                      onSelected: (_) {
                        setState(() {
                          _slimRatio = r;
                        });
                      },
                    ),
                  FilledButton.tonal(
                    onPressed: _exportNam7,
                    child: const Text('Export .nam7'),
                  ),
                ],
              ),
              if (_exportMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  _exportMessage!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
