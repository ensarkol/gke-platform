const express = require('express');
const client = require('prom-client');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequests = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [register],
});

app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequests.inc({
      method: req.method,
      path: req.route ? req.route.path : req.path,
      status: String(res.statusCode),
    });
  });
  next();
});

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from Test Node.js sample app',
    hostname: os.hostname(),
    timestamp: new Date().toISOString(),
  });
});

app.get('/healthz', (req, res) => {
  res.status(200).send('ok');
});

app.get('/readyz', (req, res) => {
  res.status(200).send('ready');
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

const server = app.listen(PORT, () => {
  console.log(`nodejs-app listening on port ${PORT}`);
});

for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    console.log(`${signal} received, draining connections`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10000).unref();
  });
}
