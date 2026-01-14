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

document.getElementById('close-btn').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8', },
        body: JSON.stringify({})
    });
});

function updateGrid(sectors) {
    for (const [id, info] of Object.entries(sectors)) {
        let card = document.getElementById(`sector-${id}`);
        if (card) {
            let bar = card.querySelector('.health-bar');
            let val = card.querySelector('.health-val');
            let status = card.querySelector('.status-indicator');

            bar.style.width = info.health + '%';
            val.innerText = Math.floor(info.health);

            if (info.health <= 20) {
                card.classList.add('critical');
                status.innerText = "CRITICAL";
            } else {
                card.classList.remove('critical');
                status.innerText = "ONLINE";
            }
        }
    }
}

function dispatchCrew(sector) {
    // Future roadmap feature: Automatically mark a GPS route for workers
    console.log("Dispatching crew to " + sector);
}
