# OpenReply en Railway, paso a paso (en español)

Todo vive en **un solo proyecto de Railway** con **3 cajitas**:

| Cajita | Qué hace |
| --- | --- |
| `Postgres` | Guarda tus campañas y mensajes |
| `Redis` | La fila de mensajes por mandar |
| `web` (tu repo) | La página, el robot que manda los DMs y la tarea diaria que renueva el token de Instagram |

El servicio `web` arranca las tres cosas solo, con `scripts/railway-start.sh`, y aplica las migraciones de la base de datos en cada deploy. No hace falta terminal.

## Paso 1: Agregar Postgres y Redis

En tu proyecto de Railway: **+ Create → Database → PostgreSQL**. Luego otra vez: **+ Create → Database → Redis**.

## Paso 2: Darle una dirección a tu página

Abre el servicio de tu repo → **Settings → Networking → Generate Domain**. Copia la dirección que sale (por ejemplo `web-production-1234.up.railway.app`). En esta guía la llamamos **TU-DOMINIO**.

## Paso 3: Pegar las variables

Servicio de tu repo → **Variables → Raw Editor**, pega esto y cambia lo que está entre `< >`:

```env
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}?family=0
NEXTAUTH_SECRET=<secreto>
CRON_SECRET=<secreto>
ENCRYPTION_KEY=<secreto de 64 letras y números>
WEBHOOK_VERIFY_TOKEN=<secreto>
RESEND_API_KEY=<tu llave de Resend>
EMAIL_FROM=OpenReply <onboarding@resend.dev>
ALLOWED_EMAILS=<tu correo>
INSTAGRAM_APP_ID=<de Meta>
INSTAGRAM_APP_SECRET=<de Meta>
FACEBOOK_APP_SECRET=<de Meta>
```

`NEXTAUTH_URL` se llena solo con TU-DOMINIO. Los secretos se generan con `openssl rand -hex 32`.

## Paso 4: Resend (el correo para entrar)

Para entrar, OpenReply te manda un enlace a tu correo. Crea una cuenta gratis en [resend.com](https://resend.com) → **API Keys → Create API Key** y pégala en `RESEND_API_KEY`. Sin dominio propio, entra a OpenReply con **el mismo correo de tu cuenta de Resend** (es el único al que Resend deja mandar desde `onboarding@resend.dev`).

## Paso 5: Revisar que está vivo

Abre `https://TU-DOMINIO/api/health`. Tiene que decir `"status":"ok"`. Luego entra a `https://TU-DOMINIO/login`.

## Paso 6: Meta

En [developers.facebook.com/apps](https://developers.facebook.com/apps) → tu app → **Instagram → API setup with Instagram login**:

1. Copia **Instagram app ID** e **Instagram app secret** a las variables. El **App secret** de *App settings → Basic* va en `FACEBOOK_APP_SECRET`.
2. **Roles → Instagram testers** → agrega tu usuario. En la app de Instagram: *Configuración → Apps y sitios web → Invitaciones de tester → Aceptar*.
3. **OAuth redirect URI:** `https://TU-DOMINIO/api/instagram/callback`
4. **Webhooks:** Callback URL `https://TU-DOMINIO/api/webhook`, Verify token = tu `WEBHOOK_VERIFY_TOKEN`, y suscríbete a `comments` y `messages`.
5. **Publish:** pon `https://TU-DOMINIO/privacy`, `https://TU-DOMINIO/terms` y `https://TU-DOMINIO/data-deletion`, y publica. Si la app no está publicada, Meta no manda los comentarios.

Tu Instagram tiene que ser cuenta **Business o Creator**.

## Paso 7: Probar

En OpenReply: **Settings → Connect Instagram**, crea una campaña con la palabra `TEST`, y desde **otra** cuenta comenta `TEST` en ese post. Te debe llegar el DM.

Más detalle (en inglés): [setup.md](setup.md).
