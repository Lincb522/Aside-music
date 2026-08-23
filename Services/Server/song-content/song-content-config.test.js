const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const { createSongContentConfigStore } = require('./song-content-config')

test('默认配置只下发现有 Agent 及其升级版本', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'song-content-agent-config-'))
  const store = createSongContentConfigStore({
    databasePath: path.join(directory, 'song-content.sqlite'),
    logger: { info() {}, warn() {}, error() {} }
  })

  try {
    const release = store.current()
    assert.deepEqual(Object.keys(release.client.agents), [
      'equalizer',
      'listeningInsight',
      'specialGreeting'
    ])
    assert.equal(release.client.agents.equalizer.promptVersion, 'mono-audio-agent-v30-dsp')
    assert.deepEqual(release.client.agents.equalizer.skills, {
      revision: 'mono-audio-skills-v1',
      builtIns: {
        measurementEvidence: true,
        deviceCoordination: true,
        headroomGuard: true,
        phaseGuard: true,
        outputValidation: true,
        artistReference: true,
        vocalReference: true
      },
      custom: []
    })
    assert.deepEqual(release.client.agents.equalizer.toolPolicy, {
      revision: 'mono-audio-tool-policy-v1',
      requiredToolName: 'mono_audio_tuning',
      invocationMode: 'required',
      requireExactlyOnce: true,
      localValidationRequired: true,
      allowPromptFallback: false
    })
    assert.equal(store.publicConfiguration().schema_version, 3)
    assert.deepEqual(
      store.publicConfiguration().agents.equalizer.skills,
      release.client.agents.equalizer.skills
    )
    assert.equal(release.client.agents.listeningInsight.promptVersion, 'mono-listening-insight-v3')
    assert.equal(release.client.agents.specialGreeting.promptVersion, 'special-greeting-v2')
    assert.equal(release.ai.promptVersion, 'song-editor-web-v7')
  } finally {
    store.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})

test('旧内置版本自动升级且 Agent 最大尝试次数会被约束', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'song-content-agent-upgrade-'))
  const store = createSongContentConfigStore({
    databasePath: path.join(directory, 'song-content.sqlite'),
    logger: { info() {}, warn() {}, error() {} }
  })

  try {
    const release = store.createDraft({
      actorId: 'test',
      ai: { promptVersion: 'song-editor-web-v6' },
      client: {
        agents: {
          equalizer: { promptVersion: 'mono-audio-agent-v27', maxAttempts: 99 },
          listeningInsight: { promptVersion: 'mono-listening-insight-v2', maxAttempts: 0 },
          specialGreeting: { promptVersion: 'special-greeting-v1', maxAttempts: 2 },
          obsoleteAgent: { promptVersion: 'removed-agent' }
        }
      }
    })

    assert.equal(release.ai.promptVersion, 'song-editor-web-v7')
    assert.equal(release.client.agents.equalizer.promptVersion, 'mono-audio-agent-v30-dsp')
    assert.equal(release.client.agents.equalizer.maxAttempts, 4)
    assert.equal(release.client.agents.listeningInsight.promptVersion, 'mono-listening-insight-v3')
    assert.equal(release.client.agents.listeningInsight.maxAttempts, 1)
    assert.equal(release.client.agents.specialGreeting.promptVersion, 'special-greeting-v2')
    assert.equal('obsoleteAgent' in release.client.agents, false)
  } finally {
    store.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})

test('没有自定义提示词的历史调音 Agent 会迁移到内置 DSP 版本', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'song-content-agent-dsp-upgrade-'))
  const store = createSongContentConfigStore({
    databasePath: path.join(directory, 'song-content.sqlite'),
    logger: { info() {}, warn() {}, error() {} }
  })

  try {
    for (const promptVersion of [
      'mono-audio-agent-v27',
      'mono-audio-agent-v28',
      'mono-audio-agent-v29-airpods'
    ]) {
      const release = store.createDraft({
        actorId: 'test',
        client: { agents: { equalizer: { promptVersion } } }
      })
      assert.equal(release.client.agents.equalizer.promptVersion, 'mono-audio-agent-v30-dsp')
    }
  } finally {
    store.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})

test('自定义调音提示词保留指定版本并由客户端叠加内置安全契约', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'song-content-agent-custom-prompt-'))
  const store = createSongContentConfigStore({
    databasePath: path.join(directory, 'song-content.sqlite'),
    logger: { info() {}, warn() {}, error() {} }
  })

  try {
    const release = store.createDraft({
      actorId: 'test',
      client: {
        agents: {
          equalizer: {
            promptVersion: 'mono-audio-agent-custom',
            systemPrompt: '保留用户自定义听感方向'
          }
        }
      }
    })
    assert.equal(release.client.agents.equalizer.promptVersion, 'mono-audio-agent-custom')
    assert.equal(release.client.agents.equalizer.systemPrompt, '保留用户自定义听感方向')
  } finally {
    store.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})

test('调音技能兼容旧字段并按客户端边界规范化后下发', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'song-content-agent-skills-'))
  const store = createSongContentConfigStore({
    databasePath: path.join(directory, 'song-content.sqlite'),
    logger: { info() {}, warn() {}, error() {} }
  })

  try {
    const customSkills = Array.from({ length: 14 }, (_, index) => ({
      id: ` skill-${index} `,
      name: ` 技能  ${index} `,
      instruction: `根据   第 ${index} 组参考信号 调整`,
      isEnabled: true
    }))
    customSkills[1].instruction = ''
    customSkills[2].id = 'x'.repeat(90)
    const release = store.createDraft({
      actorId: 'test',
      client: {
        agents: {
          equalizer: {
            skillConfiguration: {
              revision: ' server-skill-r8 ',
              builtIns: {
                measurementEvidence: false,
                headroomGuard: false,
                artistReference: false,
                unknownSkill: true
              },
              customSkills
            },
            tool_policy: {
              revision: ' server-tool-r4 ',
              requiredToolName: 'other_tool',
              invocationMode: 'disabled',
              requireExactlyOnce: false,
              localValidationRequired: false,
              allowPromptFallback: true
            }
          }
        }
      }
    })
    const equalizer = release.client.agents.equalizer

    assert.equal(equalizer.skills.revision, 'server-skill-r8')
    assert.equal(equalizer.skills.builtIns.measurementEvidence, true)
    assert.equal(equalizer.skills.builtIns.headroomGuard, true)
    assert.equal(equalizer.skills.builtIns.artistReference, false)
    assert.equal('unknownSkill' in equalizer.skills.builtIns, false)
    assert.equal(equalizer.skills.custom.length, 12)
    assert.equal(equalizer.skills.custom.filter((skill) => skill.enabled).length, 4)
    assert.equal(equalizer.skills.custom[0].id, 'skill-0')
    assert.equal(equalizer.skills.custom[1].id, 'x'.repeat(80))
    assert.equal(equalizer.skills.custom[0].name, '技能 0')
    assert.equal(equalizer.skills.custom[0].instruction, '根据 第 0 组参考信号 调整')
    assert.equal('skillConfiguration' in equalizer, false)

    assert.deepEqual(equalizer.toolPolicy, {
      revision: 'server-tool-r4',
      requiredToolName: 'mono_audio_tuning',
      invocationMode: 'required',
      requireExactlyOnce: true,
      localValidationRequired: true,
      allowPromptFallback: false
    })
    assert.deepEqual(store.get(release.id).client.agents.equalizer.skills, equalizer.skills)
    store.markValidated(release.id, { passed: true }, 'test')
    store.publish(release.id, 'test')
    assert.deepEqual(store.publicConfiguration().agents.equalizer.toolPolicy, equalizer.toolPolicy)
  } finally {
    store.close()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})

test('Agent 管理页提供调音技能和工具策略编辑入口', () => {
  const uiDirectory = path.join(__dirname, '..', 'token-admin-ui', 'original')
  const html = fs.readFileSync(path.join(uiDirectory, 'song-content.html'), 'utf8')
  const script = fs.readFileSync(path.join(uiDirectory, 'song-content-page.js'), 'utf8')

  assert.match(html, /data-agent-skill-field="revision"/)
  assert.match(html, /data-agent-builtin="artistReference"/)
  assert.match(html, /data-custom-skill-list/)
  assert.match(html, /data-agent-tool-field="invocationMode"/)
  assert.match(script, /function fillEqualizerAgentSkills/)
  assert.match(script, /function readEqualizerAgentSkills/)
  assert.match(script, /同时启用的自定义技能最多 4 个/)
})
