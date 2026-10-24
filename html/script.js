const $ = (id) => document.getElementById(id);
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));

const ICONS = {
    rod: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M4 21L16 6"/><path d="M16 6c0 6 1 10 4 14"/><path d="M4 21v-2"/></svg>',
    bait: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M12 3v12a4 4 0 1 1-4-4"/><path d="M9 6h6"/></svg>',
    fish: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"><path d="M3 12c3-5 9-6 13-2l4-3v10l-4-3c-4 4-10 3-13-2z"/><circle cx="8" cy="11" r="1"/></svg>'
};

let imagePath = null;
let labels = { status: {} };
let baits = [];
let toastTimer = null;

const mini = {
    running: false,
    loop: false,
    cfg: null,
    holding: false,
    zone: 0.5,
    fish: 0.5,
    progress: 40,
    time: 0,
    total: 1,
    jitter: 0,
    phase: 0,
    seed: 0,
    grace: 0,
    inZone: false,
    last: 0
};

function setIcon(container, kind, item) {
    container.innerHTML = '';
    const svg = () => {
        container.innerHTML = ICONS[kind] || ICONS.fish;
    };
    if (!imagePath || !item) {
        svg();
        return;
    }
    const img = document.createElement('img');
    img.alt = '';
    img.onerror = svg;
    img.src = imagePath.replace('%s', item);
    container.appendChild(img);
}

function applyLabels() {
    $('keyCast').textContent = labels.keyCast || '';
    $('keyReel').textContent = labels.keyReel || '';
    $('keyBait').textContent = labels.keyBait || '';
    $('durLabel').textContent = labels.durability || '';
    $('baitLabel').textContent = labels.bait || '';
    $('biteTitle').textContent = labels.bite || '';
    $('biteHint').textContent = labels.biteHint || '';
    $('lblProgress').textContent = labels.progress || '';
    $('lblTime').textContent = labels.time || '';
    $('miniHint').textContent = labels.miniHint || '';
}

function renderHud(d) {
    $('hud').classList.toggle('hidden', !d.visible);
    if (!d.visible) {
        return;
    }
    $('hudRod').textContent = d.rod || '';
    $('hudStatus').textContent = (labels.status && labels.status[d.status]) || '';

    baits = Array.isArray(d.baits) ? d.baits : [];
    const index = clamp(d.index || 0, 0, Math.max(0, baits.length - 1));
    const bait = baits[index];
    if (bait) {
        setIcon($('baitIcon'), 'bait', bait.item);
        $('baitName').textContent = bait.label;
        $('baitCount').textContent = 'x ' + bait.count;
    } else {
        setIcon($('baitIcon'), 'bait', null);
        $('baitName').textContent = labels.noBait || '';
        $('baitCount').textContent = '';
    }

    const pct = d.durMax > 0 ? clamp(Math.round(d.durability / d.durMax * 100), 0, 100) : 0;
    const fill = $('durFill');
    fill.style.width = pct + '%';
    fill.classList.toggle('low', pct <= 25);
    $('durValue').textContent = pct + '%';
}

function showBite(d) {
    const el = $('bite');
    el.classList.toggle('hidden', !d.visible);
    if (!d.visible) {
        return;
    }
    const fill = $('biteFill');
    fill.style.transition = 'none';
    fill.style.width = '100%';
    void fill.offsetWidth;
    fill.style.transition = 'width ' + d.duration + 'ms linear';
    fill.style.width = '0%';
}

function showToast(d) {
    const el = $('toast');
    el.classList.remove('hidden', 'success', 'fail');
    void el.offsetWidth;
    el.classList.add(d.kind === 'success' ? 'success' : 'fail');
    setIcon($('toastIcon'), 'fish', d.item);
    $('toastKind').textContent = d.kind === 'success' ? (labels.caught || '') : (labels.escaped || '');
    $('toastText').textContent = d.label || '';
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.add('hidden'), 2800);
}

function resourceName() {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'len_fishing';
}

function miniFinish(success) {
    if (!mini.running) {
        return;
    }
    mini.running = false;
    $('mini').classList.add(success ? 'success' : 'fail');
    fetch(`https://${resourceName()}/minigameResult`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ success: success })
    }).catch(() => {});
}

function miniUpdate(dt) {
    const c = mini.cfg;

    mini.phase += dt * c.speed * 2.2;
    mini.jitter += (Math.random() - 0.5) * c.noise * dt * 6;
    mini.jitter *= Math.pow(0.6, dt * 3);
    mini.jitter = clamp(mini.jitter, -0.25, 0.25);
    const wave = 0.36 * Math.sin(mini.phase) + 0.14 * Math.sin(mini.phase * 1.7 + mini.seed);
    mini.fish = clamp(0.5 + wave + mini.jitter, 0.02, 0.98);

    const half = c.zone / 2;
    const rise = mini.holding ? 1.0 : -0.6;
    mini.zone = clamp(mini.zone + rise * dt, half, 1 - half);

    mini.inZone = Math.abs(mini.fish - mini.zone) <= half;
    if (mini.inZone) {
        mini.progress += c.gain * dt;
    } else {
        mini.progress -= c.loss * dt;
    }
    mini.progress = clamp(mini.progress, 0, 100);

    mini.grace -= dt;
    mini.time -= dt;

    if (mini.progress >= 100) {
        miniFinish(true);
    } else if (mini.grace <= 0 && mini.progress <= 0) {
        miniFinish(false);
    } else if (mini.time <= 0) {
        miniFinish(false);
    }
}

function miniRender() {
    const c = mini.cfg;
    const half = c.zone / 2;
    $('zone').style.height = (c.zone * 100) + '%';
    $('zone').style.bottom = ((mini.zone - half) * 100) + '%';
    $('zone').classList.toggle('in', mini.inZone);
    $('fish').style.bottom = (mini.fish * 100) + '%';
    $('progressFill').style.width = mini.progress + '%';
    $('progressValue').textContent = Math.round(mini.progress) + '%';
    $('timeFill').style.width = clamp(mini.time / mini.total * 100, 0, 100) + '%';
    $('timer').textContent = Math.max(0, mini.time).toFixed(1) + 's';
}

function miniFrame(now) {
    if (!mini.running) {
        mini.loop = false;
        return;
    }
    const dt = Math.min(0.05, (now - mini.last) / 1000);
    mini.last = now;
    miniUpdate(dt);
    miniRender();
    requestAnimationFrame(miniFrame);
}

function openMini(d) {
    mini.cfg = d.config;
    mini.running = true;
    mini.holding = false;
    mini.zone = 0.5;
    mini.fish = 0.5;
    mini.progress = 40;
    mini.total = d.config.duration;
    mini.time = d.config.duration;
    mini.jitter = 0;
    mini.phase = Math.random() * Math.PI * 2;
    mini.seed = Math.random() * 10;
    mini.grace = 1.5;
    mini.inZone = false;
    mini.last = performance.now();

    $('miniTitle').textContent = d.title || '';
    $('miniGroup').textContent = d.group || '';
    $('fishName').textContent = (d.fish && d.fish.label) || '';
    setIcon($('fishIcon'), 'fish', d.fish && d.fish.item);

    const el = $('mini');
    el.classList.remove('hidden', 'success', 'fail');
    miniRender();

    if (!mini.loop) {
        mini.loop = true;
        requestAnimationFrame(miniFrame);
    }
}

function closeMini() {
    mini.running = false;
    $('mini').classList.add('hidden');
}

window.addEventListener('message', (event) => {
    const d = event.data || {};
    switch (d.action) {
        case 'setup':
            imagePath = d.imagePath || null;
            labels = d.labels || { status: {} };
            applyLabels();
            break;
        case 'hud':
            renderHud(d);
            break;
        case 'bite':
            showBite(d);
            break;
        case 'mini':
            if (d.visible) {
                openMini(d);
            } else {
                closeMini();
            }
            break;
        case 'hold':
            mini.holding = !!d.value;
            break;
        case 'toast':
            showToast(d);
            break;
    }
});
