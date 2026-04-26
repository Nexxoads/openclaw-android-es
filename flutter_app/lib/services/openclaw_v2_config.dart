import 'native_bridge.dart';

/// Ajustes de seguridad y valores por defecto (V2) en `openclaw.json`.
class OpenClawV2Config {
  OpenClawV2Config._();

  /// Fusiona claves V2 sin borrar API keys ni proveedores existentes.
  static Future<void> applySecurityAndDefaults() async {
    final script = r'''
const fs = require("fs");
const p = "/root/.openclaw/openclaw.json";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch (_) {}
if (!c.gateway) c.gateway = {};
if (!c.gateway.mode) c.gateway.mode = "local";
c.gateway.controlUi = c.gateway.controlUi || {};
c.gateway.controlUi.allowedOrigins = ["*"];
c.gateway.trustedProxies = ["127.0.0.1", "::1"];
if (!c.gateway.plugins) c.gateway.plugins = {};
if (!c.gateway.plugins.bonjour) c.gateway.plugins.bonjour = {};
c.gateway.plugins.bonjour.enabled = false;
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    try {
      await NativeBridge.runInProot(
        'node -e ${_shellEscape(script)}',
        timeout: 30,
      );
    } catch (_) {
      // Fallback: si node/proot falla, el gateway puede aplicar en el siguiente arranque.
    }
  }

  static String _shellEscape(String s) {
    return "'${s.replaceAll("'", "'\\''")}'";
  }
}
