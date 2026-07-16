<script setup>
import { computed, onMounted, ref, watch } from 'vue'

const props = defineProps({
  icon: { type: String, required: true },
  wordmark: { type: String, required: true },
})

const emit = defineEmits(['navigate-home'])

const categories = [
  { value: 'bug', label: 'Bug' },
  { value: 'feature', label: '功能建议' },
  { value: 'experience', label: '体验问题' },
  { value: 'other', label: '其他' },
]

const platforms = ['iPhone', 'iPad', 'Mac', '其他']
const draftKey = 'mono-public-feedback-draft-v1'
const feedbacks = ref([])
const listLoading = ref(true)
const listError = ref('')
const activeFilter = ref('all')
const submitting = ref(false)
const submitError = ref('')
const submitMessage = ref('')

const form = ref({
  category: 'bug',
  title: '',
  description: '',
  steps: '',
  platform: 'iPhone',
  appVersion: '',
  contact: '',
  consent: false,
  company: '',
})

const filteredFeedbacks = computed(() => {
  if (activeFilter.value === 'all') return feedbacks.value
  return feedbacks.value.filter((item) => item.category === activeFilter.value)
})

const descriptionCount = computed(() => form.value.description.length)

watch(
  form,
  (value) => {
    localStorage.setItem(draftKey, JSON.stringify({
      category: value.category,
      title: value.title,
      description: value.description,
      steps: value.steps,
      platform: value.platform,
      appVersion: value.appVersion,
      contact: value.contact,
    }))
  },
  { deep: true }
)

onMounted(() => {
  restoreDraft()
  fetchFeedbacks()
})

function restoreDraft() {
  try {
    const saved = JSON.parse(localStorage.getItem(draftKey) || 'null')
    if (!saved || typeof saved !== 'object') return
    form.value = { ...form.value, ...saved, consent: false, company: '' }
  } catch {}
}

async function parseJson(response, fallbackMessage) {
  const contentType = response.headers.get('content-type') || ''
  if (!contentType.includes('application/json')) throw new Error(fallbackMessage)
  const payload = await response.json()
  if (!response.ok) throw new Error(payload.message || fallbackMessage)
  return payload
}

async function fetchFeedbacks() {
  listLoading.value = true
  listError.value = ''
  try {
    const response = await fetch('/api/public/feedback')
    const payload = await parseJson(response, '反馈列表读取失败。')
    feedbacks.value = Array.isArray(payload.data) ? payload.data : []
  } catch (error) {
    listError.value = error.message || '反馈列表读取失败。'
  } finally {
    listLoading.value = false
  }
}

async function submitFeedback() {
  submitError.value = ''
  submitMessage.value = ''

  const title = form.value.title.trim()
  const description = form.value.description.trim()
  if (title.length < 4) {
    submitError.value = '标题至少填写 4 个字。'
    return
  }
  if (description.length < 10) {
    submitError.value = '反馈内容至少填写 10 个字。'
    return
  }
  if (!form.value.consent) {
    submitError.value = '请确认公开提交内容。'
    return
  }

  submitting.value = true
  try {
    const response = await fetch('/api/public/feedback', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        category: form.value.category,
        title,
        description,
        steps: form.value.steps.trim(),
        platform: form.value.platform,
        appVersion: form.value.appVersion.trim(),
        contact: form.value.contact.trim(),
        company: form.value.company,
      }),
    })
    const payload = await parseJson(response, '提交失败，请稍后重试。')
    if (payload.data) feedbacks.value = [payload.data, ...feedbacks.value]
    submitMessage.value = `已提交 · ${payload.data?.id || ''}`
    form.value.title = ''
    form.value.description = ''
    form.value.steps = ''
    form.value.contact = ''
    form.value.consent = false
    localStorage.removeItem(draftKey)
  } catch (error) {
    submitError.value = error.message || '提交失败，请稍后重试。'
  } finally {
    submitting.value = false
  }
}

function categoryLabel(value) {
  return categories.find((item) => item.value === value)?.label || '其他'
}

function formatDate(value) {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}
</script>

<template>
  <section class="feedback-page" aria-labelledby="feedback-title">
    <header class="feedback-brandbar">
      <a class="feedback-brand" href="/" @click.prevent="emit('navigate-home', $event)">
        <img :src="props.icon" alt="" />
        <img class="feedback-wordmark" :src="props.wordmark" alt="Mono" />
      </a>
      <a class="feedback-home" href="/" @click.prevent="emit('navigate-home', $event)">首页</a>
    </header>

    <div class="feedback-heading">
      <h1 id="feedback-title">意见与 Bug 反馈</h1>
      <p>提交内容会显示在公开反馈列表中。</p>
    </div>

    <div class="feedback-layout">
      <section class="feedback-composer" aria-labelledby="feedback-form-title">
        <div class="feedback-panel-heading">
          <h2 id="feedback-form-title">提交反馈</h2>
          <span>公开</span>
        </div>

        <form class="feedback-form" @submit.prevent="submitFeedback">
          <fieldset class="feedback-category-fieldset">
            <legend>类型</legend>
            <div class="feedback-category-tabs">
              <label v-for="category in categories" :key="category.value">
                <input v-model="form.category" type="radio" name="feedback-category" :value="category.value" />
                <span>{{ category.label }}</span>
              </label>
            </div>
          </fieldset>

          <label class="feedback-field">
            <span>标题</span>
            <input
              v-model="form.title"
              type="text"
              maxlength="80"
              autocomplete="off"
              placeholder="简要说明问题或建议"
              required
            />
          </label>

          <label class="feedback-field">
            <span>内容</span>
            <textarea
              v-model="form.description"
              maxlength="4000"
              rows="7"
              placeholder="发生了什么？"
              required
            ></textarea>
            <small>{{ descriptionCount }}/4000</small>
          </label>

          <label v-if="form.category === 'bug'" class="feedback-field">
            <span>复现步骤</span>
            <textarea
              v-model="form.steps"
              maxlength="2000"
              rows="4"
              placeholder="1.&#10;2.&#10;3."
            ></textarea>
          </label>

          <div class="feedback-field-row">
            <label class="feedback-field">
              <span>设备</span>
              <select v-model="form.platform">
                <option v-for="platform in platforms" :key="platform" :value="platform">{{ platform }}</option>
              </select>
            </label>
            <label class="feedback-field">
              <span>App 版本</span>
              <input v-model="form.appVersion" type="text" maxlength="32" placeholder="例如 1.0 (52)" />
            </label>
          </div>

          <label class="feedback-field">
            <span>联系方式（选填）</span>
            <input
              v-model="form.contact"
              type="text"
              maxlength="120"
              autocomplete="email"
              placeholder="邮箱 / 微信 / Telegram"
            />
            <small>不会公开显示</small>
          </label>

          <label class="feedback-consent">
            <input v-model="form.consent" type="checkbox" />
            <span>我同意公开显示标题、内容、设备和 App 版本。</span>
          </label>

          <label class="feedback-honeypot" aria-hidden="true">
            <span>Company</span>
            <input v-model="form.company" type="text" tabindex="-1" autocomplete="off" />
          </label>

          <button class="feedback-submit" type="submit" :disabled="submitting">
            {{ submitting ? '提交中…' : '提交反馈' }}
          </button>

          <p v-if="submitError" class="feedback-message is-error" role="alert">{{ submitError }}</p>
          <p v-else-if="submitMessage" class="feedback-message is-success" role="status">{{ submitMessage }}</p>
        </form>
      </section>

      <aside class="feedback-board" aria-labelledby="feedback-board-title">
        <div class="feedback-panel-heading">
          <h2 id="feedback-board-title">最近反馈</h2>
          <button type="button" :disabled="listLoading" @click="fetchFeedbacks">刷新</button>
        </div>

        <div class="feedback-filters" aria-label="反馈筛选">
          <button
            v-for="filter in [{ value: 'all', label: '全部' }, ...categories]"
            :key="filter.value"
            type="button"
            :class="{ 'is-active': activeFilter === filter.value }"
            @click="activeFilter = filter.value"
          >
            {{ filter.label }}
          </button>
        </div>

        <div v-if="listLoading" class="feedback-skeleton-list" aria-label="正在读取反馈">
          <span v-for="n in 4" :key="n"></span>
        </div>
        <div v-else-if="listError" class="feedback-list-state">
          <p>{{ listError }}</p>
          <button type="button" @click="fetchFeedbacks">重试</button>
        </div>
        <div v-else-if="filteredFeedbacks.length" class="feedback-list">
          <article v-for="item in filteredFeedbacks" :key="item.id" class="feedback-item">
            <div class="feedback-item-meta">
              <span class="feedback-kind" :class="`is-${item.category}`">{{ categoryLabel(item.category) }}</span>
              <time :datetime="item.createdAt">{{ formatDate(item.createdAt) }}</time>
            </div>
            <h3>{{ item.title }}</h3>
            <p>{{ item.description }}</p>
            <details v-if="item.steps">
              <summary>复现步骤</summary>
              <p>{{ item.steps }}</p>
            </details>
            <footer>
              <span>{{ item.id }}</span>
              <span v-if="item.platform">{{ item.platform }}</span>
              <span v-if="item.appVersion">v{{ item.appVersion }}</span>
              <span class="feedback-status">已收到</span>
            </footer>
          </article>
        </div>
        <p v-else class="feedback-list-state">暂无反馈</p>
      </aside>
    </div>
  </section>
</template>

<style scoped>
.feedback-page {
  width: 100%;
  color: #1b1712;
}

.feedback-brandbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 56px;
  border-bottom: 1px solid rgba(27, 23, 18, 0.1);
}

.feedback-brand {
  display: inline-flex;
  align-items: center;
  gap: 10px;
}

.feedback-brand > img:first-child {
  width: 32px;
  height: 32px;
  border-radius: 8px;
}

.feedback-wordmark {
  width: 82px;
  height: auto;
}

.feedback-home,
.feedback-panel-heading button {
  border: 0;
  background: transparent;
  color: #665e54;
  cursor: pointer;
  font-size: 13px;
  font-weight: 760;
}

.feedback-home:hover,
.feedback-panel-heading button:hover:not(:disabled) {
  color: #1b1712;
}

.feedback-heading {
  padding: 52px 0 32px;
}

.feedback-heading h1 {
  position: static;
  width: auto;
  height: auto;
  margin: 0;
  overflow: visible;
  clip: auto;
  color: #1b1712;
  font-size: 38px;
  font-weight: 880;
  letter-spacing: -0.035em;
  line-height: 1.12;
  text-wrap: balance;
}

.feedback-heading p {
  margin: 10px 0 0;
  color: #665e54;
  font-size: 14px;
  font-weight: 620;
}

.feedback-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.02fr) minmax(360px, 0.98fr);
  align-items: start;
  gap: 24px;
}

.feedback-composer,
.feedback-board {
  border-top: 1px solid rgba(27, 23, 18, 0.14);
  padding-top: 18px;
}

.feedback-board {
  position: sticky;
  top: 24px;
}

.feedback-panel-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  min-height: 30px;
  margin-bottom: 18px;
}

.feedback-panel-heading h2 {
  margin: 0;
  font-size: 17px;
  font-weight: 840;
  letter-spacing: -0.02em;
}

.feedback-panel-heading > span {
  padding: 5px 9px;
  border-radius: 999px;
  background: rgba(248, 183, 15, 0.16);
  color: #885d09;
  font-size: 11px;
  font-weight: 780;
}

.feedback-form {
  display: grid;
  gap: 17px;
}

.feedback-category-fieldset {
  min-width: 0;
  margin: 0;
  padding: 0;
  border: 0;
}

.feedback-category-fieldset legend,
.feedback-field > span {
  display: block;
  margin-bottom: 8px;
  color: #665e54;
  font-size: 12px;
  font-weight: 760;
}

.feedback-category-tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.feedback-category-tabs label {
  cursor: pointer;
}

.feedback-category-tabs input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.feedback-category-tabs span,
.feedback-filters button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 34px;
  padding: 0 12px;
  border: 1px solid rgba(27, 23, 18, 0.1);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.5);
  color: #665e54;
  cursor: pointer;
  font-size: 12px;
  font-weight: 720;
  transition: background-color 180ms ease, border-color 180ms ease, color 180ms ease;
}

.feedback-category-tabs input:checked + span,
.feedback-filters button.is-active {
  border-color: #1b1712;
  background: #1b1712;
  color: #fffdf8;
}

.feedback-category-tabs input:focus-visible + span,
.feedback-filters button:focus-visible,
.feedback-home:focus-visible,
.feedback-panel-heading button:focus-visible {
  outline: 3px solid rgba(248, 183, 15, 0.34);
  outline-offset: 2px;
}

.feedback-field {
  display: block;
  min-width: 0;
}

.feedback-field input,
.feedback-field textarea,
.feedback-field select {
  width: 100%;
  border: 1px solid rgba(27, 23, 18, 0.13);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.64);
  color: #1b1712;
  font: inherit;
  font-size: 14px;
  font-weight: 600;
  outline: none;
  transition: border-color 180ms ease, box-shadow 180ms ease, background-color 180ms ease;
}

.feedback-field input,
.feedback-field select {
  min-height: 46px;
  padding: 0 13px;
}

.feedback-field textarea {
  min-height: 112px;
  padding: 12px 13px;
  resize: vertical;
  line-height: 1.58;
}

.feedback-field input::placeholder,
.feedback-field textarea::placeholder {
  color: #777066;
  opacity: 1;
}

.feedback-field input:focus,
.feedback-field textarea:focus,
.feedback-field select:focus {
  border-color: #a87716;
  background: #fff;
  box-shadow: 0 0 0 3px rgba(248, 183, 15, 0.18);
}

.feedback-field small {
  display: block;
  margin-top: 6px;
  color: #777066;
  font-size: 11px;
  text-align: right;
}

.feedback-field-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.feedback-consent {
  display: flex;
  align-items: flex-start;
  gap: 9px;
  color: #554e45;
  cursor: pointer;
  font-size: 12px;
  font-weight: 620;
  line-height: 1.55;
}

.feedback-consent input {
  width: 17px;
  height: 17px;
  margin: 1px 0 0;
  accent-color: #1b1712;
}

.feedback-honeypot {
  position: absolute;
  left: -9999px;
  width: 1px;
  height: 1px;
  overflow: hidden;
}

.feedback-submit {
  min-height: 48px;
  border: 0;
  border-radius: 12px;
  background: #1b1712;
  color: #fffdf8;
  cursor: pointer;
  font-size: 14px;
  font-weight: 820;
  transition: background-color 180ms ease, transform 180ms ease, opacity 180ms ease;
}

.feedback-submit:hover:not(:disabled) {
  background: #342c24;
  transform: translateY(-1px);
}

.feedback-submit:disabled {
  cursor: wait;
  opacity: 0.55;
}

.feedback-message {
  margin: -4px 0 0;
  font-size: 12px;
  font-weight: 680;
}

.feedback-message.is-error {
  color: #a52b35;
}

.feedback-message.is-success {
  color: #23663b;
}

.feedback-filters {
  display: flex;
  gap: 7px;
  margin-bottom: 14px;
  padding-bottom: 4px;
  overflow-x: auto;
  scrollbar-width: none;
}

.feedback-filters::-webkit-scrollbar {
  display: none;
}

.feedback-filters button {
  flex: 0 0 auto;
  min-height: 30px;
  padding: 0 10px;
  border: 0;
  background: rgba(27, 23, 18, 0.055);
}

.feedback-list {
  display: grid;
  max-height: min(690px, calc(100vh - 250px));
  overflow-y: auto;
  border-top: 1px solid rgba(27, 23, 18, 0.09);
}

.feedback-item {
  padding: 17px 2px;
  border-bottom: 1px solid rgba(27, 23, 18, 0.09);
}

.feedback-item-meta,
.feedback-item footer {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
}

.feedback-item-meta {
  justify-content: space-between;
}

.feedback-item-meta time,
.feedback-item footer {
  color: #777066;
  font-size: 11px;
  font-weight: 640;
}

.feedback-kind {
  padding: 4px 7px;
  border-radius: 6px;
  background: rgba(27, 23, 18, 0.07);
  color: #554e45;
  font-size: 10px;
  font-weight: 800;
}

.feedback-kind.is-bug {
  background: rgba(192, 45, 58, 0.1);
  color: #9e2531;
}

.feedback-kind.is-feature {
  background: rgba(22, 94, 161, 0.1);
  color: #15558e;
}

.feedback-kind.is-experience {
  background: rgba(163, 105, 7, 0.12);
  color: #805303;
}

.feedback-item h3 {
  margin: 10px 0 7px;
  font-size: 15px;
  font-weight: 820;
  letter-spacing: -0.015em;
  line-height: 1.35;
}

.feedback-item > p,
.feedback-item details p {
  margin: 0;
  color: #554e45;
  font-size: 13px;
  font-weight: 560;
  line-height: 1.58;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}

.feedback-item details {
  margin-top: 10px;
}

.feedback-item summary {
  color: #665e54;
  cursor: pointer;
  font-size: 12px;
  font-weight: 720;
}

.feedback-item details p {
  margin-top: 8px;
  padding: 10px 11px;
  border-radius: 8px;
  background: rgba(27, 23, 18, 0.045);
}

.feedback-item footer {
  margin-top: 12px;
}

.feedback-status {
  margin-left: auto;
  color: #23663b;
}

.feedback-list-state {
  margin: 0;
  padding: 34px 0;
  color: #665e54;
  font-size: 13px;
  text-align: center;
}

.feedback-list-state button {
  margin-top: 10px;
  border: 0;
  background: transparent;
  color: #1b1712;
  cursor: pointer;
  font-weight: 760;
  text-decoration: underline;
  text-underline-offset: 3px;
}

.feedback-skeleton-list {
  display: grid;
  gap: 1px;
  overflow: hidden;
  border-top: 1px solid rgba(27, 23, 18, 0.08);
}

.feedback-skeleton-list span {
  height: 118px;
  background: linear-gradient(90deg, rgba(27, 23, 18, 0.035), rgba(27, 23, 18, 0.075), rgba(27, 23, 18, 0.035));
  background-size: 220% 100%;
  animation: feedback-loading 1.2s ease-in-out infinite;
}

@keyframes feedback-loading {
  to { background-position: -120% 0; }
}

@media (max-width: 820px) {
  .feedback-heading {
    padding: 38px 0 26px;
  }

  .feedback-heading h1 {
    font-size: 32px;
  }

  .feedback-layout {
    grid-template-columns: 1fr;
    gap: 42px;
  }

  .feedback-board {
    position: static;
  }

  .feedback-list {
    max-height: none;
  }
}

@media (max-width: 520px) {
  .feedback-heading h1 {
    font-size: 28px;
  }

  .feedback-field-row {
    grid-template-columns: 1fr;
  }

  .feedback-category-tabs {
    display: grid;
    grid-template-columns: 1fr 1fr;
  }

  .feedback-category-tabs span {
    width: 100%;
  }
}

@media (prefers-reduced-motion: reduce) {
  .feedback-category-tabs span,
  .feedback-filters button,
  .feedback-field input,
  .feedback-field textarea,
  .feedback-field select,
  .feedback-submit {
    transition: none;
  }

  .feedback-skeleton-list span {
    animation: none;
  }
}
</style>
