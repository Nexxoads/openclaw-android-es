import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../constants.dart';
import '../providers/node_provider.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import '../services/update_service.dart';
import 'node_screen.dart';
import 'setup_wizard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = PreferencesService();
  bool _autoStart = false;
  bool _nodeEnabled = false;
  bool _batteryOptimized = true;
  String _arch = '';
  String _prootPath = '';
  Map<String, dynamic> _status = {};
  bool _loading = true;
  bool _goInstalled = false;
  bool _brewInstalled = false;
  bool _sshInstalled = false;
  bool _storageGranted = false;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _prefs.init();
    _autoStart = _prefs.autoStartGateway;
    _nodeEnabled = _prefs.nodeEnabled;

    try {
      final arch = await NativeBridge.getArch();
      final prootPath = await NativeBridge.getProotPath();
      final status = await NativeBridge.getBootstrapStatus();
      final batteryOptimized = await NativeBridge.isBatteryOptimized();

      final storageGranted = await NativeBridge.hasStoragePermission();

      // Check optional package statuses
      final filesDir = await NativeBridge.getFilesDir();
      final rootfs = '$filesDir/rootfs/ubuntu';
      final goInstalled = File('$rootfs/usr/bin/go').existsSync();
      final brewInstalled =
          File('$rootfs/home/linuxbrew/.linuxbrew/bin/brew').existsSync();
      final sshInstalled = File('$rootfs/usr/bin/ssh').existsSync();

      setState(() {
        _batteryOptimized = batteryOptimized;
        _storageGranted = storageGranted;
        _arch = arch;
        _prootPath = prootPath;
        _status = status;
        _goInstalled = goInstalled;
        _brewInstalled = brewInstalled;
        _sshInstalled = sshInstalled;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionHeader(theme, 'GENERAL'),
                SwitchListTile(
                  title: const Text('Iniciar gateway al abrir'),
                  subtitle: const Text('Arranca el gateway cuando se abre la app'),
                  value: _autoStart,
                  onChanged: (value) {
                    setState(() => _autoStart = value);
                    _prefs.autoStartGateway = value;
                  },
                ),
                ListTile(
                  title: const Text('Optimización de batería'),
                  subtitle: Text(_batteryOptimized
                      ? 'Optimizada (puede cerrar procesos en segundo plano)'
                      : 'Sin restricciones (recomendado)'),
                  leading: const Icon(Icons.battery_alert),
                  trailing: _batteryOptimized
                      ? const Icon(Icons.warning, color: AppColors.statusAmber)
                      : const Icon(Icons.check_circle, color: AppColors.statusGreen),
                  onTap: () async {
                    await NativeBridge.requestBatteryOptimization();
                    // Refresh status after returning from settings
                    final optimized = await NativeBridge.isBatteryOptimized();
                    setState(() => _batteryOptimized = optimized);
                  },
                ),
                ListTile(
                  title: const Text('Almacenamiento del entorno'),
                  subtitle: Text(_storageGranted
                      ? 'Concedido — proot puede acceder a /sdcard. Revoca si no lo necesitas.'
                      : 'No concedido — pulsa solo si lo necesitas'),
                  leading: const Icon(Icons.sd_storage),
                  trailing: _storageGranted
                      ? const Icon(Icons.warning_amber, color: AppColors.statusAmber)
                      : const Icon(Icons.check_circle, color: AppColors.statusGreen),
                  onTap: () async {
                    await NativeBridge.requestStoragePermission();
                    // Refresh after returning from permission screen
                    final granted = await NativeBridge.hasStoragePermission();
                    setState(() => _storageGranted = granted);
                  },
                ),
                const Divider(),
                _sectionHeader(theme, 'NODO'),
                SwitchListTile(
                  title: const Text('Activar nodo'),
                  subtitle: const Text('Ofrece capacidades del dispositivo al gateway'),
                  value: _nodeEnabled,
                  onChanged: (value) {
                    setState(() => _nodeEnabled = value);
                    _prefs.nodeEnabled = value;
                    final nodeProvider = context.read<NodeProvider>();
                    if (value) {
                      nodeProvider.enable();
                    } else {
                      nodeProvider.disable();
                    }
                  },
                ),
                ListTile(
                  title: const Text('Configuración del nodo'),
                  subtitle: const Text('Conexión, emparejamiento y capacidades'),
                  leading: const Icon(Icons.devices),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NodeScreen()),
                  ),
                ),
                const Divider(),
                _sectionHeader(theme, 'SISTEMA'),
                ListTile(
                  title: const Text('Arquitectura'),
                  subtitle: Text(_arch),
                  leading: const Icon(Icons.memory),
                ),
                ListTile(
                  title: const Text('Ruta PRoot'),
                  subtitle: Text(_prootPath),
                  leading: const Icon(Icons.folder),
                ),
                ListTile(
                  title: const Text('Rootfs'),
                  subtitle: Text(_status['rootfsExists'] == true
                      ? 'Instalado'
                      : 'No instalado'),
                  leading: const Icon(Icons.storage),
                ),
                ListTile(
                  title: const Text('Node.js'),
                  subtitle: Text(_status['nodeInstalled'] == true
                      ? 'Instalado'
                      : 'No instalado'),
                  leading: const Icon(Icons.code),
                ),
                ListTile(
                  title: const Text('OpenClaw'),
                  subtitle: Text(_status['openclawInstalled'] == true
                      ? 'Instalado'
                      : 'No instalado'),
                  leading: const Icon(Icons.cloud),
                ),
                ListTile(
                  title: const Text('Cloudflare tunnel'),
                  subtitle: Text(_status['cloudflaredInstalled'] == true
                      ? 'Instalado (acceso remoto)'
                      : 'No instalado'),
                  leading: const Icon(Icons.public),
                ),
                ListTile(
                  title: const Text('Go (Golang)'),
                  subtitle: Text(_goInstalled
                      ? 'Instalado'
                      : 'No instalado'),
                  leading: const Icon(Icons.integration_instructions),
                ),
                ListTile(
                  title: const Text('Homebrew'),
                  subtitle: Text(_brewInstalled
                      ? 'Instalado'
                      : 'No instalado'),
                  leading: const Icon(Icons.science),
                ),
                ListTile(
                  title: const Text('OpenSSH'),
                  subtitle: Text(_sshInstalled
                      ? 'Instalado'
                      : 'No instalado'),
                  leading: const Icon(Icons.vpn_key),
                ),
                const Divider(),
                _sectionHeader(theme, 'MANTENIMIENTO'),
                ListTile(
                  title: const Text('Exportar copia'),
                  subtitle: const Text('Guardar configuración en Descargas'),
                  leading: const Icon(Icons.upload_file),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportSnapshot,
                ),
                ListTile(
                  title: const Text('Importar copia'),
                  subtitle: const Text('Restaurar desde copia de seguridad'),
                  leading: const Icon(Icons.download),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _importSnapshot,
                ),
                ListTile(
                  title: const Text('Volver a instalar'),
                  subtitle: const Text('Reinstalar o reparar el entorno'),
                  leading: const Icon(Icons.build),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const SetupWizardScreen(),
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('Reiniciar entorno'),
                  subtitle: const Text(
                    'Limpia procesos y bloqueos del gateway y reinicia la app',
                  ),
                  leading: const Icon(Icons.restart_alt),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _confirmRestartEnvironment,
                ),
                const Divider(),
                _sectionHeader(theme, 'ACERCA DE'),
                ListTile(
                  title: const Text('OpenClaw ES'),
                  subtitle: Text(
                    'Gateway de IA para Android\nVersión ${AppConstants.version}',
                  ),
                  leading: const Icon(Icons.info_outline),
                  isThreeLine: true,
                ),
                ListTile(
                  title: const Text('Buscar actualizaciones'),
                  subtitle: const Text('Comprobar en GitHub si hay una versión nueva'),
                  leading: _checkingUpdate
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update),
                  onTap: _checkingUpdate ? null : _checkForUpdates,
                ),
                const ListTile(
                  title: Text('Desarrollador'),
                  subtitle: Text(AppConstants.authorName),
                  leading: Icon(Icons.person),
                ),
                ListTile(
                  title: const Text('GitHub'),
                  subtitle: const Text('mithun50/openclaw-termux'),
                  leading: const Icon(Icons.code),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.githubUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: const Text('Contacto'),
                  subtitle: const Text(AppConstants.authorEmail),
                  leading: const Icon(Icons.email),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse('mailto:${AppConstants.authorEmail}'),
                  ),
                ),
                const ListTile(
                  title: Text('Licencia'),
                  subtitle: Text(AppConstants.license),
                  leading: Icon(Icons.description),
                ),
                const Divider(),
                _sectionHeader(theme, AppConstants.orgName.toUpperCase()),
                ListTile(
                  title: const Text('Instagram'),
                  subtitle: const Text('@nexgenxplorer_nxg'),
                  leading: const Icon(Icons.camera_alt),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.instagramUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: const Text('YouTube'),
                  subtitle: const Text('@nexgenxplorer'),
                  leading: const Icon(Icons.play_circle_fill),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.youtubeUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: const Text('Play Store'),
                  subtitle: const Text('NextGenX Apps'),
                  leading: const Icon(Icons.shop),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.playStoreUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: const Text('Email'),
                  subtitle: const Text(AppConstants.orgEmail),
                  leading: const Icon(Icons.email_outlined),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse('mailto:${AppConstants.orgEmail}'),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmRestartEnvironment() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar entorno'),
        content: const Text(
          'Se limpiarán procesos Node, cloudflared y archivos de bloqueo del gateway, y la aplicación se reiniciará. '
          'Úsalo si el arranque queda bloqueado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    try {
      await NativeBridge.runGatewayPreFlightCleanup();
      await NativeBridge.restartApplication();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar el reinicio: $e')),
        );
      }
    }
  }

  Future<String> _getSnapshotPath() async {
    final hasPermission = await NativeBridge.hasStoragePermission();
    if (hasPermission) {
      final sdcard = await NativeBridge.getExternalStoragePath();
      final downloadDir = Directory('$sdcard/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return '$sdcard/Download/openclaw-snapshot.json';
    }
    // Fallback to app-private directory
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/openclaw-snapshot.json';
  }

  Future<void> _exportSnapshot() async {
    try {
      final openclawJson = await NativeBridge.readRootfsFile('root/.openclaw/openclaw.json');
      final snapshot = {
        'version': AppConstants.version,
        'timestamp': DateTime.now().toIso8601String(),
        'openclawConfig': openclawJson,
        'dashboardUrl': _prefs.dashboardUrl,
        'autoStart': _prefs.autoStartGateway,
        'nodeEnabled': _prefs.nodeEnabled,
        'nodeDeviceToken': _prefs.nodeDeviceToken,
        'nodeGatewayHost': _prefs.nodeGatewayHost,
        'nodeGatewayPort': _prefs.nodeGatewayPort,
        'nodeGatewayToken': _prefs.nodeGatewayToken,
      };

      final path = await _getSnapshotPath();
      final file = File(path);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(snapshot));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copia guardada en $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  Future<void> _importSnapshot() async {
    try {
      final path = await _getSnapshotPath();
      final file = File(path);

      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay copia en $path')),
        );
        return;
      }

      final content = await file.readAsString();
      final snapshot = jsonDecode(content) as Map<String, dynamic>;

      // Restore openclaw.json into rootfs
      final openclawConfig = snapshot['openclawConfig'] as String?;
      if (openclawConfig != null) {
        await NativeBridge.writeRootfsFile('root/.openclaw/openclaw.json', openclawConfig);
      }

      // Restore preferences
      if (snapshot['dashboardUrl'] != null) {
        _prefs.dashboardUrl = snapshot['dashboardUrl'] as String;
      }
      if (snapshot['autoStart'] != null) {
        _prefs.autoStartGateway = snapshot['autoStart'] as bool;
      }
      if (snapshot['nodeEnabled'] != null) {
        _prefs.nodeEnabled = snapshot['nodeEnabled'] as bool;
      }
      if (snapshot['nodeDeviceToken'] != null) {
        _prefs.nodeDeviceToken = snapshot['nodeDeviceToken'] as String;
      }
      if (snapshot['nodeGatewayHost'] != null) {
        _prefs.nodeGatewayHost = snapshot['nodeGatewayHost'] as String;
      }
      if (snapshot['nodeGatewayPort'] != null) {
        _prefs.nodeGatewayPort = snapshot['nodeGatewayPort'] as int;
      }
      if (snapshot['nodeGatewayToken'] != null) {
        _prefs.nodeGatewayToken = snapshot['nodeGatewayToken'] as String;
      }

      // Refresh UI
      await _loadSettings();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copia restaurada. Reinicia el gateway para aplicar.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al importar: $e')),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      final result = await UpdateService.check();
      if (!mounted) return;
      if (result.available) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Actualización disponible'),
            content: Text(
              'Hay una versión nueva.\n\n'
              'Actual: ${AppConstants.version}\n'
              'Última: ${result.latest}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Más tarde'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  launchUrl(
                    Uri.parse(result.url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text('Descargar'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya tienes la última versión')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo comprobar actualizaciones')),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
