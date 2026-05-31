import { WebSocketServer } from 'ws';

import { profileForAccessToken } from '../auth/auth.service.js';
import { registerRealtimeClient } from './realtime.service.js';

const websocketPath = '/api/app/ws';
const unauthenticatedCloseMs = 10000;
const heartbeatMs = 25000;

let authenticator = profileForAccessToken;

function closeWith(ws, code, reason) {
  try {
    ws.close(code, reason);
  } catch {
    ws.terminate();
  }
}

function parseMessage(raw) {
  const text = Buffer.isBuffer(raw) ? raw.toString('utf8') : raw.toString();
  return JSON.parse(text);
}

async function authenticateSocket(ws, raw) {
  const message = parseMessage(raw);
  if (message?.type !== 'auth' || typeof message.accessToken !== 'string') {
    closeWith(ws, 4001, 'Authentication required');
    return null;
  }
  const profile = await authenticator(message.accessToken);
  return profile.id;
}

export function attachRealtimeWebSocketServer(server) {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (request, socket, head) => {
    const { pathname } = new URL(request.url ?? '/', 'http://localhost');
    if (pathname !== websocketPath) {
      socket.destroy();
      return;
    }
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request);
    });
  });

  wss.on('connection', (ws) => {
    let cleanup = null;
    let authenticated = false;
    ws.isAlive = true;

    const authTimeout = setTimeout(() => {
      if (!authenticated) {
        closeWith(ws, 4001, 'Authentication required');
      }
    }, unauthenticatedCloseMs);

    ws.on('pong', () => {
      ws.isAlive = true;
    });

    ws.once('message', async (raw) => {
      try {
        const userId = await authenticateSocket(ws, raw);
        if (!userId || ws.readyState !== 1) {
          return;
        }
        authenticated = true;
        clearTimeout(authTimeout);
        cleanup = registerRealtimeClient(userId, ws);
        ws.send(JSON.stringify({ type: 'connected', data: { userId } }));
      } catch {
        closeWith(ws, 4003, 'Authentication failed');
      }
    });

    ws.on('close', () => {
      clearTimeout(authTimeout);
      cleanup?.();
    });
  });

  const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
      if (ws.isAlive === false) {
        ws.terminate();
        continue;
      }
      ws.isAlive = false;
      ws.ping();
    }
  }, heartbeatMs);

  wss.on('close', () => {
    clearInterval(heartbeat);
  });

  return wss;
}

export function setRealtimeWebSocketAuthenticatorForTesting(nextAuthenticator) {
  const previous = authenticator;
  authenticator = nextAuthenticator;
  return () => {
    authenticator = previous;
  };
}
