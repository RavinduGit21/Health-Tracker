const STORAGE_KEY = 'health_tracker_v1';
const SUPABASE_URL = 'https://brcqcvlkxxhpantlizdd.supabase.co';
const SUPABASE_KEY = 'sb_publishable_IvESaEOXlfXfaCv4BI04mg_jOIBPe12';

let supabase = null;
if (window.supabase) {
  supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
}

function pad2(n) { return String(n).padStart(2, '0'); }
function toISODateLocal(d) {
  const year = d.getFullYear();
  const month = pad2(d.getMonth() + 1);
  const day = pad2(d.getDate());
  return `${year}-${month}-${day}`;
}

function parseISODateLocal(iso) {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function addDays(isoDate, delta) {
  const d = parseISODateLocal(isoDate);
  d.setDate(d.getDate() + delta);
  return toISODateLocal(d);
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { settings: { waterGoalMl: 2000, challengeStart: '' }, entries: {}, weights: {} };
    const parsed = JSON.parse(raw);
    return {
      settings: {
        waterGoalMl: Number(parsed?.settings?.waterGoalMl ?? 2000),
        challengeStart: String(parsed?.settings?.challengeStart ?? ''),
      },
      entries: parsed?.entries && typeof parsed.entries === 'object' ? parsed.entries : {},
      weights: parsed?.weights && typeof parsed.weights === 'object' ? parsed.weights : {}
    };
  } catch {
    return { settings: { waterGoalMl: 2000, challengeStart: '' }, entries: {}, weights: {} };
  }
}

function saveState(state) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function defaultEntry() {
  return {
    sugarCut: false,
    workoutDone: false,
    caloriesBurned: 100,
    workoutNotes: '',
    notes: '',
    waterMl: 0,
    sugarG: 0,
    logs: [],
    updatedAt: new Date().toISOString()
  };
}

function getEntry(state, isoDate) {
  const existing = state.entries[isoDate];
  if (existing && typeof existing === 'object') {
    return {
      ...defaultEntry(),
      ...existing,
      waterMl: Number(existing.waterMl ?? 0),
      sugarG: Number(existing.sugarG ?? 0),
      caloriesBurned: Number(existing.caloriesBurned ?? 100),
      sugarCut: Boolean(existing.sugarCut),
      workoutDone: Boolean(existing.workoutDone),
      logs: Array.isArray(existing.logs) ? existing.logs : []
    };
  }
  return defaultEntry();
}

function setEntry(state, isoDate, entry) {
  state.entries[isoDate] = {
    ...entry,
    waterMl: Math.max(0, Number(entry.waterMl ?? 0)),
    caloriesBurned: Math.max(0, Number(entry.caloriesBurned ?? 0)),
    updatedAt: new Date().toISOString()
  };
}

function clamp(n, min, max) { return Math.max(min, Math.min(max, n)); }

function downloadJSON(filename, obj) {
  const blob = new Blob([JSON.stringify(obj, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

function formatYesNo(v) { return v ? 'Yes' : 'No'; }

function computeSugarStreak(state, asOfDate) {
  let count = 0;
  let cursor = asOfDate;
  while (true) {
    const e = getEntry(state, cursor);
    if (!e.sugarCut) break;
    count++;
    cursor = addDays(cursor, -1);
    if (count > 3650) break;
  }
  return count;
}

function getLastNDates(endIso, n) {
  const dates = [];
  for (let i = n - 1; i >= 0; i--) {
    dates.push(addDays(endIso, -i));
  }
  return dates;
}

function computeLast7Summary(state, endIso) {
  const dates = getLastNDates(endIso, 7);
  let workoutDays = 0;
  let totalWater = 0;
  let totalCalories = 0;
  for (const d of dates) {
    const e = getEntry(state, d);
    if (e.workoutDone) workoutDays++;
    totalWater += Number(e.waterMl ?? 0);
    totalCalories += e.workoutDone ? Number(e.caloriesBurned ?? 0) : 0;
  }
  return {
    dates,
    workoutDays,
    avgWater: Math.round(totalWater / 7),
    avgCalories: Math.round(totalCalories / 7)
  };
}

function getWeightsSorted(state) {
  const keys = Object.keys(state.weights || {}).filter(k => /^\d{4}-\d{2}-\d{2}$/.test(k));
  keys.sort();
  return keys.map(k => ({ date: k, kg: Number(state.weights[k]) })).filter(x => Number.isFinite(x.kg));
}

function setWeight(state, isoDate, kg) {
  if (!state.weights || typeof state.weights !== 'object') state.weights = {};
  state.weights[isoDate] = Number(kg);
}

function deleteWeight(state, isoDate) {
  if (state.weights && state.weights[isoDate]) {
    delete state.weights[isoDate];
    return true;
  }
  return false;
}

function computeChallengeProgress(state, asOfIso) {
  const start = state.settings.challengeStart;
  if (!start) return { active: false, dayIndex: 0, completedDays: 0, targetDays: 7 };

  const diffMs = parseISODateLocal(asOfIso) - parseISODateLocal(start);
  const diffDays = Math.floor(diffMs / (24 * 60 * 60 * 1000));
  const dayIndex = diffDays + 1;

  const targetDays = 7;
  const effectiveDays = clamp(dayIndex, 0, targetDays);

  let completedDays = 0;
  for (let i = 0; i < effectiveDays; i++) {
    const d = addDays(start, i);
    const e = getEntry(state, d);
    if (e.sugarCut) completedDays++;
  }

  return { active: true, dayIndex, completedDays, targetDays };
}

// UI Elements
const els = {
  dateInput: document.getElementById('dateInput'),
  todayBtn: document.getElementById('todayBtn'),
  localTimeText: document.getElementById('localTimeText'),
  challengeStartInput: document.getElementById('challengeStartInput'),
  sugarCutInput: document.getElementById('sugarCutInput'),
  workoutDoneInput: document.getElementById('workoutDoneInput'),
  caloriesBurnedInput: document.getElementById('caloriesBurnedInput'),
  workoutNotesInput: document.getElementById('workoutNotesInput'),
  notesInput: document.getElementById('notesInput'),
  deleteDayBtn: document.getElementById('deleteDayBtn'),
  moveCopyDateInput: document.getElementById('moveCopyDateInput'),
  copyDayBtn: document.getElementById('copyDayBtn'),
  moveDayBtn: document.getElementById('moveDayBtn'),
  waterTotal: document.getElementById('waterTotal'),
  waterGoalInput: document.getElementById('waterGoalInput'),
  waterGoalHint: document.getElementById('waterGoalHint'),
  waterProgressBar: document.getElementById('waterProgressBar'),
  waterProgressText: document.getElementById('waterProgressText'),
  waterRemainingText: document.getElementById('waterRemainingText'),
  add250Btn: document.getElementById('add250Btn'),
  add500Btn: document.getElementById('add500Btn'),
  add1000Btn: document.getElementById('add1000Btn'),
  clearWaterBtn: document.getElementById('clearWaterBtn'),
  saveBtn: document.getElementById('saveBtn'),
  saveStatus: document.getElementById('saveStatus'),
  sugarStreakValue: document.getElementById('sugarStreakValue'),
  sugarStreakSub: document.getElementById('sugarStreakSub'),
  workoutCountValue: document.getElementById('workoutCountValue'),
  avgWaterValue: document.getElementById('avgWaterValue'),
  last7Body: document.getElementById('last7Body'),
  exportPdfBtn: document.getElementById('exportPdfBtn'),
  exportBtn: document.getElementById('exportBtn'),
  loginBtn: document.getElementById('loginBtn'),
  logoutBtn: document.getElementById('logoutBtn'),
  emailInput: document.getElementById('emailInput'),
  passwordInput: document.getElementById('passwordInput'),
  authSection: document.getElementById('authSection'),
  userSection: document.getElementById('userSection'),
  userEmail: document.getElementById('userEmail'),

  tabs: Array.from(document.querySelectorAll('[data-tab]')),
  panels: Array.from(document.querySelectorAll('[data-panel]')),

  weightDateInput: document.getElementById('weightDateInput'),
  weightKgInput: document.getElementById('weightKgInput'),
  saveWeightBtn: document.getElementById('saveWeightBtn'),
  weightStatus: document.getElementById('weightStatus'),
  weightChart: document.getElementById('weightChart'),
  weightLatestValue: document.getElementById('weightLatestValue'),
  weightLatestSub: document.getElementById('weightLatestSub'),
  weightChangeValue: document.getElementById('weightChangeValue'),
  weightEntriesValue: document.getElementById('weightEntriesValue'),
  weightBody: document.getElementById('weightBody')
};

let state = loadState();
let selectedDate = toISODateLocal(new Date());
let weightChartInstance = null;

async function syncRemote() {
  if (!supabase) return;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  try {
    // 1. Sync Settings
    const { data: settings } = await supabase.from('user_settings').select().eq('user_id', user.id).maybeSingle();
    if (settings) {
      state.settings.waterGoalMl = settings.water_goal;
      state.settings.challengeStart = settings.challenge_start_date;
    }

    // 2. Sync Daily Logs
    const { data: logs } = await supabase.from('daily_logs').select().eq('user_id', user.id);
    if (logs) {
      logs.forEach(l => {
        state.entries[l.date] = {
          waterMl: l.water_intake,
          sugarCut: l.sugar_cut_completed,
          workoutDone: l.workout_done,
          caloriesBurned: l.calories_burned,
          workoutNotes: l.workout_notes,
          notes: l.notes,
          logs: l.entries || [],
          updatedAt: new Date().toISOString()
        };
      });
    }

    // 3. Sync Weights
    const { data: weights } = await supabase.from('weight_logs').select().eq('user_id', user.id);
    if (weights) {
      weights.forEach(w => {
        state.weights[w.date] = w.weight;
      });
    }

    saveState(state);
    renderFormForDate(selectedDate);
    console.log("Cloud sync complete");
  } catch (e) {
    console.error("Sync failed", e);
  }
}

async function login() {
  const email = els.emailInput.value;
  const password = els.passwordInput.value;
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) {
    alert("Login failed: " + error.message);
  } else {
    initAuth();
  }
}

async function logout() {
  await supabase.auth.signOut();
  localStorage.removeItem(STORAGE_KEY);
  location.reload();
}

async function initAuth() {
  if (!supabase) return;
  const { data: { user } } = await supabase.auth.getUser();
  if (user) {
    els.authSection.style.display = 'none';
    els.userSection.style.display = 'flex';
    els.userEmail.textContent = user.email;
    syncRemote();

    // Setup subscriptions
    supabase.channel('any').on('postgres_changes', { event: '*', schema: 'public', table: 'daily_logs' }, syncRemote).subscribe();
    supabase.channel('any2').on('postgres_changes', { event: '*', schema: 'public', table: 'weight_logs' }, syncRemote).subscribe();
    supabase.channel('any3').on('postgres_changes', { event: '*', schema: 'public', table: 'user_settings' }, syncRemote).subscribe();
  }
}

function setStatus(text) {
  els.saveStatus.textContent = text;
  if (text) {
    clearTimeout(setStatus._t);
    setStatus._t = setTimeout(() => { els.saveStatus.textContent = ''; }, 1500);
  }
}

function renderWater(entry) {
  const goal = Math.max(0, Number(state.settings.waterGoalMl ?? 2000));
  const total = Math.max(0, Number(entry.waterMl ?? 0));
  els.waterTotal.textContent = `${total} ml`;
  els.waterGoalHint.textContent = `Goal: ${goal} ml`;

  const pct = goal > 0 ? clamp(Math.round((total / goal) * 100), 0, 999) : 0;
  els.waterProgressBar.style.width = `${clamp(pct, 0, 100)}%`;
  els.waterProgressText.textContent = `${pct}%`;

  const remaining = Math.max(0, goal - total);
  els.waterRemainingText.textContent = `Remaining: ${remaining} ml`;
}

function renderLast7(endIso) {
  const summary = computeLast7Summary(state, endIso);
  els.workoutCountValue.textContent = String(summary.workoutDays);
  els.avgWaterValue.textContent = String(summary.avgWater);

  els.last7Body.innerHTML = '';
  for (const d of summary.dates) {
    const e = getEntry(state, d);
    const calories = e.workoutDone ? Number(e.caloriesBurned ?? 0) : 0;
    const tr = document.createElement('tr');
    tr.className = 'clickable-row';
    tr.dataset.date = d;
    tr.innerHTML = `
            <td>${d}</td>
            <td>${formatYesNo(e.sugarCut)}</td>
            <td>${formatYesNo(e.workoutDone)}</td>
            <td>${calories}</td>
            <td>${Number(e.waterMl ?? 0)}</td>
            <td><button class="btn btn-secondary btn-mini" type="button" data-edit-date="${d}">Edit</button></td>
        `;
    els.last7Body.appendChild(tr);
  }
}

function syncCaloriesUi(entry) {
  const workout = Boolean(entry.workoutDone);
  els.caloriesBurnedInput.disabled = !workout;
  if (!workout) {
    els.caloriesBurnedInput.value = '0';
    return;
  }
  const current = Number(els.caloriesBurnedInput.value || entry.caloriesBurned || 0);
  els.caloriesBurnedInput.value = String(current > 0 ? current : 100);
}

function renderWeights() {
  const weights = getWeightsSorted(state);
  if (weights.length === 0) {
    els.weightLatestValue.textContent = '—';
    els.weightBody.innerHTML = '';
    renderWeightChart([]);
    return;
  }
  const latest = weights[weights.length - 1];
  els.weightLatestValue.textContent = String(latest.kg);
  els.weightBody.innerHTML = '';
  for (const w of weights.slice().reverse()) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${w.date}</td><td>${w.kg}</td><td style="text-align:right"><button class="btn btn-secondary btn-mini" onclick="loadWeightToForm('${w.date}', ${w.kg})">Edit</button></td>`;
    els.weightBody.appendChild(tr);
  }
  renderWeightChart(weights);
}

function renderWeightChart(weights) {
  if (!els.weightChart) return;
  if (!weightChartInstance) {
    const ctx = els.weightChart.getContext('2d');
    weightChartInstance = new Chart(ctx, {
      type: 'line',
      data: { labels: [], datasets: [{ label: 'Weight (kg)', data: [], borderColor: '#7c3aed', tension: 0.3 }] },
      options: { responsive: true, maintainAspectRatio: false }
    });
  }
  weightChartInstance.data.labels = weights.map(w => w.date);
  weightChartInstance.data.datasets[0].data = weights.map(w => w.kg);
  weightChartInstance.update();
}

function renderSugarProgress(asOfIso) {
  const streak = computeSugarStreak(state, asOfIso);
  els.sugarStreakValue.textContent = String(streak);
  const ch = computeChallengeProgress(state, asOfIso);
  els.sugarStreakSub.textContent = ch.active ? `days (Challenge: Day ${ch.dayIndex}/7)` : 'days';
}

function renderFormForDate(isoDate) {
  selectedDate = isoDate;
  const entry = getEntry(state, selectedDate);
  els.dateInput.value = selectedDate;
  els.sugarCutInput.checked = Boolean(entry.sugarCut);
  els.workoutDoneInput.checked = Boolean(entry.workoutDone);
  els.caloriesBurnedInput.value = String(entry.caloriesBurned);
  els.workoutNotesInput.value = entry.workoutNotes ?? '';
  els.notesInput.value = entry.notes ?? '';
  els.waterGoalInput.value = String(state.settings.waterGoalMl ?? 2000);
  els.challengeStartInput.value = state.settings.challengeStart || '';
  renderWater(entry);
  renderSugarProgress(selectedDate);
  renderLast7(selectedDate);
  renderWeights();
}

async function persistCurrentForm() {
  const entry = getEntry(state, selectedDate);
  entry.sugarCut = els.sugarCutInput.checked;
  entry.workoutDone = els.workoutDoneInput.checked;
  entry.caloriesBurned = entry.workoutDone ? Number(els.caloriesBurnedInput.value || 0) : 0;
  entry.workoutNotes = els.workoutNotesInput.value;
  entry.notes = els.notesInput.value;
  setEntry(state, selectedDate, entry);

  state.settings.waterGoalMl = Number(els.waterGoalInput.value);
  state.settings.challengeStart = els.challengeStartInput.value;

  saveState(state);
  setStatus('Saved locally...');

  // Cloud Save
  if (supabase) {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      try {
        // 1. Save Settings
        await supabase.from('user_settings').upsert({
          user_id: user.id,
          water_goal: state.settings.waterGoalMl,
          challenge_start_date: state.settings.challengeStart
        });
        // 2. Save Daily Log
        await supabase.from('daily_logs').upsert({
          user_id: user.id,
          date: selectedDate,
          water_intake: entry.waterMl,
          sugar_cut_completed: entry.sugarCut,
          workout_done: entry.workoutDone,
          calories_burned: entry.caloriesBurned,
          workout_notes: entry.workoutNotes,
          notes: entry.notes
        });
        setStatus('Synced to Cloud');
      } catch (e) {
        console.error(e);
        setStatus('Local only (Cloud error)');
      }
    }
  }
  renderFormForDate(selectedDate);
}

// Event Listeners
els.dateInput.onchange = () => renderFormForDate(els.dateInput.value);
els.todayBtn.onclick = () => renderFormForDate(toISODateLocal(new Date()));
els.saveBtn.onclick = persistCurrentForm;
els.loginBtn.onclick = login;
els.logoutBtn.onclick = logout;

// Tabs
els.tabs.forEach(t => {
  t.onclick = () => {
    els.tabs.forEach(tx => tx.classList.toggle('is-active', tx === t));
    els.panels.forEach(p => p.hidden = p.dataset.panel !== t.dataset.tab);
  };
});

// Water
els.add250Btn.onclick = () => { addWater(250); };
els.add500Btn.onclick = () => { addWater(500); };
els.add1000Btn.onclick = () => { addWater(1000); };
els.clearWaterBtn.onclick = () => {
  const entry = getEntry(state, selectedDate);
  entry.waterMl = 0;
  persistCurrentForm();
};

function addWater(delta) {
  const entry = getEntry(state, selectedDate);
  entry.waterMl += delta;
  persistCurrentForm();
}

// Weight
els.saveWeightBtn.onclick = async () => {
  const date = els.weightDateInput.value;
  const kg = Number(els.weightKgInput.value);
  if (!date || !kg) return;
  state.weights[date] = kg;
  saveState(state);
  if (supabase) {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      await supabase.from('weight_logs').upsert({ user_id: user.id, date, weight: kg });
    }
  }
  renderWeights();
  els.weightStatus.textContent = 'Weight logged!';
};

function loadWeightToForm(date, kg) {
  els.weightDateInput.value = date;
  els.weightKgInput.value = kg;
}

// Init
setInterval(() => {
  els.localTimeText.textContent = new Date().toLocaleTimeString();
}, 1000);

initAuth();
renderFormForDate(selectedDate);
