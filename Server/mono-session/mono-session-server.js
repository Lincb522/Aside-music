import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebSocket, WebSocketServer } from 'ws';

const DEFAULT_PATH = '/api/mono-session';
const MAX_PARTICIPANTS = 16;
const MAX_CHAT_HISTORY = 100;
const MAX_CHAT_CHARACTERS = 300;
const ROOM_IDLE_TTL_MS = 6 * 60 * 60 * 1000;
const DISCONNECTED_PARTICIPANT_TTL_MS = 90 * 1000;
const DEFAULT_LEXICON_DIRECTORY = fileURLToPath(
  new URL('./vendor/Sensitive-lexicon/Vocabulary', import.meta.url),
);
const SENSITIVE_LEXICON_DIRECTORY = process.env.MONO_SESSION_LEXICON_DIR
  ? path.resolve(process.env.MONO_SESSION_LEXICON_DIR)
  : DEFAULT_LEXICON_DIRECTORY;
const SENSITIVE_TERMS = loadSensitiveTerms(SENSITIVE_LEXICON_DIRECTORY);
const SENSITIVE_MATCHER = createSensitiveMatcher(SENSITIVE_TERMS);
const PRIVACY_PATTERNS = [
  /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/iu,
  /(?:https?:\/\/|www\.)\S+/iu,
  /(?:^|\D)1[3-9]\d{9}(?!\d)/u,
  /(?:^|\D)\d{16,19}(?!\d)/u,
  /(?:微信|微\s*信|vx|v信|qq|扣扣|telegram|tg)\s*[:：号]?\s*[A-Z0-9_-]{5,}/iu,
];

export function attachMonoSessionServer({
  server,
  path = DEFAULT_PATH,
  validateToken,
  logger = console,
}) {
  if (!server || typeof server.on !== 'function') {
    throw new TypeError('A Node HTTP/S server is required.');
  }
  if (typeof validateToken !== 'function') {
    throw new TypeError('validateToken(token) is required.');
  }

  const rooms = new Map();
  const clients = new Map();
  const webSocketServer = new WebSocketServer({ noServer: true, maxPayload: 256 * 1024 });

  server.on('upgrade', async (request, socket, head) => {
    let url;
    try {
      url = new URL(request.url, 'http://mono-session.local');
    } catch {
      socket.destroy();
      return;
    }
    if (url.pathname !== path) return;

    const authorization = String(request.headers.authorization || '');
    const token = authorization.startsWith('Bearer ')
      ? authorization.slice('Bearer '.length).trim()
      : '';
    const deviceId = String(url.searchParams.get('deviceId') || '').trim().slice(0, 128);
    if (!token || !deviceId) {
      rejectUpgrade(socket, 401, 'Missing credentials');
      return;
    }

    let credential;
    try {
      credential = await validateToken(token, { deviceId, request });
    } catch (error) {
      logger.warn?.('[MonoSession] token validation failed', error);
      rejectUpgrade(socket, 503, 'Authorization unavailable');
      return;
    }
    if (!credential) {
      rejectUpgrade(socket, 403, 'Invalid token');
      return;
    }

    webSocketServer.handleUpgrade(request, socket, head, (webSocket) => {
      webSocketServer.emit('connection', webSocket, request, {
        deviceId,
        tokenSubject: String(credential.id || credential.name || credential.tokenName || 'token'),
      });
    });
  });

  webSocketServer.on('connection', (socket, _request, credential) => {
    const connection = {
      socket,
      deviceId: credential.deviceId,
      tokenSubject: credential.tokenSubject,
      roomId: null,
      participant: null,
      rateWindowStartedAt: Date.now(),
      rateWindowCount: 0,
      lastChatAt: 0,
      connectedAt: Date.now(),
    };
    clients.set(socket, connection);

    socket.on('message', (raw, isBinary) => {
      if (isBinary && raw.length > 256 * 1024) return closeWithPolicy(socket, 'Payload too large');
      if (!consumeRateLimit(connection)) return closeWithPolicy(socket, 'Rate limit exceeded');

      let message;
      try {
        message = JSON.parse(raw.toString('utf8'));
      } catch {
        return sendError(socket, null, 'invalid_json', 'Invalid message');
      }
      handleMessage(connection, message);
    });

    socket.on('close', () => {
      clients.delete(socket);
      detachParticipant(connection, false);
    });

    socket.on('error', (error) => {
      logger.warn?.('[MonoSession] socket error', error);
    });
  });

  function handleMessage(connection, message) {
    const command = String(message?.command || '');
    const requestId = normalizeRequestId(message?.requestID);
    switch (command) {
      case 'create':
        createRoom(connection, message, requestId);
        break;
      case 'join':
        joinRoom(connection, message, requestId);
        break;
      case 'resume':
        resumeRoom(connection, message, requestId);
        break;
      case 'leave':
        detachParticipant(connection, true);
        break;
      case 'playback':
        updatePlayback(connection, message, requestId);
        break;
      case 'chat':
        postChat(connection, message, requestId);
        break;
      case 'queue':
        updateQueue(connection, message, requestId);
        break;
      case 'permissions':
        updatePermissions(connection, message, requestId);
        break;
      case 'track':
        requestTrackChange(connection, message, requestId);
        break;
      case 'heartbeat':
        {
          const room = connection.roomId ? rooms.get(connection.roomId) : null;
        send(connection.socket, {
          command: 'heartbeat',
          requestID: requestId,
          roomID: connection.roomId,
          playback: room?.playback,
          queue: room?.queue,
          permissions: room?.permissions,
          sentAt: new Date().toISOString(),
        });
        }
        break;
      default:
        sendError(connection.socket, requestId, 'unknown_command', 'Unknown command');
    }
  }

  function createRoom(connection, message, requestId) {
    detachParticipant(connection, true);
    const participant = normalizeParticipant(message.participant, connection, 'host');
    if (!participant) return sendError(connection.socket, requestId, 'invalid_participant', 'Invalid participant');

    let inviteCode;
    try {
      inviteCode = createInviteCode(rooms);
    } catch {
      return sendError(connection.socket, requestId, 'room_capacity', 'Unable to create room');
    }
    const roomId = crypto.randomUUID();
    const now = new Date().toISOString();
    const playback = normalizePlayback(message.playback, 0, now);
    const queue = normalizeQueue(message.queue, playback.song, 0, now);
    const permissions = normalizePermissions(message.permissions);
    const room = {
      id: roomId,
      inviteCode,
      hostId: connection.deviceId,
      participants: new Map([[participant.id, { participant, socket: connection.socket, disconnectedAt: null }]]),
      playback,
      queue,
      permissions,
      messages: [],
      createdAt: now,
      updatedAt: Date.now(),
      tokenSubject: connection.tokenSubject,
    };
    rooms.set(roomId, room);
    connection.roomId = roomId;
    connection.participant = participant;
    sendRoom(connection.socket, room, requestId);
  }

  function joinRoom(connection, message, requestId) {
    const inviteCode = String(message.inviteCode || '').trim().toUpperCase();
    const room = [...rooms.values()].find((candidate) => candidate.inviteCode === inviteCode);
    if (!room) return sendError(connection.socket, requestId, 'room_not_found', 'Room not found');
    if (room.participants.size >= MAX_PARTICIPANTS && !room.participants.has(connection.deviceId)) {
      return sendError(connection.socket, requestId, 'room_full', 'Room is full');
    }
    const participant = normalizeParticipant(message.participant, connection, 'listener');
    if (!participant) return sendError(connection.socket, requestId, 'invalid_participant', 'Invalid participant');

    detachParticipant(connection, true);
    room.participants.set(participant.id, {
      participant,
      socket: connection.socket,
      disconnectedAt: null,
    });
    room.updatedAt = Date.now();
    connection.roomId = room.id;
    connection.participant = participant;
    sendRoom(connection.socket, room, requestId);
    broadcastParticipants(room);
  }

  function resumeRoom(connection, message, requestId) {
    const roomId = String(message.roomID || '').trim();
    const inviteCode = String(message.inviteCode || '').trim().toUpperCase();
    const room = rooms.get(roomId);
    if (!room || room.inviteCode !== inviteCode || room.hostId !== connection.deviceId) {
      return sendError(connection.socket, requestId, 'resume_rejected', 'Room resume rejected');
    }
    const participant = normalizeParticipant(message.participant, connection, 'host');
    if (!participant) {
      return sendError(connection.socket, requestId, 'invalid_participant', 'Invalid participant');
    }

    detachParticipant(connection, true);
    room.participants.set(participant.id, {
      participant,
      socket: connection.socket,
      disconnectedAt: null,
    });
    room.updatedAt = Date.now();
    connection.roomId = room.id;
    connection.participant = participant;
    sendRoom(connection.socket, room, requestId);
    broadcastParticipants(room);
  }

  function updatePlayback(connection, message, requestId) {
    const room = connection.roomId ? rooms.get(connection.roomId) : null;
    if (!room) return sendError(connection.socket, requestId, 'room_not_found', 'Room not found');
    const isHost = room.hostId === connection.deviceId;
    if (!isHost && !room.permissions?.membersCanControlPlayback) {
      return sendError(connection.socket, requestId, 'playback_control_disabled', 'Playback control disabled');
    }
    const now = new Date().toISOString();
    const incoming = normalizePlayback(message.playback, room.playback.sequence + 1, now);
    if (!incoming.song) {
      return sendError(connection.socket, requestId, 'invalid_track', 'Invalid track');
    }
    incoming.sequence = room.playback.sequence + 1;
    incoming.hostTimestamp = now;
    if (message.queue) {
      room.queue = normalizeQueue(
        message.queue,
        incoming.song,
        (room.queue?.revision || 0) + 1,
        now,
      );
    }
    room.playback = incoming;
    room.updatedAt = Date.now();
    broadcast(room, {
      command: 'playback',
      requestID: requestId,
      roomID: room.id,
      playback: room.playback,
      queue: room.queue,
      permissions: room.permissions,
      sentAt: now,
    }, isHost ? connection.socket : null);
  }

  function updateQueue(connection, message, requestId) {
    const room = connection.roomId ? rooms.get(connection.roomId) : null;
    if (!room || !connection.participant) {
      return sendError(connection.socket, requestId, 'room_not_found', 'Room not found');
    }
    room.queue = normalizeQueue(
      message.queue,
      room.playback.song,
      (room.queue?.revision || 0) + 1,
      new Date().toISOString(),
    );
    room.updatedAt = Date.now();

    // Broadcast with the existing playback command so older clients keep the
    // room connection and simply ignore the additional queue payload.
    broadcast(room, {
      command: 'playback',
      requestID: requestId,
      roomID: room.id,
      playback: room.playback,
      queue: room.queue,
      permissions: room.permissions,
      sentAt: new Date().toISOString(),
    });
  }

  function updatePermissions(connection, message, requestId) {
    const room = connection.roomId ? rooms.get(connection.roomId) : null;
    if (!room) return sendError(connection.socket, requestId, 'room_not_found', 'Room not found');
    if (room.hostId !== connection.deviceId) {
      return sendError(connection.socket, requestId, 'host_required', 'Host permission required');
    }
    room.permissions = normalizePermissions(message.permissions);
    room.updatedAt = Date.now();
    broadcast(room, {
      command: 'participants',
      requestID: requestId,
      roomID: room.id,
      participants: publicParticipants(room),
      permissions: room.permissions,
      sentAt: new Date().toISOString(),
    });
  }

  function requestTrackChange(connection, message, requestId) {
    const room = connection.roomId ? rooms.get(connection.roomId) : null;
    if (!room || !connection.participant) {
      return sendError(connection.socket, requestId, 'room_not_found', 'Room not found');
    }
    const isHost = room.hostId === connection.deviceId;
    if (!isHost && !room.permissions?.membersCanControlPlayback) {
      return sendError(connection.socket, requestId, 'track_control_disabled', 'Track control disabled');
    }
    const requestedSong = normalizeSong(message?.playback?.song);
    if (!requestedSong) {
      return sendError(connection.socket, requestId, 'invalid_track', 'Invalid track');
    }

    const now = new Date().toISOString();
    const identity = `${String(requestedSong.musicSource || '')}:${requestedSong.id}`;
    const existsInQueue = room.queue.songs.some((song) => (
      `${String(song.musicSource || '')}:${song.id}` === identity
    ));
    if (!existsInQueue) {
      room.queue = normalizeQueue(
        {
          songs: [...room.queue.songs, requestedSong],
        },
        requestedSong,
        (room.queue.revision || 0) + 1,
        now,
      );
    }

    room.playback = {
      sequence: room.playback.sequence + 1,
      song: requestedSong,
      position: 0,
      isPlaying: true,
      hostTimestamp: now,
      queueRevision: String(message?.playback?.queueRevision || '').slice(0, 128),
    };
    room.updatedAt = Date.now();
    broadcast(room, {
      command: 'playback',
      requestID: requestId,
      roomID: room.id,
      playback: room.playback,
      queue: room.queue,
      permissions: room.permissions,
      sentAt: now,
    });
  }

  function postChat(connection, message, requestId) {
    const room = connection.roomId ? rooms.get(connection.roomId) : null;
    if (!room || !connection.participant) {
      return sendError(connection.socket, requestId, 'room_not_found', 'Room not found');
    }
    const now = Date.now();
    if (now - connection.lastChatAt < 350) {
      return sendError(connection.socket, requestId, 'chat_too_fast', 'Messages are being sent too quickly');
    }
    const text = normalizeChatText(message?.chat?.text);
    if (!text) return sendError(connection.socket, requestId, 'invalid_chat', 'Message is empty');
    const chatViolation = validateChatText(text);
    if (chatViolation) {
      // Keep the established error code so older clients treat this as a chat
      // rejection instead of changing the room connection state.
      return sendError(connection.socket, requestId, 'invalid_chat', chatViolation);
    }

    connection.lastChatAt = now;
    const chat = {
      id: crypto.randomUUID(),
      senderID: connection.participant.id,
      senderName: connection.participant.displayName,
      senderAvatarURL: connection.participant.avatarURL,
      text,
      sentAt: new Date(now).toISOString(),
    };
    room.messages.push(chat);
    if (room.messages.length > MAX_CHAT_HISTORY) {
      room.messages.splice(0, room.messages.length - MAX_CHAT_HISTORY);
    }
    room.updatedAt = now;
    broadcast(room, {
      command: 'chat',
      requestID: requestId,
      roomID: room.id,
      chat,
      sentAt: chat.sentAt,
    });
  }

  function detachParticipant(connection, explicit) {
    const room = connection.roomId ? rooms.get(connection.roomId) : null;
    if (!room || !connection.participant) {
      connection.roomId = null;
      connection.participant = null;
      return;
    }
    const entry = room.participants.get(connection.participant.id);
    const isHost = room.hostId === connection.deviceId;
    if (explicit && isHost) {
      for (const participant of room.participants.values()) {
        if (participant.socket && participant.socket !== connection.socket) {
          sendError(participant.socket, null, 'room_ended', 'Room ended');
          participant.socket.close(1000, 'Room ended');
        }
      }
      rooms.delete(room.id);
      connection.roomId = null;
      connection.participant = null;
      return;
    }
    if (explicit || !isHost) {
      room.participants.delete(connection.participant.id);
    } else if (entry) {
      entry.socket = null;
      entry.disconnectedAt = Date.now();
      entry.participant.isReady = false;
    }
    room.updatedAt = Date.now();
    connection.roomId = null;
    connection.participant = null;
    broadcastParticipants(room);
  }

  function sendRoom(socket, room, requestId) {
    send(socket, {
      command: 'room',
      requestID: requestId,
      roomID: room.id,
      room: publicRoom(room),
      queue: room.queue,
      permissions: room.permissions,
      messages: room.messages,
      sentAt: new Date().toISOString(),
    });
  }

  function broadcastParticipants(room) {
    broadcast(room, {
      command: 'participants',
      requestID: crypto.randomUUID(),
      roomID: room.id,
      participants: publicParticipants(room),
      permissions: room.permissions,
      sentAt: new Date().toISOString(),
    });
  }

  const cleanupTimer = setInterval(() => {
    const now = Date.now();
    for (const [roomId, room] of rooms) {
      for (const [participantId, entry] of room.participants) {
        if (entry.disconnectedAt && now - entry.disconnectedAt > DISCONNECTED_PARTICIPANT_TTL_MS) {
          room.participants.delete(participantId);
        }
      }
      const hostIsPresent = room.participants.has(room.hostId);
      if (!hostIsPresent || room.participants.size === 0 || now - room.updatedAt > ROOM_IDLE_TTL_MS) {
        for (const entry of room.participants.values()) {
          if (entry.socket) {
            sendError(entry.socket, null, 'room_ended', 'Room ended');
            entry.socket.close(1000, 'Room ended');
          }
        }
        rooms.delete(roomId);
      }
    }
  }, 30_000);
  cleanupTimer.unref?.();

  return {
    rooms,
    close() {
      clearInterval(cleanupTimer);
      for (const client of webSocketServer.clients) client.close(1001, 'Server shutdown');
      webSocketServer.close();
    },
  };
}

function normalizeParticipant(value, connection, role) {
  if (!value || typeof value !== 'object') return null;
  const requestedName = normalizeChatText(value.displayName);
  const displayName = validateChatText(requestedName)
    ? ''
    : Array.from(requestedName).slice(0, 40).join('');
  return {
    id: connection.deviceId,
    displayName: displayName || 'Mono',
    avatarURL: normalizeAvatarURL(value.avatarURL),
    role,
    joinedAt: new Date().toISOString(),
    isReady: true,
  };
}

function normalizeAvatarURL(value) {
  const raw = String(value || '').trim().slice(0, 2048);
  if (!raw) return null;
  try {
    const url = new URL(raw);
    return url.protocol === 'https:' || url.protocol === 'http:' ? url.toString() : null;
  } catch {
    return null;
  }
}

function normalizePlayback(value, fallbackSequence, now) {
  const raw = value && typeof value === 'object' ? value : {};
  return {
    sequence: Number.isSafeInteger(raw.sequence) ? raw.sequence : fallbackSequence,
    song: normalizeSong(raw.song),
    position: clampNumber(raw.position, 0, 24 * 60 * 60, 0),
    isPlaying: Boolean(raw.isPlaying),
    hostTimestamp: isDate(raw.hostTimestamp) ? raw.hostTimestamp : now,
    queueRevision: String(raw.queueRevision || '').slice(0, 128),
  };
}

function normalizeQueue(value, currentSong, revision, now) {
  const raw = value && typeof value === 'object' ? value : {};
  const incomingSongs = Array.isArray(raw.songs) ? raw.songs : [];
  const songs = [];
  const identities = new Set();
  let encodedBytes = 0;

  for (const candidate of incomingSongs.slice(0, 100)) {
    const song = normalizeSong(candidate);
    if (!song) continue;
    const identity = `${String(song.musicSource || '')}:${song.id}`;
    if (identities.has(identity)) continue;
    const bytes = Buffer.byteLength(JSON.stringify(song), 'utf8');
    if (encodedBytes + bytes > 160 * 1024) break;
    identities.add(identity);
    encodedBytes += bytes;
    songs.push(song);
  }

  const normalizedCurrent = normalizeSong(currentSong);
  if (songs.length === 0 && normalizedCurrent) songs.push(normalizedCurrent);
  return {
    revision: Number.isSafeInteger(revision) ? revision : 0,
    songs,
    updatedAt: now,
  };
}

function normalizePermissions(value) {
  const raw = value && typeof value === 'object' ? value : {};
  return {
    membersCanControlPlayback: Boolean(
      raw.membersCanControlPlayback ?? raw.membersCanChangeTracks,
    ),
  };
}

function normalizeSong(song) {
  if (!song || typeof song !== 'object' || !Number.isSafeInteger(song.id)) return null;
  const encoded = JSON.stringify(song);
  if (Buffer.byteLength(encoded, 'utf8') > 128 * 1024) return null;
  return song;
}

function normalizeChatText(value) {
  return String(value || '')
    .normalize('NFKC')
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F\u200B-\u200D]/gu, '')
    .trim();
}

function validateChatText(text) {
  if (Array.from(text).length > MAX_CHAT_CHARACTERS) return 'chat_too_long';
  const compact = compactSensitiveText(text);
  if (SENSITIVE_MATCHER(compact)) {
    return 'chat_sensitive';
  }
  if (PRIVACY_PATTERNS.some((pattern) => pattern.test(text))) return 'chat_privacy';
  return null;
}

function loadSensitiveTerms(directory) {
  const terms = new Set();
  try {
    const files = fs.readdirSync(directory, { withFileTypes: true })
      .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith('.txt'))
      .map((entry) => entry.name)
      .sort();
    for (const file of files) {
      const content = fs.readFileSync(path.join(directory, file), 'utf8');
      for (const line of content.split(/\r?\n/u)) {
        const term = compactSensitiveText(line.replace(/^\uFEFF/u, '').trim());
        const characters = Array.from(term);
        if (characters.length < 2 || characters.length > 64) continue;
        if (/^[\d\p{P}\p{S}_]+$/u.test(term)) continue;
        if (/^[a-z0-9]+$/iu.test(term) && characters.length < 4) continue;
        terms.add(term);
      }
    }
  } catch (error) {
    throw new Error(`Mono Session sensitive lexicon unavailable: ${directory}`, { cause: error });
  }
  if (terms.size === 0) {
    throw new Error(`Mono Session sensitive lexicon is empty: ${directory}`);
  }
  console.info(`[MonoSession] Sensitive-lexicon loaded terms=${terms.size}`);
  return [...terms];
}

function compactSensitiveText(value) {
  return String(value || '')
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[\s\p{P}\p{S}_]+/gu, '');
}

function createSensitiveMatcher(terms) {
  const root = { children: new Map(), terminal: false };
  for (const term of terms) {
    let node = root;
    for (const character of Array.from(term)) {
      let child = node.children.get(character);
      if (!child) {
        child = { children: new Map(), terminal: false };
        node.children.set(character, child);
      }
      node = child;
    }
    node.terminal = true;
  }

  return (text) => {
    const characters = Array.from(text);
    for (let start = 0; start < characters.length; start += 1) {
      let node = root;
      for (let index = start; index < characters.length; index += 1) {
        node = node.children.get(characters[index]);
        if (!node) break;
        if (node.terminal) return true;
      }
    }
    return false;
  };
}

function publicRoom(room) {
  return {
    id: room.id,
    inviteCode: room.inviteCode,
    hostID: room.hostId,
    participants: publicParticipants(room),
    playback: room.playback,
    queue: room.queue,
    permissions: room.permissions,
    createdAt: room.createdAt,
  };
}

function publicParticipants(room) {
  return [...room.participants.values()].map((entry) => entry.participant);
}

function broadcast(room, payload, excluding = null) {
  for (const entry of room.participants.values()) {
    if (entry.socket && entry.socket !== excluding) send(entry.socket, payload);
  }
}

function send(socket, payload) {
  if (socket.readyState !== WebSocket.OPEN) return;
  socket.send(JSON.stringify(payload));
}

function sendError(socket, requestId, errorCode, errorMessage) {
  send(socket, {
    command: 'error',
    requestID: requestId || crypto.randomUUID(),
    sentAt: new Date().toISOString(),
    errorCode,
    errorMessage,
  });
}

function consumeRateLimit(connection) {
  const now = Date.now();
  if (now - connection.rateWindowStartedAt > 5_000) {
    connection.rateWindowStartedAt = now;
    connection.rateWindowCount = 0;
  }
  connection.rateWindowCount += 1;
  return connection.rateWindowCount <= 30;
}

function createInviteCode(rooms) {
  const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  for (let attempt = 0; attempt < 32; attempt += 1) {
    const bytes = crypto.randomBytes(6);
    const code = [...bytes].map((byte) => alphabet[byte % alphabet.length]).join('');
    if (![...rooms.values()].some((room) => room.inviteCode === code)) return code;
  }
  throw new Error('Invite code space exhausted');
}

function normalizeRequestId(value) {
  const normalized = String(value || '');
  return /^[0-9a-f-]{36}$/i.test(normalized) ? normalized : crypto.randomUUID();
}

function clampNumber(value, lower, upper, fallback) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.min(upper, Math.max(lower, number)) : fallback;
}

function isDate(value) {
  return typeof value === 'string' && Number.isFinite(Date.parse(value));
}

function closeWithPolicy(socket, reason) {
  socket.close(1008, reason);
}

function rejectUpgrade(socket, status, message) {
  socket.write(`HTTP/1.1 ${status} ${message}\r\nConnection: close\r\n\r\n`);
  socket.destroy();
}
