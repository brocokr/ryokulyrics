// 가사 노트 → 디스코드 알림
// 푸시가 들어오면 바뀐 가사 파일을 이전 버전과 곡 단위로 비교해서
// "어느 곡의 어느 칸이 바뀌었는지"를 곡 링크와 함께 디스코드 웹후크로 보냅니다.
//
// 환경 변수
//   DISCORD_WEBHOOK_URL  디스코드 웹후크 주소 (저장소 Secrets에 넣어 둡니다)
//   BEFORE / AFTER       비교할 커밋 (GitHub Actions가 넣어 줍니다)
// 직접 시험하기: node .github/scripts/lyrics-notify.mjs --dry-run HEAD~1 HEAD

import { execFileSync } from "node:child_process";

const SITE = "https://brocokr.github.io/ryokulyrics/";
const SECTIONS = ["원문", "발음", "한글발음", "해석", "공부", "메모"];
const SECTION_NAME = { 원문: "원문", 발음: "로마자 발음", 한글발음: "한글 발음", 해석: "해석", 공부: "단어 공부", 메모: "메모" };

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const revs = args.filter(a => !a.startsWith("--"));
const webhook = process.env.DISCORD_WEBHOOK_URL;
let before = revs[0] || process.env.BEFORE;
const after = revs[1] || process.env.AFTER || "HEAD";

const git = (...a) => execFileSync("git", ["-c", "core.quotepath=false", ...a], { encoding: "utf8", maxBuffer: 256 << 20 });
const show = (rev, path) => { try { return git("show", `${rev}:${path}`); } catch { return null; } };

// 새 브랜치이거나 이전 커밋 정보가 없으면 바로 앞 커밋과 비교합니다.
if (!before || /^0+$/.test(before)) {
  try { before = git("rev-parse", `${after}~1`).trim(); } catch { console.log("비교할 이전 커밋이 없어 알림을 건너뜁니다."); process.exit(0); }
}

// ---------- 앨범 목록 (index.html 안의 ALBUMS) ----------
function readAlbums(html) {
  if (!html) return [];
  const start = html.indexOf("/*ALBUMS*/");
  if (start < 0) return [];
  const open = html.indexOf("[", start);
  const end = html.indexOf("/*END*/", open);
  const close = end >= 0 ? html.lastIndexOf("]", end) : html.indexOf("\n];", open) + 1;
  const literal = html.slice(open, close + 1);
  try { return JSON.parse(literal); } catch {}
  try { return Function(`"use strict"; return (${literal});`)(); } catch { return []; }
}
const albums = readAlbums(show(after, "index.html"));
const albumByFile = Object.fromEntries(albums.map(al => [al.file, al]));

// ---------- 가사 파일 읽기 (사이트와 같은 규칙) ----------
function parseLyrics(text) {
  const songs = {};
  if (text == null) return songs;
  let cur = null, sec = null;
  for (const raw of String(text).split(/\r?\n/)) {
    const line = raw.replace(/\s+$/, "");
    const head = line.match(/^\s*###\s*(\d+)\s*(.*)$/);
    if (head) {
      cur = songs[Number(head[1])] = { title: head[2].trim(), 원문: [], 발음: [], 한글발음: [], 해석: [], 공부: [], 메모: [] };
      sec = null;
      continue;
    }
    if (!cur || /^\s*\/\//.test(line)) continue;
    const s = line.match(/^\s*\[(원문|발음|한글발음|해석|공부|메모)\]\s*$/);
    if (s) sec = s[1];
    else if (sec) cur[sec].push(line);
  }
  return songs;
}
const filled = lines => (lines || []).filter(l => l.trim() !== "");
const same = (a, b) => filled(a).join("\n") === filled(b).join("\n");
const hasAny = song => !!song && SECTIONS.some(k => filled(song[k]).length > 0);

function compareSongs(oldSongs, newSongs) {
  const out = [];
  const numbers = [...new Set([...Object.keys(oldSongs), ...Object.keys(newSongs)].map(Number))].sort((a, b) => a - b);
  for (const no of numbers) {
    const o = oldSongs[no], n = newSongs[no];
    if (!n) continue; // 곡 블록이 통째로 사라진 경우는 알리지 않습니다
    const parts = [];
    for (const k of SECTIONS) {
      const was = filled(o && o[k]).length, now = filled(n[k]).length;
      if (same(o && o[k], n[k])) continue;
      if (!was && now) parts.push(`${SECTION_NAME[k]} 추가${k === "공부" || k === "메모" ? "" : ` (${now}줄)`}`);
      else if (was && !now) parts.push(`${SECTION_NAME[k]} 삭제`);
      else parts.push(`${SECTION_NAME[k]} 수정`);
    }
    if (!parts.length) continue;
    out.push({ no, title: n.title, isNew: !hasAny(o) && hasAny(n), parts });
  }
  return out;
}

// ---------- 바뀐 파일 모으기 ----------
const OTHER_NAMES = [
  [/^index\.html$/, "사이트 화면"],
  [/^call\//, "콜 가이드"],
  [/^jlpt\.js$/, "JLPT 단어 데이터"],
  [/^streams\.js$/, "스트리밍 링크"],
  [/^music_db\.xml$/, "곡 데이터"],
  [/^(sw\.js|manifest\.webmanifest)$/, "앱 설정"],
  [/\.(webp|jpe?g|png|gif)$/i, "이미지"],
];
const IGNORE = [/^\.github\//, /^도구\//, /^[^/]+\.js$/]; // 도구 폴더, 예전 루트 가사 사본은 사이트에 안 쓰여서 건너뜁니다

const diff = git("diff", "--name-status", "--no-renames", before, after).trim();
const changes = diff ? diff.split("\n").map(l => { const [status, ...p] = l.split("\t"); return { status, path: p.join("\t") }; }) : [];

const lyricUpdates = [];
const others = new Set();
for (const { status, path } of changes) {
  const m = path.match(/^가사\/(.+)\.js$/);
  if (m) {
    if (status === "D") continue;
    const al = albumByFile[m[1]];
    const songs = compareSongs(parseLyrics(show(before, path)), parseLyrics(show(after, path)));
    if (songs.length) lyricUpdates.push({ file: m[1], al, songs });
    continue;
  }
  const keep = ["jlpt.js", "streams.js", "sw.js"].includes(path); // 루트 .js 중 사이트가 쓰는 파일
  if (!keep && IGNORE.some(re => re.test(path))) continue;
  const hit = OTHER_NAMES.find(([re]) => re.test(path));
  others.add(hit ? hit[1] : "기타 파일");
}

if (!lyricUpdates.length && !others.size) {
  console.log("사이트에 보이는 변경이 없어 알림을 보내지 않습니다.");
  process.exit(0);
}

// ---------- 메시지 만들기 ----------
const pad = n => String(n).padStart(2, "0");
const lines = [];
let songCount = 0;
for (const { file, al, songs } of lyricUpdates) {
  lines.push(al ? `**${al.label} 『${al.title}』**` : `**${file}**`);
  for (const s of songs) {
    songCount++;
    const t = al && al.tracks && al.tracks[s.no - 1];
    const name = t ? (t[1] ? `${t[0]} · ${t[1]}` : t[0]) : (s.title || "");
    const label = `${pad(s.no)} ${name}`.trim();
    const link = al ? `${SITE}#/s/${al.key}/${s.no}` : SITE;
    lines.push(`${s.isNew ? "🆕" : "✏️"} [${label}](${link}) — ${s.parts.join(" · ")}`);
  }
  lines.push("");
}

let description = "";
for (let i = 0; i < lines.length; i++) {
  const next = description + lines[i] + "\n";
  if (next.length > 3800) { description += `…그 밖에 더 있어요. [사이트에서 보기](${SITE})`; break; }
  description = next;
}

const embed = {
  title: songCount ? `📝 가사 노트 업데이트 · ${songCount}곡` : "🛠 가사 노트 사이트 업데이트",
  url: SITE,
  color: 0x7bc043,
  description: description.trim() || undefined,
  fields: others.size ? [{ name: "🛠 사이트 개선", value: [...others].join(", ") }] : undefined,
  footer: { text: `${git("rev-parse", "--short", after).trim()} · 사이트에 반영되기까지 1~2분 걸릴 수 있어요` },
  timestamp: new Date(git("show", "-s", "--format=%cI", after).trim()).toISOString(),
};
const payload = { username: "가사 노트", embeds: [embed], allowed_mentions: { parse: [] } };

if (dryRun || !webhook) {
  if (!webhook && !dryRun) console.log("DISCORD_WEBHOOK_URL 이 없어 보내지 않고 내용만 출력합니다.");
  console.log(JSON.stringify(payload, null, 2));
  process.exit(0);
}

const res = await fetch(`${webhook}?wait=true`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(payload),
});
if (!res.ok) {
  console.error(`디스코드 전송 실패: ${res.status} ${await res.text()}`);
  process.exit(1);
}
console.log(`디스코드로 보냈어요: 가사 ${songCount}곡, 사이트 변경 ${others.size}건`);
