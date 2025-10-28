class PumpkinSystem {
    constructor() {
        this.menuOpen = false;
        this.playerData = {
            collected: 0,
            rewardsClaimed: [],
            rank: 0
        };
        this.rewards = [];
        this.leaderboard = [];
        this.init();
    }

    init() {
        document.querySelectorAll('.menu-tabs .tab').forEach(tab => {
            tab.addEventListener('click', () => this.switchTab(tab.dataset.tab));
        });
    }

    openMenu(data) {
        if (this.menuOpen) return;

        this.playerData = data.player || this.playerData;
        this.rewards = data.rewards || [];
        this.leaderboard = data.leaderboard || [];

        const menu = document.getElementById('pumpkin-menu');
        menu.classList.remove('hidden');
        menu.style.pointerEvents = 'auto';
        this.menuOpen = true;

        this.updateStats(data);
        this.updateRewardsList();
        this.updateLeaderboard(this.leaderboard);
        this.updateEventDates(data.eventStart, data.eventEnd);

        if (window.horrorSystem) {
            window.horrorSystem.activeEffects.clear();
        }

        document.querySelectorAll('#jumpscare-overlay, #static-effect, #chromatic-effect, #blindness-overlay, #visual-effects, #ghost-container, #zone-indicator, #notification-container')
            .forEach(el => el.style.pointerEvents = 'none');
    }

    closeMenu() {
        const menu = document.getElementById('pumpkin-menu');
        menu.classList.add('hidden');
        menu.style.pointerEvents = 'none';
        this.menuOpen = false;

        fetch(`https://${GetParentResourceName()}/closePumpkinMenu`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    }

    switchTab(tabName) {
        document.querySelectorAll('.menu-tabs .tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        document.querySelector(`.menu-tabs .tab[data-tab="${tabName}"]`).classList.add('active');
        document.getElementById(`tab-${tabName}`).classList.add('active');
    }

    updateStats(data) {
        document.getElementById('total-collected').textContent = this.playerData.collected || 0;
        document.getElementById('rewards-claimed').textContent = this.playerData.rewardsClaimed?.length || 0;
        document.getElementById('player-rank').textContent = this.playerData.rank || '-';
        document.getElementById('active-pumpkins').textContent = data.activePumpkins || 0;
        document.getElementById('total-players').textContent = data.totalPlayers || 0;
        document.getElementById('total-collected-global').textContent = data.totalCollectedGlobal || 0;

        const nextReward = this.rewards.find(r => !this.playerData.rewardsClaimed.includes(r.pumpkinsRequired));
        if (nextReward) {
            const progress = (this.playerData.collected / nextReward.pumpkinsRequired) * 100;
            document.getElementById('next-reward-progress').style.width = Math.min(progress, 100) + '%';
            document.getElementById('progress-text').textContent =
                `${this.playerData.collected} / ${nextReward.pumpkinsRequired}`;
        }

        const maxReward = Math.max(...this.rewards.map(r => r.pumpkinsRequired));
        const totalProgress = (this.playerData.collected / maxReward) * 100;
        document.getElementById('total-progress').style.width = Math.min(totalProgress, 100) + '%';
        document.getElementById('total-progress-text').textContent =
            `${this.playerData.collected} / ${maxReward}`;

        if (data.timeRemaining) {
            this.updateTimeRemaining(data.timeRemaining);
        }
    }

    updateRewardsList() {
        const container = document.getElementById('rewards-container');
        container.innerHTML = '';

        this.rewards.forEach(reward => {
            const isClaimed = this.playerData.rewardsClaimed.includes(reward.pumpkinsRequired);
            const isAvailable = this.playerData.collected >= reward.pumpkinsRequired && !isClaimed;
            const isLocked = this.playerData.collected < reward.pumpkinsRequired;

            const rewardEl = document.createElement('div');
            rewardEl.className = `reward-item ${isClaimed ? 'claimed' : ''}`;

            let statusClass = 'locked';
            let statusText = `${reward.pumpkinsRequired - this.playerData.collected} más`;

            if (isClaimed) {
                statusClass = 'claimed';
                statusText = '✓ Reclamada';
            } else if (isAvailable) {
                statusClass = 'available';
                statusText = '¡Reclamar!';
            }

            let rewardsList = reward.rewards.map(r => {
                if (r.type === 'money') return `💰 ${r.amount}`;
                if (r.type === 'black_money') return `💵 Dinero negro ${r.amount}`;
                if (r.type === 'item') return `📦 ${r.name} x${r.amount}`;
                if (r.type === 'weapon') return `🔫 ${r.name}`;
                return r.type;
            }).join('</div><div class="reward-req-item">');

            rewardEl.innerHTML = `
                <div class="reward-header">
                    <div style="display: flex; align-items: center; flex: 1;">
                        <div class="reward-icon">${reward.icon}</div>
                        <div class="reward-info">
                            <div class="reward-name">${reward.name}</div>
                            <div class="reward-desc">${reward.description}</div>
                        </div>
                    </div>
                    <div class="reward-status ${statusClass}">${statusText}</div>
                </div>
                <div class="reward-requirements">
                    <div class="reward-req-item">${rewardsList}</div>
                </div>
                ${isAvailable ? `<button class="claim-btn" onclick="pumpkinSystem.claimReward(${reward.pumpkinsRequired})">🎁 RECLAMAR RECOMPENSA</button>` : ''}
            `;

            container.appendChild(rewardEl);
        });
    }

    updateLeaderboard(data) {
        const tbody = document.getElementById('leaderboard-body');
        tbody.innerHTML = '';

        if (!data || data.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="3">
                        <div class="empty-state">
                            <div class="icon">👻</div>
                            <div class="text">No hay datos de ranking disponibles</div>
                        </div>
                    </td>
                </tr>
            `;
            return;
        }

        data.forEach((entry, index) => {
            const row = document.createElement('tr');
            if (entry.isPlayer) row.classList.add('player-row');

            let rankClass = 'rank-other';
            if (index === 0) rankClass = 'rank-1';
            else if (index === 1) rankClass = 'rank-2';
            else if (index === 2) rankClass = 'rank-3';

            row.innerHTML = `
                <td style="text-align: center;">
                    <span class="rank-badge ${rankClass}">${index + 1}</span>
                </td>
                <td style="font-weight: bold; color: ${entry.isPlayer ? '#ffd700' : '#ff8c00'};">
                    ${entry.player_name}${entry.isPlayer ? ' (TÚ)' : ''}
                </td>
                <td style="text-align: center; font-size: 18px; font-weight: bold; color: #ffd700;">
                    🎃 ${entry.collected}
                </td>
            `;

            tbody.appendChild(row);
        });
    }

    updateEventDates(startDate, endDate) {
        if (startDate) document.getElementById('start-date').textContent = startDate;
        if (endDate) document.getElementById('end-date').textContent = endDate;
    }

    updateTimeRemaining(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;

        document.getElementById('time-remaining').textContent =
            `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }

    claimReward(pumpkinsRequired) {
        fetch(`https://${GetParentResourceName()}/claimPumpkinReward`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ pumpkinsRequired })
        })
            .then(res => res.json())
            .then(data => {
                this.playerData = data.playerData || this.playerData;
                this.rewards = data.rewards || this.rewards;
                this.leaderboard = data.leaderboard || this.leaderboard;

                this.closeMenu();
            })
            .catch(err => console.error('[PUMPKIN] Error al reclamar recompensa:', err));
    }

}

const pumpkinSystem = new PumpkinSystem();

function closePumpkinMenu() {
    pumpkinSystem.closeMenu();
}

window.addEventListener('message', (event) => {
    const data = event.data;

    if (!data.type) return;

    switch (data.type) {
        case 'openPumpkinMenu':
            pumpkinSystem.openMenu(data.data);
            break;

        case 'closePumpkinMenu':
            pumpkinSystem.closeMenu();
            break;

        case 'updatePumpkinStats':
            pumpkinSystem.updateStats(data.data);
            break;

        case 'updatePumpkinLeaderboard':
            pumpkinSystem.updateLeaderboard(data.data);
            break;
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && pumpkinSystem.menuOpen) {
        pumpkinSystem.closeMenu();
    }
});