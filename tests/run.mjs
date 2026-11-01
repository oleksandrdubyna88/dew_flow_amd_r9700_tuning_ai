// The one test runner: every `tests/test_*.py` and `tests/test_*.sh`, one after the other (one worker, below the
// 8-worker cap of common/local-cpu-budget.md), at lowered priority, inside ONE owned run folder.
//
//   node tests/run.mjs                              every test file
//   node tests/run.mjs tests/test_verdict.py        only the named files (a name that matches no file is an error)
//
// Order of work (common/test-leftovers.md): lower the priority FIRST, so every child inherits it; sweep what a killed run of
// this user left; claim and create the run folder; run; then, in `finally`, kill the stub containers a test recorded and
// remove the folder. The sweep never changes the exit code. Every child is started from an argv array, never a shell string,
// and has a ceiling; a child past it is killed with its whole process group. SIGINT, SIGTERM and SIGHUP end the current
// child's process group, kill the recorded stub pids, remove the run folder and exit 130, 143 and 129.
//
// Test knob: R9700_RUNNER_TESTS_DIR names another folder to discover `test_*.py` and `test_*.sh` in (the runner's own test
// uses it, so a signal test never has to put a sleeping file into tests/).

await import("./lib/lower-priority.mjs");

const { spawn } = await import("node:child_process");
const fs = await import("node:fs");
const path = await import("node:path");
const { fileURLToPath } = await import("node:url");
const { sweepLeftovers } = await import("../tools/lib/leftovers-sweep.mjs");
const { cleanupScope, isAskablePid, ownedDir } = await import("../tools/lib/owned.mjs");

const TESTS = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.dirname(TESTS);
const FILE_CEILING_MS = 10 * 60_000;
const KILL_GRACE_MS = 2_000;
const PID_FOLDER = "containers"; // scenario A4: a stub container records its pid in `<test root>/containers/<name>.pid`

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
const live = { child: null, closed: null, run: null, scope: null, stopping: false };

/** Run one child to its end or its ceiling; resolves with `{ code, signal }` (code `124` for a ceiling, `127` when it could not start; `signal` when the child was ended by one). */
function runChild(command, args, env, ceilingMs = FILE_CEILING_MS) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { cwd: REPO, env, stdio: "inherit", detached: true });
    let settled = false;
    let timedOut = false;
    let markClosed;
    live.child = child;
    live.closed = new Promise((done) => { markClosed = done; });
    const finish = (code, signal = null) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve({ code, signal });
    };
    const timer = setTimeout(() => {
      timedOut = true;
      console.log(`  ceiling of ${ceilingMs / 1000} s reached: ending the process group of ${path.basename(args.at(-1))}`);
      killGroup(child.pid, "SIGTERM");
      setTimeout(() => { killGroup(child.pid, "SIGKILL"); finish(124); }, KILL_GRACE_MS); // the group, even when its leader is already gone
    }, ceilingMs);
    child.on("error", (error) => { console.log(`  could not start ${command}: ${error.code ?? error.message}`); markClosed(); finish(127); });
    child.on("close", (code, signal) => { markClosed(); if (!timedOut) finish(code, signal); });
  });
}

function killGroup(pid, signal) {
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
  if (live.child?.pid) {
    killGroup(live.child.pid, "SIGTERM");
    await Promise.race([live.closed, new Promise((done) => setTimeout(done, KILL_GRACE_MS))]);
    killGroup(live.child.pid, "SIGKILL"); // stragglers of the group
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

async function runFiles(files, run) {
  const failed = [];
  for (const file of files) {
    if (live.stopping) break;
    const step = plan(file, run);
    for (const dir of step.make) fs.mkdirSync(dir, { recursive: true });
    const { code, signal } = await runChild(step.command, step.args, step.env);
    if (live.stopping) break; // an interrupt: the file was ended on purpose; no verdict line, no summary
    const how = signal ? `signal ${signal}` : `exit ${code}`;
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
  const scope = cleanupScope();
  live.scope = scope;
  let failed = [];
  try {
    live.run = ownedDir(scope, "run");
    try {
      failed = await runFiles(files, live.run);
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
