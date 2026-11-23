/* 녹황색사회 가사 퀴즈: 곡의 [공부](단어·문법)로 문제를 만든다. 가사 노트(ryokulyrics)와 broco Nihongo가 같은 코드를 쓴다.
   곡 = { id, title, ko, lines: [{ jp }], items: [{ line, term, mean, gram }] }  (line은 0부터 센 가사 줄 번호)
   문제 = { key, kind: "word" | "gram" | "read", q, c: [정답, 오답, 오답, 오답], e, line, term, mean, lv, song }  (c의 첫 번째가 정답) */
const RQ = (() => {
  const FURI = /\{([^{}|]+)\|([^{}|]+)(?:\|N[1-5])?\}/g;
  const plain = s => String(s).replace(FURI, "$1");
  const reading = s => String(s).replace(FURI, "$2");
  const KANJI = /[㐀-鿿々]/;
  const HIRA = /^[ぁ-ゟー]+$/;
  const same = s => plain(s).normalize("NFKC").replace(/[\s、。,.!?！？「」'"‘’“”]/g, "");
  const hash = s => { let h = 2166136261; for (const ch of s) { h ^= ch.codePointAt(0); h = Math.imul(h, 16777619) >>> 0; } return h.toString(36); };
  // JLPT 급수표(jlpt.js)의 열쇠: "후리가나를 뺀 글자|읽기"
  const lvKey = term => `${plain(term)}|${reading(term)}`;
  // 퀴즈에 쓰는 [공부] 항목: 낱말과 뜻이 있는 것. 급수표에 0으로 적힌 말(영어, 노랫말 소리, 이름, 지어낸 말)은 문제로 내지 않는다.
  const usable = (it, levels) => it.term && it.mean && (it.gram || levels[lvKey(it.term)] !== 0);
  const shuffle = a => { a = a.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };

  // 오답 후보: t = 보기 글, k = 그 글이 풀이하는 낱말이나 가사 줄. 같은 낱말·같은 줄의 다른 풀이는 정답과 뜻이 같을 수 있어서 오답으로 쓰지 않는다.
  // 후보는 글자 수별로 묶어 두고(idx[글자 수]), 정답과 길이가 가까운 묶음부터 고른다.
  const entry = (t, k) => ({ t, k: same(k), s: same(t), n: plain(t).length });
  function lenIndex(list) { const m = []; for (const c of list) if (c.s) (m[c.n] ||= []).push(c); return m; }
  function pickWrong(right, idx, n, not, taken) {
    const seen = new Set([same(right), ...(taken || []).map(same)]), skip = same(not), len = plain(right).length, out = [];
    for (let d = 0; out.length < n && (len - d >= 0 || len + d < idx.length); d++) {
      for (const c of shuffle([...(idx[len - d] || []), ...(d ? idx[len + d] || [] : [])])) {
        if (seen.has(c.s) || c.k === skip) continue;
        seen.add(c.s); out.push(c.t);
        if (out.length >= n) break;
      }
    }
    return out;
  }

  // 읽기 문제의 오답: 탁음·장음·작은 っ·ゅ/ょ처럼 헷갈리기 쉬운 쪽으로 한자 읽기를 살짝 바꾼다.
  // end가 false면(뒤에 送り仮名가 이어지면) 끝에 장음을 붙이지 않는다(迷う → まようう 같은 보기가 생기지 않게).
  const PAIRS = ["かが", "きぎ", "くぐ", "けげ", "こご", "さざ", "しじ", "すず", "せぜ", "そぞ", "ただ", "てで", "とど", "はばぱ", "ひびぴ", "ふぶぷ", "へべぺ", "ほぼぽ"];
  const SWAP = {};
  for (const p of PAIRS) for (const c of p) SWAP[c] = [...p].filter(x => x !== c);
  const O_ROW = /[おこそとのほもよろごぞどぼぽょ]/, E_ROW = /[えけせてねへめれげぜでべぺ]/;
  function misreads(r, end = true) {
    const M = [...r], out = new Set();
    const at = (i, ...x) => { const s = [...M.slice(0, i), ...x, ...M.slice(i + 1)].join(""); if (s && s !== r) out.add(s); };
    M.forEach((c, i) => {
      if (SWAP[c] && M[i - 1] !== "っ") SWAP[c].forEach(x => at(i, x));
      if (c === "う" && i > 0 && O_ROW.test(M[i - 1])) at(i);
      if (end && O_ROW.test(c) && M[i + 1] !== "う" && i === M.length - 1) at(i, c, "う");
      if (c === "い" && i > 0 && E_ROW.test(M[i - 1])) at(i);
      if (c === "っ") { at(i); at(i, "つ"); }
      if (/[くつち]/.test(c) && i + 1 < M.length && /[かきくけこさしすせそたちつてとぱぴぷぺぽ]/.test(M[i + 1])) at(i, "っ");
      if (c === "ゅ") at(i, "ょ");
      if (c === "ょ") at(i, "ゅ");
    });
    return [...out];
  }
  const fine = s => s.length >= 2 && !/^[っんーゃゅょ]|っ$|っっ|っん|んっ/.test(s);

  // 낱말을 한자 칸({迷|まよ})과 보이는 가나 칸(う)으로 나눈다. frame은 한자 칸을 □로 바꾼 모양(迷う → □う).
  const SEG = /\{([^{}|]+)\|([^{}|]+)(?:\|N[1-5])?\}|([^{}]+)/g;
  const segs = term => [...String(term).matchAll(SEG)].map(m => m[3] != null ? { kana: m[3] } : { kanji: m[1], read: m[2] });
  const frame = ss => ss.map(s => s.kana != null ? s.kana : "□").join("");
  const build = (ss, i, v) => ss.map((s, j) => s.kana != null ? s.kana : j === i ? v : s.read).join("");

  // 읽기 문제로 낼 수 있는 [공부] 항목: 한자가 있고, 후리가나가 달려 있고, 읽기가 히라가나뿐인 짧은 낱말
  function readable(term) {
    const p = plain(term);
    return KANJI.test(p) && /\{/.test(term) && !/[～〜~=＝→·・、,\s/()（）]/.test(p) && p.length <= 8 && HIRA.test(reading(term));
  }

  // 읽기 오답 3개. 보이는 가나(送り仮名)는 정답과 똑같이 두고 한자 읽기만 바꾼다.
  // 1) 한자 읽기를 헷갈리기 쉽게 바꾼 것 2) 모양이 같은 다른 낱말의 읽기(迷う → 思う·歌う의 읽기)
  // 3) 한자 칸 하나를 다른 낱말의 한자 읽기로 바꾼 것 4) 보이는 가나가 없는 낱말만: 길이가 비슷한 다른 읽기
  function readWrong(term, all) {
    const ss = segs(term), r = reading(term), slots = ss.map((s, i) => s.kana == null ? i : -1).filter(i => i >= 0), out = new Set();
    slots.forEach(i => { for (const v of misreads(ss[i].read, i === ss.length - 1)) { const c = build(ss, i, v); if (c !== r && fine(c)) out.add(c); } });
    let wrong = shuffle([...out]).slice(0, 3);
    if (wrong.length < 3) wrong = wrong.concat(pickWrong(r, all.frames[frame(ss)] || [], 3 - wrong.length, term, wrong));
    for (let tries = 0; wrong.length < 3 && slots.length && tries < 8; tries++) {
      const i = slots[Math.floor(Math.random() * slots.length)], [v] = pickWrong(ss[i].read, all.segReads, 1, ss[i].kanji);
      if (!v) break;
      const c = build(ss, i, v);
      if (c !== r && fine(c) && !wrong.includes(c)) wrong.push(c);
    }
    if (wrong.length < 3 && ss.every(s => s.kana == null)) wrong = wrong.concat(pickWrong(r, all.reads, 3 - wrong.length, term, wrong));
    return wrong;
  }

  // 모든 곡에서 모은 오답 후보: 한 곡 안에서 오답이 모자랄 때 쓴다
  function pool(songs, levels) {
    const items = songs.flatMap(s => s.items.filter(it => usable(it, levels || {}))), rd = items.filter(it => readable(it.term)), frames = {};
    for (const it of rd) (frames[frame(segs(it.term))] ||= []).push(entry(reading(it.term), it.term));
    for (const k in frames) frames[k] = lenIndex(frames[k]);
    return {
      means: { true: lenIndex(items.filter(it => it.gram).map(it => entry(it.mean, it.term))), false: lenIndex(items.filter(it => !it.gram).map(it => entry(it.mean, it.term))) },
      reads: lenIndex(rd.map(it => entry(reading(it.term), it.term))),
      frames,
      levels: levels || {},
      segReads: lenIndex(rd.flatMap(it => segs(it.term).filter(s => s.kana == null).map(s => entry(s.read, s.kanji)))),
    };
  }

  function bank(song, all) {
    const qs = [], done = new Set();
    // 열쇠 글자: 단어와 문법은 w, 읽기는 r (문법을 따로 나누기 전에 모인 틀린 문제도 이어지게 문법도 w를 쓴다)
    const add = (kind, id, q) => { const key = `${song.id}:${kind === "read" ? "r" : "w"}${hash(id)}`; if (done.has(key)) return; done.add(key); qs.push({ key, kind, song, ...q }); };
    const lineOf = i => song.lines[i] || null;
    const items = song.items.filter(it => usable(it, all.levels));
    // 1. 단어·문법 뜻 고르기: [공부]의 '낱말 - 뜻'. 오답은 같은 곡의 낱말(문법이면 문법) 뜻에서 먼저 고른다.
    const kin = { true: lenIndex(items.filter(it => it.gram).map(it => entry(it.mean, it.term))), false: lenIndex(items.filter(it => !it.gram).map(it => entry(it.mean, it.term))) };
    for (const it of items) {
      let wrong = pickWrong(it.mean, kin[it.gram], 3, it.term);
      if (wrong.length < 3) wrong = wrong.concat(pickWrong(it.mean, all.means[it.gram], 3 - wrong.length, it.term, wrong));
      if (wrong.length < 3) continue;
      const l = lineOf(it.line);
      add(it.gram ? "gram" : "word", same(it.term), { q: `「${it.term}」의 뜻은?`, c: [it.mean, ...wrong], term: it.term, mean: it.mean, line: it.line, lv: all.levels[lvKey(it.term)] || "",
        e: `${plain(it.term)} - ${it.mean}${l ? ` · 가사 ${it.line + 1}번째 줄: ${plain(l.jp)}` : ""}` });
    }
    // 2. 읽기 맞히기: 한자가 들어간 [공부] 낱말
    for (const it of items) {
      if (!readable(it.term)) continue;
      const r = reading(it.term), wrong = readWrong(it.term, all);
      if (wrong.length < 3) continue;
      add("read", plain(it.term), { q: `「${plain(it.term)}」의 읽기는?`, c: [r, ...wrong], term: it.term, mean: it.mean, line: it.line, lv: all.levels[lvKey(it.term)] || "",
        e: `${plain(it.term)}(${r}) - ${it.mean}` });
    }
    return qs;
  }

  // 문제 뽑기: 고른 종류를 번갈아 가며 n문제
  function pick(qs, kinds, n) {
    const by = {};
    for (const k of kinds) by[k] = shuffle(qs.filter(q => q.kind === k));
    const out = [];
    for (let i = 0; out.length < n && kinds.some(k => by[k].length); i++) {
      const k = kinds[i % kinds.length];
      if (by[k].length) out.push(by[k].pop());
    }
    return shuffle(out);
  }

  // JLPT 급수별로 나누기: n = 5~1, 그 급수의 단어·읽기 문제. 문법은 급수가 없어서 넣지 않는다.
  // 급수가 없어 Anki 덱 단계로 짐작한 b·m·a는 걸치는 급수에 모두, 어림한 e5~e1은 그 급수에 넣는다. 같은 낱말이 여러 곡에 나오면 그중 한 곡의 것만 낸다.
  const BAND = { b: [5], m: [4, 3], a: [2, 1], e5: [5], e4: [4], e3: [3], e2: [2], e1: [1] };
  const levelsOf = lv => BAND[lv] || (lv ? [lv] : []);
  function byLevel(qs, n) {
    const seen = new Set();
    return shuffle(qs).filter(q => {
      if (q.kind === "gram") return false;
      const k = `${q.kind}|${lvKey(q.term)}`;
      if (!levelsOf(q.lv).includes(n) || seen.has(k)) return false;
      seen.add(k);
      return true;
    });
  }

  // 읽기 문제의 보기(가나)를 그 낱말의 {한자|읽기} 모양으로 되돌린다(로마자를 조사·送り仮名에 맞게 붙이려고). 붙어 있는 한자 칸은 하나로 본다.
  function markRead(term, kana) {
    const ss = [];
    for (const s of segs(term)) { const p = ss[ss.length - 1]; if (s.kana == null && p && p.kana == null) p.kanji += s.kanji; else ss.push({ ...s }); }
    const m = new RegExp("^" + ss.map(s => s.kana == null ? "(.+?)" : s.kana.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("") + "$").exec(kana);
    if (!m) return kana;
    let i = 0;
    return ss.map(s => s.kana == null ? `{${s.kanji}|${m[++i]}}` : s.kana).join("");
  }

  // 영어 발음(로마자): [공부] 낱말 하나를 헵번식으로 바꾼다. 긴 소리는 ou, uu처럼 소리 나는 글자로 풀어 쓰고, 조사 앞뒤는 띄운다(雨が降る → ame ga furu).
  const ROMA = { あ: "a", い: "i", う: "u", え: "e", お: "o", か: "ka", き: "ki", く: "ku", け: "ke", こ: "ko", さ: "sa", し: "shi", す: "su", せ: "se", そ: "so", た: "ta", ち: "chi", つ: "tsu", て: "te", と: "to", な: "na", に: "ni", ぬ: "nu", ね: "ne", の: "no", は: "ha", ひ: "hi", ふ: "fu", へ: "he", ほ: "ho", ま: "ma", み: "mi", む: "mu", め: "me", も: "mo", や: "ya", ゆ: "yu", よ: "yo", ら: "ra", り: "ri", る: "ru", れ: "re", ろ: "ro", わ: "wa", を: "o", が: "ga", ぎ: "gi", ぐ: "gu", げ: "ge", ご: "go", ざ: "za", じ: "ji", ず: "zu", ぜ: "ze", ぞ: "zo", だ: "da", ぢ: "ji", づ: "zu", で: "de", ど: "do", ば: "ba", び: "bi", ぶ: "bu", べ: "be", ぼ: "bo", ぱ: "pa", ぴ: "pi", ぷ: "pu", ぺ: "pe", ぽ: "po", ゔ: "vu", ぁ: "a", ぃ: "i", ぅ: "u", ぇ: "e", ぉ: "o" };
  const hira = s => s.replace(/[ァ-ヶ]/g, c => String.fromCharCode(c.charCodeAt(0) - 0x60));
  function kanaRom(s) {
    s = hira(s);
    let out = "";
    for (let i = 0; i < s.length; i++) {
      const c = s[i], n = s[i + 1] || "", r = ROMA[c];
      if (c === "ー") { const m = /[aeiou](?=[^aeiou]*$)/.exec(out); out += m ? m[0] : ""; }
      else if (c === "っ") { const x = kanaRom(s.slice(i + 1, i + 3)); out += x.startsWith("ch") ? "t" : /^[^aeiou]/.test(x) ? x[0] : ""; }
      else if (c === "ん") out += "n" + (/^[aeiouy]/.test(n && kanaRom(n)) ? "'" : "");
      else if (r === undefined) out += c === "？" ? "?" : c === "！" ? "!" : c;
      else if (n && "ゃゅょ".includes(n)) { const y = { ゃ: "a", ゅ: "u", ょ: "o" }[n]; out += /^(sh|ch|j)/.test(r) ? r.slice(0, -1) + y : r.slice(0, -1) + "y" + y; i++; }
      else if (n && "ぁぃぅぇぉ".includes(n) && r.length > 1 && !r.endsWith(ROMA[n])) { out += r.slice(0, -1) + ROMA[n]; i++; }
      else out += r;
    }
    return out;
  }
  // 낱말로만 봐서는 어디서 끊는지 알 수 없는 말(가나로만 적은 표현, は·へ가 조사인 말). 왼쪽은 후리가나를 뺀 글자.
  const ROM_FIX = { いいよね: "ii yo ne", いいさ: "ii sa", あのね: "ano ne", だね: "da ne", だよ: "da yo", よね: "yo ne", またね: "mata ne", ごめんね: "gomen ne", でもね: "demo ne", ほらね: "hora ne", ここはもう: "koko wa mou", ここから: "koko kara", ここまで: "koko made", これから: "kore kara", これまで: "kore made", これが: "kore ga", それが: "sore ga", それも: "sore mo", それでいい: "sore de ii", それだけ: "sore dake", それだけで: "sore dake de", それだけでいい: "sore dake de ii", それだけなの: "sore dake na no", それだけのこと: "sore dake no koto", それって: "sore tte", それもいいね: "sore mo ii ne", そうです: "sou desu", そうだ: "sou da", そんなの: "sonna no", そんなはずない: "sonna hazu nai", そんなふうに: "sonna fuu ni", こんなの: "konna no", このまま: "kono mama", すぐそこ: "sugu soko", どうかな: "dou kana", どうしたの: "doushita no", どうしてかな: "doushite kana", どうだろう: "dou darou", どうやったか: "dou yatta ka", どうでもいい: "dou demo ii", どうしようもない: "dou shiyou mo nai", どこへ: "doko e", どこまで: "doko made", どこまでも: "doko made mo", どちらも: "dochira mo", どれも: "dore mo", そのどちらも: "sono dochira mo", いつから: "itsu kara", いつかは: "itsuka wa", たまには: "tama ni wa", なんでもいい: "nandemo ii", もうない: "mou nai", もんね: "mon ne", あなたがいれば: "anata ga ireba", あれもこれも: "are mo kore mo", ひとつだけ: "hitotsu dake", ひとつずつ: "hitotsu zutsu", ひとりで: "hitori de", ほんとの: "honto no", みんなで: "minna de", じゃないの: "ja nai no", 私のもの: "watashi no mono", その代わりに: "sono kawari ni" };
  const PART = { は: "わ", へ: "え", を: "お", には: "に わ", では: "で わ", とは: "と わ", にも: "に も" };
  function spaced(term) {
    const ss = segs(term), kj = s => !!s && s.kana == null;
    let out = "";
    ss.forEach((s, i) => {
      if (kj(s)) { out += s.read; return; }
      const prev = kj(ss[i - 1]), next = kj(ss[i + 1]);
      let k = hira(s.kana).replace(/くはない/g, "く わ ない").replace(/ではない/g, "で わ ない");
      const m = prev && /^(ら|たち)?(から|まで|だけ|でも|なら|ならば|すぐ|こそ|さえ|より|には|では|とは|にも|が|を|に|は|も|の|と|で|へ|な)$/.exec(k);
      if (m && !(m[2] === "な" && !next)) k = `${m[1] || ""} ${PART[m[2]] || m[2]}${next ? " " : ""}`;
      else if (prev) {
        k = k.replace(/^(ら|たち|つ)(が|を|に|は|も|の|と|で)$/, (x, a, b) => `${a} ${PART[b] || b}`)
          .replace(/^を(?=.)/, " お ")
          .replace(/^(が|に|は|も|の|と)(?=(する|した|して|しな|され|させ|なる|なっ|なれ|なら|ない|ある|いる|いれ|いい|かか|でる|でき|わか|つく|くる|いう))/, (x, a) => ` ${PART[a] || a} `)
          .replace(/^(しか)(ない|できない)$/, " $1 $2").replace(/^じゃない/, " じゃ ない")
          .replace(/く(なる|なって|なった|させる|する)$/, "く $1")
          .replace(/([うくぐすつぬぶむるいた])かな$/, "$1 かな").replace(/([うくぐすつぬぶむるいたて])([ねよ])$/, "$1 $2").replace(/(.)(だけ|ずつ)$/, "$1 $2").replace(/([うくぐすつぬぶむる])まま$/, "$1 まま");
        if (next) k = k.replace(/^([^\s]{1,3})([にをがはも])$/, (x, a, b) => `${a} ${PART[b] || b} `);
        if (next && !k.endsWith(" ") && /(しい|たい|ない|きい|るい|ろい|な|た|たり|だり|[うくぐすつぬぶむる])$/.test(k)) k += " ";
      }
      else if (next && /^(この|その|あの|どの|もう|あと|そう|こう|どう|まだ|また|ただ|これ|それ|あれ|ずっと|とても|おもちゃ|ガラス|がらす|こんな|そんな|どんな)$/.test(k)) k += " ";
      out += k;
    });
    return out;
  }
  function romaji(term) {
    const p = plain(term);
    if (ROM_FIX[p]) return ROM_FIX[p];
    if (/～/.test(term)) return term.split("～").map(x => romaji(x)).join(" ~ ").trim();
    if (/・/.test(term)) return term.split("・").map(x => romaji(x)).join(" / ");
    if (segs(term).some(s => s.kana != null && KANJI.test(s.kana))) return "";
    return spaced(term.replace(/[(（]を[)）]/g, "を")).split(/\s+/).filter(Boolean).map(kanaRom).join(" ");
  }

  return { plain, reading, lvKey, readable, misreads, readWrong, pool, bank, pick, byLevel, markRead, romaji, shuffle, hash };
})();
