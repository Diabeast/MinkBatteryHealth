const dialog=document.querySelector('#confirm');
const labels={climate:'Klimaat starten op 21 °C?',lock:'Auto vergrendelen?',charge:'Laden starten?',flash:'Lichten kort laten knipperen?'};
document.querySelectorAll('[data-command]').forEach(button=>button.addEventListener('click',()=>{dialog.dataset.command=button.dataset.command;document.querySelector('#confirmText').textContent=labels[button.dataset.command];dialog.showModal()}));
document.querySelector('#cancel').onclick=()=>dialog.close();
document.querySelector('#send').onclick=()=>{dialog.close();alert('De veilige backendkoppeling wordt in de volgende versie geactiveerd.');};
