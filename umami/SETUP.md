# Umami + Cloudflare Tunnel on TrueNAS

## Architecture

```
Internet --> Cloudflare Tunnel --> gateway container --> umami
             (one tunnel,          (cloudflared +       (TrueNAS
              many hostnames)       nginx in one image)  catalog app)
                                          |
                                only /metrics.js and /api/ack
                                everything else returns 404

LAN --> http://truenas-ip:30060 --> umami (full admin access)
```

The gateway image (`ghcr.io/tjw/self-hosted-gateway`) is built by GitHub Actions whenever
`gateway/` changes on main. It bundles nginx + cloudflared into a single container.
One image, one app on TrueNAS, handles all tunneled services.

## Step 1: Create the shared Docker network

SSH into TrueNAS and run:

```bash
docker network create gateway
```

All services that need tunnel access join this network.

## Step 2: Install Umami from the app catalog

Go to **Apps > Discover > Umami > Install** and configure:

### Umami Configuration

| Field | Value |
|-------|-------|
| Timezone | `America/Detroit` (or your TZ) |
| Postgres Image | `Postgres 18` |
| Database Password | `********` |
| App Secret | generate with `openssl rand -hex 32` |

Add these additional environment variables:

| Name | Value |
|------|-------|
| `TRACKER_SCRIPT_NAME` | `metrics` |
| `COLLECT_API_ENDPOINT` | `ack` |
| `CLIENT_IP_HEADER` | `CF-Connecting-IP` |
| `DISABLE_TELEMETRY` | `1` |
| `DISABLE_UPDATES` | `1` |

### Network Configuration

| Field | Value |
|-------|-------|
| Port Bind Mode | `Publish` (so you can access admin on LAN) |
| Port Number | `30060` (default) |

Under **Networks**, add an external network:

| Field | Value |
|-------|-------|
| Name | `gateway` |
| Containers | `umami` |
| Alias | `umami` |

### Storage Configuration

| Field | Value |
|-------|-------|
| Postgres Data Storage | `ixVolume` (default, auto-managed) |

### Resources Configuration

- 1 CPU
- 1024 MB memory

## Step 3: Enable Cloudflare visitor location headers

1. Go to **Cloudflare Dashboard > tjw.dev > Rules > Settings**
2. Under **Managed Transforms**, enable **"Add visitor location headers"**

This adds `CF-IPCountry`, `CF-IPCity`, etc. to requests so Umami gets geo data.

## Step 4: Create the Cloudflare Tunnel

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com)
2. **Networks > Tunnels > Create a tunnel**
3. Name: `self-hosted-gateway`
4. Connector: Docker (copy the `TUNNEL_TOKEN`)
5. Add public hostname:
   - Subdomain: `metrics`
   - Domain: `tjw.dev`
   - Service type: `HTTP`
   - URL: `localhost:8080`

Future services: add more public hostnames to this same tunnel,
all pointing to `localhost:8080`. The gateway routes by hostname.

## Step 5: Deploy the gateway app

1. Go to **Apps > Discover > Custom App**
2. Application Name: `gateway`
3. Image Repository: `ghcr.io/tjw/self-hosted-gateway`
4. Image Tag: `latest`
5. Add environment variable: `TUNNEL_TOKEN` = your tunnel token
6. Under Networks, join the `gateway` external network

## Step 6: First login

1. Visit `http://truenas-ip:30060` on your LAN
2. Login: `admin` / `umami`
3. **Change the password immediately**
4. Create a new admin user, delete the default `admin` user
5. Go to Settings > Websites > Add `tjw.dev`
6. Copy the website ID

## Step 7: Add tracking to tjw.dev

In your Astro site's `BaseLayout.astro`, add to `<head>`:

```astro
{import.meta.env.PROD && (
  <script
    defer
    src="https://metrics.tjw.dev/metrics.js"
    data-website-id="YOUR_WEBSITE_ID"
  />
)}
```

## Verify

- `https://metrics.tjw.dev/metrics.js` should return the tracking script
- `https://metrics.tjw.dev/login` should return 404
- `https://metrics.tjw.dev/api/ack` should accept POST requests
- `http://truenas-ip:30060` should show the full Umami dashboard

## Adding future services

1. Add a new `server {}` block to `gateway/nginx.conf` for the new hostname
2. Push to main — GitHub Actions rebuilds the gateway image
3. In Cloudflare Zero Trust, add a new public hostname to the existing tunnel
4. Configure the new TrueNAS app to join the `gateway` network
5. Restart the gateway app in TrueNAS to pull the new image

## Maintenance

- **Umami updates**: managed by TrueNAS app catalog (check Apps page)
- **Gateway image**: rebuilt on push by GitHub Actions
- **Tunnel health**: check Cloudflare Zero Trust dashboard
- **Postgres backups**: Apps > Umami > (three-dot menu) > Shell into postgres container, run `pg_dump`

