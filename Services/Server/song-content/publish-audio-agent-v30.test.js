const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')

const { createSongContentConfigStore } = require('./song-content-config')

test('调音 Agent v30 发布保留已配置的技能与必需工具策略', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'song-content-agent-v30-publish-'))
  const databasePath = path.join(directory, 'song-content.sqlite')
  const scriptPath = path.join(__dirname, 'scripts', 'publish-audio-agent-v30.js')
  let store = createSongContentConfigStore({
    databasePath,
    logger: { info() {}, warn() {}, error() {} }
  })

  try {
    const original = store.createDraft({
      actorId: 'test',
      client: {
        agents: {
          equalizer: {
            promptVersion: 'mono-audio-agent-custom-before-v30',
            systemPrompt: '保留当前系统听感指令\n\nMandatory Mono DSP contract (mono-tuning-knowledge-v1); obsolete',
            secondarySystemPrompt: '保留 32 段系统听感指令\n\nMandatory Mono DSP contract (mono-tuning-knowledge-v1); obsolete',
            skills: {
              revision: 'server-skills-r12',
              builtIns: {
                artistReference: false,
                vocalReference: true
              },
              custom: [{
                id: 'transient-focus',
                name: '瞬态聚焦',
                instruction: '仅在瞬态证据充足时调整',
                enabled: true
              }]
            },
            toolPolicy: {
              revision: 'server-tool-r9'
            }
          }
        }
      }
    })
    store.markValidated(original.id, { passed: true }, 'test')
    store.publish(original.id, 'test')
    store.close()
    store = null

    const result = spawnSync(process.execPath, [scriptPath, databasePath, '--publish'], {
      encoding: 'utf8'
    })
    assert.equal(result.status, 0, result.stderr)
    const output = JSON.parse(result.stdout)
    assert.equal(output.changed, true)
    assert.equal(output.skillRevision, 'server-skills-r12')
    assert.equal(output.toolPolicyRevision, 'server-tool-r9')
    assert.equal(output.validationPassed, true)

    store = createSongContentConfigStore({
      databasePath,
      logger: { info() {}, warn() {}, error() {} }
    })
    const published = store.current().client.agents.equalizer
    assert.equal(published.promptVersion, 'mono-audio-agent-v30-dsp')
    assert.match(published.systemPrompt, /Mandatory Mono DSP contract \(mono-tuning-knowledge-v2\)/)
    assert.match(published.secondarySystemPrompt, /Mandatory Mono DSP contract \(mono-tuning-knowledge-v2\)/)
    assert.doesNotMatch(published.systemPrompt, /mono-tuning-knowledge-v1/)
    assert.doesNotMatch(published.secondarySystemPrompt, /mono-tuning-knowledge-v1/)
    assert.equal(published.skills.revision, 'server-skills-r12')
    assert.equal(published.skills.builtIns.artistReference, false)
    assert.equal(published.skills.builtIns.vocalReference, true)
    assert.deepEqual(published.skills.custom, [{
      id: 'transient-focus',
      name: '瞬态聚焦',
      instruction: '仅在瞬态证据充足时调整',
      enabled: true
    }])
    assert.deepEqual(published.toolPolicy, {
      revision: 'server-tool-r9',
      requiredToolName: 'mono_audio_tuning',
      invocationMode: 'required',
      requireExactlyOnce: true,
      localValidationRequired: true,
      allowPromptFallback: false
    })
  } finally {
    store?.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})
