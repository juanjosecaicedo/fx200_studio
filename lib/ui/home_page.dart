import 'package:material_ui/material_ui.dart';

import '../core/fx200_constants.dart';
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
  final TextEditingController _namJsonController = TextEditingController();

  UsbScanResult? _scanResult;
  HidExchangeResult? _hidResult;
  NamModel? _parsedNam;
  String? _namParseError;
  int _selectedModuleIndex = 2; // AMP (NAM A2)

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
    _namJsonController.dispose();
    super.dispose();
  }

  void _scanUsb() {
    final result = _usb.scanForFx200();
    setState(() {
      _scanResult = result;
    });
  }

  void _probeHid() {
    final result = _usb.sendAndReceiveHid(<int>[Fx200Protocol.opCmdE0]);
    setState(() {
      _hidResult = result;
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
    final hid = _hidResult;
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
                  onPressed: _probeHid,
                  child: const Text('Probe HID'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(statusText, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            if (hid != null)
              Text(
                hid.ok
                    ? 'HID RX (${hid.crcValid ? "CRC OK" : "raw"}): ${HidExchangeResult.formatHex(hid.rxBytes, maxBytes: 16)}'
                    : 'HID: ${hid.errorMessage}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: hid.ok ? colorScheme.primary : colorScheme.error,
                ),
              )
            else
              Text(
                'HID IF 3 · EP 0x05 OUT / 0x84 IN · 64B',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalChainCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FX200 Signal Chain (${Fx200Constants.effectModuleCount} Modules)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List<Widget>.generate(
                Fx200Constants.defaultSignalChain.length,
                (index) {
                  final label = Fx200Constants.defaultSignalChain[index];
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
            Text(
              'IR Spec: ${Fx200Constants.irSampleRateHz} Hz · '
              '${Fx200Constants.irBitDepth}-bit · '
              '${Fx200Constants.irSamplePoints} pts · '
              '${Fx200Constants.presetPatchCount} presets',
              style: Theme.of(context).textTheme.labelSmall,
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
                FilledButton.tonal(
                  onPressed: _parseNamJson,
                  child: const Text('Validate .nam JSON'),
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
            else if (nam != null)
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
                    label: Text('Weights: ${nam.weightCount}'),
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
                      'M7 Budget: ${nam.dspCompatibility.name.toUpperCase()}',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
