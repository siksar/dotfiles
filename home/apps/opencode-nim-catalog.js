// opencode plugin — NVIDIA NIM model kataloğunu CANLI çeker.
//
// Neden var: opencode'un model bilgisi models.dev'den gelir ve orası NIM'in
// gerçek katalogunu geriden takip eder. 17 Eyl 2026'da ölçüldü: models.dev
// nvidia altında 105 model sayıyor, NIM'in /v1/models'ı 82 — kesişim dışındaki
// 79 model artık çağrılamıyor (eski öntanımlımız qwen3-coder-480b HTTP 410
// "end of life" döndürüyordu) ve NIM'de olan 56 model models.dev'de hiç yok.
// Bu kanca her açılışta /v1/models'ı okur, listeyi ona göre keser/genişletir.
//
// Sözleşme (opencode 1.18.29, @opencode-ai/plugin: Hooks.provider.models):
//   models(provider, ctx) DÖNÜŞÜ sağlayıcının model kaydını TAMAMEN DEĞİŞTİRİR.
//   Sıra: models.dev kataloğu → bu kanca → opencode.json'daki provider
//   override'ları. Yani buradan dönen liste config ile hâlâ ezilebilir.
//   Katalogda olmayan sağlayıcı için kanca hiç çağrılmaz (nvidia katalogda var).
//
// Ağ sözleşmesi: 4 s timeout, 6 saatlik disk önbelleği, her hata yutulur.
// Uçuş başarısızsa sırayla önbellek → models.dev'e düşer; opencode'un açılışı
// bu kanca yüzünden ASLA bloke olmaz veya çökmez.
import { mkdir, readFile, rename, writeFile } from "node:fs/promises"
import { homedir } from "node:os"
import { dirname, join } from "node:path"

const ENDPOINT = "https://integrate.api.nvidia.com/v1/models"
const TTL_MS = 6 * 60 * 60 * 1000
const TIMEOUT_MS = 4000

// Kısmi/bozuk bir yanıt yüzünden katalogu boşaltmamak için alt sınır: NIM
// 17 Eyl 2026'da 82 model sayıyordu, 10'un altı "yanıt bozuk" demektir.
const MIN_SANE = 10

// models.dev'in tanımadığı kimlikler için tek eleme: NIM kataloğu embedding,
// rerank, TTS, görüntü/video ve güvenlik sınıflandırıcılarıyla dolu — bunlar
// bir kodlama ajanının model seçicisinde yalnızca gürültü. models.dev'in
// TANIDIĞI modeller bu filtreye girmez, onların yetenekleri zaten ölçülü.
const NON_CHAT =
  /(embed|rerank|retriev|nvclip|nemoguard|guard|safety|topic-control|parse|whisper|tts|magpie|riva|translate|flux|-image|image-|video|ocr|esm|fold|cosmos-(predict|transfer)|bevformer|sparsedrive|streampetr|deplot|paligemma|kosmos|vila|neva|reward|detector|speaker|studiovoice|voicechat|usdcode|usdvalidate|gliner|calibration|arctic|diffusiongemma|recurrentgemma)/i

const cachePath = () =>
  join(
    process.env.XDG_CACHE_HOME ?? join(homedir(), ".cache"),
    "opencode",
    "nvidia-nim-models.json",
  )

async function readCache() {
  try {
    const data = JSON.parse(await readFile(cachePath(), "utf8"))
    if (!Array.isArray(data?.ids) || data.ids.length < MIN_SANE) return null
    return { fetched: Number(data.fetched) || 0, ids: data.ids }
  } catch {
    return null
  }
}

async function writeCache(ids) {
  const path = cachePath()
  // tmp + rename: iki opencode aynı anda açılırsa yarım dosya okunmasın.
  const tmp = `${path}.${process.pid}.tmp`
  try {
    await mkdir(dirname(path), { recursive: true })
    await writeFile(tmp, JSON.stringify({ fetched: Date.now(), ids }))
    await rename(tmp, path)
  } catch {
    /* önbellek lüks, yazılamazsa sorun değil */
  }
}

async function fetchIDs(key) {
  const res = await fetch(ENDPOINT, {
    headers: key ? { Authorization: `Bearer ${key}` } : {},
    signal: AbortSignal.timeout(TIMEOUT_MS),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  const ids = ((await res.json())?.data ?? [])
    .map((m) => m?.id)
    .filter((id) => typeof id === "string" && id.length)
  if (ids.length < MIN_SANE) throw new Error(`yanıt ${ids.length} model içeriyor`)
  return ids.sort()
}

// models.dev'in bilmediği canlı model için iskelet. Limitler bilinçli olarak
// DÜŞÜK: fazla tahmin edilen bir bağlam penceresi istemi sunucuda kestirir,
// az tahmin edilen yalnızca erken sıkıştırma yaptırır.
function synth(id, sample) {
  return {
    id,
    providerID: "nvidia",
    api: {
      id,
      url: sample?.api?.url || "https://integrate.api.nvidia.com/v1",
      npm: sample?.api?.npm || "@ai-sdk/openai-compatible",
    },
    name: `${id} (NIM)`,
    family: "",
    capabilities: {
      temperature: true,
      reasoning: false,
      attachment: false,
      toolcall: true,
      input: { text: true, audio: false, image: false, video: false, pdf: false },
      output: { text: true, audio: false, image: false, video: false, pdf: false },
      interleaved: false,
    },
    cost: { input: 0, output: 0, cache: { read: 0, write: 0 } },
    limit: { context: 128000, output: 8192 },
    status: "active",
    options: {},
    headers: {},
    release_date: "",
    variants: {},
  }
}

export const NvidiaNimCatalog = async () => ({
  provider: {
    id: "nvidia",
    async models(provider) {
      const catalog = provider?.models ?? {}
      const cached = await readCache()
      let ids = cached && Date.now() - cached.fetched < TTL_MS ? cached.ids : null

      if (!ids) {
        try {
          ids = await fetchIDs(process.env.NVIDIA_API_KEY)
          await writeCache(ids)
        } catch (err) {
          ids = cached?.ids ?? null
          console.error(
            `[nvidia-nim] canlı katalog alınamadı (${err?.message ?? err}) — ` +
              `${ids ? "önbellek" : "models.dev"} listesi kullanılıyor`,
          )
        }
      }
      if (!ids) return catalog

      const sample = Object.values(catalog)[0]
      const live = {}
      for (const id of ids) {
        const known = catalog[id]
        if (known) live[id] = known
        else if (!NON_CHAT.test(id)) live[id] = synth(id, sample)
      }
      if (!Object.keys(live).length) return catalog

      // OPENCODE_NIM_KEEP_STALE=1: models.dev'in bildiği ama NIM'in artık
      // sunmadığı modelleri de listede tut (yalnız hata ayıklama için —
      // bunları çağırmak HTTP 410 döndürür).
      return process.env.OPENCODE_NIM_KEEP_STALE === "1" ? { ...catalog, ...live } : live
    },
  },
})
