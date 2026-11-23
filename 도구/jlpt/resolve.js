// Runs in the browser with window.CACHE (Naver results), window.TERMS (quiz word terms), window.ANKI (broco Nihongo ANKI_V),
// window.LIST (공개 JLPT 단어 목록 "글자|읽기" → 급수), window.JISHO (Jisho 사전 결과), window.MANUAL ([글자, 방법] 손으로 분류한 표).
// 순서: 네이버 → Anki 덱 → 공개 목록 → Jisho → manual.tsv. 목록에 없어 어림한 급수는 "e3"처럼 앞에 e를 붙인다.
// Returns { map: {"plain|reading": 1~5 | "b"/"m"/"a" | "e1"~"e5" | 0(퀴즈에 내지 않는 말)}, stats, samples, need, jneed, missing, todo }.
//   need = 네이버에서 더 찾을 말, jneed = Jisho에서 더 찾을 말, missing = manual.tsv에 적은 낱말의 급수를 못 찾은 것, todo = 아직 분류하지 않은 낱말
(() => {
  const FURI = /\{([^{}|]+)\|([^{}|]+)(?:\|N[1-5])?\}/g;
  const plain = s => String(s).replace(FURI, "$1"), reading = s => String(s).replace(FURI, "$2");
  const hira = s => s.replace(/[ァ-ヶ]/g, c => String.fromCharCode(c.charCodeAt(0) - 0x60));
  const kana = s => hira(String(s).replace(/<[^>]+>/g, "")).replace(/[^ぁ-ゟー]/g, "");
  const KANJI = /[㐀-鿿々]/;
  const forms = k => String(k).replace(/<[^>]+>/g, "").split(/[·・∙,、]/).flatMap(f => [f.replace(/[()（）]/g, ""), f.replace(/[(（][^)）]*[)）]/g, "")]).map(x => x.trim()).filter(Boolean);
  const lvOf = it => { const m = /JLPT (\d)/.exec(it.f || ""); return m ? +m[1] : 0; };
  // 끝의 조사·종조사, 복수 접미사(僕ら, 夢たち). 떼고 남은 말에 한자나 가타카나가 있을 때만 쓴다(ほら → ほ 같은 잘못을 막으려고).
  const PARTICLE = /(だよ|だね|でしょ|かな|が|を|に|は|も|で|と|の|へ|や|よ|ね|さ|たち|達|ら)$/;
  const HARD = /[㐀-鿿々ァ-ヶ]/;
  const need = new Set(), jneed = new Set();
  const anki = {};
  for (const [w, r, , band] of window.ANKI) { anki[w] ||= []; anki[w].push({ r: kana(r) || "", band }); }

  function naver(p, r) {
    const list = (window.CACHE[p] || []).filter(it => /일한/.test(it.d) && /^exact/.test(it.m) && kana(it.e));
    const best = arr => arr.find(it => lvOf(it)) || arr[0];
    const hasK = KANJI.test(p);
    const entry = list.filter(it => it.m.startsWith("exact:entry") || it.m.startsWith("exact:subEntry"));
    let hit = best(entry.filter(it => kana(it.e) === r && (!hasK || forms(it.k).includes(p))));
    if (!hit) hit = best(entry.filter(it => kana(it.e) === r));
    if (!hit && hasK && !/^[ぁ-ゟー]+$/.test(r)) hit = best(entry.filter(it => forms(it.k).includes(p)));
    let via = hit ? "entry" : "";
    if (!hit) { hit = best(list.filter(it => it.m.startsWith("exact:revert") || it.m.startsWith("exact:subEntry"))); via = hit ? "revert" : ""; }
    return hit ? { lv: lvOf(hit), via, e: kana(hit.e), k: String(hit.k).replace(/<[^>]+>/g, "") } : null;
  }

  // 공개 JLPT 목록: 글자와 읽기가 둘 다 맞을 때만
  const LIST = window.LIST || {}, byExpr = {};
  for (const k of Object.keys(LIST)) { const e = k.split("|")[0]; byExpr[e] = Math.max(byExpr[e] || 0, LIST[k]); }
  const listLv = (p, r) => LIST[`${p}|${r}`] || 0;
  // Jisho: 표기와 읽기가 맞는 올림말의 JLPT 표시. 가나뿐인 말은 한자 표기가 없는 올림말만(はれ → 晴れ 같은 잘못을 막으려고)
  function jishoLv(p, r) {
    for (const d of (window.JISHO || {})[p] || []) {
      const ok = KANJI.test(p) ? d.f.some(([w, x]) => w === p && kana(x) === r) : d.f.some(([w, x]) => !w && kana(x) === r) && !d.f.some(([w]) => w && KANJI.test(w));
      const ls = (d.j || []).map(t => +(/jlpt-n(\d)/.exec(t) || [])[1]).filter(Boolean);
      if (ok && ls.length) return Math.max(...ls);
    }
    return 0;
  }

  const map = {}, stats = { terms: 0, naverLevel: 0, naverNoLevel: 0, noMatch: 0, stripped: 0, ankiOnly: { b: 0, m: 0, a: 0 }, list: 0, jisho: 0, same: 0, phrase: 0, guess: 0, none: 0, todo: 0, agree: 0, disagree: [] }, samples = { list: [], jisho: [], same: [], phrase: [], revert: [] };
  const late = [];
  for (const term of window.TERMS) {
    stats.terms++;
    let p = plain(term), r = kana(reading(term));
    const key = `${plain(term)}|${reading(term)}`;
    // 가나 한 글자(よ, さ, の 같은 조사)는 사전에서 다른 낱말(世, 夜)과 섞여서 사전 급수를 붙이지 않고 manual.tsv만 본다
    if (/^[ぁ-ゟ゠-ヿー]$/.test(p)) { late.push({ p, r, key, single: true }); continue; }
    let res = naver(p, r);
    const p2 = p.replace(PARTICLE, "");
    if ((!res || !res.lv) && p2 !== p && HARD.test(p2) && !window.CACHE[p2]) need.add(p2);
    if ((!res || !res.lv) && p2 !== p && HARD.test(p2) && window.CACHE[p2]) {
      const r2 = r.slice(0, r.length - (p.length - p2.length)), res2 = naver(p2, r2);
      if (res2 && res2.lv) { res = res2; stats.stripped++; }
    }
    const a = (anki[p] || []).find(x => !x.r || x.r === r || x.r === p) || null;
    if (res && res.lv) {
      map[key] = res.lv; stats.naverLevel++;
      if (res.via === "revert" && samples.revert.length < 25) samples.revert.push(`${p} → ${res.k}(${res.e}) N${res.lv}`);
      if (a) { const exp = { b: [5], m: [4, 3], a: [2, 1] }[a.band]; if (exp && exp.includes(res.lv)) stats.agree++; else if (stats.disagree.length < 40) stats.disagree.push(`${p} N${res.lv} anki:${a.band}`); }
      continue;
    }
    if (res) stats.naverNoLevel++; else stats.noMatch++;
    if (a) { map[key] = a.band; stats.ankiOnly[a.band]++; continue; }
    const l = listLv(p, r);
    if (l) { map[key] = l; stats.list++; samples.list.push(`${p} N${l}`); continue; }
    if (!(window.JISHO || {})[p] && !/^[\x00-\x7f]+$/.test(p)) jneed.add(p);
    const j = jishoLv(p, r);
    if (j) { map[key] = j; stats.jisho++; samples.jisho.push(`${p} N${j}`); continue; }
    late.push({ p, r, key });
  }

  // manual.tsv의 낱말 급수: 네이버와 공개 목록이 다르면 쉬운 쪽(큰 숫자). 가나뿐인 낱말은 다른 낱말과 섞이기 쉬워 공개 목록부터 본다.
  const known = {};
  for (const k in map) if (typeof map[k] === "number") { const e = k.split("|")[0]; known[e] = Math.max(known[e] || 0, map[k]); }
  const kanaList = w => { let best = 0; for (const k in LIST) { const [e, x] = k.split("|"); if (x === hira(w) && (!KANJI.test(e) || !best)) best = Math.max(best, KANJI.test(e) ? 0 : LIST[k]); } return best; };
  const naverLv = w => {
    if (!window.CACHE[w]) { need.add(w); return 0; }
    const list = window.CACHE[w].filter(it => /일한/.test(it.d) && /^exact:(entry|subEntry)/.test(it.m) && lvOf(it) && (KANJI.test(w) ? forms(it.k).includes(w) : kana(it.e) === hira(w)));
    return list.length ? Math.max(...list.map(lvOf)) : 0;
  };
  const memo = {};
  function wordLv(w) {
    if (w in memo) return memo[w];
    const v = KANJI.test(w) ? Math.max(naverLv(w), byExpr[w] || 0) || known[w] || 0 : byExpr[w] || kanaList(w) || known[w] || naverLv(w) || 0;
    return (memo[w] = v);
  }
  const manual = {}, missing = [], todo = [];
  for (const [p, spec] of window.MANUAL || []) manual[p] = spec;
  for (const { p, r, key } of late) {
    const spec = manual[p];
    if (!spec) { stats.todo++; todo.push(`${p}|${r}`); continue; }
    if (spec === "-") { map[key] = 0; stats.none++; continue; }
    const fixed = /~([1-5])$/.exec(spec), body = spec.slice(1).replace(/~[1-5]$/, "");
    if (spec[0] === "~") { map[key] = "e" + spec[1]; stats.guess++; continue; }
    if (spec[0] === "=") {
      const v = wordLv(body);
      if (v) { map[key] = v; stats.same++; samples.same.push(`${p}=${body} N${v}`); }
      else if (fixed) { map[key] = "e" + fixed[1]; stats.guess++; }
      else missing.push(`${p} ← ${body}`);
      continue;
    }
    const parts = spec.slice(1).split(","), lv = parts.map(x => x[0] === "~" ? +x[1] : wordLv(x)), bad = parts.filter((x, i) => !lv[i]);
    if (bad.length) { missing.push(`${p} ← ${bad.join(",")}`); continue; }
    map[key] = "e" + Math.min(...lv); stats.phrase++;
    samples.phrase.push(`${p} N${Math.min(...lv)} (${parts.map((x, i) => x + ":" + lv[i]).join(" ")})`);
  }
  return JSON.stringify({ map, stats, samples, need: [...need], jneed: [...jneed], missing, todo });
})()
