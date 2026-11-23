
// 퀴즈에 쓰는 곡: 해석이나 [공부]가 있는 곡. 같은 곡이 두 앨범에 실렸으면 앞 앨범 것 하나만 쓴다.
let QUIZ = null;
function quizData() {
  if (QUIZ) return QUIZ;
  const songs = [], seen = new Set();
  for (const t of ALL) {
    if (t.inst || seen.has(norm(t.jp))) continue;
    const { d } = lyricsFor(t);
    if (!d) continue;
    const L = layout(d);
    const items = Object.entries(studyNotes(d.공부).notes).flatMap(([i, list]) => list.map(it => ({ line: Number(i), term: it.term, mean: it.mean, gram: it.gram })));
    if (!items.length && !L.ko.length) continue;
    seen.add(norm(t.jp));
    songs.push({ id: t.id, t, title: t.jp, ko: t.ko, lines: L.jp.map((jp, i) => ({ jp, ko: L.ko[i] || "" })), items });
  }
  const all = RQ.pool(songs);
  for (const s of songs) s.bank = RQ.bank(s, all);
  QUIZ = { songs: songs.filter(s => s.bank.length), keys: {} };
  for (const s of QUIZ.songs) for (const q of s.bank) QUIZ.keys[q.key] = q;
  return QUIZ;
}
const quizSongFor = t => quizData().songs.find(s => s.t === t || t.twins.includes(s.t));

// 기록: 문제 종류·문제 수 설정, 곡별 최고 점수, 틀린 문제(맞히면 빠진다). 이 브라우저에만 저장된다.
const QKIND = { word: "단어 뜻", line: "가사 해석", read: "읽기" };
const qrec = Object.assign({ kinds: ["word", "line", "read"], n: 10, best: {}, wrong: {} }, store.get("ryokushaka-lyrics:quiz", {}));
if (!Array.isArray(qrec.kinds) || !qrec.kinds.length) qrec.kinds = ["word", "line", "read"];
const saveQuiz = () => store.set("ryokushaka-lyrics:quiz", qrec);
let qrun = null;

function renderQuizHome(msg) {
  const Q = quizData();
  document.title = "가사 퀴즈 · 녹황색사회 가사 노트";
  const nWrong = Object.keys(qrec.wrong).filter(k => Q.keys[k]).length;
  const count = (s, k) => s.bank.filter(q => q.kind === k).length;
  app.innerHTML = `${topRowHTML("quiz")}
    <div class="narrow">
      <header class="quiz-head">
        <h1>가사 퀴즈</h1>
        <p class="lede">해석과 단어·문법을 정리한 ${Q.songs.length}곡으로 문제를 내요. 곡을 고르면 그 곡에서, '전체 곡에서 섞어 풀기'를 누르면 여러 곡에서 골고루 나와요. 틀린 문제는 따로 모아 두었다가 다시 풀 수 있어요.</p>
      </header>
      ${msg ? `<p class="warn">${esc(msg)}</p>` : ""}
      <div class="quiz-set">
        <span class="qs-label">문제 종류</span>
        <div class="seg" role="group" aria-label="문제 종류">${Object.entries(QKIND).map(([k, v]) => `<button type="button" data-qk="${k}" aria-pressed="${qrec.kinds.includes(k)}">${v}</button>`).join("")}</div>
        <span class="qs-label">문제 수</span>
        <div class="seg" role="group" aria-label="문제 수">${[10, 20].map(n => `<button type="button" data-qn="${n}" aria-pressed="${qrec.n === n}">${n}문제</button>`).join("")}</div>
      </div>
      <div class="qz-btns">
        <a class="quiz-go" href="#/quiz/all">전체 곡에서 섞어 풀기</a>
        ${nWrong ? `<a class="quiz-go ghost" href="#/quiz/wrong">틀린 문제 다시 풀기 · ${nWrong}</a>` : ""}
      </div>
      ${GROUPS.map(g => {
        const list = Q.songs.filter(s => s.t.album.group === g.id);
        return list.length ? `<section class="group"><h2>${g.name}</h2><div class="quiz-songs">${list.map(s => {
          const b = qrec.best[s.id];
          return `<a class="quiz-song" href="#/quiz/${s.t.album.key}/${s.t.no}"><span class="qs-main"><span class="qs-t" lang="ja">${esc(s.title)}</span>${s.ko ? `<span class="qs-ko">${esc(s.ko)}</span>` : ""}</span><span class="qs-meta">${esc(s.t.album.label)}${isSolo(s.t.album) ? "" : ` ${s.t.no}번`} · 단어 ${count(s, "word")} · 해석 ${count(s, "line")} · 읽기 ${count(s, "read")}</span>${b ? `<span class="qs-best">최고 ${b.score}/${b.n}</span>` : ""}</a>`;
        }).join("")}</div></section>` : "";
      }).join("")}
    </div>`;
}

// #/quiz/all: 전체 곡, #/quiz/wrong: 틀린 문제, #/quiz/앨범/번호: 그 곡
function renderQuiz(key, no) {
  const Q = quizData();
  if (key === "all") return startQuiz(RQ.pick(Q.songs.flatMap(s => s.bank), qrec.kinds, qrec.n), "전체 곡에서 섞어 풀기", null);
  if (key === "wrong") return startQuiz(RQ.shuffle(Object.keys(qrec.wrong).map(k => Q.keys[k]).filter(Boolean)).slice(0, 30), "틀린 문제 다시 풀기", null);
  const t = byKey[key] && byKey[key].tracks[no - 1];
  const s = t && quizSongFor(t);
  if (s) return startQuiz(RQ.pick(s.bank, qrec.kinds, qrec.n), s.title, s);
  renderQuizHome();
}

function startQuiz(list, title, song) {
  if (!list.length) return renderQuizHome("고른 문제 종류로는 낼 문제가 없어요. 문제 종류를 바꿔 보세요.");
  qrun = { list, i: 0, score: 0, miss: [], title, song, answered: false };
  document.title = `${title} · 가사 퀴즈`;
  drawQuiz();
}

function quizQHTML(q) {
  if (q.kind === "line") return `<span class="qz-line" lang="ja">${rich(q.q)}</span><span class="qz-ask">이 가사의 해석은?</span>`;
  if (q.kind === "read") return `<span class="qz-term" lang="ja">${esc(RQ.plain(q.term))}</span><span class="qz-ask">이 낱말의 읽기는?</span>${q.mean ? `<span class="qz-hint">뜻: ${rich(q.mean)}</span>` : ""}`;
  return `<span class="qz-term" lang="ja">${rich(q.term)}</span><span class="qz-ask">이 낱말의 뜻은?</span>`;
}

function drawQuiz() {
  const r = qrun, q = r.list[r.i];
  if (!q) return drawQuizDone();
  r.answered = false;
  r.opts = RQ.shuffle(q.c.map((t, k) => ({ t, ok: k === 0 })));
  app.innerHTML = `${topRowHTML("quiz")}
    <div class="narrow">
      <a class="back" href="#/quiz">← 가사 퀴즈</a>
      <div class="quiz-prog"><span>${r.i + 1} / ${r.list.length}</span><div class="bar"><i style="width:${r.i / r.list.length * 100}%"></i></div><span>${r.score}점</span></div>
      <div class="quiz-card">
        <span class="quiz-kind">${QKIND[q.kind]} · <span lang="ja">${esc(q.song.title)}</span></span>
        <p class="quiz-q">${quizQHTML(q)}</p>
        <div class="quiz-opts${q.kind === "read" ? "" : " col"}">${r.opts.map((o, k) => `<button type="button" class="quiz-opt" data-qa="${k}"${q.kind === "read" ? ' lang="ja"' : ""}><span class="n">${k + 1}</span>${rich(o.t)}</button>`).join("")}</div>
        <div class="quiz-fb" id="qfb" hidden></div>
        <button type="button" class="quiz-go" data-qnext hidden>${r.i + 1 < r.list.length ? "다음 문제" : "결과 보기"}</button>
      </div>
    </div>`;
}

function answerQuiz(k) {
  const r = qrun;
  if (!r || r.answered || !r.opts[k]) return;
  r.answered = true;
  const q = r.list[r.i], ok = r.opts[k].ok;
  if (ok) { r.score++; delete qrec.wrong[q.key]; }
  else { r.miss.push(q); qrec.wrong[q.key] = (qrec.wrong[q.key] || 0) + 1; }
  saveQuiz();
  app.querySelectorAll("[data-qa]").forEach((b, i) => {
    b.disabled = true;
    if (r.opts[i].ok) b.classList.add("ok");
    else if (i === k) b.classList.add("no");
  });
  const l = q.song.lines[q.line];
  const fb = document.getElementById("qfb");
  fb.innerHTML = `<p class="qz-res ${ok ? "ok" : "no"}">${ok ? "정답이에요!" : "아쉬워요"}</p>
    ${q.kind === "line" ? "" : `<p class="qz-ans"><span lang="ja">${rich(q.term)}</span>${q.kind === "read" ? ` (${esc(q.c[0])})` : ""} · ${rich(q.mean || "")}</p>`}
    ${l ? `<a class="qz-src" href="#/s/${q.song.t.album.key}/${q.song.t.no}/${q.line}"><span lang="ja">${rich(l.jp)}</span>${l.ko ? `<span>${esc(l.ko)}</span>` : ""}<small>${q.line + 1}번째 줄 · 가사에서 보기 →</small></a>` : ""}`;
  fb.hidden = false;
  const next = app.querySelector("[data-qnext]");
  next.hidden = false;
  next.focus({ preventScroll: true });
}

function drawQuizDone() {
  const r = qrun, n = r.list.length;
  let best = null;
  if (r.song) {
    const b = qrec.best[r.song.id];
    if (!b || r.score / n > b.score / b.n || (r.score / n === b.score / b.n && n > b.n)) qrec.best[r.song.id] = { score: r.score, n };
    best = qrec.best[r.song.id];
    saveQuiz();
  }
  const missQ = q => q.kind === "line" ? rich(q.q) : q.kind === "read" ? `${esc(RQ.plain(q.term))}의 읽기` : `${rich(q.term)}의 뜻`;
  app.innerHTML = `${topRowHTML("quiz")}
    <div class="narrow">
      <a class="back" href="#/quiz">← 가사 퀴즈</a>
      <div class="quiz-card">
        <span class="quiz-kind" lang="ja">${esc(r.title)}</span>
        <p class="qz-score">${r.score} / ${n}</p>
        <p class="qz-sub">${r.score === n ? "모두 맞혔어요!" : `틀린 ${r.miss.length}문제는 '틀린 문제 다시 풀기'에 모아 두었어요.`}${best ? ` 이 곡 최고 점수는 ${best.score} / ${best.n}이에요.` : ""}</p>
        <div class="qz-btns">
          <button type="button" class="quiz-go" data-qagain>다시 풀기</button>
          ${r.miss.length ? `<button type="button" class="quiz-go ghost" data-qmiss>틀린 것만 다시</button>` : ""}
          ${r.song ? `<a class="quiz-go ghost" href="#/s/${r.song.t.album.key}/${r.song.t.no}">가사 보기</a>` : ""}
        </div>
        ${r.miss.length ? `<div class="qz-miss"><h2>틀린 문제</h2>${r.miss.map(q => `<div class="qz-m"><span class="quiz-kind">${QKIND[q.kind]} · <span lang="ja">${esc(q.song.title)}</span></span><p lang="ja">${missQ(q)}</p><p class="qz-ans">정답: <span${q.kind === "read" ? ' lang="ja"' : ""}>${rich(q.c[0])}</span></p></div>`).join("")}</div>` : ""}
      </div>
    </div>`;
  scrollTo(0, 0);
}

// 곡 화면의 '이 곡 퀴즈 풀기' 링크
function quizLinkHTML(t) {
  if (window.SINGLE) return "";
  const s = quizSongFor(t);
  return s ? `<a class="maker call-link quiz-link" href="#/quiz/${s.t.album.key}/${s.t.no}"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-2h2v2zm2.1-7.1-.9.9c-.7.7-1.2 1.3-1.2 2.7h-2v-.5c0-1.1.4-2.1 1.2-2.8l1.2-1.3c.4-.3.6-.8.6-1.4a2 2 0 0 0-4 0H7a5 5 0 0 1 10 0c0 .9-.4 1.7-.9 2.4z"/></svg>이 곡 퀴즈 풀기</a>` : "";
}

// 퀴즈 버튼들. 숫자 1~4로 답하고 Enter로 다음 문제로 넘어갈 수 있다.
function quizClick(e) {
  const kind = e.target.closest("[data-qk]");
  if (kind) {
    const k = kind.dataset.qk, on = qrec.kinds.includes(k);
    if (on && qrec.kinds.length === 1) return true;
    qrec.kinds = on ? qrec.kinds.filter(x => x !== k) : Object.keys(QKIND).filter(x => x === k || qrec.kinds.includes(x));
    saveQuiz(); renderQuizHome();
    return true;
  }
  const num = e.target.closest("[data-qn]");
  if (num) { qrec.n = Number(num.dataset.qn); saveQuiz(); renderQuizHome(); return true; }
  const ans = e.target.closest("[data-qa]");
  if (ans) { answerQuiz(Number(ans.dataset.qa)); return true; }
  if (e.target.closest("[data-qnext]")) { qrun.i++; drawQuiz(); scrollTo(0, 0); return true; }
  if (e.target.closest("[data-qagain]")) { route(); return true; }
  if (e.target.closest("[data-qmiss]")) { startQuiz(RQ.shuffle(qrun.miss), qrun.title, qrun.song); scrollTo(0, 0); return true; }
  return false;
}
document.addEventListener("keydown", e => {
  if (document.body.dataset.view !== "quiz" || !qrun || e.target.closest("input, textarea") || e.altKey || e.ctrlKey || e.metaKey) return;
  if (!qrun.answered && /^[1-4]$/.test(e.key) && app.querySelector("[data-qa]")) { e.preventDefault(); answerQuiz(Number(e.key) - 1); }
  else if (qrun.answered && e.key === "Enter" && e.target === document.body) { const b = app.querySelector("[data-qnext]"); if (b && !b.hidden) { e.preventDefault(); b.click(); } }
});
