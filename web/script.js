// DPS City Worker - Control Room UI

window.addEventListener('message', function(event) {
    let data = event.data;

    if (data.action === 'open') {
        document.getElementById('app').style.display = 'flex';
        updateGrid(data.sectors);
    } else if (data.action === 'close') {
        document.getElementById('app').style.display = 'none';
    } else if (data.action === 'update') {
        updateGrid(data.sectors);
    }
});

// Close button
document.getElementById('close-btn').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });
});

// ESC key to close
document.addEventListener('keyup', function(e) {
    if (e.key === 'Escape') {
        fetch(`https://${GetParentResourceName()}/closeUI`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        });
    }
});

function updateGrid(sectors) {
    for (const [id, info] of Object.entries(sectors)) {
        let card = document.getElementById(`sector-${id}`);
        if (card) {
            let bar = card.querySelector('.health-bar');
            let val = card.querySelector('.health-val');
            let status = card.querySelector('.status-indicator');

            const health = typeof info === 'object' ? info.health : info;
            bar.style.width = health + '%';
            val.innerText = Math.floor(health);

            // Update color based on health
            if (health <= 20) {
                card.classList.add('critical');
                status.innerText = "CRITICAL";
                bar.style.background = '#ff3333';
            } else if (health <= 50) {
                card.classList.remove('critical');
                status.innerText = "WARNING";
                bar.style.background = 'linear-gradient(90deg, #ffaa00, #ff6600)';
            } else {
                card.classList.remove('critical');
                status.innerText = "ONLINE";
                bar.style.background = 'linear-gradient(90deg, #00ff88, #00aaff)';
            }
        }
    }
}

function dispatchCrew(sector) {
    fetch(`https://${GetParentResourceName()}/dispatchCrew`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ sector: sector })
    }).then(response => {
        console.log("Dispatched crew to " + sector);
    });
}
