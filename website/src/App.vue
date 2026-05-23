<script setup>
import { useLandingViewModel } from './viewmodels/useLandingViewModel'

const {
  assets,
  content,
  currentPage,
  contactCopied,
  showContactDialog,
  tokenQueryInput,
  tokenQueryLoading,
  tokenQueryError,
  tokenQueryMessage,
  tokenResults,
  copiedTokenKey,
  updatesLoading,
  updatesError,
  latestUpdate,
  historyUpdates,
  showHistoryUpdates,
  downloadTab,
  ipaRegisterName,
  ipaRegisterEmail,
  ipaRegisterProtectCode,
  ipaRegisterSubmitting,
  ipaRegisterError,
  ipaRegisterMessage,
  ipaRegisterResult,
  testFlightInfo,
  testFlightLoading,
  testFlightSubmitting,
  testFlightTrialSubmitting,
  testFlightError,
  testFlightMessage,
  testFlightResult,
  testFlightDuplicateDialog,
  testFlightNoticeDialog,
  testFlightName,
  testFlightEmail,
  testFlightProtectCode,
  testFlightCheckingEmail,
  miniPlayerAudio,
  miniPlayerLoading,
  miniPlayerError,
  miniPlayerTrack,
  miniPlayerArtist,
  miniPlayerCover,
  miniPlayerPlaying,
  miniPlayerExpanded,
  openContactDialog,
  copyWechatAndOpen,
  closeContactDialog,
  queryToken,
  fetchUpdates,
  submitIpaRegister,
  toggleUpdateLog,
  isUpdateLogExpanded,
  toggleHistoryUpdates,
  setDownloadTab,
  fetchTestFlightInfo,
  submitTestFlightInvite,
  submitTestFlightTrial,
  closeTestFlightDuplicateDialog,
  changeTestFlightEmail,
  closeTestFlightNoticeDialog,
  goToTokenQuery,
  openMailboxForTestFlight,
  toggleMiniPlayer,
  toggleMiniPlayerPanel,
  nextMiniPlayerTrack,
  onMiniPlayerPlay,
  onMiniPlayerPause,
  onMiniPlayerError,
  copyTokenKey,
  tokenStatusLabel,
  tokenStatusClass,
  formatDate,
  formatSize,
  navigateTo,
} = useLandingViewModel()
</script>

<template>
  <div class="dynamic-ambient-backdrop" aria-hidden="true">
    <div class="ambient-glow glow-1"></div>
    <div class="ambient-glow glow-2"></div>
    <div class="ambient-glow glow-3"></div>
  </div>

  <main id="top" class="page-shell" :class="{ 'page-shell-subpage': currentPage !== 'home' }">
    <section v-if="currentPage === 'home'" class="hero-section" aria-labelledby="hero-title">
      <img class="app-icon" :src="assets.pawIcon" alt="" />
      <img class="hero-wordmark" :src="assets.monoTextBlack" alt="mono" />
      <h1 id="hero-title">{{ content.hero.title }}</h1>
      <p class="hero-slogan">{{ content.hero.slogan }}</p>
      <p class="hero-lead">{{ content.hero.lead }}</p>

      <div class="hero-actions" aria-label="主要操作">
        <div class="hero-action-main">
          <a class="action-button action-button-primary" :href="content.purchase.href" @click="navigateTo(content.purchase.href, $event)">
            {{ content.purchase.label }}
          </a>
          <button class="action-button action-button-secondary" type="button" @click="openContactDialog">
            {{ content.contact.label }}
          </button>
        </div>
        <div class="hero-action-links" aria-label="更多功能">
          <a href="/token" @click="navigateTo('/token', $event)">{{ content.tokenQuery.label }}</a>
          <a :href="content.ipaDownload.href" @click="navigateTo(content.ipaDownload.href, $event)">{{ content.ipaDownload.label }}</a>
          <a href="/updates" @click="navigateTo('/updates', $event)">{{ content.updates.label }}</a>
        </div>
      </div>
    </section>

    <div v-if="miniPlayerPlaying" class="immersive-soundwave" aria-hidden="true">
      <span v-for="n in 64" :key="n" :style="{ '--i': n }"></span>
    </div>

    <aside class="mini-player" :class="{ 'is-playing': miniPlayerPlaying, 'is-expanded': miniPlayerExpanded }" aria-label="迷你播放器">
      <div class="mini-player-panel">
        <button class="mini-panel-artwork" type="button" :disabled="miniPlayerLoading" @click="toggleMiniPlayer">
          <img :src="miniPlayerCover" alt="" />
        </button>
        <button class="mini-track-info" type="button" :disabled="miniPlayerLoading" @click="toggleMiniPlayer">
          <strong>{{ miniPlayerTrack?.name || (miniPlayerLoading ? '准备播放中' : '今日推荐') }}</strong>
          <small>{{ miniPlayerError || miniPlayerArtist }}</small>
        </button>
        <button class="mini-play-button" type="button" :disabled="miniPlayerLoading" @click="toggleMiniPlayer">
          {{ miniPlayerPlaying ? 'Ⅱ' : '▶' }}
        </button>
        <button class="mini-next-button" type="button" :disabled="miniPlayerLoading" @click="nextMiniPlayerTrack">›</button>
      </div>
      <button class="mini-player-ball" type="button" :disabled="miniPlayerLoading" @click="toggleMiniPlayerPanel">
        <span class="vinyl-disc">
          <img :src="miniPlayerCover" alt="" />
        </span>
      </button>
      <audio
        ref="miniPlayerAudio"
        preload="none"
        crossorigin="anonymous"
        @play="onMiniPlayerPlay"
        @pause="onMiniPlayerPause"
        @ended="nextMiniPlayerTrack"
        @error="onMiniPlayerError"
      ></audio>
    </aside>

    <section v-if="currentPage === 'token'" class="subpage-section token-page" aria-labelledby="token-query-title">
      <header class="subpage-brand-hero">
        <img class="subpage-hero-icon" :src="assets.pawIcon" alt="" />
        <img class="subpage-hero-wordmark" :src="assets.monoTextBlack" alt="mono" />
        <p>{{ content.tokenQuery.lead }}</p>
      </header>

      <article class="mono-feature-card">
        <h2 id="token-query-title">{{ content.tokenQuery.title }}</h2>
        <p class="feature-desc">输入邮箱、用户名或 Token Key，查询你的授权信息。</p>

        <form class="mono-form" @submit.prevent="queryToken">
          <label>
            <span>查询内容</span>
            <input v-model="tokenQueryInput" :placeholder="content.tokenQuery.placeholder" autocomplete="off" />
          </label>
          <button type="submit" :disabled="tokenQueryLoading">
            {{ tokenQueryLoading ? content.tokenQuery.loadingLabel : content.tokenQuery.submitLabel }}
          </button>
        </form>

        <p v-if="tokenQueryError" class="section-message is-error">{{ tokenQueryError }}</p>
        <p v-else-if="tokenQueryMessage" class="section-message">{{ tokenQueryMessage }}</p>

        <div v-if="tokenResults.length" class="token-result-list">
          <article v-for="token in tokenResults" :key="token.id || token.key" class="token-result-card">
            <div class="token-result-header">
              <div>
                <h3>{{ token.registeredName || token.name || 'mono user' }}</h3>
                <p>{{ token.email || '未填写邮箱' }}</p>
              </div>
              <span class="token-status" :class="tokenStatusClass(token)">
                {{ tokenStatusLabel(token) }}
              </span>
            </div>
            <div class="token-key-row">
              <code>{{ token.key }}</code>
              <button type="button" @click="copyTokenKey(token.key)">
                {{ copiedTokenKey === token.key ? content.tokenQuery.copiedLabel : content.tokenQuery.copyLabel }}
              </button>
            </div>
            <div class="token-meta-grid">
              <span>创建 {{ formatDate(token.createdAt) }}</span>
              <span>到期 {{ formatDate(token.expiresAt) }}</span>
            </div>
          </article>
        </div>
      </article>

      <a class="subpage-home-link" href="/" @click="navigateTo('/', $event)">返回 mono 首页</a>
    </section>

    <section v-if="currentPage === 'testflight'" class="subpage-section testflight-page" aria-labelledby="testflight-title">
      <header class="subpage-brand-hero">
        <img class="subpage-hero-icon" :src="assets.pawIcon" alt="" />
        <img class="subpage-hero-wordmark" :src="assets.monoTextBlack" alt="mono" />
        <p>{{ testFlightInfo?.group_name || 'TestFlight 测试组' }}</p>
      </header>

      <div v-if="testFlightLoading" class="section-placeholder">读取 TestFlight 信息中...</div>
      <div v-else-if="testFlightError && !testFlightInfo" class="section-placeholder">
        <p>{{ testFlightError }}</p>
        <button type="button" @click="fetchTestFlightInfo">重新读取</button>
      </div>

      <div v-else class="testflight-layout">
        <article class="mono-feature-card">
          <h2 id="testflight-title">{{ content.testflight.title }}</h2>
          <p class="feature-desc">填写你的信息以加入 TestFlight 测试组，提交后将通过邮件收到邀请。</p>

          <form class="mono-form" @submit.prevent="submitTestFlightInvite">
            <label>
              <span>测试姓名</span>
              <input v-model="testFlightName" :placeholder="content.testflight.namePlaceholder" autocomplete="name" />
            </label>
            <label>
              <span>Apple ID 邮箱</span>
              <input v-model="testFlightEmail" :placeholder="content.testflight.emailPlaceholder" autocomplete="email" type="email" />
            </label>
            <label>
              <span>保护码</span>
              <input v-model="testFlightProtectCode" class="code-input" :placeholder="content.testflight.protectCodePlaceholder" autocomplete="off" />
            </label>
            <button type="submit" :disabled="testFlightSubmitting || testFlightTrialSubmitting || testFlightCheckingEmail">
              {{ (testFlightSubmitting || testFlightCheckingEmail) ? content.testflight.loadingLabel : content.testflight.submitLabel }}
            </button>
          </form>

          <div class="mono-card-divider">
            <p>没有保护码？可免费体验 1 小时</p>
            <button type="button" class="mono-secondary-button" :disabled="testFlightSubmitting || testFlightTrialSubmitting || testFlightCheckingEmail" @click="submitTestFlightTrial">
              {{ (testFlightTrialSubmitting || testFlightCheckingEmail) ? content.testflight.loadingLabel : content.testflight.trialLabel }}
            </button>
          </div>

        </article>

        <article v-if="testFlightResult" class="testflight-result-card tf-token-query-card">
          <span>Token Query</span>
          <h3>查询 Token</h3>
          <p>申请成功后如果忘记复制，或之后忘记 Token，都可以前往查询页用邮箱找回。</p>
          <a class="release-download tf-token-query-link" href="/token" @click="navigateTo('/token', $event)">
            查询 Token
          </a>
        </article>

        <div class="mono-guide">
          <div class="mono-guide-title">使用指南</div>
          <div class="mono-guide-item">
            <span>1</span>
            <p>填写<strong>姓名</strong>和 <strong>Apple ID 邮箱</strong></p>
          </div>
          <div class="mono-guide-item">
            <span>2</span>
            <p>查收 TestFlight <strong>邀请邮件</strong>，点击邮件获取兑换码</p>
          </div>
          <div class="mono-guide-item">
            <span>3</span>
            <p>打开 TestFlight App，点击右上角头像，选择<strong>兑换邀请码</strong>，输入邀请码即可加入测试组并安装</p>
          </div>
        </div>

        <article class="xianyu-card">
          <div>
            <h3>{{ content.xianyu.label }}</h3>
            <p>{{ content.xianyu.lead }}</p>
          </div>
          <a class="release-download" :href="content.xianyu.href" target="_blank" rel="noreferrer">
            {{ content.xianyu.label }}
          </a>
        </article>
      </div>

      <a class="subpage-home-link" href="/" @click="navigateTo('/', $event)">返回 mono 首页</a>
    </section>

    <section v-if="currentPage === 'updates'" class="subpage-section updates-page" aria-labelledby="updates-title">
      <header class="subpage-brand-hero">
        <img class="subpage-hero-icon" :src="assets.pawIcon" alt="" />
        <img class="subpage-hero-wordmark" :src="assets.monoTextBlack" alt="mono" />
        <p>{{ content.updates.lead }}</p>
      </header>

      <a class="subpage-home-link updates-home-link-top" href="/" @click="navigateTo('/', $event)">返回 mono 首页</a>

      <div v-if="updatesLoading" class="section-placeholder">读取更新公告中...</div>
      <div v-else-if="updatesError" class="section-placeholder">
        <p>{{ updatesError }}</p>
        <button type="button" @click="fetchUpdates">重新读取</button>
      </div>
      <div v-else-if="latestUpdate" class="updates-timeline">
        <article class="update-hero-card">
          <span class="release-kicker">Latest Update</span>
          <h2 id="updates-title">v{{ latestUpdate.version }}</h2>
          <p>{{ latestUpdate.title || 'mono 更新' }}</p>
          <div class="release-meta">
            <span>{{ formatDate(latestUpdate.publishedAt || latestUpdate.updatedAt || latestUpdate.createdAt) }}</span>
            <span v-if="latestUpdate.fileSize">{{ formatSize(latestUpdate.fileSize) }}</span>
          </div>
          <pre v-if="latestUpdate.releaseNotes" class="update-notes" :class="{ 'is-expanded': isUpdateLogExpanded(latestUpdate) }">{{ latestUpdate.releaseNotes }}</pre>
          <button v-if="latestUpdate.releaseNotes" class="update-expand-button" type="button" @click="toggleUpdateLog(latestUpdate)">
            {{ isUpdateLogExpanded(latestUpdate) ? '收起' : '展开查看' }}
          </button>
        </article>

        <section v-if="historyUpdates.length" class="history-updates-section">
          <button class="history-toggle-button" type="button" @click="toggleHistoryUpdates">
            <span>历史版本</span>
            <small>{{ historyUpdates.length }} 个版本</small>
            <strong>{{ showHistoryUpdates ? '收起' : '展开' }}</strong>
          </button>

          <div v-if="showHistoryUpdates" class="history-updates-list">
            <article v-for="release in historyUpdates" :key="release.id" class="update-log-card">
              <div class="update-log-version">
                <strong>v{{ release.version }}</strong>
                <span>{{ formatDate(release.publishedAt || release.createdAt) }}</span>
              </div>
              <div>
                <h3>{{ release.title || '版本更新' }}</h3>
                <pre v-if="release.releaseNotes" class="update-notes" :class="{ 'is-expanded': isUpdateLogExpanded(release) }">{{ release.releaseNotes }}</pre>
                <button v-if="release.releaseNotes" class="update-expand-button" type="button" @click="toggleUpdateLog(release)">
                  {{ isUpdateLogExpanded(release) ? '收起' : '展开查看' }}
                </button>
              </div>
            </article>
          </div>
        </section>
      </div>
      <div v-else class="section-placeholder">{{ content.updates.emptyMessage }}</div>
    </section>

    <section v-if="currentPage === 'download'" class="subpage-section download-page" aria-label="IPA 下载">
      <header class="subpage-brand-hero download-brand-hero">
        <img class="subpage-hero-icon" :src="assets.pawIcon" alt="" />
        <img class="subpage-hero-wordmark" :src="assets.monoTextBlack" alt="mono" />
        <p>领取专属 Token，并下载最新自签 IPA。</p>
      </header>

      <nav class="download-tab-bar" aria-label="IPA 下载操作">
        <div class="tab-slider-bg" :class="`is-${downloadTab}`"></div>
        <button class="download-tab" :class="{ 'is-active': downloadTab === 'token' }" type="button" @click="setDownloadTab('token')">领取 Token</button>
        <button class="download-tab" :class="{ 'is-active': downloadTab === 'updates' }" type="button" @click="setDownloadTab('updates')">更新版本</button>
      </nav>

      <div class="download-card-stack">
        <Transition name="tab-fade" mode="out-in">
          <article v-if="downloadTab === 'token'" key="token" class="mono-feature-card ipa-register-card download-focus-card">
            <span class="release-kicker">Self Service</span>
            <h2>领取 Token</h2>
            <p class="feature-desc">填写邮箱、用户名和保护码，系统会自动创建或找回 Token。</p>

            <form class="mono-form" @submit.prevent="submitIpaRegister">
              <label>
                <span>邮箱地址</span>
                <input v-model="ipaRegisterEmail" type="email" placeholder="your@email.com" autocomplete="email" />
              </label>
              <label>
                <span>用户名</span>
                <input v-model="ipaRegisterName" placeholder="你的用户名" autocomplete="name" />
              </label>
              <label>
                <span>保护码</span>
                <input v-model="ipaRegisterProtectCode" class="code-input" placeholder="请输入保护码" autocomplete="off" />
              </label>
              <button type="submit" :disabled="ipaRegisterSubmitting">
                {{ ipaRegisterSubmitting ? '处理中...' : '获取 Token' }}
              </button>
            </form>

            <p v-if="ipaRegisterError" class="section-message is-error">{{ ipaRegisterError }}</p>
            <p v-else-if="ipaRegisterMessage" class="section-message">{{ ipaRegisterMessage }}</p>

            <div v-if="ipaRegisterResult?.key" class="token-result-card ipa-token-card">
              <div class="token-result-header">
                <div>
                  <h3>{{ ipaRegisterResult.name || 'mono user' }}</h3>
                  <p>{{ ipaRegisterResult.email || ipaRegisterEmail }}</p>
                </div>
                <span class="token-status is-active">已领取</span>
              </div>
              <div class="token-key-row">
                <code>{{ ipaRegisterResult.key }}</code>
                <button type="button" @click="copyTokenKey(ipaRegisterResult.key)">
                  {{ copiedTokenKey === ipaRegisterResult.key ? content.tokenQuery.copiedLabel : content.tokenQuery.copyLabel }}
                </button>
              </div>
              <div class="token-meta-grid">
                <span>创建 {{ formatDate(ipaRegisterResult.createdAt) }}</span>
                <span>到期 {{ formatDate(ipaRegisterResult.expiresAt) }}</span>
              </div>
            </div>
          </article>

          <div v-else-if="downloadTab === 'updates'" key="updates" class="download-updates-panel">
            <div v-if="updatesLoading" class="section-placeholder">读取 IPA 信息中...</div>
            <div v-else-if="updatesError" class="section-placeholder">
              <p>{{ updatesError }}</p>
              <button type="button" @click="fetchUpdates">重新读取</button>
            </div>
            <template v-else-if="latestUpdate">
              <article class="mono-feature-card download-focus-card ipa-download-card">
                <span class="release-kicker">Latest Release</span>
                <h2>v{{ latestUpdate.version }}</h2>
                <p>{{ latestUpdate.title || 'mono 最新版' }}</p>
                <div class="release-meta">
                  <span v-if="latestUpdate.fileSize">{{ formatSize(latestUpdate.fileSize) }}</span>
                  <span>{{ formatDate(latestUpdate.publishedAt || latestUpdate.updatedAt || latestUpdate.createdAt) }}</span>
                  <span v-if="latestUpdate.downloadCount">{{ latestUpdate.downloadCount }} 次下载</span>
                </div>
                <pre v-if="latestUpdate.releaseNotes" class="update-notes" :class="{ 'is-expanded': isUpdateLogExpanded(latestUpdate) }">{{ latestUpdate.releaseNotes }}</pre>
                <button v-if="latestUpdate.releaseNotes" class="update-expand-button" type="button" @click="toggleUpdateLog(latestUpdate)">
                  {{ isUpdateLogExpanded(latestUpdate) ? '收起' : '展开查看' }}
                </button>
                <a v-if="latestUpdate.downloadUrl" class="release-download" :href="latestUpdate.downloadUrl" download>
                  下载 v{{ latestUpdate.version }}
                </a>
              </article>

              <section v-if="historyUpdates.length" class="release-history download-release-history" aria-label="历史版本">
                <button class="history-toggle-button" type="button" @click="toggleHistoryUpdates">
                  <span>历史版本</span>
                  <small>{{ historyUpdates.length }} 个版本</small>
                  <strong>{{ showHistoryUpdates ? '收起' : '展开' }}</strong>
                </button>

                <div v-if="showHistoryUpdates" class="history-download-list">
                  <article v-for="release in historyUpdates" :key="release.id" class="mono-feature-card history-release-card">
                    <div>
                      <strong>v{{ release.version }} {{ release.title || '' }}</strong>
                      <span>{{ formatDate(release.publishedAt || release.createdAt) }} · {{ formatSize(release.fileSize) }}</span>
                    </div>
                    <a v-if="release.downloadUrl" :href="release.downloadUrl" download>下载</a>
                  </article>
                </div>
              </section>
            </template>
            <div v-else class="section-placeholder">{{ content.updates.emptyMessage }}</div>
          </div>
        </Transition>
      </div>

      <section class="download-guide" aria-label="使用指南">
        <h3>使用指南</h3>
        <ol>
          <li><span>1</span>输入保护码领取专属 Token。</li>
          <li><span>2</span>下载最新 IPA 文件并完成自签安装。</li>
          <li><span>3</span>打开 App，在设置中粘贴 Token。</li>
          <li><span>4</span>后续更新回到本页下载新版 IPA。</li>
        </ol>
      </section>

      <a class="subpage-home-link" href="/" @click="navigateTo('/', $event)">返回 mono 首页</a>
    </section>

    <footer class="site-footer" aria-label="开发者信息">
      <div class="footer-brand">
        <img class="footer-icon" :src="assets.pawIcon" alt="" />
        <span class="footer-app-name">{{ content.footer.appName }}</span>
      </div>
      <span class="footer-divider"></span>
      <span class="footer-developer">{{ content.footer.developer }}</span>
    </footer>

    <div v-if="showContactDialog" class="contact-dialog-backdrop" role="presentation" @click="closeContactDialog">
      <div class="contact-dialog" role="dialog" aria-modal="true" :aria-label="content.contact.dialogTitle" @click.stop>
        <h2>{{ content.contact.dialogTitle }}</h2>
        <p>{{ content.contact.dialogMessage }}</p>
        <div class="contact-card-grid">
          <article class="contact-method-card is-wechat">
            <img class="contact-method-icon" :src="assets.contactWechatIcon" alt="" />
            <div class="contact-method-copy">
              <span>Developer</span>
              <h3>开发者微信</h3>
              <strong>{{ content.contact.value }}</strong>
            </div>
            <button class="contact-method-action" type="button" @click="copyWechatAndOpen">
              {{ contactCopied ? content.contact.copiedLabel : '复制并打开微信' }}
            </button>
          </article>

          <article class="contact-method-card is-telegram">
            <img class="contact-method-icon" :src="assets.contactTelegramIcon" alt="" />
            <div class="contact-method-copy">
              <span>Telegram Channel</span>
              <h3>{{ content.contact.telegramName }}</h3>
              <strong>{{ content.contact.telegramCode }}</strong>
            </div>
            <a class="contact-method-action" :href="content.contact.telegramHref" target="_blank" rel="noreferrer">
              加入 TG 频道
            </a>
          </article>
        </div>
        <button class="contact-close-button" type="button" @click="closeContactDialog">
          {{ content.contact.dialogAction }}
        </button>
      </div>
    </div>

    <div v-if="testFlightDuplicateDialog" class="tf-duplicate-backdrop" role="presentation" @click="closeTestFlightDuplicateDialog">
      <div class="tf-duplicate-dialog" role="dialog" aria-modal="true" aria-label="邮箱已在测试组" @click.stop>
        <img class="tf-duplicate-icon" :src="assets.pawIcon" alt="" />
        <span>Already Joined</span>
        <h2>已在测试组</h2>
        <p>
          <strong>{{ testFlightDuplicateDialog.email }}</strong>
          已经在 {{ testFlightDuplicateDialog.groupName }} 测试组中。
        </p>
        <p>请前往邮箱检查 TestFlight 邀请邮件，或更换邮箱重新申请。</p>
        <div class="tf-duplicate-actions">
          <button class="tf-duplicate-primary" type="button" @click="openMailboxForTestFlight(testFlightDuplicateDialog.email)">
            前往邮箱
          </button>
          <button class="tf-duplicate-secondary" type="button" @click="changeTestFlightEmail">
            更换邮箱
          </button>
        </div>
      </div>
    </div>

    <div v-if="testFlightNoticeDialog" class="tf-duplicate-backdrop" role="presentation" @click="closeTestFlightNoticeDialog">
      <div class="tf-duplicate-dialog tf-notice-dialog" :class="`is-${testFlightNoticeDialog.type}`" role="dialog" aria-modal="true" :aria-label="testFlightNoticeDialog.title" @click.stop>
        <img class="tf-duplicate-icon" :src="assets.pawIcon" alt="" />
        <span>{{ testFlightNoticeDialog.type === 'success' ? 'Request Sent' : 'Notice' }}</span>
        <h2>{{ testFlightNoticeDialog.title }}</h2>
        <p>{{ testFlightNoticeDialog.message }}</p>
        <p v-if="testFlightNoticeDialog.email">
          <strong>{{ testFlightNoticeDialog.email }}</strong>
        </p>
        <div class="tf-duplicate-actions" :class="{ 'is-single': !(testFlightNoticeDialog.canOpenMailbox && testFlightNoticeDialog.canQueryToken) }">
          <button v-if="testFlightNoticeDialog.canOpenMailbox" class="tf-duplicate-primary" type="button" @click="openMailboxForTestFlight(testFlightNoticeDialog.email)">
            前往邮箱
          </button>
          <button v-if="testFlightNoticeDialog.canQueryToken" class="tf-duplicate-secondary" type="button" @click="goToTokenQuery">
            查询 Token
          </button>
          <button v-if="!testFlightNoticeDialog.canOpenMailbox && !testFlightNoticeDialog.canQueryToken" class="tf-duplicate-primary" type="button" @click="closeTestFlightNoticeDialog">
            知道了
          </button>
        </div>
      </div>
    </div>
  </main>
</template>
