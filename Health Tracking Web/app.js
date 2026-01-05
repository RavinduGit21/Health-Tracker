const STORAGE_KEY = 'health_tracker_v1';

function pad2(n){ return String(n).padStart(2,'0'); }
function toISODateLocal(d){
  const year = d.getFullYear();
  const month = pad2(d.getMonth() + 1);
  const day = pad2(d.getDate());
  return `${year}-${month}-${day}`;
}

function parseISODateLocal(iso){
  const [y,m,d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function addDays(isoDate, delta){
  const d = parseISODateLocal(isoDate);
  d.setDate(d.getDate() + delta);
  return toISODateLocal(d);
}

function loadState(){
  try{
    const raw = localStorage.getItem(STORAGE_KEY);
    if(!raw) return { settings: { waterGoalMl: 2000, challengeStart: '' }, entries: {}, weights: {} };
    const parsed = JSON.parse(raw);
    return {
      settings: {
        waterGoalMl: Number(parsed?.settings?.waterGoalMl ?? 2000),
        challengeStart: String(parsed?.settings?.challengeStart ?? ''),
      },
      entries: parsed?.entries && typeof parsed.entries === 'object' ? parsed.entries : {},
      weights: parsed?.weights && typeof parsed.weights === 'object' ? parsed.weights : {}
    };
  }catch{
    return { settings: { waterGoalMl: 2000, challengeStart: '' }, entries: {}, weights: {} };
  }
}

function saveState(state){
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function defaultEntry(){
  return {
    sugarCut: false,
    workoutDone: false,
    caloriesBurned: 100,
    workoutNotes: '',
    notes: '',
    waterMl: 0,
    updatedAt: new Date().toISOString()
  };
}

function getEntry(state, isoDate){
  const existing = state.entries[isoDate];
  if(existing && typeof existing === 'object'){
    return {
      ...defaultEntry(),
      ...existing,
      waterMl: Number(existing.waterMl ?? 0),
      caloriesBurned: Number(existing.caloriesBurned ?? 100),
      sugarCut: Boolean(existing.sugarCut),
      workoutDone: Boolean(existing.workoutDone),
    };
  }
  return defaultEntry();
}

function setEntry(state, isoDate, entry){
  state.entries[isoDate] = {
    ...entry,
    waterMl: Math.max(0, Number(entry.waterMl ?? 0)),
    caloriesBurned: Math.max(0, Number(entry.caloriesBurned ?? 0)),
    updatedAt: new Date().toISOString()
  };
}

function clamp(n, min, max){ return Math.max(min, Math.min(max, n)); }

function downloadJSON(filename, obj){
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

function formatYesNo(v){ return v ? 'Yes' : 'No'; }

function computeSugarStreak(state, asOfDate){
  // Streak counts consecutive sugarCut=true days ending at asOfDate.
  let count = 0;
  let cursor = asOfDate;
  while(true){
    const e = getEntry(state, cursor);
    if(!e.sugarCut) break;
    count++;
    cursor = addDays(cursor, -1);
    if(count > 3650) break;
  }
  return count;
}

function getLastNDates(endIso, n){
  const dates = [];
  for(let i = n - 1; i >= 0; i--){
    dates.push(addDays(endIso, -i));
  }
  return dates;
}

function computeLast7Summary(state, endIso){
  const dates = getLastNDates(endIso, 7);
  let workoutDays = 0;
  let totalWater = 0;
  let totalCalories = 0;
  for(const d of dates){
    const e = getEntry(state, d);
    if(e.workoutDone) workoutDays++;
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

function getWeightsSorted(state){
  const keys = Object.keys(state.weights || {}).filter(k => /^\d{4}-\d{2}-\d{2}$/.test(k));
  keys.sort();
  return keys.map(k => ({ date: k, kg: Number(state.weights[k]) })).filter(x => Number.isFinite(x.kg));
}

function setWeight(state, isoDate, kg){
  if(!state.weights || typeof state.weights !== 'object') state.weights = {};
  state.weights[isoDate] = Number(kg);
}

function computeChallengeProgress(state, asOfIso){
  const start = state.settings.challengeStart;
  if(!start) return { active: false, dayIndex: 0, completedDays: 0, targetDays: 7 };

  const diffMs = parseISODateLocal(asOfIso) - parseISODateLocal(start);
  const diffDays = Math.floor(diffMs / (24*60*60*1000));
  const dayIndex = diffDays + 1; // 1-based

  const targetDays = 7;
  const effectiveDays = clamp(dayIndex, 0, targetDays);

  let completedDays = 0;
  for(let i = 0; i < effectiveDays; i++){
    const d = addDays(start, i);
    const e = getEntry(state, d);
    if(e.sugarCut) completedDays++;
  }

  return {
    active: true,
    dayIndex,
    completedDays,
    targetDays
  };
}

// UI
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
  importFile: document.getElementById('importFile'),
  resetBtn: document.getElementById('resetBtn'),

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

function setStatus(text){
  els.saveStatus.textContent = text;
  if(text){
    clearTimeout(setStatus._t);
    setStatus._t = setTimeout(() => { els.saveStatus.textContent = ''; }, 1500);
  }
}

function renderWater(entry){
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

function renderLast7(endIso){
  const summary = computeLast7Summary(state, endIso);
  els.workoutCountValue.textContent = String(summary.workoutDays);
  els.avgWaterValue.textContent = String(summary.avgWater);

  els.last7Body.innerHTML = '';
  for(const d of summary.dates){
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

function syncCaloriesUi(entry){
  const workout = Boolean(entry.workoutDone);
  els.caloriesBurnedInput.disabled = !workout;
  if(!workout){
    els.caloriesBurnedInput.value = '0';
    return;
  }

  const current = Number(els.caloriesBurnedInput.value || entry.caloriesBurned || 0);
  const normalized = Number.isFinite(current) && current > 0 ? current : 100;
  els.caloriesBurnedInput.value = String(normalized);
}

function renderWeights(){
  const weights = getWeightsSorted(state);
  els.weightEntriesValue.textContent = String(weights.length);

  if(weights.length === 0){
    els.weightLatestValue.textContent = '—';
    els.weightLatestSub.textContent = 'kg';
    els.weightChangeValue.textContent = '—';
    els.weightBody.innerHTML = '';
    renderWeightChart([]);
    return;
  }

  const latest = weights[weights.length - 1];
  const first = weights[0];
  els.weightLatestValue.textContent = String(latest.kg);
  els.weightLatestSub.textContent = `kg (${latest.date})`;
  const change = Math.round((latest.kg - first.kg) * 10) / 10;
  els.weightChangeValue.textContent = String(change);

  els.weightBody.innerHTML = '';
  for(const w of weights.slice().reverse()){
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${w.date}</td>
      <td>${w.kg}</td>
    `;
    els.weightBody.appendChild(tr);
  }

  renderWeightChart(weights);
}

function ensureWeightChart(){
  if(!els.weightChart) return null;
  if(weightChartInstance) return weightChartInstance;
  if(!window.Chart) return null;

  const ctx = els.weightChart.getContext('2d');
  weightChartInstance = new window.Chart(ctx, {
    type: 'line',
    data: {
      labels: [],
      datasets: [
        {
          label: 'Weight loss (kg)',
          data: [],
          borderWidth: 3,
          borderColor: 'rgba(56, 189, 248, 0.95)',
          backgroundColor: 'rgba(56, 189, 248, 0.20)',
          fill: true,
          tension: 0.35,
          pointRadius: 3,
          pointHoverRadius: 5
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: (ctx2) => `Loss: ${ctx2.parsed.y} kg`
          }
        }
      },
      scales: {
        x: {
          ticks: { maxRotation: 0, autoSkip: true },
          grid: { display: false }
        },
        y: {
          beginAtZero: true,
          grid: { color: 'rgba(255,255,255,0.08)' }
        }
      }
    }
  });

  return weightChartInstance;
}

function renderWeightChart(weights){
  const chart = ensureWeightChart();
  if(!chart) return;

  if(!weights || weights.length === 0){
    chart.data.labels = [];
    chart.data.datasets[0].data = [];
    chart.update();
    return;
  }

  const firstKg = weights[0].kg;
  const labels = weights.map(w => w.date);
  const lossSeries = weights.map(w => Math.round((firstKg - w.kg) * 10) / 10);

  chart.data.labels = labels;
  chart.data.datasets[0].data = lossSeries;
  chart.update();
}

function renderSugarProgress(asOfIso){
  const streak = computeSugarStreak(state, asOfIso);
  els.sugarStreakValue.textContent = String(streak);

  const ch = computeChallengeProgress(state, asOfIso);
  if(!ch.active){
    els.sugarStreakSub.textContent = 'days';
    return;
  }

  if(ch.dayIndex <= 0){
    els.sugarStreakSub.textContent = 'days (challenge not started yet)';
    return;
  }

  if(ch.dayIndex > ch.targetDays){
    els.sugarStreakSub.textContent = `days (challenge done: ${ch.completedDays}/${ch.targetDays})`;
    return;
  }

  els.sugarStreakSub.textContent = `days (challenge day ${ch.dayIndex}/7, done ${ch.completedDays}/7)`;
}

function renderFormForDate(isoDate){
  selectedDate = isoDate;
  const entry = getEntry(state, selectedDate);

  els.dateInput.value = selectedDate;

  els.sugarCutInput.checked = Boolean(entry.sugarCut);
  els.workoutDoneInput.checked = Boolean(entry.workoutDone);
  els.caloriesBurnedInput.value = String(entry.workoutDone ? Number(entry.caloriesBurned ?? 0) : 0);
  syncCaloriesUi(entry);
  els.workoutNotesInput.value = entry.workoutNotes ?? '';
  els.notesInput.value = entry.notes ?? '';

  els.waterGoalInput.value = String(state.settings.waterGoalMl ?? 2000);
  els.challengeStartInput.value = state.settings.challengeStart || '';

  renderWater(entry);
  renderSugarProgress(selectedDate);
  renderLast7(selectedDate);
  renderWeights();
}

function persistCurrentForm(){
  const entry = getEntry(state, selectedDate);

  entry.sugarCut = els.sugarCutInput.checked;
  entry.workoutDone = els.workoutDoneInput.checked;
  entry.caloriesBurned = entry.workoutDone ? Number(els.caloriesBurnedInput.value || 0) : 0;
  entry.workoutNotes = els.workoutNotesInput.value;
  entry.notes = els.notesInput.value;

  setEntry(state, selectedDate, entry);

  const waterGoal = Number(els.waterGoalInput.value || 0);
  state.settings.waterGoalMl = Number.isFinite(waterGoal) ? Math.max(0, Math.round(waterGoal)) : 2000;

  const challengeStart = String(els.challengeStartInput.value || '');
  state.settings.challengeStart = challengeStart;

  saveState(state);
  setStatus('Saved');

  renderWater(entry);
  renderSugarProgress(selectedDate);
  renderLast7(selectedDate);
}

function hasDayEntry(state, isoDate){
  return Boolean(state.entries && Object.prototype.hasOwnProperty.call(state.entries, isoDate));
}

function deleteDayEntry(isoDate){
  if(!hasDayEntry(state, isoDate)){
    setStatus('Nothing to delete');
    return;
  }
  const ok = confirm(`Delete saved record for ${isoDate}?`);
  if(!ok) return;
  delete state.entries[isoDate];
  saveState(state);
  renderFormForDate(isoDate);
  setStatus('Deleted');
}

function copyOrMoveDay({ fromDate, toDate, move }){
  if(!fromDate || !toDate){
    setStatus('Pick a date');
    return;
  }
  if(fromDate === toDate){
    setStatus('Same date');
    return;
  }
  if(!hasDayEntry(state, fromDate)){
    setStatus('Nothing to copy');
    return;
  }

  const src = getEntry(state, fromDate);
  const destExists = hasDayEntry(state, toDate);
  if(destExists){
    const okOverwrite = confirm(`A record already exists for ${toDate}. Overwrite it?`);
    if(!okOverwrite) return;
  }

  const next = { ...src };
  next.updatedAt = new Date().toISOString();
  setEntry(state, toDate, next);

  if(move){
    delete state.entries[fromDate];
  }

  saveState(state);
  renderFormForDate(toDate);
  setStatus(move ? 'Moved' : 'Copied');
}

function setWeightStatus(text){
  els.weightStatus.textContent = text;
  if(text){
    clearTimeout(setWeightStatus._t);
    setWeightStatus._t = setTimeout(() => { els.weightStatus.textContent = ''; }, 1500);
  }
}

function saveWeightFromForm(){
  const date = String(els.weightDateInput.value || '');
  const kg = Number(els.weightKgInput.value);
  if(!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)){
    setWeightStatus('Pick a date');
    return;
  }
  if(!Number.isFinite(kg) || kg <= 0){
    setWeightStatus('Enter weight');
    return;
  }

  setWeight(state, date, Math.round(kg * 10) / 10);
  saveState(state);
  renderWeights();
  setWeightStatus('Saved');
}

function setActiveTab(tab){
  for(const b of els.tabs){
    b.classList.toggle('is-active', b.dataset.tab === tab);
  }
  for(const p of els.panels){
    p.hidden = p.dataset.panel !== tab;
  }
}

function exportPdfReport(){
  try{
    const jspdfNS = window.jspdf;
    const JsPDF = jspdfNS?.jsPDF;
    if(!JsPDF) throw new Error('jsPDF not loaded');

    const doc = new JsPDF({ unit: 'pt', format: 'a4' });
    const pageWidth = doc.internal.pageSize.getWidth();

    const generated = toISODateLocal(new Date());
    const summary7 = computeLast7Summary(state, selectedDate);
    const streak = computeSugarStreak(state, selectedDate);
    const ch = computeChallengeProgress(state, selectedDate);
    const weights = getWeightsSorted(state);

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(18);
    doc.text('Personal Health Report', 40, 54);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(11);
    doc.text(`Generated: ${generated}`, 40, 74);
    doc.text(`Report as of: ${selectedDate}`, 40, 90);

    doc.setDrawColor(255);
    doc.setFillColor(124, 58, 237);
    doc.roundedRect(40, 105, pageWidth - 80, 68, 10, 10, 'F');
    doc.setTextColor(255, 255, 255);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.text(`Sugar cut streak: ${streak} days`, 54, 130);
    doc.text(`Workouts (last 7): ${summary7.workoutDays} days`, 54, 148);
    doc.text(`Avg water (last 7): ${summary7.avgWater} ml/day`, 320, 130);
    doc.text(`Avg calories (last 7): ${summary7.avgCalories} kcal/day`, 320, 148);
    doc.setTextColor(0, 0, 0);

    let challengeLine = 'Challenge: not set';
    if(ch.active){
      challengeLine = `7-day sugar challenge start: ${state.settings.challengeStart || '-'} | done: ${ch.completedDays}/7`;
    }
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(11);
    doc.text(challengeLine, 40, 195);

    const dailyRows = summary7.dates.map(d => {
      const e = getEntry(state, d);
      const calories = e.workoutDone ? Number(e.caloriesBurned ?? 0) : 0;
      return [
        d,
        formatYesNo(e.sugarCut),
        formatYesNo(e.workoutDone),
        String(calories),
        String(Number(e.waterMl ?? 0))
      ];
    });

    doc.autoTable({
      startY: 215,
      head: [['Date', 'Sugar', 'Workout', 'Calories', 'Water (ml)']],
      body: dailyRows,
      styles: { font: 'helvetica', fontSize: 10 },
      headStyles: { fillColor: [17, 24, 39] },
      alternateRowStyles: { fillColor: [245, 246, 248] },
      margin: { left: 40, right: 40 }
    });

    const afterDailyY = doc.lastAutoTable?.finalY ? doc.lastAutoTable.finalY + 18 : 470;

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.text('Weight progress', 40, afterDailyY);

    const chart = ensureWeightChart();
    if(chart && els.weightChart){
      // Ensure it is up-to-date for export.
      renderWeightChart(getWeightsSorted(state));
      const chartDataUrl = els.weightChart.toDataURL('image/png', 1.0);
      const imgW = pageWidth - 80;
      const imgH = 180;
      doc.addImage(chartDataUrl, 'PNG', 40, afterDailyY + 10, imgW, imgH);
    }

    const tableStartY = afterDailyY + (chart && els.weightChart ? 210 : 10);

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.text('Weight history', 40, afterDailyY + (chart && els.weightChart ? 205 : 10));

    const weightRows = weights.slice().reverse().map(w => [w.date, String(w.kg)]);
    doc.autoTable({
      startY: afterDailyY + (chart && els.weightChart ? 220 : 20),
      head: [['Date', 'Weight (kg)']],
      body: weightRows.length ? weightRows : [['—', '—']],
      styles: { font: 'helvetica', fontSize: 10 },
      headStyles: { fillColor: [17, 24, 39] },
      alternateRowStyles: { fillColor: [245, 246, 248] },
      margin: { left: 40, right: 40 }
    });

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(9);
    doc.text('Generated by your personal tracker (local data).', 40, doc.internal.pageSize.getHeight() - 30);

    doc.save(`health-report-${selectedDate}.pdf`);
  }catch{
    setStatus('PDF export failed');
  }
}

function addWater(delta){
  const entry = getEntry(state, selectedDate);
  entry.waterMl = Math.max(0, Number(entry.waterMl ?? 0) + delta);
  setEntry(state, selectedDate, entry);
  saveState(state);
  renderWater(entry);
  renderLast7(selectedDate);
}

function clearWater(){
  const entry = getEntry(state, selectedDate);
  entry.waterMl = 0;
  setEntry(state, selectedDate, entry);
  saveState(state);
  renderWater(entry);
  renderLast7(selectedDate);
}

// Events
els.dateInput.addEventListener('change', () => {
  const v = els.dateInput.value;
  if(v) renderFormForDate(v);
});

els.todayBtn.addEventListener('click', () => {
  const today = toISODateLocal(new Date());
  renderFormForDate(today);
});

if(els.deleteDayBtn){
  els.deleteDayBtn.addEventListener('click', () => {
    deleteDayEntry(selectedDate);
  });
}

if(els.copyDayBtn && els.moveCopyDateInput){
  els.copyDayBtn.addEventListener('click', () => {
    const toDate = String(els.moveCopyDateInput.value || '');
    copyOrMoveDay({ fromDate: selectedDate, toDate, move: false });
  });
}

if(els.moveDayBtn && els.moveCopyDateInput){
  els.moveDayBtn.addEventListener('click', () => {
    const toDate = String(els.moveCopyDateInput.value || '');
    copyOrMoveDay({ fromDate: selectedDate, toDate, move: true });
  });
}

els.last7Body.addEventListener('click', (ev) => {
  const editBtn = ev.target?.closest?.('[data-edit-date]');
  const tr = ev.target?.closest?.('tr[data-date]');
  const date = (editBtn && editBtn.getAttribute('data-edit-date')) || (tr && tr.dataset.date);
  if(!date) return;

  setActiveTab('today');
  renderFormForDate(date);
});

els.saveBtn.addEventListener('click', () => {
  persistCurrentForm();
});

els.waterGoalInput.addEventListener('change', () => {
  persistCurrentForm();
});

els.challengeStartInput.addEventListener('change', () => {
  persistCurrentForm();
});

els.caloriesBurnedInput.addEventListener('change', () => {
  persistCurrentForm();
});

els.workoutDoneInput.addEventListener('change', () => {
  const entry = getEntry(state, selectedDate);
  entry.workoutDone = els.workoutDoneInput.checked;
  syncCaloriesUi(entry);
  persistCurrentForm();
});

els.add250Btn.addEventListener('click', () => addWater(250));
els.add500Btn.addEventListener('click', () => addWater(500));
els.add1000Btn.addEventListener('click', () => addWater(1000));
els.clearWaterBtn.addEventListener('click', () => clearWater());

els.exportBtn.addEventListener('click', () => {
  const payload = loadState();
  const filename = `health-tracker-backup-${toISODateLocal(new Date())}.json`;
  downloadJSON(filename, payload);
});

els.exportPdfBtn.addEventListener('click', () => {
  exportPdfReport();
});

els.importFile.addEventListener('change', async () => {
  const file = els.importFile.files?.[0];
  if(!file) return;
  try{
    const text = await file.text();
    const parsed = JSON.parse(text);
    if(!parsed || typeof parsed !== 'object') throw new Error('Invalid file');

    const merged = {
      settings: {
        waterGoalMl: Number(parsed?.settings?.waterGoalMl ?? state.settings.waterGoalMl ?? 2000),
        challengeStart: String(parsed?.settings?.challengeStart ?? state.settings.challengeStart ?? ''),
      },
      entries: parsed?.entries && typeof parsed.entries === 'object' ? parsed.entries : {},
      weights: parsed?.weights && typeof parsed.weights === 'object' ? parsed.weights : (state.weights || {})
    };

    state = merged;
    saveState(state);
    renderFormForDate(selectedDate);
    setStatus('Imported');
  }catch{
    setStatus('Import failed');
  }finally{
    els.importFile.value = '';
  }
});

els.resetBtn.addEventListener('click', () => {
  const ok = confirm('This will delete all saved data on this device. Continue?');
  if(!ok) return;
  localStorage.removeItem(STORAGE_KEY);
  state = loadState();
  renderFormForDate(toISODateLocal(new Date()));
  setStatus('Reset');
});

els.saveWeightBtn.addEventListener('click', () => {
  saveWeightFromForm();
});

for(const b of els.tabs){
  b.addEventListener('click', () => {
    setActiveTab(b.dataset.tab);
  });
}

// Init
els.weightDateInput.value = toISODateLocal(new Date());
if(els.moveCopyDateInput){
  els.moveCopyDateInput.value = toISODateLocal(new Date());
}
renderFormForDate(selectedDate);
setActiveTab('today');

function updateLocalTime(){
  if(!els.localTimeText) return;
  const now = new Date();
  const time = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  els.localTimeText.textContent = `Local time: ${time}`;
}

updateLocalTime();
setInterval(updateLocalTime, 1000);
