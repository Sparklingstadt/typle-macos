const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { text } = require('../scripts/catalog.cjs')

// The app is built on macOS only; these checks of its text run anywhere with `node --test tests/`. Shared/ holds the
// text the Mac shares with the iPad app of Sparklingstadt/typle-r, and Typle/Resources/*/Mac.strings replaces it where
// that names the iPad.
const root = path.join(__dirname, '..')
// TYPLE_R, a checkout of typle-r, also compares the official packs with the web app's.
const typleR = process.env.TYPLE_R ? path.resolve(process.env.TYPLE_R) : undefined

function swiftFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(dir, entry.name)
    if (entry.isDirectory()) return entry.name === 'build' ? [] : swiftFiles(file)
    return entry.name.endsWith('.swift') ? [file] : []
  })
}

function readStrings(file) {
  const text = fs.readFileSync(file, 'utf8')
  const strings = new Map()
  for (const match of text.matchAll(/^"((?:[^"\\]|\\.)*)" = "((?:[^"\\]|\\.)*)";$/gm)) {
    assert.equal(strings.has(match[1]), false, `${file}: ${match[1]} twice`)
    strings.set(match[1], JSON.parse(`"${match[2]}"`))
  }
  return strings
}

// `%@`, `%ld` and their positional forms, as [position, type]; `%%` is a literal percent sign.
function placeholders(value) {
  let next = 0
  return [...value.replaceAll('%%', '').matchAll(/%(?:(\d+)\$)?(@|ld|d)/g)]
    .map(([, position, type]) => `${position ?? ++next}:${type}`).sort()
}

const languages = ['ja', 'en']
const ipad = Object.fromEntries(languages.map(lang => [lang, readStrings(path.join(root, 'Shared/Resources', `${lang}.lproj/Localizable.strings`))]))
const mac = Object.fromEntries(languages.map(lang => [lang, readStrings(path.join(root, 'Typle/Resources', `${lang}.lproj/Mac.strings`))]))
// Words for the iPad and its touch screen, which the Mac has not.
const iPadWords = /iPad|タップ|\bTap\b/

test('the Mac app has its own text wherever the iPad text names the iPad', () => {
  for (const lang of languages) {
    for (const [key, value] of ipad[lang]) {
      if (iPadWords.test(value)) assert.ok(mac[lang].has(key), `${lang}: Mac.strings needs ${key} (${value})`)
    }
    for (const [key, value] of mac[lang]) {
      assert.doesNotMatch(value, iPadWords, `${lang}: ${key}`)
      if (ipad[lang].has(key)) assert.deepEqual(placeholders(value), placeholders(ipad[lang].get(key)), `${lang}: ${key}`)
    }
  }
  assert.deepEqual([...mac.en.keys()].sort(), [...mac.ja.keys()].sort())
  for (const [key, value] of mac.ja) assert.deepEqual(placeholders(mac.en.get(key)), placeholders(value), key)
})

test('the Mac app has Japanese and English text for every key its own sources use', () => {
  const sources = [...swiftFiles(path.join(root, 'Typle')), ...swiftFiles(path.join(root, 'Shared'))].map(file => fs.readFileSync(file, 'utf8')).join('\n')
  const used = new Set([...sources.matchAll(/\bL\("([^"\\]*)"/g)].map(([, key]) => key))
  assert.ok(used.size > 5)
  for (const lang of languages) {
    for (const key of used) assert.ok(mac[lang].has(key) || ipad[lang].has(key), `${lang}: missing ${key}`)
  }
})

test('the Mac app builds its own sources and the shared rules', () => {
  const project = fs.readFileSync(path.join(root, 'project.yml'), 'utf8')
  assert.match(project, /- path: Shared\n/)
  assert.match(project, /- path: Typle\n/)
  assert.match(project, /path: TypleCore\n/)
  // The Mac's text field is the only one: the iPad's UITextField is not in Shared/.
  assert.equal(fs.existsSync(path.join(root, 'Shared/Practice/PracticeTextField.swift')), false)
  assert.ok(fs.existsSync(path.join(root, 'Typle/Practice/PracticeTextField.swift')))
})

test('the Mac app bundles the official packs of the web app', { skip: !typleR && 'TYPLE_R is not set' }, () => {
  assert.equal(fs.readFileSync(path.join(root, 'TypleCore/Sources/TypleCore/Resources/catalog.json'), 'utf8'), text(typleR),
    'run node scripts/catalog.cjs <typle-r> again')
})
