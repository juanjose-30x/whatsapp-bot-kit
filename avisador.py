#!/usr/bin/env python3
"""Avisador: vigila el puente de WhatsApp y avisa por webhook cuando llega un mensaje nuevo.

El puente no avisa solo, así que este programa revisa cada pocos segundos los chats,
detecta mensajes entrantes nuevos y hace un POST a la URL guardada en webhook.url.
Solo usa la biblioteca estándar de Python.
"""
import json, os, sys, time, urllib.request, urllib.parse

DIR = os.environ.get("AVISADOR_DIR", os.path.expanduser("~/whatsapp-grokbot"))
PUENTE = "http://127.0.0.1:%s" % os.environ.get("WHATSAPP_BRIDGE_PORT", "8090")
CADA = int(os.environ.get("AVISADOR_CADA_SEGUNDOS", "10"))
GRUPOS = os.environ.get("AVISADOR_GRUPOS", "0") == "1"
ESTADO = os.path.join(DIR, "avisador-estado.json")


def log(*a):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), *a, flush=True)


def leer(nombre):
    try:
        return open(os.path.join(DIR, nombre)).read()
    except OSError:
        return ""


def get(ruta, **q):
    url = PUENTE + ruta + ("?" + urllib.parse.urlencode(q) if q else "")
    with urllib.request.urlopen(url, timeout=15) as r:
        return json.load(r)


def permitidos():
    """Números de permitidos.txt (uno por línea). Vacío o sin archivo = todos."""
    out = set()
    for linea in leer("permitidos.txt").splitlines():
        n = "".join(c for c in linea.split("#")[0] if c.isdigit())
        if n:
            out.add(n)
    return out


def avisar(url, cuerpo):
    req = urllib.request.Request(url, data=json.dumps(cuerpo).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.status


def main():
    try:
        estado = json.load(open(ESTADO))
    except (OSError, ValueError):
        estado = None  # primera vez: se toma nota de lo que hay y no se avisa nada viejo
    log("avisador arriba; puente", PUENTE, "cada", CADA, "s")
    while True:
        url = leer("webhook.url").strip()
        try:
            chats = get("/api/chats", limit=40).get("chats", [])
            primera = estado is None
            if primera:
                estado = {}
            lista = permitidos()
            for c in chats:
                jid, ult = c["jid"], c.get("last_message_time", 0)
                previo = estado.get(jid)
                if previo is not None and ult <= previo.get("chat", 0):
                    continue
                visto = (previo or {}).get("msg", 0)
                d = get("/api/messages", chat_jid=jid, limit=10)
                msgs = d.get("messages", d) if isinstance(d, dict) else d
                nuevos = sorted((m for m in msgs if m.get("timestamp", 0) > visto), key=lambda m: m["timestamp"])
                tope = max([m.get("timestamp", 0) for m in msgs] + [visto])
                estado[jid] = {"chat": ult, "msg": tope}
                if primera or previo is None and not nuevos:
                    continue
                es_grupo = jid.endswith("@g.us") or c.get("chat_type") == "group"
                numero = jid.split("@")[0].split(":")[0]
                entrantes = [m for m in nuevos if not m.get("is_from_me")]
                if not entrantes or (es_grupo and not GRUPOS) or jid.endswith("@broadcast") or jid.endswith("@newsletter"):
                    continue
                if lista and not es_grupo and numero not in lista:
                    log("ignorado (no está en permitidos.txt):", numero)
                    continue
                if not url:
                    log("mensaje nuevo de", numero, "pero no hay webhook.url")
                    continue
                cuerpo = {
                    "origen": "whatsapp",
                    "evento": "mensaje_nuevo",
                    "chat_jid": jid,
                    "nombre": c.get("name") or numero,
                    "es_grupo": es_grupo,
                    "mensajes": [{"de": m.get("sender_display") or m.get("sender_jid", ""), "tipo": m.get("type", ""),
                                  "texto": m.get("content_text") or "", "hora": m.get("timestamp")} for m in entrantes],
                }
                try:
                    log("aviso enviado:", numero, "→ HTTP", avisar(url, cuerpo))
                except Exception as e:  # el aviso falló: se reintenta en la siguiente vuelta
                    log("aviso falló:", numero, repr(e))
                    estado[jid] = previo or {"chat": 0, "msg": visto}
            tmp = ESTADO + ".tmp"
            json.dump(estado, open(tmp, "w"))
            os.replace(tmp, ESTADO)
        except Exception as e:
            log("vuelta falló:", repr(e))
        time.sleep(CADA)


if __name__ == "__main__":
    sys.exit(main())
