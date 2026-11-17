This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Deployment (Dokploy)

Deployment is handled entirely by **Dokploy** on the server `10.117.66.20` — no GitHub Actions, no self-hosted runner, no manual SSH.

### How it works

1. Push code to the Git repo (private repo, accessed by Dokploy via an SSH deploy key).
2. Dokploy detects the push (Git webhook / polling) and rebuilds automatically.
3. Dokploy builds the Docker image from the repo `Dockerfile`, runs the container, and routes traffic through its Traefik proxy (TLS + domain).
4. Dokploy performs zero-downtime rolling deploys and keeps history for rollback.

### Dokploy setup (one-time)

1. Create a **Docker Compose** service in the Dokploy dashboard.
2. Point it at this repository using your private-repo **SSH deploy key**.
3. Set the branch (e.g. `main`).
4. Assign a **domain** to the `app` service (container port `3000`).
5. Enable **Auto Deploy**.

That is the entire pipeline — Dokploy does test/build/deploy.

### Build-time checks

The `Dockerfile` runs `npm run lint` before `npm run build`, so a lint failure fails the Dokploy build/deploy.

## Getting Started (local dev)

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

## Learn More

To learn more about Next.js, take a look at the [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.