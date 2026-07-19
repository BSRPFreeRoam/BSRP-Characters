(() => {
    const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'bsrp-characters';
    const creator = document.getElementById('creator');
    const spawn = document.getElementById('spawn');
    const charSelect = document.getElementById('charSelect');
    const deleteModal = document.getElementById('deleteModal');

    let step = 0;
    let gender = 'male';
    let selectedSpawn = null;
    let faceFeatures = [];
    let maxName = 24;
    let createSlot = null;
    let selectData = null;
    let pendingDelete = null; // { slot, name, job_label, cash, bank }
    let presetsByGender = { male: {}, female: {} };
    let activePreset = 'casual';

    const $ = (s) => document.querySelector(s);

    function money(n) {
        return '$' + (Number(n) || 0).toLocaleString('en-US');
    }

    function openDeleteMenu(character) {
        if (!character || character.empty) return;
        pendingDelete = {
            slot: Number(character.slot),
            name: character.name || 'RACER',
            job_label: character.job_label || character.job || 'Civilian',
            cash: character.cash,
            bank: character.bank,
        };
        const nameEl = document.getElementById('delName');
        const slotEl = document.getElementById('delSlot');
        const metaEl = document.getElementById('delMeta');
        if (nameEl) nameEl.textContent = String(pendingDelete.name).toUpperCase();
        if (slotEl) slotEl.textContent = '#' + pendingDelete.slot;
        if (metaEl) {
            metaEl.textContent = `${pendingDelete.job_label} · Cash ${money(pendingDelete.cash)} · Bank ${money(pendingDelete.bank)}`;
        }
        if (deleteModal) deleteModal.classList.remove('hidden');
        const confirmBtn = document.getElementById('delConfirm');
        if (confirmBtn) confirmBtn.disabled = false;
    }

    function closeDeleteMenu() {
        pendingDelete = null;
        if (deleteModal) deleteModal.classList.add('hidden');
    }

    function escapeHtml(s) {
        return String(s ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    function normalizeSlotList(data) {
        const raw = (data && data.characters) || [];
        const max = Math.max(1, Number(data && data.maxSlots) || raw.length || 5);
        const bySlot = {};
        raw.forEach((c) => {
            if (!c) return;
            const s = Number(c.slot);
            if (s >= 1 && s <= max) bySlot[s] = c;
        });
        const list = [];
        for (let s = 1; s <= max; s++) {
            list.push(bySlot[s] || { slot: s, empty: true, name: null });
        }
        return { list, max };
    }

    function renderCharacterSelect(data) {
        selectData = data || {};
        const { list, max } = normalizeSlotList(selectData);
        selectData.maxSlots = max;

        let used = 0;
        list.forEach((c) => { if (c && !c.empty) used += 1; });
        const countEl = document.getElementById('slotCount');
        if (countEl) countEl.textContent = `${used}/${max}`;

        const grid = document.getElementById('charGrid');
        if (!grid) return;
        grid.innerHTML = '';
        grid.dataset.slots = String(max);

        list.forEach((c) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'char-card' + (c.empty ? ' empty' : ' filled');
            btn.dataset.slot = String(c.slot);

            if (c.empty) {
                btn.innerHTML = `
                    <div class="slot-num">${c.slot}</div>
                    <div class="char-body">
                        <div class="cname">EMPTY SLOT</div>
                        <div class="cmeta">Click to create character #${c.slot}</div>
                    </div>
                    <div class="cside"><span class="create-tag">+ CREATE</span></div>
                `;
                btn.addEventListener('click', () => {
                    post('select:create', {
                        slot: c.slot,
                        suggested: selectData.suggested || '',
                        maxName: selectData.maxName || 24,
                    });
                });
            } else {
                btn.innerHTML = `
                    <div class="slot-num">${c.slot}</div>
                    <div class="char-body">
                        <div class="cname">${escapeHtml((c.name || 'RACER').toUpperCase())}</div>
                        <div class="cmeta">${escapeHtml(c.job_label || c.job || 'Civilian')} · Cash ${money(c.cash)} · Bank ${money(c.bank)}</div>
                    </div>
                    <div class="cside">
                        <span class="play-tag">PLAY</span>
                        <button type="button" class="del-btn" data-del="${c.slot}">DELETE</button>
                    </div>
                `;
                btn.addEventListener('click', (e) => {
                    if (e.target && e.target.closest && e.target.closest('.del-btn')) return;
                    post('select:play', { slot: c.slot });
                });
                const del = btn.querySelector('.del-btn');
                if (del) {
                    del.addEventListener('click', (e) => {
                        e.stopPropagation();
                        openDeleteMenu(c);
                    });
                }
            }
            grid.appendChild(btn);
        });
    }

    // Delete confirmation menu
    const delCancel = document.getElementById('delCancel');
    const delConfirm = document.getElementById('delConfirm');
    if (delCancel) {
        delCancel.addEventListener('click', () => closeDeleteMenu());
    }
    if (delConfirm) {
        delConfirm.addEventListener('click', () => {
            if (!pendingDelete || pendingDelete.slot == null) {
                closeDeleteMenu();
                return;
            }
            const slot = pendingDelete.slot;
            delConfirm.disabled = true;
            post('select:delete', { slot }).finally(() => {
                closeDeleteMenu();
            });
        });
    }
    if (deleteModal) {
        deleteModal.addEventListener('click', (e) => {
            // click backdrop (not the panel) to cancel
            if (e.target === deleteModal) closeDeleteMenu();
        });
    }
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && deleteModal && !deleteModal.classList.contains('hidden')) {
            closeDeleteMenu();
        }
    });

    function post(name, data = {}) {
        return fetch(`https://${res}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).then((r) => r.json()).catch(() => ({}));
    }

    function showStep(n) {
        step = n;
        document.querySelectorAll('.step').forEach((el) => {
            el.classList.toggle('active', Number(el.dataset.step) === n);
        });
        document.querySelectorAll('.step-pane').forEach((el, i) => {
            el.classList.toggle('active', i === n);
        });
        const last = n === 3;
        $('#btnNext').classList.toggle('hidden', last);
        $('#btnFinish').classList.toggle('hidden', !last);
        $('#btnPrev').disabled = n === 0;
    }

    function pushHeadBlend() {
        post('creator:update', {
            headBlend: {
                shapeFirst: Number($('#shapeFirst').value),
                shapeSecond: Number($('#shapeSecond').value),
                shapeThird: 0,
                skinFirst: Number($('#skinFirst').value),
                skinSecond: Number($('#skinSecond').value),
                skinThird: 0,
                shapeMix: Number($('#shapeMix').value) / 100,
                skinMix: Number($('#skinMix').value) / 100,
                thirdMix: 0,
            },
        });
        $('#vShapeA').textContent = $('#shapeFirst').value;
        $('#vShapeB').textContent = $('#shapeSecond').value;
        $('#vShapeMix').textContent = $('#shapeMix').value + '%';
        $('#vSkinA').textContent = $('#skinFirst').value;
        $('#vSkinB').textContent = $('#skinSecond').value;
        $('#vSkinMix').textContent = $('#skinMix').value + '%';
    }

    function pushStyle() {
        const beard = Number($('#beard').value);
        post('creator:update', {
            hair: Number($('#hair').value),
            hairColor: Number($('#hairColor').value),
            hairHighlight: Number($('#hairHighlight').value),
            eyeColor: Number($('#eyeColor').value),
            overlay: {
                id: 1,
                index: beard < 0 ? 255 : beard,
                opacity: beard < 0 ? 0.0 : 1.0,
                colorType: 1,
                firstColor: Number($('#hairColor').value),
                secondColor: 0,
            },
        });
        $('#vHair').textContent = $('#hair').value;
        $('#vHairColor').textContent = $('#hairColor').value;
        $('#vHairHi').textContent = $('#hairHighlight').value;
        $('#vEye').textContent = $('#eyeColor').value;
        $('#vBeard').textContent = beard < 0 ? 'None' : String(beard);
    }

    function buildFaceList(list) {
        faceFeatures = list || [];
        const box = $('#faceList');
        box.innerHTML = '';
        faceFeatures.forEach((f) => {
            const wrap = document.createElement('div');
            wrap.className = 'face-item';
            wrap.innerHTML = `
                <label>${f.label} <span id="ff${f.id}">0</span></label>
                <input type="range" min="-100" max="100" value="0" data-ff="${f.id}" />
            `;
            const input = wrap.querySelector('input');
            input.addEventListener('input', () => {
                const v = Number(input.value) / 100;
                document.getElementById('ff' + f.id).textContent = v.toFixed(2);
                post('creator:update', { faceFeature: { id: f.id, value: v } });
            });
            box.appendChild(wrap);
        });
    }

    // Creator events
    document.querySelectorAll('.step').forEach((el) => {
        el.addEventListener('click', () => showStep(Number(el.dataset.step)));
    });

    function renderPresets(g) {
        const row = document.getElementById('presetRow');
        if (!row) return;
        const bag = (presetsByGender && presetsByGender[g]) || {};
        const keys = Object.keys(bag);
        // Prefer a stable, readable order
        const preferred = [
            'casual', 'street', 'business', 'smart', 'formal', 'athletic', 'hoodie',
            'racer', 'biker', 'hipster', 'party', 'beach', 'summer', 'winter',
            'workwear', 'sleeveless', 'open_shirt', 'elegant', 'chic', 'crop', 'dress', 'open_jacket',
        ];
        const ordered = [
            ...preferred.filter((k) => bag[k]),
            ...keys.filter((k) => !preferred.includes(k)).sort(),
        ];
        row.innerHTML = '';
        if (!ordered.length) {
            row.innerHTML = '<div class="hint">No presets configured</div>';
            return;
        }
        if (!bag[activePreset]) {
            activePreset = ordered[0];
        }
        ordered.forEach((key) => {
            const p = bag[key] || {};
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'btn tiny preset' + (key === activePreset ? ' active' : '');
            btn.dataset.preset = key;
            btn.textContent = (p.label || key).toUpperCase();
            btn.addEventListener('click', () => {
                activePreset = key;
                row.querySelectorAll('.preset').forEach((b) => b.classList.remove('active'));
                btn.classList.add('active');
                post('creator:update', { preset: key });
            });
            row.appendChild(btn);
        });
    }

    document.querySelectorAll('.gender').forEach((btn) => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.gender').forEach((b) => b.classList.remove('active'));
            btn.classList.add('active');
            gender = btn.dataset.gender;
            activePreset = 'casual';
            renderPresets(gender);
            post('creator:setGender', { gender });
            // Re-apply default preset for the new gender after model swap
            setTimeout(() => post('creator:update', { preset: activePreset }), 50);
        });
    });

    ['shapeFirst', 'shapeSecond', 'shapeMix', 'skinFirst', 'skinSecond', 'skinMix'].forEach((id) => {
        document.getElementById(id).addEventListener('input', pushHeadBlend);
    });
    ['hair', 'hairColor', 'hairHighlight', 'eyeColor', 'beard'].forEach((id) => {
        document.getElementById(id).addEventListener('input', pushStyle);
    });

    $('#rotL').addEventListener('click', () => post('creator:update', { rotate: -15 }));
    $('#rotR').addEventListener('click', () => post('creator:update', { rotate: 15 }));

    $('#btnPrev').addEventListener('click', () => {
        if (step > 0) showStep(step - 1);
    });
    $('#btnNext').addEventListener('click', () => {
        if (step === 0) {
            const n = ($('#charName').value || '').trim();
            if (n.length < 2) return;
        }
        if (step < 3) showStep(step + 1);
    });
    $('#btnFinish').addEventListener('click', () => {
        const name = ($('#charName').value || '').trim();
        if (name.length < 2) {
            showStep(0);
            return;
        }
        post('creator:finish', { name, slot: createSlot });
    });

    // Spawn
    function renderSpawns(list) {
        const grid = $('#spawnGrid');
        grid.innerHTML = '';
        selectedSpawn = null;
        $('#btnSpawn').disabled = true;
        (list || []).forEach((s) => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'spawn-card' + (s.useLast && !s.hasLast ? ' disabled' : '');
            btn.innerHTML = `
                <span class="ico">${s.icon || '•'}</span>
                <div class="lbl">${s.label}</div>
                <div class="desc">${s.description || ''}${s.useLast && !s.hasLast ? ' (none yet)' : ''}</div>
            `;
            if (!(s.useLast && !s.hasLast)) {
                btn.addEventListener('click', () => {
                    document.querySelectorAll('.spawn-card').forEach((c) => c.classList.remove('selected'));
                    btn.classList.add('selected');
                    selectedSpawn = s;
                    $('#btnSpawn').disabled = false;
                });
            }
            grid.appendChild(btn);
        });
    }

    $('#btnSpawn').addEventListener('click', () => {
        if (!selectedSpawn) return;
        post('spawn:select', {
            id: selectedSpawn.id,
            coords: selectedSpawn.coords,
        });
    });

    window.addEventListener('message', (e) => {
        const { action, data } = e.data || {};
        if (action === 'openSelect') {
            if (charSelect) charSelect.classList.remove('hidden');
            creator.classList.add('hidden');
            spawn.classList.add('hidden');
            closeDeleteMenu();
            renderCharacterSelect(data || {});
        } else if (action === 'closeSelect') {
            if (charSelect) charSelect.classList.add('hidden');
            closeDeleteMenu();
        } else if (action === 'openCreator') {
            creator.classList.remove('hidden');
            spawn.classList.add('hidden');
            if (charSelect) charSelect.classList.add('hidden');
            closeDeleteMenu();
            maxName = (data && data.maxName) || 24;
            createSlot = data && data.slot != null ? Number(data.slot) : null;
            $('#charName').maxLength = maxName;
            $('#charName').value = (data && data.name) || '';
            buildFaceList((data && data.faceFeatures) || []);
            presetsByGender = (data && data.presets) || { male: {}, female: {} };
            showStep(0);
            if (data && data.logout) {
                $('#creatorTitle').textContent = 'CHARACTER // SWITCH';
                $('#creatorTag').textContent = 'LOGOUT · EDIT · REDEPLOY';
            } else {
                const slotLabel = createSlot != null ? ` · SLOT ${createSlot}` : '';
                $('#creatorTitle').textContent = 'CHARACTER // CREATE';
                $('#creatorTag').textContent = 'BSRP GRID REGISTRATION' + slotLabel;
            }
            gender = 'male';
            activePreset = 'casual';
            document.querySelectorAll('.gender').forEach((b) => {
                b.classList.toggle('active', b.dataset.gender === 'male');
            });
            renderPresets(gender);
        } else if (action === 'closeCreator') {
            creator.classList.add('hidden');
        } else if (action === 'openSpawn') {
            spawn.classList.remove('hidden');
            creator.classList.add('hidden');
            if (charSelect) charSelect.classList.add('hidden');
            closeDeleteMenu();
            $('#spawnName').textContent = (data && data.name) || 'RACER';
            renderSpawns(data && data.spawns);
        } else if (action === 'closeSpawn') {
            spawn.classList.add('hidden');
            closeDeleteMenu();
        }
    });
})();
