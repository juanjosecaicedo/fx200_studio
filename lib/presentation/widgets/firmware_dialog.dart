import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../services/fx200_firmware.dart';
import '../../services/fx200_firmware_updater.dart';
import '../state/editor_notifier.dart';
import '../../core/l10n/l10n.dart';

Future<void> showFirmwareDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const FirmwareDialog(),
  );
}

enum _Phase { choose, ready, running, done, failed }

/// FIRMWARE UPDATE (Software Guide p. 17 / Manual p. 59): flashes an `.fl`
/// file with the same protocol as the official updater, to the pedal booted
/// in update mode (hold VALUE while switching it on).
class FirmwareDialog extends ConsumerStatefulWidget {
  const FirmwareDialog({super.key});

  @override
  ConsumerState<FirmwareDialog> createState() => _FirmwareDialogState();
}

class _FirmwareDialogState extends ConsumerState<FirmwareDialog> {
  _Phase _phase = _Phase.choose;
  Fx200FirmwareImage? _image;
  String? _fileName;
  String? _error;
  bool _deviceFound = false;
  bool _confirmBackup = false;
  bool _confirmUnofficial = false;
  Timer? _poll;
  StreamSubscription<Fx200UpdateEvent>? _sub;
  int _done = 0;
  int _total = 1;
  String _step = '';
  List<String> _deviceInfo = const <String>[];
  DateTime? _startedAt;

  static XTypeGroup get _fl =>
      XTypeGroup(label: tr('FX200 firmware'), extensions: <String>['fl']);

  @override
  void initState() {
    super.initState();
    _checkDevice();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _checkDevice());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _checkDevice() {
    if (_phase == _Phase.running) return;
    final found = fx200UpdateModeConnected();
    if (found != _deviceFound && mounted) setState(() => _deviceFound = found);
  }

  Future<void> _choose() async {
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[_fl]);
    if (file == null) return;
    try {
      final image = Fx200FirmwareImage.parse(
        await File(file.path).readAsBytes(),
      );
      setState(() {
        _image = image;
        _fileName = file.name;
        _error = null;
        _confirmUnofficial = false;
        _phase = _Phase.ready;
      });
    } catch (e) {
      setState(() {
        _image = null;
        _error = '${file.name}: $e';
        _phase = _Phase.choose;
      });
    }
  }

  bool get _canStart {
    final image = _image;
    return (_phase == _Phase.ready || _phase == _Phase.failed) &&
        image != null &&
        _deviceFound &&
        _confirmBackup &&
        (image.officialName != null || _confirmUnofficial);
  }

  void _start() {
    final image = _image;
    if (image == null || !_canStart) return;
    final editor = ref.read(editorProvider.notifier);
    editor.setFirmwareUpdateActive(true);
    setState(() {
      _phase = _Phase.running;
      _done = 0;
      _total = image.totalBlocks;
      _step = 'Starting';
      _startedAt = DateTime.now();
    });
    _sub = fx200FlashFirmware(image.bytes).listen((e) {
      if (!mounted) return;
      switch (e) {
        case Fx200UpdateProgress(:final done, :final total, :final step):
          setState(() {
            _done = done;
            _total = total;
            _step = step;
          });
        case Fx200UpdateDeviceInfo(:final info):
          setState(() => _deviceInfo = info);
        case Fx200UpdateFinished(:final error):
          setState(() {
            _phase = error == null ? _Phase.done : _Phase.failed;
            _error = error;
          });
          editor.setFirmwareUpdateActive(false);
      }
    });
  }

  String get _eta {
    final start = _startedAt;
    if (start == null || _done < 32) return '';
    final elapsed = DateTime.now().difference(start).inSeconds;
    final left = (elapsed * (_total - _done) / _done).round();
    return tr(' · about {0} min {1} s left', [left ~/ 60, left % 60]);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final warn = ext.colorFor(EffectCategory.drive);
    final ok = ext.colorFor(EffectCategory.amp);
    final image = _image;
    final running = _phase == _Phase.running;

    Widget stepText(String n, String s) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 20, child: Text(n, style: text.labelLarge)),
          Expanded(child: Text(s, style: text.bodySmall)),
        ],
      ),
    );

    final children = <Widget>[
      stepText(
        '1',
        tr('Make a BACKUP first: an update can reset presets and IRs.'),
      ),
      stepText(
        '2',
        tr(
          'Switch the FX200 off, then hold the VALUE knob while switching it on. It boots in update mode.',
        ),
      ),
      stepText(
        '3',
        tr('Keep it connected by USB, choose the .fl file and START.'),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Icon(
            _deviceFound ? Icons.check_circle : Icons.usb_off,
            size: 18,
            color: _deviceFound ? ok : ext.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _deviceFound
                  ? tr('FX200 in update mode detected')
                  : tr(
                      'Waiting for the FX200 in update mode (USB 0483:5703)...',
                    ),
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          OutlinedButton.icon(
            onPressed: running ? null : _choose,
            icon: const Icon(Icons.folder_open, size: 16),
            label: Text(tr('CHOOSE .FL FILE...')),
          ),
          const SizedBox(width: 12),
          if (_fileName != null)
            Expanded(
              child: Text(
                _fileName!,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall,
              ),
            ),
        ],
      ),
      if (image != null) ...[
        const SizedBox(height: 10),
        Text(
          image.officialName != null
              ? tr('Official firmware: {0}', [image.officialName])
              : tr(
                  'Unknown firmware (not a known official release). It may be modified or damaged.',
                ),
          style: text.bodyMedium?.copyWith(
            color: image.officialName != null ? ok : warn,
          ),
        ),
        const SizedBox(height: 4),
        for (final s in image.sections)
          Text(
            tr('• {0}: {1} KB', [s.description, (s.size / 1024).round()]),
            style: text.bodySmall?.copyWith(color: ext.textMuted),
          ),
        Text(
          tr('SHA-256 {0}...', [image.sha256Hex.substring(0, 16)]),
          style: text.bodySmall?.copyWith(color: ext.textMuted),
        ),
      ],
      if (_phase == _Phase.ready) ...[
        const SizedBox(height: 8),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: _confirmBackup,
          onChanged: (v) => setState(() => _confirmBackup = v ?? false),
          title: Text(
            tr(
              'I have a backup and will not unplug or switch off the pedal until the update finishes.',
            ),
            style: text.bodySmall,
          ),
        ),
        if (image?.officialName == null)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _confirmUnofficial,
            onChanged: (v) => setState(() => _confirmUnofficial = v ?? false),
            title: Text(
              tr(
                'I understand this is not an official firmware and may leave the pedal unusable.',
              ),
              style: text.bodySmall?.copyWith(color: warn),
            ),
          ),
      ],
      if (running || _phase == _Phase.done || _phase == _Phase.failed) ...[
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: _total == 0 ? null : _done / _total,
          minHeight: 6,
          valueColor: AlwaysStoppedAnimation<Color>(
            _phase == _Phase.failed ? warn : ok,
          ),
          backgroundColor: ext.blockSurface,
        ),
        const SizedBox(height: 6),
        Text(
          tr('{0} · {1} / {2} blocks{3}', [tr(_step), _done, _total, _eta]),
          style: text.bodySmall,
        ),
        if (_deviceInfo.isNotEmpty)
          Text(
            tr('Device: {0}', [_deviceInfo.join('  ')]),
            style: text.bodySmall?.copyWith(color: ext.textMuted),
          ),
      ],
      if (running)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            tr('Do not unplug or switch off the FX200.'),
            style: text.bodyMedium?.copyWith(color: warn),
          ),
        ),
      if (_phase == _Phase.done)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            tr(
              'Update complete. The FX200 restarts with the new firmware; restore your backup if presets or IRs were reset.',
            ),
            style: text.bodyMedium?.copyWith(color: ok),
          ),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _phase == _Phase.failed
                ? tr(
                    '{0}\nThe pedal stays in update mode: you can start the update again.',
                    [_error],
                  )
                : _error!,
            style: text.bodySmall?.copyWith(color: warn),
          ),
        ),
    ];

    return Dialog(
      backgroundColor: ext.panelSurface,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: ext.subtleBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tr('FIRMWARE UPDATE'), style: text.titleSmall),
                  ),
                  IconButton(
                    tooltip: running
                        ? tr('Wait for the update to finish')
                        : 'Close',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: running
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: warn),
                  onPressed: _canStart ? _start : null,
                  icon: const Icon(Icons.system_update_alt, size: 16),
                  label: Text(
                    _phase == _Phase.failed ? tr('RETRY') : tr('START'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
