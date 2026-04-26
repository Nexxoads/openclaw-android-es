import 'native_bridge.dart';

/// Ajustes de seguridad y valores por defecto (V2) en `openclaw.json`.
class OpenClawV2Config {
  OpenClawV2Config._();

  static const defaultModelId = 'xiaomi/mimo-v2.5-pro';

  /// Fusiona claves V2 sin borrar API keys ni proveedores existentes.
  static Future<void> applySecurityAndDefaults() async {
    final script = r'''
const fs = require("fs");
const p = "/root/.openclaw/openclaw.json";
const DEFAULT_MODEL = "xiaomi/mimo-v2.5-pro";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch (_) {}
if (!c.gateway) c.gateway = {};
c.gateway.controlUi = c.gateway.controlUi || {};
c.gateway.controlUi.allowedOrigins = ["*"];
c.gateway.trustedProxies = ["127.0.0.1", "::1"];
if (!c.gateway.plugins) c.gateway.plugins = {};
if (!c.gateway.plugins.bonjour) c.gateway.plugins.bonjour = {};
c.gateway.plugins.bonjour.enabled = false;
if (!c.agents) c.agents = {};
if (!c.agents.defaults) c.agents.defaults = {};
if (!c.agents.defaults.model) c.agents.defaults.model = {};
if (!c.agents.defaults.model.primary) {
  c.agents.defaults.model.primary = DEFAULT_MODEL;
}
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
