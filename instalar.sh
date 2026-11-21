#!/usr/bin/env bash
# Kit WhatsApp para Grokbot · instala el puente de WhatsApp (adelaidasofia/whatsapp-mcp) en esta Mac.
#   ./instalar.sh            instala y abre el puente para escanear el QR
#   ./instalar.sh servicio   lo deja corriendo solo (arranca al iniciar sesión)
#   ./instalar.sh mcp        muestra la URL del conector MCP para Grokbot
#   ./instalar.sh estado     dice si la línea está conectada
#   ./instalar.sh quitar     apaga el servicio (no borra la sesión)
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/whatsapp-grokbot"
PUERTO="${PUERTO:-8090}"
LABEL="com.30x.wa-bridge-grokbot"
LABEL_MCP="com.30x.wa-mcp-grokbot"
PUERTO_MCP="${PUERTO_MCP:-8091}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
PLIST_MCP="$HOME/Library/LaunchAgents/$LABEL_MCP.plist"
UV="$(command -v uv || true)"; [ -z "$UV" ] && [ -x "$HOME/.local/bin/uv" ] && UV="$HOME/.local/bin/uv"

instalar() {
  case "$(uname -m)" in arm64) BIN=whatsapp-bridge-arm64 ;; *) BIN=whatsapp-bridge-amd64 ;; esac
  mkdir -p "$DEST/store" "$DEST/media" "$DEST/mcp-server"
  cp "$AQUI/bin/$BIN" "$DEST/whatsapp-bridge"
  cp "$AQUI/mcp-server/"* "$DEST/mcp-server/"
  chmod +x "$DEST/whatsapp-bridge"
  xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
  codesign --force -s - "$DEST/whatsapp-bridge" 2>/dev/null || true
  if [ ! -f "$DEST/.env" ]; then cat > "$DEST/.env" <<EOF
WHATSAPP_BRIDGE_PORT=$PUERTO
WHATSAPP_BRIDGE_HOST=127.0.0.1
WHATSAPP_DB_PATH=$DEST/store/messages.db
WHATSAPP_MEDIA_PATH=$DEST/media/
WHATSAPP_BACKUP_INTERVAL_HOURS=0
WHATSAPP_ENCRYPT_DB=true
WHATSAPP_KEYCHAIN_SERVICE=whatsapp-grokbot
WHATSAPP_KEYCHAIN_ACCOUNT=default
WHATSAPP_WHISPER_BACKEND=off
WHATSAPP_SCRUB_PROMPT_INJECTION=true
WHATSAPP_AUDIT_LOG=true
WHATSAPP_AUDIT_LOG_PATH=$DEST/audit.log
WHATSAPP_CAPTURE_CALLS=true
WHATSAPP_AUTO_DOWNLOAD_MEDIA=false
EOF
  fi
  if [ -z "$UV" ]; then
    echo; echo "Falta 'uv' (lo usa el servidor MCP). Instálalo con:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "y vuelve a correr ./instalar.sh"; exit 1
  fi
  (cd "$DEST/mcp-server" && "$UV" sync --quiet) && echo "Servidor MCP listo."
  echo
  echo "Ahora escanea el QR con el teléfono de la línea del bot:"
  echo "  WhatsApp > Dispositivos vinculados > Vincular un dispositivo"
  echo "Si macOS pide acceso al Llavero, elige «Permitir siempre»."
  echo "Cuando diga que quedó conectado, cierra con Ctrl+C y corre:  ./instalar.sh servicio"
  echo
  cd "$DEST" && exec ./whatsapp-bridge
}

servicio() {
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$DEST/whatsapp-bridge</string></array>
  <key>WorkingDirectory</key><string>$DEST</string>
  <key>EnvironmentVariables</key><dict><key>MYCELIUM_NO_PING</key><string>1</string></dict>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>20</integer>
  <key>StandardOutPath</key><string>$DEST/bridge.out</string>
  <key>StandardErrorPath</key><string>$DEST/bridge.out</string>
</dict></plist>
EOF
  [ -z "$UV" ] && { echo "Falta uv; corre primero ./instalar.sh"; exit 1; }
  cat > "$PLIST_MCP" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL_MCP</string>
  <key>ProgramArguments</key><array><string>$UV</string><string>--directory</string><string>$DEST/mcp-server</string><string>run</string><string>main.py</string></array>
  <key>WorkingDirectory</key><string>$DEST/mcp-server</string>
  <key>EnvironmentVariables</key><dict>
    <key>WHATSAPP_BRIDGE_HOST</key><string>127.0.0.1</string>
    <key>WHATSAPP_BRIDGE_PORT</key><string>$PUERTO</string>
    <key>WHATSAPP_MCP_HTTP_PORT</key><string>$PUERTO_MCP</string>
    <key>WHATSAPP_AUDIT_LOG_PATH</key><string>$DEST/audit.log</string>
    <key>PATH</key><string>$(dirname "$UV"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>20</integer>
  <key>StandardOutPath</key><string>$DEST/mcp.out</string>
  <key>StandardErrorPath</key><string>$DEST/mcp.out</string>
</dict></plist>
EOF
  for L in "$LABEL" "$LABEL_MCP"; do launchctl bootout "gui/$(id -u)/$L" 2>/dev/null || true; done
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  launchctl bootstrap "gui/$(id -u)" "$PLIST_MCP"
  sleep 12; estado
}

estado() {
  curl -s --max-time 5 "http://127.0.0.1:$PUERTO/api/status" | python3 -c '
import sys,json
try: d=json.load(sys.stdin)
except Exception: print("El puente no responde. Mira el registro en ~/whatsapp-grokbot/bridge.out"); sys.exit(1)
print("Conectado:", d.get("connected"), "· Sesión:", d.get("auth_state"), "· Número:", (d.get("device_jid") or "").split(":")[0].split("@")[0])'
  if curl -s -o /dev/null --max-time 5 "http://127.0.0.1:$PUERTO_MCP/mcp"; then echo "Conector MCP: arriba en http://127.0.0.1:$PUERTO_MCP/mcp"; else echo "Conector MCP: no responde. Mira ~/whatsapp-grokbot/mcp.out"; fi
}

mcp() {
  echo "URL del conector MCP para Grokbot:"
  echo
  echo "  http://127.0.0.1:$PUERTO_MCP/mcp"
  echo
  echo "No pide clave ni inicio de sesión. Solo responde dentro de esta Mac."
}

case "${1:-instalar}" in
  instalar) instalar ;; servicio) servicio ;; estado) estado ;; mcp) mcp ;;
  quitar) for L in "$LABEL" "$LABEL_MCP"; do launchctl bootout "gui/$(id -u)/$L" 2>/dev/null || true; done; rm -f "$PLIST" "$PLIST_MCP"; echo "Servicio apagado. La sesión sigue en $DEST." ;;
  *) sed -n 2,7p "$0" ;;
esac
