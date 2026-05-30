const clientsByUser = new Map();

function writeEvent(res, type, data = {}) {
  res.write(`event: ${type}\n`);
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

export function subscribeAppEvents(userId, req, res) {
  res.set({
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'Content-Type': 'text/event-stream',
    'X-Accel-Buffering': 'no',
  });
  res.flushHeaders?.();

  const clients = clientsByUser.get(userId) ?? new Set();
  clients.add(res);
  clientsByUser.set(userId, clients);

  writeEvent(res, 'connected', { userId });
  const heartbeat = setInterval(() => {
    res.write(': keep-alive\n\n');
  }, 25000);

  req.on('close', () => {
    clearInterval(heartbeat);
    clients.delete(res);
    if (clients.size === 0) {
      clientsByUser.delete(userId);
    }
  });
}

export function publishAppEvent(userIds, { type, payload = {} }) {
  const delivered = new Set();
  for (const userId of userIds.filter(Boolean)) {
    const clients = clientsByUser.get(userId);
    if (!clients) {
      continue;
    }
    for (const res of clients) {
      if (delivered.has(res)) {
        continue;
      }
      delivered.add(res);
      writeEvent(res, type, payload);
    }
  }
}
