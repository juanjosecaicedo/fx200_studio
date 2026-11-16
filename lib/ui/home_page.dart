import 'package:material_ui/material_ui.dart';

import '../core/fx200_constants.dart';
import '../models/nam_model.dart';
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
        title: const Text('FX200 Studio · NAM A2'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _scanUsb,
              icon: const Icon(Icons.usb),
              label: const Text('Scan FX200 USB'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          if (isWide) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildUsbCard(colorScheme),
                        const SizedBox(height: 12),
                        _buildSignalChainCard(colorScheme),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: _buildNamInspectorCard(colorScheme),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildUsbCard(colorScheme),
              const SizedBox(height: 12),
              _buildSignalChainCard(colorScheme),
              const SizedBox(height: 12),
              _buildNamInspectorCard(colorScheme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUsbCard(ColorScheme colorScheme) {
    final scan = _scanResult;
    String statusText = 'Not scanned yet. Connect FX200 via USB-C and click "Scan FX200 USB".';
    if (scan != null) {
      if (scan.errorMessage != null) {
        statusText = 'USB error: ${scan.errorMessage}';
      } else if (scan.devices.isEmpty) {
        statusText =
            'No devices found with VID 0x${Fx200Constants.usbVendorId.toRadixString(16).padLeft(4, '0')}.';
      } else {
        final summary = scan.devices
            .map((d) => '${d.hexVidPid} (bcd 0x${d.bcdDevice.toRadixString(16)})')
            .join(', ');
        statusText = 'Detected: $summary';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cable, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'USB Hardware Connection (libusb-1.0)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(statusText),
            const SizedBox(height: 6),
            Text(
              'Target VID 0x0483 · Known PIDs: ${Fx200Constants.usbProductIds.map((e) => '0x${e.toRadixString(16)}').join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalChainCard(ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FX200 Signal Chain (${Fx200Constants.effectModuleCount} Modules)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(
                Fx200Constants.defaultSignalChain.length,
                (index) {
                  final label = Fx200Constants.defaultSignalChain[index];
                  final selected = index == _selectedModuleIndex;
                  return ChoiceChip(
                    label: Text(label),
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
            const SizedBox(height: 12),
            Text(
              'IR Spec: ${Fx200Constants.irSampleRateHz} Hz · '
              '${Fx200Constants.irBitDepth}-bit · '
              '${Fx200Constants.irSamplePoints} pts · '
              '${Fx200Constants.presetPatchCount} presets',
              style: Theme.of(context).textTheme.bodySmall,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'NAM A2 / TONE3000 Capture Inspector',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _parseNamJson,
                  child: const Text('Validate .nam JSON'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _namJsonController,
              maxLines: 4,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Paste .nam JSON content',
              ),
            ),
            const SizedBox(height: 12),
            if (_namParseError != null)
              Text(
                'Parse error: $_namParseError',
                style: TextStyle(color: colorScheme.error),
              )
            else if (nam != null)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Name: ${nam.displayName}')),
                  Chip(label: Text('Arch: ${nam.architecture}')),
                  Chip(label: Text('Weights: ${nam.weightCount}')),
                  Chip(
                    label: Text(
                      'Rate: ${nam.sampleRate?.round() ?? 'unspecified'} Hz'
                      '${nam.needsSampleRateConversion ? ' (resample -> 44.1k)' : ''}',
                    ),
                  ),
                  Chip(
                    label: Text('M7 Budget: ${nam.dspCompatibility.name.toUpperCase()}'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
