import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../momcozy.dart';
import '../pump_ble.dart';
import '../pump_session.dart';
import 'common.dart';
import 'theme.dart';

/// Connects to Momcozy pumps and shows everything they report, with the raw
/// packets, to check the protocol against real pumps before pumping sessions
/// are logged from them.
class PumpLabPage extends StatelessWidget {
  const PumpLabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = PumpHub.instance;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const LText('Pump lab'),
          actions: [
            LIconButton(
              tooltip: 'Copy packet log',
              icon: const Icon(Icons.content_copy_rounded),
              onPressed: hub.pumps.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: hub.logText()));
                      showMessage(context, 'Packet log copied');
                    },
            ),
          ],
        ),
        body: PageWidth(
          maxWidth: 720,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (hub.problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    color: Baby.warn.withValues(alpha: 0.12),
                    child: ListTile(
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: Baby.warn,
                      ),
                      title: LText(hub.problem!),
                    ),
                  ),
                ),
              if (hub.pumps.isNotEmpty) ...[
                SectionTitle(
                  'Connected pumps',
                  trailing: hub.ready.length > 1
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LText('Both'),
                            Switch(value: hub.both, onChanged: hub.setBoth),
                          ],
                        )
                      : null,
                ),
                for (final p in hub.pumps.values) _PumpCard(pump: p),
              ],
              SectionTitle(
                'Find pumps',
                trailing: hub.scanning
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              ListCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bluetooth_searching_rounded),
                    title: LText(
                      hub.scanning ? 'Stop looking' : 'Look for pumps',
                    ),
                    subtitle: const LText(
                      'Switch the pumps on and close the Momcozy app first.',
                    ),
                    onTap: hub.scanning ? hub.stopScan : hub.startScan,
                  ),
                  SwitchListTile(
                    title: const LText('Show all Bluetooth devices'),
                    value: hub.showAll,
                    onChanged: hub.setShowAll,
                  ),
                  for (final f in hub.found.values)
                    if (!hub.pumps.containsKey(f.id) &&
                        (hub.showAll || f.model != null))
                      ListTile(
                        leading: Icon(
                          f.model == null
                              ? Icons.bluetooth_rounded
                              : Icons.water_drop_rounded,
                          color: f.model == null ? Baby.muted : Baby.primary,
                        ),
                        title: Text(f.name),
                        subtitle: Text(
                          [
                            if (f.model != null) _modelName(f.model!),
                            f.id,
                            if (f.device.rssi != null) '${f.device.rssi} dBm',
                          ].join(' · '),
                        ),
                        trailing: const LText('Connect'),
                        onTap: () => hub.connect(f.id, f.name),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _modelName(PumpModel m) => switch (m) {
  PumpModel.m5Pro => 'M5 Pro / BP380',
  PumpModel.m9 => 'M9',
  PumpModel.m9Pro => 'M9 Pro',
  PumpModel.m10 => 'M10',
  PumpModel.air1 => 'Air 1',
};

String _modeName(PumpMode? m) => switch (m) {
  PumpMode.massage => 'Massage',
  PumpMode.expression => 'Expression',
  PumpMode.mixed => 'Mixed',
  PumpMode.custom => 'Custom',
  PumpMode.auto => 'Auto',
  null => '?',
};

String _stateName(PumpStatus s) => switch (s.runState) {
  PumpRunState.running => 'Pumping',
  PumpRunState.stopped || PumpRunState.paused => 'Paused',
  PumpRunState.off => 'Off',
  null => 'State ${s.runStateCode}',
};

String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

class _PumpCard extends StatelessWidget {
  const _PumpCard({required this.pump});
  final ConnectedPump pump;

  @override
  Widget build(BuildContext context) {
    final hub = PumpHub.instance;
    final s = pump.session;
    final status = s?.status;
    final info = s?.info;
    final ready = pump.state == PumpLinkState.ready;
    // The BP380 offers these three; other models add custom and auto.
    final modes = s?.model == PumpModel.m5Pro
        ? const [PumpMode.massage, PumpMode.expression, PumpMode.mixed]
        : PumpMode.values;
    final running = status?.runState == PumpRunState.running;

    Future<void> act(Future<void> Function(PumpSession s) f) =>
        hub.control(hub.both ? null : pump, f);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LText(
                    pump.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (status != null)
                  Text(
                    '${status.battery}%',
                    style: TextStyle(color: Baby.muted),
                  ),
                LIconButton(
                  tooltip: 'Disconnect',
                  icon: const Icon(Icons.link_off_rounded),
                  onPressed: () => hub.disconnect(pump.id),
                ),
              ],
            ),
            Text(
              [
                info?.serial ?? pump.id,
                if (info != null)
                  'firmware ${info.firmwareVersion}, hardware ${info.hardwareVersion}',
              ].join('\n'),
              style: TextStyle(color: Baby.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (pump.state == PumpLinkState.connecting)
              const LText('Connecting…')
            else if (pump.state == PumpLinkState.failed)
              Text(pump.error ?? 'Failed', style: TextStyle(color: Baby.error))
            else if (status != null) ...[
              Text(
                '${tr(_stateName(status))} · ${tr(_modeName(status.mode))} · '
                '${tr('level')} ${status.level} · ${_clock(status.totalSeconds)}'
                '${status.milkMl > 0 ? ' · ${status.milkMl} ml' : ''}'
                '${status.errorCode != 0 ? ' · ${tr('error')} ${status.errorCode}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in modes)
                    ChoiceChip(
                      label: LText(_modeName(m)),
                      selected: status.mode == m,
                      onSelected: (_) => act((s) => s.setMode(m)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: tr('Lower'),
                    icon: const Icon(Icons.remove_rounded),
                    onPressed: () => act((s) => s.changeLevel(-1)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${status.level} / ${s!.model.maxLevel}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: tr('Higher'),
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => act((s) => s.changeLevel(1)),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: Icon(
                      running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    label: LText(running ? 'Pause' : 'Start'),
                    onPressed: () =>
                        act((s) => running ? s.pause() : s.resume()),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.history_rounded),
                    label: const LText('Read history'),
                    onPressed: ready ? () => _readHistory(context) : null,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.power_settings_new_rounded),
                    label: const LText('Switch off'),
                    onPressed: () => act((s) => s.switchOff()),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _readHistory(BuildContext context) async {
    List<PumpHistoryRecord> records;
    try {
      records = await PumpHub.instance.importHistory(pump);
    } catch (e) {
      if (context.mounted) showMessage(context, '$e');
      return;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => records.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: LText('The pump has no stored records.'),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: LText(
                    'Saved on this phone; the pump no longer has these.',
                    style: TextStyle(color: Baby.muted),
                  ),
                ),
                for (final r in records)
                  ListTile(
                    dense: true,
                    title: Text(
                      '${r.event?.name ?? 'event ${r.eventCode}'} · '
                      '${_modeName(r.mode)} ${r.level}'
                      '${r.milkMl > 0 ? ' · ${r.milkMl} ml' : ''}',
                    ),
                    subtitle: Text(
                      '${r.time.toLocal()} · state ${r.runStateCode} · '
                      'battery ${r.battery}%',
                    ),
                  ),
              ],
            ),
    );
  }
}
