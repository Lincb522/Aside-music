const express = require('express');
const router = express.Router();
const AppleApiService = require('../services/apple-api');
const { getDecryptedAccount } = require('../services/account-helper');
const { getDb } = require('../config/database');
const {
  parseTesterName,
  validateTesterEmail,
  addTesterToBetaGroupAfterConnect,
} = require('../services/beta-tester-invite');

function normalizeSlug(input) {
  return (input || '').trim();
}

// 统一调用 token-admin 内部接口
function tokenAdminRequest(path, body) {
  return new Promise((resolve) => {
    const http = require('http');
    const payload = JSON.stringify(body || {});
    const r = http.request({
      hostname: '127.0.0.1',
      port: 3388,
      path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
        'x-admin-token': process.env.TOKEN_ADMIN_PASSWORD || ''
      },
      timeout: 5000
    }, (resp) => {
      let data = '';
      resp.on('data', c => data += c);
      resp.on('end', () => {
        let json = null;
        try { json = JSON.parse(data); } catch {}
        resolve({ status: resp.statusCode, json, raw: data });
      });
    });
    r.on('error', () => resolve({ status: 0, json: null, raw: '' }));
    r.on('timeout', () => { r.destroy(); resolve({ status: 0, json: null, raw: '' }); });
    r.write(payload);
    r.end();
  });
}

async function getShareContext(slug) {
  const normalizedSlug = normalizeSlug(slug);
  if (!normalizedSlug || normalizedSlug.length > 80) {
    throw Object.assign(new Error('无效的链接'), { status: 400 });
  }

  const db = getDb();
  const row = await db.prepare('SELECT * FROM tf_share_links WHERE slug = ?').get(normalizedSlug);
  if (!row) {
    throw Object.assign(new Error('链接无效或已失效'), { status: 404 });
  }

  const account = await getDecryptedAccount(row.account_id);
  if (!account) {
    throw Object.assign(new Error('关联账号不存在或已失效'), { status: 404 });
  }

  const api = new AppleApiService(account);
  const groupResult = await api.request('GET', `/betaGroups/${row.group_id}`, null, {
    'fields[betaGroups]':
      'name,isInternalGroup,publicLinkEnabled,publicLink,publicLinkLimit,publicLinkLimitEnabled,createdDate',
    include: 'app',
    'fields[apps]': 'name,bundleId',
  });

  const group = groupResult.data;
  if (!group) {
    throw Object.assign(new Error('测试组已不存在'), { status: 404 });
  }

  const appData = (groupResult.included || []).find(item => item.type === 'apps');
  return { row, api, group, appData };
}

function normalizeTesterEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function serializeTester(tester) {
  if (!tester) return null;
  return {
    id: tester.id,
    email: tester.attributes?.email || null,
    first_name: tester.attributes?.firstName || null,
    last_name: tester.attributes?.lastName || null,
    invite_type: tester.attributes?.inviteType || null,
    state: tester.attributes?.state || null,
  };
}

function buildAlreadyInGroupPayload({ email, group, appData, tester }) {
  return {
    email,
    already_in_group: Boolean(tester),
    group_name: group.attributes?.name,
    app_name: appData?.attributes?.name,
    tester: serializeTester(tester),
  };
}

async function findTesterInGroupByEmail(api, groupId, email) {
  const normalizedEmail = normalizeTesterEmail(email);
  if (!normalizedEmail) return null;

  const result = await api.listGroupTesters(groupId, { limit: 200 });
  return (result.data || []).find(tester => {
    const testerEmail = normalizeTesterEmail(tester.attributes?.email);
    return testerEmail === normalizedEmail;
  }) || null;
}

function sendAlreadyInGroupResponse(res, payload) {
  return res.status(409).json({
    success: false,
    code: 'TF_EMAIL_ALREADY_IN_GROUP',
    message: '该邮箱已在测试组中，请前往邮箱检查 TestFlight 邀请邮件，或更换邮箱。',
    data: payload,
  });
}

function sendTrialAlreadyUsedResponse(res, email) {
  return res.status(409).json({
    success: false,
    code: 'TF_TRIAL_EMAIL_ALREADY_USED',
    message: '该邮箱已经体验过免保护码 1 小时体验，请使用保护码正式申请或更换邮箱。',
    data: { email },
  });
}

async function claimTrialEmailUsage(db, { email, groupId, accountId }) {
  const normalizedEmail = normalizeTesterEmail(email);
  const result = await db.prepare(
    'INSERT INTO tf_trial_email_history (email, normalized_email, group_id, account_id) VALUES (?, ?, ?, ?) ON CONFLICT (normalized_email) DO NOTHING'
  ).run(email, normalizedEmail, groupId, accountId);
  return result.changes > 0;
}

async function releaseTrialEmailUsage(db, email) {
  await db.prepare('DELETE FROM tf_trial_email_history WHERE normalized_email = ?').run(normalizeTesterEmail(email));
}

/**
 * 无需登录：展示页面信息（应用名、测试组名）
 * GET /api/public/tf/:slug
 */
router.get('/tf/:slug', async (req, res, next) => {
  try {
    const { group, appData } = await getShareContext(req.params.slug);

    res.json({
      success: true,
      data: {
        group_name: group.attributes?.name,
        is_internal: group.attributes?.isInternalGroup,
        app_name: appData?.attributes?.name,
        bundle_id: appData?.attributes?.bundleId,
        public_link_enabled: group.attributes?.publicLinkEnabled,
        public_link: group.attributes?.publicLink || null,
        public_link_limit: group.attributes?.publicLinkLimit,
        public_link_limit_enabled: group.attributes?.publicLinkLimitEnabled,
        join_enabled: !group.attributes?.isInternalGroup,
      },
    });
  } catch (err) {
    next(err);
  }
});

router.post('/tf/:slug/check-email', async (req, res, next) => {
  try {
    const email = (req.body?.email || '').trim();
    if (!email) {
      return res.status(400).json({ success: false, message: '请填写邮箱' });
    }
    if (!validateTesterEmail(email)) {
      return res.status(400).json({ success: false, message: '邮箱格式不正确' });
    }

    const { api, group, appData } = await getShareContext(req.params.slug);
    if (group.attributes?.isInternalGroup) {
      return res.status(400).json({
        success: false,
        message: '当前分享的是内部测试组，不能通过公开页面报名加入',
      });
    }

    const tester = await findTesterInGroupByEmail(api, group.id, email);
    res.json({
      success: true,
      data: buildAlreadyInGroupPayload({ email, group, appData, tester }),
    });
  } catch (err) {
    next(err);
  }
});

/**
 * 无需登录：填写姓名、邮箱后加入测试组（App Store Connect）
 * POST /api/public/tf/:slug/join
 * body: { email, full_name }
 */
router.post('/tf/:slug/join', async (req, res, next) => {
  try {
    const email = (req.body?.email || '').trim();
    const hasNameInput = [
      req.body?.full_name,
      req.body?.name,
      req.body?.first_name,
      req.body?.last_name,
    ].some(value => String(value || '').trim());

    if (!email) {
      return res.status(400).json({ success: false, message: '请填写邮箱' });
    }
    if (!validateTesterEmail(email)) {
      return res.status(400).json({ success: false, message: '邮箱格式不正确' });
    }
    if (!hasNameInput) {
      return res.status(400).json({ success: false, message: '请填写姓名' });
    }

    const { row, api, group, appData } = await getShareContext(req.params.slug);
    if (group.attributes?.isInternalGroup) {
      return res.status(400).json({
        success: false,
        message: '当前分享的是内部测试组，不能通过公开页面报名加入',
      });
    }

    const protectCode = (req.body?.protect_code || '').trim();
    if (!process.env.TOKEN_ADMIN_PASSWORD) {
      return res.status(500).json({ success: false, message: '保护码服务暂时不可用' });
    }
    if (!protectCode) {
      return res.status(400).json({ success: false, message: '请填写保护码' });
    }

    // 预校验保护码（不消耗）
    const precheck = await tokenAdminRequest('/api/internal/verify-protect-code', { code: protectCode, purpose: 'tf', consume: false });
    if (precheck.status !== 200) {
      return res.status(403).json({ success: false, message: '保护码错误或可使用次数已达上限' });
    }

    // 已在测试组（含 1 小时体验用户）→ 升级为正式；否则正式加入
    const { firstName, lastName } = parseTesterName(req.body);
    const existingTester = await findTesterInGroupByEmail(api, group.id, email);
    let result, isUpgrade = false;
    if (existingTester) {
      isUpgrade = true;
      result = { tester_id: existingTester.id, already_in_group: true };
    } else {
      result = await addTesterToBetaGroupAfterConnect(api, {
        email,
        groupId: group.id,
        firstName,
        lastName,
      });
    }
    const testerId = result?.tester_id || existingTester?.id || null;

    // ---- 正式加入后，清理该 email 的体验记录，避免被定时踢出 ----
    try {
      const db = getDb();
      const deleted = await db.prepare("DELETE FROM tf_trial_users WHERE email = ?").run(email);
      if (deleted.changes > 0) {
        console.log(`[TF Trial] 用户 ${email} 已正式加入，清理 ${deleted.changes} 条体验记录`);
      }
    } catch (trialCleanErr) {
      console.warn("[TF Trial] 清理体验记录失败:", trialCleanErr.message);
    }
    // ---- 注册/升级为永久 Token（试用生成的转正为永久）----
    const testerName = [firstName, lastName].filter(Boolean).join(' ').trim() || email.split('@')[0];
    let tokenResult = null;
    try {
      const reg = await tokenAdminRequest('/api/internal/auto-register', {
        email, name: testerName, source: 'tf-public-join', make_permanent: true,
      });
      tokenResult = reg.json;
    } catch (tokenErr) {
      console.warn('[TF公开页→Token] 自动注册失败:', tokenErr.message);
    }

    // 已是正式成员（既非新加入、也非试用转正）则不再消耗保护码，避免重复扣次数
    const alreadyFormal = isUpgrade && tokenResult && tokenResult.exists && tokenResult.upgraded === false && (tokenResult.expiresAt == null);
    if (!alreadyFormal) {
      // 授予成功后才消耗保护码，并记录绑定（含 testerId/groupId/accountId 便于后续踢出）
      await tokenAdminRequest('/api/internal/verify-protect-code', {
        code: protectCode,
        purpose: 'tf',
        consume: true,
        email,
        name: testerName,
        tokenKey: tokenResult?.key || null,
        testerId,
        groupId: group.id,
        accountId: row?.account_id || null,
        source: 'tf-public-join',
      });
    }

    res.json({
      success: true,
      message: alreadyFormal ? '你已是正式测试成员' : (isUpgrade ? '已升级为正式，永久保留测试资格' : '提交成功，已自动加入测试组'),
      data: {
        email,
        group_name: group.attributes?.name,
        app_name: appData?.attributes?.name,
        public_link_enabled: group.attributes?.publicLinkEnabled,
        public_link: group.attributes?.publicLink || null,
        invite: result,
        upgraded: isUpgrade && !alreadyFormal,
        token_auto: tokenResult ? { key: tokenResult.key, name: tokenResult.name, exists: tokenResult.exists, expiresAt: tokenResult.expiresAt } : null,
      },
    });
  } catch (err) {
    next(err);
  }
});

/**
 * 内部：供 token-admin 绑定管理调用，从测试组踢出并删除 tester
 * POST /api/public/internal/kick-tester  { testerId, groupId, accountId }
 */
router.post('/internal/kick-tester', async (req, res) => {
  const adminToken = req.headers['x-admin-token'];
  if (!process.env.TOKEN_ADMIN_PASSWORD || adminToken !== process.env.TOKEN_ADMIN_PASSWORD) {
    return res.status(401).json({ success: false, message: '未授权' });
  }
  const { testerId, groupId, accountId } = req.body || {};
  if (!testerId || !groupId || !accountId) {
    return res.status(400).json({ success: false, message: '缺少 testerId/groupId/accountId' });
  }
  try {
    const account = await getDecryptedAccount(accountId);
    if (!account) return res.status(404).json({ success: false, message: '账号不存在' });
    const api = new AppleApiService(account);
    await api.removeTesterFromGroup(groupId, [testerId]).catch(e => {
      if (e.status !== 404 && e.status !== 409) throw e;
    });
    await api.deleteBetaTester(testerId).catch(e => {
      if (e.status !== 404 && e.status !== 409) throw e;
    });
    try { await getDb().prepare("DELETE FROM tf_trial_users WHERE tester_id = ?").run(testerId); } catch {}
    res.json({ success: true });
  } catch (err) {
    console.error('[TF kick-tester] 失败:', err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

/**
 * 体验：加入测试组一小时并获得一小时Token
 * POST /api/public/tf/:slug/join-trial
 */
router.post('/tf/:slug/join-trial', async (req, res, next) => {
  try {
    const email = (req.body?.email || '').trim();
    const hasNameInput = [
      req.body?.full_name,
      req.body?.name,
      req.body?.first_name,
      req.body?.last_name,
    ].some(value => String(value || '').trim());

    if (!email) {
      return res.status(400).json({ success: false, message: '请填写邮箱' });
    }
    if (!validateTesterEmail(email)) {
      return res.status(400).json({ success: false, message: '邮箱格式不正确' });
    }
    if (!hasNameInput) {
      return res.status(400).json({ success: false, message: '请填写姓名' });
    }

    const { row, api, group, appData } = await getShareContext(req.params.slug);
    if (group.attributes?.isInternalGroup) {
      return res.status(400).json({
        success: false,
        message: '内部测试组无法体验',
      });
    }

    const db = getDb();
    const claimedTrialEmail = await claimTrialEmailUsage(db, {
      email,
      groupId: group.id,
      accountId: row.account_id,
    });
    if (!claimedTrialEmail) {
      return sendTrialAlreadyUsedResponse(res, email);
    }

    const { firstName, lastName } = parseTesterName(req.body);
    let result;
    try {
      result = await addTesterToBetaGroupAfterConnect(api, {
        email,
        groupId: group.id,
        firstName,
        lastName,
      });
    } catch (err) {
      await releaseTrialEmailUsage(db, email);
      throw err;
    }

    const testerId = result.tester_id;
    if (testerId) {
      await db.prepare(
        "INSERT INTO tf_trial_users (group_id, tester_id, email, account_id, expires_at) VALUES (?, ?, ?, ?, NOW() + INTERVAL '1 hour')"
      ).run(group.id, testerId, email, row.account_id);
    }

    let tokenResult = null;
    try {
      const tokenAdminPassword = process.env.TOKEN_ADMIN_PASSWORD || '';
      if (tokenAdminPassword) {
        const testerName = [firstName, lastName].filter(Boolean).join(' ').trim() || email.split('@')[0];
        const http = require('http');
        const postData = JSON.stringify({ email, name: testerName, source: 'tf-public-trial', expires_in_hours: 1 });
        tokenResult = await new Promise((resolve, reject) => {
          const req = http.request({
            hostname: '127.0.0.1',
            port: 3388,
            path: '/api/internal/auto-register',
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'x-admin-token': tokenAdminPassword
            },
            timeout: 5000
          }, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
              try { resolve(JSON.parse(data)); } catch { resolve({ raw: data }); }
            });
          });
          req.on('error', reject);
          req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
          req.write(postData);
          req.end();
        });
      }
    } catch (tokenErr) {
      console.warn('[TF公开页体验→Token] 自动注册失败:', tokenErr.message);
    }

    res.json({
      success: true,
      message: '提交成功，已获得1小时体验',
      data: {
        email,
        group_name: group.attributes?.name,
        app_name: appData?.attributes?.name,
        invite: result,
        token_auto: tokenResult ? { key: tokenResult.key, name: tokenResult.name, exists: tokenResult.exists } : null,
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
