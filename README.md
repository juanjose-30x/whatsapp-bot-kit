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
4. Cuando quede conectado, cierra con Ctrl+C y corre `cd ~/whatsapp-bot-kit-main && ./instalar.sh servicio`. Debe decir `Conectado: True`.
5. En Grokbot, agrega un conector MCP personalizado por URL con `http://127.0.0.1:8091/mcp`. No pide clave ni inicio de sesión.
6. Prueba: pídele a Grokbot que liste los últimos chats de WhatsApp.

Todo queda en `~/whatsapp-grokbot`. Registro: `~/whatsapp-grokbot/bridge.out`.

## Que el bot responda solo (avisos)
El conector solo le da herramientas a Grokbot; para que se active cuando entra un mensaje hay que encender los avisos:
1. Pídele a Grokbot un webhook (una URL pública que lo activa).
2. Corre `./instalar.sh avisos <URL>`. Queda un tercer servicio que revisa el puente cada 10 segundos y le envía a esa URL cada mensaje entrante nuevo (chat, nombre y texto).
3. Para limitar quién activa al bot, escribe los números permitidos en `~/whatsapp-grokbot/permitidos.txt`, uno por línea. Vacío = cualquiera.

Los grupos no generan aviso. Enciende los avisos en **un solo computador**. La URL del webhook es una llave: quien la tenga puede activar al bot.

## Otros clientes MCP
`./instalar.sh servicio` deja dos servicios: el puente de WhatsApp (puerto 8090) y el conector MCP por URL (puerto 8091). Los dos escuchan solo dentro de la Mac. Para un cliente que use comando en vez de URL: `uv --directory ~/whatsapp-grokbot/mcp-server run main.py` con `WHATSAPP_BRIDGE_PORT=8090`.

## Dos computadores (arriba y abajo)
Se instala en los dos: cada uno corre `./instalar.sh` y escanea su propio QR (WhatsApp permite hasta 4 dispositivos vinculados). Si se programa una respuesta automática, que quede en uno solo; si no, el bot responde doble.

## Reglas de la línea
- Primera semana: el bot solo responde y le escribe al equipo.
- Después: máximo 20 a 25 primeros mensajes por día, espaciados.
- El teléfono de la SIM debe conectarse a internet al menos cada 14 días.
- La sesión vence cada cierto tiempo: si `./instalar.sh estado` no dice conectado, se vuelve a escanear el QR.

## Créditos
Puente y servidor MCP de [adelaidasofia/whatsapp-mcp](https://github.com/adelaidasofia/whatsapp-mcp) (licencia MIT), con parches propios. Solo macOS.
