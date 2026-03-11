# Self-Hosted Gateway

Nginx reverse proxy + Cloudflare Tunnel in a single container. Routes public traffic to backend services on a shared Docker network, exposing only the endpoints you allow.

## Image

```
ghcr.io/tjw/self-hosted-gateway:latest
```

Built automatically by GitHub Actions on push to `main`.

## How it works

Cloudflared connects outbound to Cloudflare's edge. Nginx listens on port 8080 and routes requests by hostname to backend services. Only explicitly allowed paths are proxied — everything else returns 404. Unknown hostnames are dropped (444).

## TrueNAS Custom App Setup

Go to **Apps > Discover > Custom App** and configure:

### Application Name

`gateway`

### Image Configuration

| Field | Value |
|-------|-------|
| Image Repository | `ghcr.io/tjw/self-hosted-gateway` |
| Image Tag | `latest` |
| Image Pull Policy | `Always` (so restarts pull the latest build) |

### Container Configuration

No command or args override needed — the entrypoint handles everything.

### Environment Variables

| Name | Value |
|------|-------|
| `TUNNEL_TOKEN` | Your Cloudflare Tunnel token |

### Port Configuration

No ports need to be published. All traffic arrives via the Cloudflare Tunnel (outbound connection), not through host ports.

### Storage Configuration

No storage needed. Config is baked into the image.

### Network Configuration

Under **Networks**, join an external network:

| Field | Value |
|-------|-------|
| Name | `gateway` |

This network must be created first via SSH: `docker network create gateway`.
Backend services (umami, etc.) also join this network.

### Security Configuration

Leave defaults. No privileged mode or capabilities needed.

### Resources Configuration

| Field | Value |
|-------|-------|
| CPUs | `1` |
| Memory | `512 MB` |

### All other fields

Leave as defaults. No DNS, labels, portal, or restart policy changes needed.

## Adding a new service

1. Add a `server {}` block to `gateway/nginx.conf` with the new hostname and allowed paths
2. Push to `main` — GitHub Actions rebuilds the image
3. In Cloudflare Zero Trust, add a public hostname to the existing tunnel pointing to `localhost:8080`
4. Configure the new TrueNAS app to join the `gateway` network with an alias matching the `proxy_pass` upstream
5. Restart the gateway app in TrueNAS to pull the new image

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TUNNEL_TOKEN` | Yes | Cloudflare Tunnel token from Zero Trust dashboard |
