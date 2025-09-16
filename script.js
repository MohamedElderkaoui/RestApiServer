// app.js - front-end logic para la API /people
const API_BASE = 'http://localhost:8080/people'; // <- cámbialo si tu API está en otra URL
const DEFAULT_TIMEOUT = 8000;
const RETRIES = 2;
const BASE_RETRY_DELAY = 150; // ms

const $ = sel => document.querySelector(sel);
const $$ = sel => Array.from(document.querySelectorAll(sel));

/* ----------------- network helpers ----------------- */
function fetchWithTimeout(url, options = {}, timeout = DEFAULT_TIMEOUT) {
  const controller = new AbortController();
  const signal = controller.signal;
  const mergedOptions = { ...options, signal };

  const timer = setTimeout(() => controller.abort(), timeout);

  return fetch(url, mergedOptions)
    .finally(() => clearTimeout(timer));
}

async function safeJson(res) {
  // devuelve objeto o texto bruto si no es JSON
  const text = await res.text();
  try { return text ? JSON.parse(text) : null; } catch { return text; }
}

async function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function withRetries(fn, tries = RETRIES, baseDelay = BASE_RETRY_DELAY) {
  let lastErr;
  for (let i = 0; i < tries; i++) {
    try { return await fn(); }
    catch (e) {
      lastErr = e;
      if (i < tries - 1) {
        // backoff exponencial con jitter pequeño
        const jitter = Math.floor(Math.random() * 100);
        const delay = baseDelay * Math.pow(2, i) + jitter;
        await sleep(delay);
      }
    }
  }
  throw lastErr;
}

/* API helpers */
async function apiGetAll() {
  return withRetries(async () => {
    const res = await fetchWithTimeout(API_BASE, { method: 'GET', headers: { 'Accept': 'application/json' } });
    if (!res.ok) {
      const body = await safeJson(res);
      throw new Error(body && body.error ? body.error : `GET failed ${res.status}`);
    }
    return safeJson(res);
  });
}

async function apiGetOne(dni) {
  const res = await fetchWithTimeout(`${API_BASE}/${encodeURIComponent(dni)}`, { method: 'GET', headers: { 'Accept': 'application/json' } });
  if (!res.ok) {
    const body = await safeJson(res);
    throw new Error(body && body.error ? body.error : `GET ${dni} failed ${res.status}`);
  }
  return safeJson(res);
}

async function apiCreate(person) {
  return withRetries(async () => {
    const res = await fetchWithTimeout(API_BASE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify(person)
    });
    if (res.status === 409) {
      const body = await safeJson(res);
      const msg = body && body.error ? body.error : 'DNI ya existe';
      const err = new Error(msg); err.code = 409; throw err;
    }
    if (!res.ok) {
      const body = await safeJson(res);
      const msg = body && body.error ? body.error : `POST failed ${res.status}`;
      throw new Error(msg);
    }
    return safeJson(res);
  });
}

async function apiUpdate(dni, person) {
  return withRetries(async () => {
    const res = await fetchWithTimeout(`${API_BASE}/${encodeURIComponent(dni)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify(person)
    });
    if (!res.ok) {
      const body = await safeJson(res);
      const msg = body && body.error ? body.error : `PUT failed ${res.status}`;
      throw new Error(msg);
    }
    return safeJson(res);
  });
}

async function apiDelete(dni) {
  const res = await fetchWithTimeout(`${API_BASE}/${encodeURIComponent(dni)}`, { method: 'DELETE', headers: { 'Accept': 'application/json' } });
  if (!res.ok) {
    const body = await safeJson(res);
    const msg = body && body.error ? body.error : `DELETE failed ${res.status}`;
    throw new Error(msg);
  }
  return safeJson(res);
}

/* ----------------- UI helpers ----------------- */
const tableBody = document.querySelector('#peopleTable tbody');
const emptyState = document.getElementById('emptyState');
const toastEl = document.getElementById('toast');

function showToast(message, ms = 3500, opts = {}) {
  // opts: { type: 'info'|'error'|'success' }
  toastEl.textContent = message;
  toastEl.classList.remove('show', 'error', 'success', 'info');
  toastEl.classList.add('show');
  if (opts.type) toastEl.classList.add(opts.type);
  clearTimeout(toastEl._t);
  toastEl._t = setTimeout(() => toastEl.classList.remove('show', 'error', 'success', 'info'), ms);
}

function escapeHtml(s){
  if (s == null) return '';
  return String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
}

function formatRow(person) {
  const tr = document.createElement('tr');
  tr.dataset.dni = person.dni;
  tr.setAttribute('aria-label', `Persona ${person.name} ${person.dni}`);
  tr.innerHTML = `
    <td>${escapeHtml(person.name)}</td>
    <td>${escapeHtml(person.dni)}</td>
    <td>${Number.isFinite(person.age) ? String(person.age) : ''}</td>
    <td class="actions">
      <button class="btn" data-action="edit" title="Editar" aria-label="Editar ${escapeHtml(person.name)}">✎</button>
      <button class="btn danger" data-action="delete" title="Eliminar" aria-label="Eliminar ${escapeHtml(person.name)}">🗑</button>
    </td>
  `;
  return tr;
}

/* ----------------- app state & operations ----------------- */
let peopleCache = [];
let loadingCount = 0;
function setLoading(on) {
  if (on) {
    loadingCount++;
    document.body.classList.add('loading');
  } else {
    loadingCount = Math.max(0, loadingCount - 1);
    if (loadingCount === 0) document.body.classList.remove('loading');
  }
}

async function loadAndRender({ notify = true } = {}) {
  setLoading(true);
  try {
    const arr = await apiGetAll();
    peopleCache = Array.isArray(arr) ? arr : [];
    renderTable(peopleCache);
    if (notify) showToast('Lista actualizada', 1200, { type: 'success' });
  } catch (e) {
    console.error(e);
    showToast('Error al cargar personas: ' + (e.message || e), 5000, { type: 'error' });
  } finally {
    setLoading(false);
  }
}

function renderTable(list) {
  tableBody.innerHTML = '';
  const sorted = (list || []).slice().sort((a, b) => {
    const na = (a.name || '').toLowerCase();
    const nb = (b.name || '').toLowerCase();
    return na < nb ? -1 : na > nb ? 1 : 0;
  });
  if (!sorted.length) {
    emptyState.style.display = 'block';
    return;
  }
  emptyState.style.display = 'none';
  for (const p of sorted) {
    tableBody.appendChild(formatRow(p));
  }
}

/* ----------------- search (debounced) ----------------- */
const searchInput = $('#searchInput');
let searchTimer = null;
searchInput.addEventListener('input', (ev) => {
  const q = ev.target.value.trim().toLowerCase();
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    const filtered = peopleCache.filter(p =>
      (p.name && p.name.toLowerCase().includes(q)) || (p.dni && p.dni.toLowerCase().includes(q))
    );
    renderTable(filtered);
  }, 200);
});

/* row actions (edit/delete) */
tableBody.addEventListener('click', async (ev) => {
  const btn = ev.target.closest('button');
  if (!btn) return;
  const tr = btn.closest('tr');
  const dni = tr?.dataset?.dni;
  if (!dni) return;

  const action = btn.dataset.action;
  if (action === 'edit') {
    openModalFor('edit', dni);
  } else if (action === 'delete') {
    if (!confirm('¿Eliminar persona con DNI ' + dni + ' ?')) return;

    // Optimistic UI: quitar de la tabla y cache inmediatamente
    const previousCache = peopleCache.slice();
    peopleCache = peopleCache.filter(p => p.dni !== dni);
    renderTable(peopleCache);
    showToast('Eliminando...', 2000);

    try {
      await apiDelete(dni);
      showToast('Eliminado correctamente', 2000, { type: 'success' });
    } catch (e) {
      console.error(e);
      // rollback
      peopleCache = previousCache;
      renderTable(peopleCache);
      showToast('Error al eliminar: ' + (e.message || e), 5000, { type: 'error' });
    }
  }
});

/* ----------------- modal / form logic ----------------- */
const modal = $('#modal');
const modalTitle = $('#modalTitle');
const form = $('#personForm');
const nameInput = $('#name');
const dniInput = $('#dni');
const ageInput = $('#age');
const submitBtn = $('#submitBtn');

let modalMode = 'new'; // 'new' or 'edit'
let editingDni = null;

async function openModalFor(mode = 'new', dni = null) {
  modalMode = mode;
  editingDni = dni;
  form.reset();
  submitBtn.disabled = false;

  if (mode === 'new') {
    modalTitle.textContent = 'Nueva persona';
    dniInput.disabled = false;
    submitBtn.textContent = 'Crear';
    // Pre-fill nothing
  } else {
    modalTitle.textContent = 'Editar persona';
    dniInput.disabled = true;
    submitBtn.textContent = 'Actualizar';
    // prefer to load fresh data from API (fallback to cache)
    setLoading(true);
    try {
      const person = await apiGetOne(dni).catch(() => null) || peopleCache.find(p => p.dni === dni);
      if (person) {
        nameInput.value = person.name ?? '';
        dniInput.value = person.dni ?? '';
        ageInput.value = person.age ?? '';
      }
    } catch (e) {
      console.error(e);
      showToast('No se pudieron cargar los datos de la persona', 3000, { type: 'error' });
    } finally {
      setLoading(false);
    }
  }

  modal.setAttribute('aria-hidden', 'false');
  nameInput.focus();
}

function closeModal() {
  modal.setAttribute('aria-hidden', 'true');
  editingDni = null;
  form.reset();
}

/* modal buttons */
$('#btnNew').addEventListener('click', () => openModalFor('new'));
$('#modalClose').addEventListener('click', closeModal);
$('#cancelBtn').addEventListener('click', (ev) => { ev.preventDefault(); closeModal(); });
modal.addEventListener('click', (ev) => {
  if (ev.target === modal) closeModal(); // click fuera del cuadro
});

/* submit */
form.addEventListener('submit', async (ev) => {
  ev.preventDefault();
  // simple client-side validation
  const name = nameInput.value.trim();
  const dni = dniInput.value.trim();
  const ageRaw = ageInput.value.trim();
  const age = Number(ageRaw);

  if (!name || !dni || ageRaw === '' || Number.isNaN(age) || !Number.isInteger(age) || age < 0 || age > 130) {
    showToast('Rellena todos los campos correctamente (edad: entero 0-130)', 4000, { type: 'error' });
    return;
  }

  const person = { name, dni, age };

  submitBtn.disabled = true;
  setLoading(true);
  try {
    if (modalMode === 'new') {
      const created = await apiCreate(person);
      // si la API devuelve el recurso creado (u otros campos), preferir ese objeto
      peopleCache.push(created && created.dni ? created : person);
      renderTable(peopleCache);
      showToast('Creado correctamente', 2000, { type: 'success' });
    } else {
      await apiUpdate(editingDni, person);
      const idx = peopleCache.findIndex(p => p.dni === editingDni);
      if (idx >= 0) peopleCache[idx] = person;
      renderTable(peopleCache);
      showToast('Actualizado correctamente', 2000, { type: 'success' });
    }
    closeModal();
  } catch (e) {
    console.error(e);
    if (e.code === 409) {
      showToast('El DNI ya existe. Usa uno diferente.', 4000, { type: 'error' });
    } else {
      showToast('Error al guardar: ' + (e.message || e), 5000, { type: 'error' });
    }
  } finally {
    submitBtn.disabled = false;
    setLoading(false);
  }
});

/* initial load */
document.addEventListener('DOMContentLoaded', () => {
  loadAndRender();
});
