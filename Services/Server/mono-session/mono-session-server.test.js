import assert from 'node:assert/strict';
import http from 'node:http';
import crypto from 'node:crypto';
import { once } from 'node:events';
import test from 'node:test';
import { WebSocket } from 'ws';
import { attachMonoSessionServer } from './mono-session-server.js';

async function fixture(t, validateToken = (token) => ({ id: token })) {
  const server = http.createServer();
  const service = attachMonoSessionServer({ server, validateToken, logger: { warn() {} } });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const sockets = [];
  t.after(async () => {
    for (const socket of sockets) socket.terminate();
    service.close();
    await new Promise((resolve) => server.close(resolve));
  });
  async function connect(account, device) {
    const socket = new WebSocket(`ws://127.0.0.1:${server.address().port}/api/mono-session?deviceId=${device}`, {
      headers: { Authorization: `Bearer ${account}` },
    });
    sockets.push(socket);
    await once(socket, 'open');
    return {
      socket,
      command(command, fields = {}) {
        const requestID = crypto.randomUUID();
        return new Promise((resolve, reject) => {
          const timeout = setTimeout(() => { socket.off('message', receive); reject(new Error('Reply timeout')); }, 2000);
          function receive(raw) {
            const message = JSON.parse(raw);
            if (message.requestID !== requestID) return;
            clearTimeout(timeout);
            socket.off('message', receive);
            resolve(message);
          }
          socket.on('message', receive);
          socket.send(JSON.stringify({ command, requestID, participant: { displayName: 'Fixture' }, ...fields }));
        });
      },
    };
  }
  return { connect, service };
}

test('another account cannot resume or join with the host device ID', { timeout: 10_000 }, async (t) => {
  const { connect, service } = await fixture(t);
  const host = await connect('fixture-account-a', 'host-device');
  const created = await host.command('create');
  const { roomID, room } = created;
  const listener = await connect('fixture-account-b', 'listener-device');
  assert.equal((await listener.command('join', { inviteCode: room.inviteCode })).command, 'room');
  assert.equal((await listener.command('permissions', { permissions: { membersCanControlPlayback: true } })).command, 'error');
  const spoof = await connect('fixture-account-b', 'host-device');
  assert.equal((await spoof.command('resume', { roomID, inviteCode: room.inviteCode })).command, 'error');
  assert.equal((await spoof.command('join', { inviteCode: room.inviteCode })).command, 'error');
  assert.equal((await spoof.command('permissions', { permissions: { membersCanControlPlayback: true } })).command, 'error');
  assert.equal(service.rooms.get(roomID).participants.get('host-device').tokenSubject, 'account:fixture-account-a');
});

test('valid host reconnect keeps ownership and stale socket close cannot end the room', { timeout: 10_000 }, async (t) => {
  const { connect, service } = await fixture(t);
  const host = await connect('fixture-account-a', 'host-device');
  const { roomID, room } = await host.command('create');
  const resumed = await connect('fixture-account-a', 'host-device');
  const closed = once(host.socket, 'close');
  assert.equal((await resumed.command('resume', { roomID, inviteCode: room.inviteCode })).command, 'room');
  await closed;
  assert.equal((await resumed.command('permissions', { permissions: { membersCanControlPlayback: true } })).command, 'participants');
  assert.equal(service.rooms.get(roomID).permissions.membersCanControlPlayback, true);
});

test('validators without a stable account ID still isolate different tokens', { timeout: 10_000 }, async (t) => {
  const { connect } = await fixture(t, () => ({ name: 'same-display-name' }));
  const host = await connect('fixture-a', 'device');
  const { roomID, room } = await host.command('create');
  const other = await connect('fixture-b', 'device');
  assert.equal((await other.command('resume', { roomID, inviteCode: room.inviteCode })).command, 'error');
});
