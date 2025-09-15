// app.js - front-end logic para la API /people
const API_BASE = 'http://localhost:8080/people'; // <- cámbialo si tu API está en otra URL
const DEFAULT_TIMEOUT = 8000;
const RETRIES = 2;

const $ = sel => document.querySelector(sel);
const $$ = sel => Array.from(document.querySelectorAll(sel));

/* ----------------- network helpers ----------------- */
function fetchWithTimeout(url, options = {}, timeout = DEFAULT_TIMEOUT) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('timeout')), timeout);
    fetch(url, options)
      .then(res => { clearTimeout(timer); resolve(res); })
      .catch(err => { clearTimeout(timer); reject(err); });
  });
}

async function safeJson(res) {
  const text = await res.text();
  try { return text ? JSON.parse(text) : null; } catch { return text; }
}

async function withRetries(fn, tries = RETRIES) {
  let lastErr;
  for (let i = 0; i < tries; i++) {
    try { return await fn(); } catch (e) { lastErr = e; if (i < tries - 1) await new Promise(r => setTimeout(r, 150)); }
  }
  throw lastErr;
}

/* API helpers */
async function apiGetAll() {
  return withRetries(async () => {
    const res = await fetchWithTimeout(API_BASE, { method: 'GET' });
    if (!res.ok) throw new Error(`GET failed ${res.status}`);
    return res.json();
  });
}

async function apiGetOne(dni) {
  const res = await fetchWithTimeout(`${API_BASE}/${encodeURIComponent(dni)}`, { method: 'GET' });
  if (!res.ok) throw new Error(`GET ${dni} failed ${res.status}`);
  return res.json();
}

async function apiCreate(person) {
  return withRetries(async () => {
    const res = await fetchWithTimeout(API_BASE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
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
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(person)
    });
    if (!res.ok) throw new Error(`PUT failed ${res.status}`);
    return safeJson(res);
  });
}

async function apiDelete(dni) {
  const res = await fetchWithTimeout(`${API_BASE}/${encodeURIComponent(dni)}`, { method: 'DELETE' });
  if (!res.ok) throw new Error(`DELETE failed ${res.status}`);
  return safeJson(res);
}

/* ----------------- UI helpers ----------------- */
const tableBody = document.querySelector('#peopleTable tbody');
const emptyState = document.getElementById('emptyState');
const toastEl = document.getElementById('toast');

function showToast(message, ms = 3500) {
  toastEl.textContent = message;
  toastEl.classList.add('show');
  clearTimeout(toastEl._t);
  toastEl._t = setTimeout(() => toastEl.classList.remove('show'), ms);
}

function formatRow(person) {
  const tr = document.createElement('tr');
  tr.dataset.dni = person.dni;
  tr.innerHTML = `
    <td>${escapeHtml(person.name)}</td>
    <td>${escapeHtml(person.dni)}</td>
    <td>${String(person.age)}</td>
    <td class="actions">
      <button class="btn" data-action="edit" title="Editar">✎</button>
      <button class="btn danger" data-action="delete" title="Eliminar">🗑</button>
    </td>
  `;
  return tr;
}

function escapeHtml(s){
  if (s == null) return '';
  return String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
}

/* ----------------- app state & operations ----------------- */
let peopleCache = [];

async function loadAndRender() {
  try {
    const arr = await apiGetAll();
    peopleCache = Array.isArray(arr) ? arr : [];
    renderTable(peopleCache);
    showToast('Lista actualizada', 1200);
  } catch (e) {
    console.error(e);
    showToast('Error al cargar personas: ' + (e.message||e));
  }
}

function renderTable(list) {
  tableBody.innerHTML = '';
  if (!list.length) {
    emptyState.style.display = 'block';
    return;
  }
  emptyState.style.display = 'none';
  for (const p of list) {
    tableBody.appendChild(formatRow(p));
  }
}

/* search */
$('#searchInput').addEventListener('input', (ev) => {
  const q = ev.target.value.trim().toLowerCase();
  const filtered = peopleCache.filter(p =>
    p.name?.toLowerCase().includes(q) || p.dni?.toLowerCase().includes(q)
  );
  renderTable(filtered);
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
    try {
      await apiDelete(dni);
      peopleCache = peopleCache.filter(p => p.dni !== dni);
      renderTable(peopleCache);
      showToast('Eliminado correctamente');
    } catch (e) {
      console.error(e);
      showToast('Error al eliminar: ' + (e.message || e));
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

function openModalFor(mode = 'new', dni = null) {
  modalMode = mode;
  editingDni = dni;
  form.reset();
  if (mode === 'new') {
    modalTitle.textContent = 'Nueva persona';
    dniInput.disabled = false;
    submitBtn.textContent = 'Crear';
  } else {
    modalTitle.textContent = 'Editar persona';
    dniInput.disabled = true;
    submitBtn.textContent = 'Actualizar';
    // load data into form
    const person = peopleCache.find(p => p.dni === dni);
    if (person) {
      nameInput.value = person.name ?? '';
      dniInput.value = person.dni ?? '';
      ageInput.value = person.age ?? '';
    }
  }
  modal.setAttribute('aria-hidden', 'false');
  nameInput.focus();
}

function closeModal() {
  modal.setAttribute('aria-hidden', 'true');
  editingDni = null;
}

/* modal buttons */
$('#btnNew').addEventListener('click', () => openModalFor('new'));
$('#modalClose').addEventListener('click', closeModal);
$('#cancelBtn').addEventListener('click', closeModal);
modal.addEventListener('click', (ev) => {
  if (ev.target === modal) closeModal(); // click fuera del cuadro
});

/* submit */
form.addEventListener('submit', async (ev) => {
  ev.preventDefault();
  // simple client-side validation
  const name = nameInput.value.trim();
  const dni = dniInput.value.trim();
  const age = Number(ageInput.value);

  if (!name || !dni || Number.isNaN(age)) {
    showToast('Rellena todos los campos correctamente');
    return;
  }

  const person = { name, dni, age };

  try {
    if (modalMode === 'new') {
      await apiCreate(person);
      peopleCache.push(person);
      renderTable(peopleCache);
      showToast('Creado correctamente');
    } else {
      await apiUpdate(editingDni, person);
      // update cache
      const idx = peopleCache.findIndex(p => p.dni === editingDni);
      if (idx >= 0) peopleCache[idx] = person;
      renderTable(peopleCache);
      showToast('Actualizado correctamente');
    }
    closeModal();
  } catch (e) {
    console.error(e);
    if (e.code === 409) {
      showToast('El DNI ya existe. Usa uno diferente.');
    } else {
      showToast('Error al guardar: ' + (e.message || e));
    }
  }
});

/* initial load */
document.addEventListener('DOMContentLoaded', () => {
  loadAndRender();
});
