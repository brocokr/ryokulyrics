// 가사 노트를 앱처럼 쓰게 해 주는 서비스 워커입니다.
// 인터넷이 되면 항상 서버의 새 파일을 보여 줍니다. 저장해 둔 파일은 인터넷이 끊겼거나 3초 안에 답이 없을 때만 씁니다.
// 그래서 가사 파일을 고쳐 올릴 때 이 파일은 고치지 않아도 됩니다.
// 저장 방식을 바꿀 때만 아래 이름의 숫자를 올립니다. 같은 주소(brocokr.github.io)의 다른 사이트 저장 공간은 건드리지 않습니다.
const FILES = "ryokulyrics-files-v1";
const FONTS = "ryokulyrics-fonts-v1";
const WAIT_MS = 3000;
const MAX_FONTS = 300;
const SCOPE = self.registration.scope;

self.addEventListener("install", () => self.skipWaiting());

self.addEventListener("activate", e => e.waitUntil((async () => {
  for (const name of await caches.keys()) {
    if (name.startsWith("ryokulyrics-") && name !== FILES && name !== FONTS) await caches.delete(name);
  }
  await self.clients.claim();
})()));

// 저장에 실패해도(휴대폰 저장 공간 부족 등) 사이트는 그대로 열려야 하므로 저장 오류는 모두 무시합니다.
const keep = (cacheName, url, res) => caches.open(cacheName).then(c => c.put(url, res)).catch(() => {});
const find = (cacheName, url) => caches.open(cacheName).then(c => c.match(url)).catch(() => undefined);

// 페이지가 알려 준 파일(가사, 커버, 아이콘) 중 아직 없는 것만 저장합니다. 있는 파일은 열 때마다 새로 받습니다.
self.addEventListener("message", e => {
  if (e.data && e.data.type === "save-all") e.waitUntil(saveAll(e.data.files));
});

async function saveAll(files) {
  for (const file of files) {
    const url = new URL(file, SCOPE).href;
    if (!url.startsWith(SCOPE) || await find(FILES, url)) continue;
    try {
      const res = await fetch(url);
      if (res.ok) await keep(FILES, url, res);
    } catch {}
  }
}

self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return;
  const url = e.request.url.split("#")[0];
  const host = new URL(url).hostname;
  if (host === "fonts.googleapis.com" || host === "fonts.gstatic.com") e.respondWith(savedFont(url, e));
  else if (url.startsWith(SCOPE)) e.respondWith(freshFile(url, e));
});

// 저장본이 없는 주소로 들어왔을 때(?fbclid=… 같은 꼬리가 붙은 링크 등): 꼬리를 뗀 같은 페이지를 찾습니다.
// 다른 폴더의 페이지를 보여 주면 그림과 파일 경로가 어긋나므로 같은 폴더 안에서만 찾습니다.
async function findPage(url) {
  const { origin, pathname } = new URL(url);
  const dir = origin + pathname.replace(/[^/]*$/, "");
  return await find(FILES, origin + pathname) || await find(FILES, dir) || await find(FILES, dir + "index.html");
}

async function freshFile(url, e) {  // 주소 끝의 /가 빠져 서버가 다른 주소로 보낸 경우(.../call → .../call/) 브라우저가 직접 따라가게 합니다.
  const network = fetch(url, { cache: "no-cache" }).then(res =>
    (res.redirected && e.request.mode === "navigate" ? Response.redirect(res.url, 302) : res));
  // 3초가 지나 저장본을 보여 준 뒤에도 끝까지 받아서 다음번에 씁니다.
  e.waitUntil(network.then(res => (res.ok ? keep(FILES, url, res.clone()) : null)).catch(() => {}));

  const saved = await find(FILES, url) || (e.request.mode === "navigate" ? await findPage(url) : undefined);

  if (!saved) return network;
  return Promise.race([
    network.catch(() => saved),
    new Promise(resolve => setTimeout(() => resolve(saved), WAIT_MS)),
  ]);
}

// 글꼴은 주소가 바뀌지 않으니 저장해 둔 것을 먼저 씁니다. 전파가 약해도 글꼴 때문에 화면이 멈추지 않습니다.
async function savedFont(url, e) {
  const saved = await find(FONTS, url);
  if (saved) return saved;
  const res = await fetch(url, { mode: "cors", credentials: "omit" });
  if (res.ok) {
    e.waitUntil(keep(FONTS, url, res.clone()).then(trimFonts));
  }
  return res;
}

async function trimFonts() {
  try {
    const cache = await caches.open(FONTS);
    const keys = await cache.keys();
    for (const old of keys.slice(0, Math.max(0, keys.length - MAX_FONTS))) await cache.delete(old);
  } catch {}
}
