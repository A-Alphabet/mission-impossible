# Automated Deployment Guide for Mission Impossible App

This guide will help you automate deployment of your frontend (React/Vite) to GitHub Pages and backend (Node.js/WebSocket) to Render.com using GitHub Actions.

---

## 1. GitHub Actions for Frontend (GitHub Pages)

Create a workflow file at `.github/workflows/deploy-frontend.yml`:

```yaml
name: Deploy Frontend to GitHub Pages

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run build
      - run: npm install -g gh-pages
      - run: gh-pages -d dist -u "github-actions-bot <support+actions@github.com>"
```

---

## 2. GitHub Actions for Backend (Render.com)

Render.com can auto-deploy from your GitHub repo. Just:
- Go to [Render.com](https://render.com/), create a new Web Service, and connect your repo.
- Set build command: `npm install`
- Set start command: `node server/index.js`
- Choose the Free plan.
- Render will auto-deploy on every push to main.

---

## 3. Project Structure Recommendations

- Make sure your frontend build outputs to `dist/` (Vite default).
- Your backend should be in `server/` and have its own `package.json` and `index.js`.

---

## 4. Update Frontend WebSocket URL

- In production, set the WebSocket URL to your Render.com backend (e.g., `wss://your-app.onrender.com`).
- You can use an environment variable or a simple check in your code:

```ts
const SIGNAL_SERVER_URL = process.env.NODE_ENV === 'production'
  ? 'wss://your-app.onrender.com'
  : 'ws://localhost:3001';
```

---

## 5. Summary

- Frontend auto-deploys to GitHub Pages on every push to main.
- Backend auto-deploys to Render.com on every push to main.
- Both services are free (with usage limits).

---

For more automation (e.g., custom domains, environment variables), see the docs for [GitHub Actions](https://docs.github.com/en/actions) and [Render.com](https://render.com/docs/deploy-hooks).
