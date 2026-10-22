# Desplegar OpenReply todo en Railway (guía en español)

Esta guía monta OpenReply completo en **un solo proyecto de Railway**, sin Vercel y sin terminal:

| Servicio en Railway | Qué es | Archivo de config |
| --- | --- | --- |
| `Postgres` | Base de datos | (plantilla de Railway) |
| `Redis` | Cola de envíos | (plantilla de Railway) |
| `web` | Dashboard, login, webhook de Meta | `railway.json` (por defecto) |
| `worker` | Proceso que **manda los DMs** | `railway/worker.json` |
| `cron` | Refresca tokens de Instagram cada día, etc. | `railway/cron.json` |

Los tres servicios de código salen del mismo repo y del mismo `Dockerfile`; solo cambia el comando de arranque. Las migraciones de la base de datos se aplican solas en el servicio `web` (pre-deploy), así que **no necesitas correr `npm run db:migrate` desde tu máquina**.

## 1. Bases de datos

En el proyecto de Railway: **+ New → Database → Add PostgreSQL**, y luego **+ New → Database → Add Redis**. Déjales los nombres `Postgres` y `Redis` (las referencias de abajo usan esos nombres).

## 2. Servicio `web`

Es el servicio que ya conectaste al repo. Renómbralo a `web` (Settings → nombre del servicio).

1. **Settings → Networking → Generate Domain.** Te da algo como `web-production-xxxx.up.railway.app`. Esa es tu URL pública (si te pregunta el puerto, pon el que muestre Railway, normalmente `8080`).
2. **Settings → Config-as-code:** déjalo en `railway.json` (es el valor por defecto).
3. **Variables → Raw Editor**, pega esto y rellena:

```env
NEXTAUTH_URL=https://${{RAILWAY_PUBLIC_DOMAIN}}
NEXTAUTH_SECRET=<generado>
CRON_SECRET=<generado>
ENCRYPTION_KEY=<generado, 64 caracteres hex>
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}?family=0

RESEND_API_KEY=re_...
EMAIL_FROM=OpenReply <onboarding@resend.dev>
ALLOWED_EMAILS=tu-correo@gmail.com

META_GRAPH_API_VERSION=v25.0
INSTAGRAM_APP_ID=...
INSTAGRAM_APP_SECRET=...
FACEBOOK_APP_SECRET=...
WEBHOOK_VERIFY_TOKEN=<generado>
```

Notas:

- `?family=0` en `REDIS_URL` es necesario en la red privada de Railway (IPv6); sin eso BullMQ no conecta.
- Genera los secretos con `openssl rand -hex 32` (o pídeselos a tu asistente). **`ENCRYPTION_KEY` tiene que ser exactamente la misma en `web` y `worker`.**
- `ALLOWED_EMAILS` evita que cualquiera que encuentre tu URL se cree una cuenta.

## 3. Correo de login (Resend)

El login es solo por *magic link* al correo. Railway bloquea SMTP saliente en los planes Trial/Hobby, así que usa **Resend** (va por HTTPS).

1. Crea cuenta en [resend.com](https://resend.com) y una API key → `RESEND_API_KEY`.
2. **Sin dominio propio:** usa `EMAIL_FROM=OpenReply <onboarding@resend.dev>`. Resend solo entrega a **el mismo correo con el que creaste la cuenta de Resend**, así que entra a OpenReply con ese correo. Para uso personal es suficiente.
3. **Con dominio:** verifícalo en Resend y usa `EMAIL_FROM=OpenReply <login@tudominio.com>`.

## 4. Servicio `worker`

**+ New → GitHub Repo →** el mismo repo. Renómbralo a `worker`.

1. **Settings → Config-as-code → Railway config file:** `railway/worker.json`
2. **No** le generes dominio público.
3. **Variables:** las mismas que `web`, excepto que `NEXTAUTH_URL` apunta al dominio de `web`. Lo más fácil es pegar esto en el Raw Editor:

```env
NEXTAUTH_URL=https://${{web.RAILWAY_PUBLIC_DOMAIN}}
NEXTAUTH_SECRET=${{web.NEXTAUTH_SECRET}}
ENCRYPTION_KEY=${{web.ENCRYPTION_KEY}}
DATABASE_URL=${{Postgres.DATABASE_URL}}
REDIS_URL=${{Redis.REDIS_URL}}?family=0
META_GRAPH_API_VERSION=${{web.META_GRAPH_API_VERSION}}
INSTAGRAM_APP_ID=${{web.INSTAGRAM_APP_ID}}
INSTAGRAM_APP_SECRET=${{web.INSTAGRAM_APP_SECRET}}
FACEBOOK_APP_SECRET=${{web.FACEBOOK_APP_SECRET}}
```

## 5. Servicio `cron`

Sin esto el token de Instagram caduca a los ~60 días y todo deja de responder **sin ningún error**.

**+ New → GitHub Repo →** el mismo repo. Renómbralo a `cron`.

1. **Settings → Config-as-code → Railway config file:** `railway/cron.json`
2. Sin dominio público.
3. **Variables:**

```env
CRON_BASE_URL=https://${{web.RAILWAY_PUBLIC_DOMAIN}}
CRON_SECRET=${{web.CRON_SECRET}}
```

## 6. Comprobar que todo está vivo

Abre `https://TU-DOMINIO/api/health`. Debe responder `"status": "ok"` y `worker.healthy: true`. Si `worker.healthy` es `false`, revisa los logs del servicio `worker`.

Luego entra a `https://TU-DOMINIO/login` con tu correo y abre el enlace que te llega.

## 7. Configurar la app de Meta

Con tu dominio de Railway (`https://TU-DOMINIO`), en [developers.facebook.com/apps](https://developers.facebook.com/apps) → tu app → producto **Instagram → API setup with Instagram login**:

1. **Caso de uso:** "Manage messaging and content on Instagram" (no Facebook Login, no Marketing API).
2. **Secretos:**
   - `INSTAGRAM_APP_ID` y `INSTAGRAM_APP_SECRET`: en la página del producto Instagram (el ID de Instagram **no** es el App ID de Facebook).
   - `FACEBOOK_APP_SECRET`: App settings → Basic → App secret.
3. **Tester:** App roles → Roles → Instagram testers → agrega tu usuario de Instagram. Luego **en la app de Instagram**: Configuración → Apps y sitios web → Invitaciones de tester → **Aceptar**. (Si no, sale "Insufficient Developer Role".)
4. **OAuth redirect URI** (Business login settings), exacto y sin `/` final:
   `https://TU-DOMINIO/api/instagram/callback`
5. **Webhooks:**
   - Callback URL: `https://TU-DOMINIO/api/webhook`
   - Verify token: el mismo valor de `WEBHOOK_VERIFY_TOKEN`
   - Verify and save, y suscríbete a **`comments`** y **`messages`**.
6. **Publicar la app** (Publish en la barra lateral). Antes pon estas URLs, que OpenReply ya trae:
   - `https://TU-DOMINIO/privacy`
   - `https://TU-DOMINIO/terms`
   - `https://TU-DOMINIO/data-deletion`

   En modo Development **Meta no manda comentarios reales**, solo el botón de prueba. Es la causa #1 de "configuré todo y no pasa nada".

Tu cuenta de Instagram tiene que ser **Business o Creator** (no personal).

## 8. Probar

1. En OpenReply: **Settings → Connect Instagram**.
2. Crea una campaña en un post con la palabra clave `TEST`.
3. Desde **otra** cuenta de Instagram comenta `TEST` en ese post (tus propios comentarios se ignoran a propósito).
4. Debe llegar el DM. Si no, mira **DM Logs** y `/api/health`.

Si la cuenta estuvo conectada antes a ManyChat u otra herramienta: Meta Business Suite → Configuración → Integraciones → Enrutamiento de conversaciones → quita la app vieja y en OpenReply activa "Access all conversations" y "Take control of conversations".

Más detalle (en inglés): [setup.md](setup.md).
