// ==========================================================
// 1. VARIABLES Y CONFIGURACIÓN INICIAL (DEFAULTS)
// ==========================================================

const container = document.getElementById('container');
const elements = {}; // Elementos TextUI activos
let Config = { // Configuración por defecto (recibida de LUA al inicio)
    Spacing: 0.045,
    Position: {
        x: 0.02,
        y: 0.7
    }
};

// ** NUEVAS VARIABLES DE AJUSTES **
const DEFAULT_SETTINGS = {
    // soundToggle: true por defecto (según la solicitud)
    soundToggle: true,
    // volumen: 50 por defecto (medio, según el HTML)
    volume: 50,
    // position: 'left' por defecto (¡CORREGIDO!)
    position: 'left', 
};

let playerSettings = {}; // Configuraciones guardadas del jugador (se cargan al inicio)
let tempSettings = {};   // Configuraciones temporales (cambios en el formulario)
const notificationSound = new Audio('notification.ogg'); // Crea el objeto de sonido

// ==========================================================
// 2. FUNCIONES DE UTILIDAD PARA AJUSTES
// ==========================================================

// Función para mapear las posiciones de texto a coordenadas LUA (x, y)
function getPositionCoords(position) {
    // NOTA: FiveM NUI usa coordenadas normalizadas (0 a 1)
    switch (position) {
        case 'left': return { x: 0.015, y: 0.725 }; // Esta es tu posición "Izquierda (Default)"
        case 'top-center': return { x: 0.45, y: 0.002 };
        case 'top-right': return { x: 0.88, y: 0.002 };
        case 'center-left': return { x: 0.015, y: 0.45 };
        case 'center-right': return { x: 0.88, y: 0.45 };
        case 'bottom-center': return { x: 0.45, y: 0.956 };
        case 'bottom-right': return { x: 0.88, y: 0.956 };
        default: return { x: 0.015, y: 0.725 }; // Default del config inicial
    }
}

// Función para inicializar los valores del formulario con las configuraciones (playerSettings)
function loadSettingsToForm(settings) {
    // 1. Usar el valor de settings.volume o el valor por defecto (50) como fallback
    const validVolume = settings.volume !== undefined ? settings.volume : DEFAULT_SETTINGS.volume;

    document.getElementById('toggle-sound').checked = settings.soundToggle;
    document.getElementById('volume-slider').value = validVolume; // Usar el valor validado
    document.getElementById('position-select').value = settings.position;

    // Inicializar el volumen del audio usando el valor validado (0-1)
    notificationSound.volume = validVolume / 100;

    // Sincronizar tempSettings con los valores cargados
    tempSettings = { ...settings, volume: validVolume }; // Asegura que tempSettings tenga el valor
}

// ** NUEVA FUNCIÓN: Reproducir sonido condicionalmente **
function PlayNotificationSound() {
    // Usamos el playerSettings.volume o el valor por defecto (50) como fallback
    const currentVolume = playerSettings.volume !== undefined ? playerSettings.volume : DEFAULT_SETTINGS.volume;

    // 1. Comprobar si el sonido está activado en las configuraciones guardadas
    if (playerSettings.soundToggle) {
        // 2. Establecer el volumen del objeto Audio según el valor validado
        notificationSound.volume = currentVolume / 100;

        // 3. Reproducir (reinicio si ya está sonando)
        notificationSound.currentTime = 0;
        notificationSound.play();
    }
}

// Función para enviar las configuraciones guardadas a LUA (para aplicar los cambios)
function saveSettingsToLUA(settings) {
    // 1. Obtener las coordenadas X/Y de la posición seleccionada
    const newCoords = getPositionCoords(settings.position);

    // 2. Enviar el mensaje a LUA
    fetch(`https://DP-TextUI/saveClientSettings`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            soundToggle: settings.soundToggle,
            volume: settings.volume,
            position: settings.position,
            x: newCoords.x,
            y: newCoords.y
        }),
    }).then(resp => resp.json());

    // NOTA: LUA debe tener un RegisterNuiCallback('saveClientSettings', ...)
}

// ==========================================================
// 3. EVENT LISTENERS NUI (Mensajes de LUA)
// ==========================================================

window.addEventListener('message', (event) => {
    const data = event.data;
    const settingsContainer = document.getElementById('settings-ui-container');

    switch (data.type) {
        case 'config': // Recibir configuración inicial de LUA
            Config = data.data;
            break;

        // ** NUEVO CASO: Recibir configuraciones guardadas o por defecto **
        case 'DP-TextUI:Client:LoadSettings':
            // Inicializar las configuraciones del jugador con los datos recibidos (si existen)
            // Si no recibe datos (es la primera vez), usará DEFAULT_SETTINGS
            playerSettings = { ...DEFAULT_SETTINGS, ...data.settings };

            // Cargar los valores iniciales en el formulario temporal
            loadSettingsToForm(playerSettings);
            break;
        // ***************************************************************

        case 'DP-TextUI:Client:OpenSettingsUI':
            if (settingsContainer) {
                settingsContainer.style.display = 'flex';
                // Recargar el formulario con los playerSettings guardados para asegurar consistencia
                loadSettingsToForm(playerSettings);
            }
            break;

        case 'DP-TextUI:Client:CloseSettingsUI':
            if (settingsContainer) {
                settingsContainer.style.display = 'none';
                // Restaurar los valores temporales del formulario a los guardados (si no se pulsa 'Guardar')
                loadSettingsToForm(playerSettings);
            }
            break;

        case 'updatePosition':
            // 1. Aplicar la nueva posición base
            Config.Position.x = data.x;
            Config.Position.y = data.y;

            // 2. Recalcular y reposicionar todos los elementos existentes
            let i = 0;
            // 'elements' contiene todas las TextUI activas en el DOM
            Object.values(elements).forEach(el => {
                // Calcular la nueva posición vertical (base + espaciado)
                let newYOffset = Config.Position.y + (i * Config.Spacing);
                el.style.left = `${Config.Position.x * 100}%`;
                el.style.top = `${newYOffset * 100}%`;
                i++;
            });
            break;

        case 'create':
            CreateUI(data.data);
            // ** Reproducir sonido al crear/mostrar la TextUI **
            PlayNotificationSound();
            break;

        case 'remove':
            RemoveUI(data.id);
            break;

        case 'update':
            const element = elements[data.id];
            if (element && data.data.yOffset) {
                element.style.top = `${data.data.yOffset * 100}%`;
            }
            break;

        case 'progress':
            UpdateProgress(data.id, data.progress);
            break;
    }
});

// ==========================================================
// 4. LÓGICA DEL FORMULARIO DE AJUSTES (Guardar, Restaurar, Inputs)
// ==========================================================

document.addEventListener('DOMContentLoaded', (event) => {
    const closeButton = document.getElementById('close-button');
    const saveButton = document.getElementById('save-settings');
    const restoreButton = document.getElementById('restore-settings');
    const volumeSlider = document.getElementById('volume-slider');

    // Manejar el cierre con la 'X'
    if (closeButton) {
        closeButton.addEventListener('click', function () {
            // Enviamos el callback a LUA para que cierre NUIFocus
            fetch(`https://DP-TextUI/closeSettingsUI`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({}),
            });
        });
    }

    // ----------------------------------------------------
    // Capturar cambios en el formulario y guardar en tempSettings
    // ----------------------------------------------------

    // Toggle de Sonido
    document.getElementById('toggle-sound').addEventListener('change', (e) => {
        tempSettings.soundToggle = e.target.checked;
    });

    // Slider de Volumen
    volumeSlider.addEventListener('input', (e) => {
        const newVolume = parseInt(e.target.value, 10);
        tempSettings.volume = newVolume;
        // Opcional: escuchar el cambio en tiempo real
        notificationSound.volume = newVolume / 100;

        // Opcional: Test de sonido al arrastrar el slider
        if (newVolume > 0 && playerSettings.soundToggle) {
            notificationSound.currentTime = 0;
            notificationSound.play();
        }
    });

    // Select de Posición
    document.getElementById('position-select').addEventListener('change', (e) => {
        tempSettings.position = e.target.value;
    });

    // ----------------------------------------------------
    // Botón GUARDAR CAMBIOS
    // ----------------------------------------------------
    if (saveButton) {
        saveButton.addEventListener('click', function () {
            // Aplicar los cambios temporales a las configuraciones guardadas
            playerSettings = { ...tempSettings };

            // Enviar la nueva configuración a LUA para aplicarla y guardarla
            saveSettingsToLUA(playerSettings);

            // Opcional: Cerrar el menú
            fetch(`https://DP-TextUI/closeSettingsUI`, { method: 'POST', body: JSON.stringify({}) });
        });
    }

    // ----------------------------------------------------
    // Botón RESTAURAR
    // ----------------------------------------------------
    if (restoreButton) {
        restoreButton.addEventListener('click', function () {
            // 1. Restaurar las configuraciones temporales a los valores por defecto
            tempSettings = { ...DEFAULT_SETTINGS };

            // 2. Aplicar los defaults al formulario visible y a las configuraciones guardadas
            playerSettings = { ...DEFAULT_SETTINGS };

            // 3. Cargar los defaults en el formulario (visual)
            loadSettingsToForm(DEFAULT_SETTINGS);

            // 4. Enviar los defaults a LUA para aplicarlos y guardarlos
            saveSettingsToLUA(playerSettings);
        });
    }

    if (closeButton) {
        closeButton.addEventListener('click', function () {
            // Enviamos el callback a LUA para que cierre NUIFocus
            fetch(`https://DP-TextUI/closeSettingsUI`, { // ¡CORRECCIÓN! Usar HTTPS
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                // El body puede estar vacío, solo necesitamos que LUA reciba la llamada
                body: JSON.stringify({}),
            });
        });
    }

    // Opcional: También puedes añadir el cierre con ESC aquí, aunque LUA ya lo hace de forma más robusta
    document.onkeyup = function (data) {
        if (data.key === 'Escape') {
            const settingsContainer = document.getElementById('settings-ui-container');
            if (settingsContainer && settingsContainer.style.display === 'flex') {
                fetch(`https://DP-TextUI/closeSettingsUI`, { method: 'POST', body: JSON.stringify({}) }); // ¡CORRECCIÓN! Usar HTTPS
            }
        }
    };
});

// ==========================================================
// 5. FUNCIONES DE LÓGICA DE TEXTUI (Sin cambios)
// ==========================================================

function CreateUI(data) {
    if (elements[data.id]) {
        RemoveUI(data.id);
    }

    const element = document.createElement('div');
    element.className = 'textui-element';
    element.id = `textui-${data.id}`;
    element.style.left = `${data.x * 100}%`;
    element.style.top = `${data.yOffset * 100}%`;
    element.dataset.originalY = data.yOffset;

    const contentElement = document.createElement('div');
    contentElement.className = 'textui-content';

    const keyElement = document.createElement('span');
    keyElement.className = 'textui-key';
    keyElement.textContent = data.key;

    const actionElement = document.createElement('span');
    actionElement.textContent = data.action;

    contentElement.appendChild(keyElement);
    contentElement.appendChild(actionElement);
    element.appendChild(contentElement);

    if (data.hold) {
        const progressContainer = document.createElement('div');
        progressContainer.className = 'progress-container';

        const progressBar = document.createElement('div');
        progressBar.className = 'hold-progress';
        progressBar.style.width = '0%';

        progressContainer.appendChild(progressBar);
        element.appendChild(progressContainer);
    }

    container.appendChild(element);
    elements[data.id] = element;

    setTimeout(() => {
        element.classList.add('visible');
    }, 10);
}

function RemoveUI(id) {
    const element = elements[id];
    if (!element) return;

    // Guardar la posición original del elemento que se va a eliminar
    const removedPosition = parseFloat(element.style.top) / 100;

    // Iniciar animación de fade out
    element.classList.remove('visible');

    // Eliminar el elemento del registro inmediatamente
    delete elements[id];

    // Ajustar posiciones de los elementos restantes
    Object.values(elements).forEach(el => {
        const currentPos = parseFloat(el.style.top) / 100;
        if (currentPos < removedPosition) {
            // Mover hacia arriba los elementos que estaban debajo
            const newPos = currentPos + Config.Spacing;
            el.style.top = `${newPos * 100}%`;
        }
    });

    // Eliminar el elemento del DOM después de la animación
    setTimeout(() => {
        element.remove();
    }, 300);
}

function UpdateProgress(id, progress) {
    const element = elements[id];
    if (!element) return;

    const progressBar = element.querySelector('.hold-progress');
    if (progressBar) {
        // Añadir transición suave
        progressBar.style.transition = 'width 0.1s ease-out';
        progressBar.style.width = `${progress}%`;

        // Mantener posición durante la animación
        element.style.zIndex = progress > 0 ? '10' : '1';
    }
}