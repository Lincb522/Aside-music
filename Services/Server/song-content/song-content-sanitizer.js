const INTERNAL_PAYLOAD_PATTERNS = [
  /\borpheus:\/\//iu,
  /\b(?:songTag|songBizTag|melody_style)\b/iu,
  /\b(?:component|route|tagId|resId|mainProcessCompat|isTheme)=/iu,
  /\brn-(?:genre|tag|page|detail)\b/iu
]

const WIKI_METADATA_LINE = /^(?:songTag|songBizTag|melody_style|曲风|推荐标签|标签|类型|genre|style)$/iu

function containsInternalPayload(value) {
  const text = String(value || '')
  return INTERNAL_PAYLOAD_PATTERNS.some((pattern) => pattern.test(text))
}

function sanitizePublishedText(value, maximum = 20_000) {
  if (typeof value !== 'string') return null
  const normalized = value.normalize('NFC').trim()
  if (!normalized || containsInternalPayload(normalized)) return null
  return normalized.slice(0, maximum)
}

function sanitizeWikiProse(value, maximum = 4_000) {
  if (typeof value !== 'string') return null
  const lines = value
    .normalize('NFC')
    .replace(/<[^>]+>/gu, ' ')
    .split(/\r?\n/gu)
    .map((line) => line.replace(/[ \t]+/gu, ' ').trim())
    .filter(Boolean)
    .filter((line) => !WIKI_METADATA_LINE.test(line))
    .filter((line) => !containsInternalPayload(line))
    .filter((line) => !/\b[a-z][a-z\d+.-]*:\/\//iu.test(line))
    .filter(isProseLine)

  const normalized = [...new Set(lines)].join('\n').trim()
  return normalized ? normalized.slice(0, maximum) : null
}

function isProseLine(value) {
  const characters = value.match(/[\p{L}\p{N}]/gu) || []
  if (characters.length < 24) return false
  const cjkCharacters = value.match(/[\u3400-\u9fff\uf900-\ufaff]/gu) || []
  return cjkCharacters.length >= 30 || /[。！？；，、,.!?;:]/u.test(value)
}

module.exports = {
  containsInternalPayload,
  sanitizePublishedText,
  sanitizeWikiProse
}
