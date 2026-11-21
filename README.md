# Kit WhatsApp para Grokbot

Deja una línea de WhatsApp conectada a Grokbot con el mismo MCP que ya usamos (adelaidasofia/whatsapp-mcp). No hay versión especial para Grokbot: es un servidor MCP estándar.

## Antes de ir
- La SIM activa en un teléfono, con el número registrado en WhatsApp Business.
- Internet en el computador.

## En la Mac donde corre Grokbot (10 minutos)
1. Abre Terminal y pega esto (descarga el kit y arranca el instalador):
   ```bash
   cd ~ && curl -L https://github.com/juanjose-30x/whatsapp-bot-kit/archive/refs/heads/main.tar.gz | tar xz && cd whatsapp-bot-kit-main && ./instalar.sh
   ```
   - Si dice que falta `uv`, corre el comando que muestra y repite.
2. Aparece un QR. En el teléfono de la línea: WhatsApp > Dispositivos vinculados > Vincular un dispositivo.
3. Si macOS pide acceso al Llavero, elige **Permitir siempre**.
4. Cuando quede conectado, cierra con Ctrl+C y corre `cd ~/whatsapp-bot-kit-main && ./instalar.sh servicio`. Debe decir `Conectado: True`.
5. Corre `./instalar.sh mcp` y pega ese bloque en Grokbot, donde se agregan servidores MCP.
6. Prueba: pídele a Grokbot que liste los últimos chats de WhatsApp.

Todo queda en `~/whatsapp-grokbot`. Registro: `~/whatsapp-grokbot/bridge.out`.

## Si Grokbot no acepta servidores MCP locales
El puente responde en `http://127.0.0.1:8090` y Grokbot lo puede usar con comandos locales:
- Leer: `curl "http://127.0.0.1:8090/api/messages?chat_jid=<numero>@s.whatsapp.net&limit=20"`
- Enviar (dos pasos): `POST /api/sends` con `{"recipient_jid","send_type":"text","text"}` y luego `POST /api/sends/<draft_id>/confirm`.

## Dos computadores (arriba y abajo)
Se instala en los dos: cada uno corre `./instalar.sh` y escanea su propio QR (WhatsApp permite hasta 4 dispositivos vinculados). Si se programa una respuesta automática, que quede en uno solo; si no, el bot responde doble.

## Reglas de la línea
- Primera semana: el bot solo responde y le escribe al equipo.
- Después: máximo 20 a 25 primeros mensajes por día, espaciados.
- El teléfono de la SIM debe conectarse a internet al menos cada 14 días.
- La sesión vence cada cierto tiempo: si `./instalar.sh estado` no dice conectado, se vuelve a escanear el QR.

## Créditos
Puente y servidor MCP de [adelaidasofia/whatsapp-mcp](https://github.com/adelaidasofia/whatsapp-mcp) (licencia MIT), con parches propios. Solo macOS.
