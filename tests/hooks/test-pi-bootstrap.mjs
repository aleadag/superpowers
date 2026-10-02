import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, copyFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

if (!process.features.typescript) {
  console.log('SKIP Pi bootstrap runtime test (Node with native TypeScript support required)');
  process.exit(0);
}

const root = fileURLToPath(new URL('../../', import.meta.url));
const fixture = mkdtempSync(join(tmpdir(), 'pi-bootstrap-'));
const oldPath = process.env.PATH;
try {
  mkdirSync(join(fixture, '.pi/extensions'), { recursive: true });
  mkdirSync(join(fixture, 'skills/using-superpowers/references'), { recursive: true });
  copyFileSync(resolve(root, '.pi/extensions/superpowers.ts'), join(fixture, '.pi/extensions/superpowers.ts'));
  writeFileSync(join(fixture, 'package.json'), '{"type":"module"}');
  writeFileSync(join(fixture, 'skills/using-superpowers/SKILL.md'), '---\nname: using-superpowers\n---\nBootstrap fixture\n');
  const mapping = readFileSync(resolve(root, 'skills/using-superpowers/references/pi-tools.md'), 'utf8');
  const fixtureMapping = mapping + '\nCanonical mapping fixture marker\n';
  writeFileSync(join(fixture, 'skills/using-superpowers/references/pi-tools.md'), fixtureMapping);
  writeFileSync(join(fixture, 'bd'), '#!/bin/sh\n[ "$1" = prime ] || exit 1\nprintf "Beads fixture context\\n"\n', { mode: 0o755 });
  process.env.PATH = fixture;

  const { default: extension } = await import(pathToFileURL(join(fixture, '.pi/extensions/superpowers.ts')).href);
  const handlers = new Map();
  extension({ on: (event, handler) => handlers.set(event, handler) });
  assert.ok(!handlers.has('resources_discover'), 'package skill filters must not be bypassed');
  const manifest = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
  assert.deepEqual(manifest.pi.skills, ['./skills'], 'the package manifest must still expose skills');

  const user = { role: 'user', content: [{ type: 'text', text: 'Review this change' }] };
  const summary = { role: 'compactionSummary', content: 'Prior context' };
  const context = handlers.get('context');
  await handlers.get('session_start')();
  const result = await context({ messages: [summary, user] });
  assert.equal(result.messages[0], summary);
  assert.equal(result.messages[2], user);
  const bootstrap = result.messages[1].content[0].text;
  assert.match(bootstrap, /Bootstrap fixture/);
  assert.ok(bootstrap.includes(fixtureMapping), 'bootstrap must read the canonical reference, not a hardcoded copy');
  assert.match(bootstrap, /<beads-context>\nBeads fixture context/);
  assert.match(bootstrap, /subagents.*agent-to-agent/);
  assert.doesNotMatch(bootstrap, /execute sequentially|do the work in this session|repo-local `TODO\.md`/);
  assert.equal(await context({ messages: result.messages }), undefined, 'do not duplicate bootstrap');
  await handlers.get('agent_end')();
  assert.equal(await context({ messages: [user] }), undefined, 'later turns must not reinject');
  await handlers.get('session_compact')();
  assert.ok((await context({ messages: [summary, user] })).messages[1].content[0].text.includes(fixtureMapping));
  await handlers.get('agent_end')();
  await handlers.get('session_start')();
  assert.ok(await context({ messages: [user] }), 'new sessions must receive bootstrap');
  console.log('PASS Pi bootstrap: canonical mapping, package discovery, beads and lifecycle hooks');
} finally {
  if (oldPath === undefined) delete process.env.PATH;
  else process.env.PATH = oldPath;
  rmSync(fixture, { recursive: true, force: true });
}
