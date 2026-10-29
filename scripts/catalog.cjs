// Makes TypleCore/Sources/TypleCore/Resources/catalog.json, the official packs an account follows, from a checkout of
// typle-r: `node scripts/catalog.cjs ../typle-r`. It follows officialPacks (src/plugins/packs/catalog.ts in typle-r, and
// OfficialPacks in its server/internal/workspace/packs.go): the lists of src/plugins/packs in the order of
// commands/manifest.json, made into packs as convertLibrary (src/core/wordPacks.ts) makes them, in the saved shape.
// tests/strings.test.cjs checks the copy with TYPLE_R set.
const fs = require('node:fs')
const path = require('node:path')

const maxName = 200
const maxTags = 20

const lower = value => value.toLowerCase()

function fit(name, suffix, limit) {
  let units = name
  const keep = limit - suffix.length
  if (units.length > keep) {
    units = units.slice(0, Math.max(keep, 0))
    const last = units.charCodeAt(units.length - 1)
    if (last >= 0xd800 && last <= 0xdbff) units = units.slice(0, -1)
  }
  return units.trimEnd() + suffix
}

function unique(taken, wanted) {
  let value = wanted
  for (let count = 2; taken.has(lower(value)); count++) value = fit(wanted, `（${count}）`, maxName)
  taken.add(lower(value))
  return value
}

function labelsOf(category, tags) {
  const seen = new Set()
  const kept = []
  for (const tag of tags) {
    const value = tag.trim()
    if (!value || seen.has(lower(value))) continue
    seen.add(lower(value))
    kept.push(value)
  }
  return { category: (category ?? '').trim(), tags: kept.slice(0, maxTags) }
}

const earlier = (a, b) => Date.parse(a) < Date.parse(b)

function readLists(typleR) {
  const packs = path.join(typleR, 'src/plugins/packs')
  const read = file => JSON.parse(fs.readFileSync(path.join(packs, file), 'utf8'))
  const samples = read('samples.json').map((list, index) => ({ ...list, id: `sample-${index + 1}`, records: [] }))
  const commands = read('commands/manifest.json').map(name => read(`commands/${name}`))
  return [...samples, ...read('countries.json'), ...commands]
}

function catalog(typleR) {
  const lists = readLists(typleR)
  const entries = []
  const byKey = new Map()
  const names = new Set()
  for (const list of lists) {
    const group = (list.group ?? '').trim()
    const key = group ? `group:${group}` : `list:${list.id}`
    let entry = byKey.get(key)
    if (!entry) {
      const members = group ? lists.filter(item => (item.group ?? '').trim() === group) : [list]
      const oldest = members.reduce((found, member) => earlier(member.createdAt, found.createdAt) ? member : found)
      const { category, tags } = labelsOf(list.category, members.flatMap(member => member.tags ?? []))
      const pack = { id: `pack-${list.id}`, name: unique(names, group || list.name.trim()),
        ...(category ? { category } : {}), ...(tags.length ? { tags } : {}), createdAt: oldest.createdAt }
      entry = { catalogId: pack.id, version: 1, pack, lists: [] }
      byKey.set(key, entry)
      entries.push(entry)
    }
    if ((list.levels ?? []).length > 1) throw new Error(`${list.id}: an official list has one level at most`)
    entry.lists.push({
      id: list.id, name: list.name, ...(list.levels?.length ? { levels: [...list.levels] } : {}),
      words: list.words.map(({ display, input, annotation, input_type }) => ({ display, input, annotation, ...(input_type ? { input_type } : {}) })),
      createdAt: list.createdAt,
    })
  }
  // separateLevels would rename lists of a pack whose names or levels meet; the official ones never do.
  for (const { pack, lists: items } of entries) {
    const paths = items.map(item => lower((item.levels ?? [item.name])[0].trim()))
    if (new Set(paths).size !== paths.length) throw new Error(`${pack.id}: lists whose levels meet`)
  }
  return entries
}

const text = typleR => `${JSON.stringify(catalog(typleR))}\n`

module.exports = { catalog, text }

if (require.main === module) {
  const typleR = process.argv[2]
  if (!typleR) throw new Error('usage: node scripts/catalog.cjs <typle-r>')
  fs.writeFileSync(path.join(__dirname, '../TypleCore/Sources/TypleCore/Resources/catalog.json'), text(path.resolve(typleR)))
}
