// The one test runner: every `tests/test_*.py` and `tests/test_*.sh`, one after the other (one worker, below the
// 8-worker cap of common/local-cpu-budget.md), at lowered priority, inside ONE owned run folder.
//
//   node tests/run.mjs                              every test file
//   node tests/run.mjs tests/test_verdict.py        only the named files (a name that matches no file is an error)
//
// Order of work (common/test-leftovers.md): lower the priority FIRST, so every child inherits it; sweep what a killed run of
// this user left; claim and create the run folder; run; then, in `finally`, kill the stub containers a test recorded and
// remove the folder. The sweep never changes the exit code. Every child is started from an argv array, never a shell string,
// and has a ceiling; a child past it is killed with its whole process group AND its whole session (the children of `timeout`, such as
// every stub call, have a process group of their own but share the session). SIGINT, SIGTERM and SIGHUP end the current child's
// process group and session, kill the recorded stub pids, remove the run folder and exit 130, 143 and 129.
//
// A process cap (2026-11-02: a test shim that exec'd itself forked about 15,900 processes and crashed the session): every test file runs under
// `ulimit -u <cap>`, the cap being the user's thread count at the start of the run (Linux counts THREADS of the whole user against RLIMIT_NPROC) plus
// R9700_TEST_NPROC_HEADROOM (default 3000). The runner also watches the file's session: when its threads come within 10 % of the headroom it reports
// `process cap reached (<cap>): a test forks without end`, ends the whole session (stopped first, then killed, round after round) and the file FAILS. Only
// the file's own session is ever signalled.
//
// Test knobs: R9700_TEST_NPROC_HEADROOM (the headroom, whole number from 100); R9700_RUNNER_TESTS_DIR names another folder to discover `test_*.py` and `test_*.sh` in (the runner's own test
// uses it, so a signal test never has to put a sleeping file into tests/); R9700_RUNNER_CEILING_MS replaces the 10-minute ceiling of one
// test file (the runner's own test uses it to reach the ceiling in seconds).

await import("./lib/lower-priority.mjs");

const { spawn } = await import("node:child_process");
const fs = await import("node:fs");
const path = await import("node:path");
const { fileURLToPath } = await import("node:url");
const { sweepLeftovers } = await import("../tools/lib/leftovers-sweep.mjs");
const { cleanupScope, isAskablePid, ownedDir } = await import("../tools/lib/owned.mjs");

const TESTS = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.dirname(TESTS);
const FILE_CEILING_MS = Number(process.env.R9700_RUNNER_CEILING_MS) || 10 * 60_000; // test knob: the runner's own test shortens it
const KILL_GRACE_MS = 2_000;
const PID_FOLDER = "containers"; // scenario A4: a stub container records its pid in `<test root>/containers/<name>.pid`

const HEADROOM_DEFAULT = 3000;
const CAP_POLL_MS = 400;
const EXIT_CAP = 125; // a file ended by the process cap

/** Field `index` (0 = the state) of /proc/<pid>/stat after the command name, or undefined. */
function statField(pid, index) {
  try {
    const stat = fs.readFileSync(`/proc/${pid}/stat`, "utf8");
    return stat.slice(stat.lastIndexOf(")") + 2).split(" ")[index];
  } catch {
    return undefined;
  }
}

/** The threads of every process of this user (what RLIMIT_NPROC counts: `ps -L -u <uid> | wc -l`). */
function userThreads() {
  let total = 0;
  const uid = process.getuid();
  for (const name of fs.readdirSync("/proc")) {
    if (!/^[0-9]+$/.test(name)) continue;
    try {
      if (fs.statSync(`/proc/${name}`).uid !== uid) continue;
    } catch {
      continue;
    }
    total += Number(statField(name, 17)) || 0;
  }
  return total;
}

/** The threads of one session (the child's own: it is spawned `detached`, so its session id is its pid). */
function sessionThreads(sid) {
  let total = 0;
  for (const pid of sessionPids(sid)) total += Number(statField(pid, 17)) || 0;
  return total;
}

/** The hard limit on processes of this process, or Infinity: a cap above it cannot be set. */
function hardProcessLimit() {
  try {
    const line = fs.readFileSync("/proc/self/limits", "utf8").split("\n").find((l) => l.startsWith("Max processes"));
    const hard = line?.trim().split(/\s+/).at(-2);
    return /^[0-9]+$/.test(hard ?? "") ? Number(hard) : Infinity;
  } catch {
    return Infinity;
  }
}

/** {cap, headroom} of this run: the user's threads now plus the headroom, never above the hard limit. Throws a message for a bad headroom. */
function processCap(env = process.env) {
  const raw = env.R9700_TEST_NPROC_HEADROOM ?? String(HEADROOM_DEFAULT);
  if (!/^[0-9]+$/.test(raw) || Number(raw) < 100) throw new Error(`R9700_TEST_NPROC_HEADROOM "${raw}" is not a whole number from 100`);
  const headroom = Number(raw);
  return { cap: Math.min(userThreads() + headroom, hardProcessLimit()), headroom };
}

/** Stop, then kill, every process of a session, round after round until none is left (a fork loop keeps making members while it is being killed). */
function killSessionHard(sid, ticks) {
  for (let round = 0; round < 60; round++) {
    if (leaderIsForeign(sid, ticks)) return;
    const members = sessionPids(sid);
    if (members.length === 0) return;
    for (const signal of ["SIGSTOP", "SIGKILL"]) {
      for (const pid of members) {
        try { process.kill(pid, signal); } catch { /* gone */ }
      }
    }
  }
}

/** `test_*.py` and `test_*.sh` of a folder, sorted, as paths the runner resolves against the repository root (never typed: derived by listing). */
function discoverTests(testsDir = process.env.R9700_RUNNER_TESTS_DIR ?? TESTS) {
  const shown = path.resolve(testsDir) === TESTS ? "tests" : path.resolve(testsDir);
  return fs.readdirSync(testsDir)
    .filter((name) => /^test_.+\.(py|sh)$/.test(name))
    .sort()
    .map((name) => path.join(shown, name));
}

/** The files a command line asks for: all of them without arguments; else each argument must name one discovered file. */
function selectTests(all, args, cwd = process.cwd(), repo = REPO) {
  if (args.length === 0) return { files: all, unknown: [] };
  const absolute = (file) => path.resolve(repo, file);
  const wanted = args.map((arg) => path.resolve(cwd, arg));
  return {
    files: all.filter((file) => wanted.includes(absolute(file))),
    unknown: wanted.filter((file) => !all.some((known) => absolute(known) === file)).map((file) => path.relative(repo, file)),
  };
}

function printSweep(result) {
  for (const entry of result.removed) console.log(`leftovers: removed ${typeof entry === "string" ? entry : JSON.stringify(entry)}`);
  for (const entry of result.preserved) console.log(`leftovers: preserved ${entry.path ?? JSON.stringify(entry)} (${entry.reason ?? "kept"})`);
  for (const line of result.listed) console.log(`leftovers: listed ${line}`);
  for (const line of result.errors) console.log(`leftovers: error ${line}`);
}

// What a signal handler needs to end the run: the current child, whether it has closed, and the run folder.
const live = { child: null, ticks: undefined, closed: null, run: null, scope: null, stopping: false };

/** Run one child to its end or its ceiling; resolves with `{ code, signal }` (code `124` for a ceiling, `127` when it could not start; `signal` when the child was ended by one). */
function runChild(command, args, env, ceilingMs = FILE_CEILING_MS, limits = null) {
  return new Promise((resolve) => {
    // under `ulimit -u <cap>`: the wrapper sets the limit and replaces itself by the test command (the cap is for this file and everything it starts)
    const wrapped = limits ? ["-c", 'ulimit -u "$1" || exit 126; shift; exec "$@"', "_", String(limits.cap), command, ...args] : args;
    const child = spawn(limits ? "bash" : command, wrapped, { cwd: REPO, env, stdio: "inherit", detached: true });
    let settled = false;
    let timedOut = false;
    let markClosed;
    const ticks = startTicks(child.pid); // recorded at spawn: a kill by pid, group or session later must still be about THIS child
    live.child = child;
    live.ticks = ticks;
    live.closed = new Promise((done) => { markClosed = done; });
    let capHit = false;
    const finish = (code, signal = null) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      clearInterval(watcher);
      resolve({ code, signal, pid: child.pid, ticks, capHit });
    };
    const watcher = limits ? setInterval(() => {
      if (settled || capHit || sessionThreads(child.pid) < limits.headroom * 0.9) return;
      capHit = true;
      console.log(`  process cap reached (${limits.cap}): a test forks without end`);
      killSessionHard(child.pid, ticks);
      finish(EXIT_CAP);
    }, CAP_POLL_MS) : null;
    const timer = setTimeout(() => {
      timedOut = true;
      console.log(`  ceiling of ${ceilingMs / 1000} s reached: ending the process group of ${path.basename(args.at(-1))}`);
      killGroup(child.pid, "SIGTERM", ticks);
      killSession(child.pid, "SIGTERM", ticks);
      setTimeout(() => { killGroup(child.pid, "SIGKILL", ticks); killSession(child.pid, "SIGKILL", ticks); finish(124); }, KILL_GRACE_MS); // the group and the session, even when the leader is already gone
    }, ceilingMs);
    child.on("error", (error) => { console.log(`  could not start ${command}: ${error.code ?? error.message}`); markClosed(); finish(127); });
    child.on("close", (code, signal) => { live.child = null; markClosed(); if (!timedOut && !capHit) finish(code, signal); });
  });
}

/** The pids of every process whose session id (field 6 of /proc/<pid>/stat, read after the LAST `)`) is `sid`. A child is spawned with
 *  `detached: true`, so its session id is its own pid and everything it started stays in that session unless it called `setsid`. GNU
 *  `timeout` calls setpgid (a new process group, the same session): its children, such as every stub call, are outside the child's
 *  process group but inside its session. */
function sessionPids(sid) {
  const found = [];
  let names;
  try {
    names = fs.readdirSync("/proc");
  } catch {
    return found;
  }
  for (const name of names) {
    if (!/^[0-9]+$/.test(name)) continue;
    let stat;
    try {
      stat = fs.readFileSync(`/proc/${name}/stat`, "utf8");
    } catch {
      continue;
    }
    if (stat.slice(stat.lastIndexOf(")") + 2).split(" ")[3] === String(sid)) found.push(Number(name));
  }
  return found;
}

/** True when `pid` is NOT a process we may signal as the leader we spawned: a process with that pid exists and its start ticks are not the
 *  recorded ones (the pid was reused), or one exists and nothing was recorded (unknown). No process with that pid is the normal case of a
 *  leader that has ended: its pid cannot be reused while a group or a session still carries it as its id. */
function leaderIsForeign(pid, ticks) {
  const now = startTicks(pid);
  return now !== undefined && now !== ticks;
}

function killSession(sid, signal, ticks) {
  if (leaderIsForeign(sid, ticks)) return;
  for (const pid of sessionPids(sid)) {
    try {
      process.kill(pid, signal);
    } catch (error) {
      if (error?.code !== "ESRCH") console.log(`  kill ${signal} of pid ${pid} (session ${sid}) failed: ${error?.code ?? error}`);
    }
  }
}

function killGroup(pid, signal, ticks) {
  if (leaderIsForeign(pid, ticks)) return;
  try {
    process.kill(-pid, signal);
  } catch (error) {
    if (error?.code !== "ESRCH") console.log(`  kill ${signal} of group ${pid} failed: ${error?.code ?? error}`);
  }
}

/** An interrupt (a signal, or a closed output pipe) ends the run: the child's group, the recorded stub pids, the run folder, then the exit code. */
async function endRun(reason, code, { quiet = false } = {}) {
  if (live.stopping) process.exit(code); // a second signal: no more waiting
  live.stopping = true;
  if (!quiet) console.log(`run: interrupted (${reason}): ending the current test file and removing the run folder`);
  const { child, ticks } = { child: live.child, ticks: live.ticks }; // the close handler clears live.child while this waits
  if (child?.pid) {
    killGroup(child.pid, "SIGTERM", ticks);
    killSession(child.pid, "SIGTERM", ticks);
    await Promise.race([live.closed, new Promise((done) => setTimeout(done, KILL_GRACE_MS))]);
    killGroup(child.pid, "SIGKILL", ticks); // stragglers of the group
    killSession(child.pid, "SIGKILL", ticks); // and of the session: the children of `timeout` have a group of their own
  }
  if (live.run) killRecordedPids(live.run);
  if (live.scope) await live.scope.close();
  process.exit(code);
}

// A closed pipe (`node tests/run.mjs | head -3`) is an interrupt like a signal: without a handler the first write to it is an unhandled
// error event that skips every cleanup. The output is gone, so the run says nothing more; exit 141 is 128 + SIGPIPE.
const EXIT_PIPE = 141;
function onOutputError(error) {
  if (live.stopping) return; // the cleanup is already under way; its own writes fail the same way
  void endRun("closed output", error?.code === "EPIPE" ? EXIT_PIPE : 1, { quiet: true });
}
process.stdout.on("error", onOutputError);
process.stderr.on("error", onOutputError);

for (const [signal, code] of [["SIGINT", 130], ["SIGTERM", 143], ["SIGHUP", 129]]) process.on(signal, () => { void endRun(signal, code); });

/** Every `*.pid` file in a folder named `containers` anywhere under `root`. */
function recordedPidFiles(root) {
  const found = [];
  const visit = (dir) => {
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) visit(full);
      else if (entry.isFile() && path.basename(dir) === PID_FOLDER && entry.name.endsWith(".pid")) found.push(full);
    }
  };
  visit(root);
  return found;
}

/** Field 22 of /proc/<pid>/stat (the start time in clock ticks), read after the LAST `)` because the command name may hold one. */
function startTicks(pid) {
  try {
    const stat = fs.readFileSync(`/proc/${pid}/stat`, "utf8");
    return stat.slice(stat.lastIndexOf(")") + 2).split(" ")[19];
  } catch {
    return undefined;
  }
}

/** Scenario A4: stub containers are outside every process group by design, so the runner kills each recorded process before it removes the folder.
 *  A record is `<pid> <start ticks>`; the pid is killed only while that pid still has those start ticks (it is then the same process, never a reused pid). */
function killRecordedPids(root) {
  const killed = [];
  for (const file of recordedPidFiles(root)) {
    let text;
    try {
      text = fs.readFileSync(file, "utf8").trim();
    } catch {
      continue;
    }
    const [pid, ticks, ...extra] = text.split(/\s+/);
    if (!isAskablePid(pid) || !/^[0-9]+$/.test(ticks ?? "") || extra.length > 0) {
      console.log(`  recorded pid file ${path.relative(root, file)} is not "<pid> <start ticks>"; left alone`);
      continue;
    }
    if (startTicks(pid) !== ticks) continue; // gone, or a different process by now
    try {
      process.kill(Number(pid), "SIGKILL");
      killed.push(Number(pid));
    } catch (error) {
      if (error?.code !== "ESRCH") console.log(`  kill of recorded pid ${pid} (${path.relative(root, file)}) failed: ${error?.code ?? error}`);
    }
  }
  return killed;
}

function pythonCommand() {
  const venv = path.join(REPO, ".venv", "bin", "python");
  return fs.existsSync(venv) ? venv : "python3";
}

/** The command line, environment and folders of one test file inside the run folder. */
function plan(file, run) {
  const stem = path.basename(file).replace(/\.[^.]+$/, "");
  const env = { ...process.env, PYTHONDONTWRITEBYTECODE: "1" };
  if (file.endsWith(".py")) {
    return { command: pythonCommand(), args: ["-m", "pytest", "-q", "-p", "no:cacheprovider", "--basetemp", path.join(run, "pytest", stem), file], env, make: [path.join(run, "pytest")] };
  }
  const root = path.join(run, "sh", stem);
  return { command: "bash", args: [file], env: { ...env, R9700_TEST_ROOT: root }, make: [path.join(run, "sh"), root] };
}

async function runFiles(files, run, limits) {
  const failed = [];
  for (const file of files) {
    if (live.stopping) break;
    const step = plan(file, run);
    for (const dir of step.make) fs.mkdirSync(dir, { recursive: true });
    const { code, signal, pid, ticks, capHit } = await runChild(step.command, step.args, step.env, FILE_CEILING_MS, limits);
    killSession(pid, "SIGKILL", ticks); // whatever the file left in its session (a passing file may leave a disowned subshell too)
    if (live.stopping) break; // an interrupt: the file was ended on purpose; no verdict line, no summary
    const how = capHit ? `process cap reached (${limits.cap})` : signal ? `signal ${signal}` : `exit ${code}`;
    console.log(code === 0 && !signal ? `PASS ${file}` : `FAIL ${file} (${how})`);
    if (code !== 0 || signal) failed.push(file);
  }
  return failed;
}

async function main() {
  printSweep(sweepLeftovers({ repo: REPO }));
  const { files, unknown } = selectTests(discoverTests(), process.argv.slice(2));
  if (unknown.length > 0 || files.length === 0) {
    console.log(`run: no test file matches: ${unknown.join(" ") || "(none discovered)"}`);
    return 2;
  }
  let limits;
  try {
    limits = processCap();
  } catch (error) {
    console.log(`run: ${error.message}`);
    return 2;
  }
  console.log(`run: process cap ${limits.cap} (the user's threads now + a headroom of ${limits.headroom}; R9700_TEST_NPROC_HEADROOM)`);
  const scope = cleanupScope();
  live.scope = scope;
  let failed = [];
  try {
    live.run = ownedDir(scope, "run");
    try {
      failed = await runFiles(files, live.run, limits);
    } finally {
      const killed = killRecordedPids(live.run);
      if (killed.length > 0) console.log(`run: killed ${killed.length} recorded stub pid(s): ${killed.join(" ")}`);
    }
  } finally {
    await scope.close();
  }
  if (live.stopping) return 0; // endRun owns the exit code and the last word
  console.log(`${files.length - failed.length} passed, ${failed.length} failed of ${files.length} test files`);
  return failed.length > 0 ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const code = await main();
  if (!live.stopping) process.exitCode = code;
}

// The runner's own test imports these to check the session kill against a pid that belongs to another process.
export { killSession, startTicks, processCap, userThreads };
