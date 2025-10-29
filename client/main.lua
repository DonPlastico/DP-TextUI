-- ==========================================================
-- 1. VARIABLES GLOBALES y CONFIGURACIÓN INICIAL
-- ==========================================================
local activeUIs = {}
local framework = nil
local QBCore, ESX = nil, nil
local isSettingsUIOpen = false
local playerSettings = {} -- NUEVO: Almacena los ajustes del jugador

-- El Config se carga automáticamente si está en el mismo recurso
Config = Config or {}

-- Mapeo de controles (Se usa tanto en el TextUI como en la lógica de hold/close)
local controlMappings = {
    ['E'] = 38, -- INPUT_PICKUP
    ['F'] = 23, -- INPUT_ENTER
    ['G'] = 47, -- INPUT_DETONATE
    ['~'] = 243, -- INPUT_ENTER_CHEAT_CODE
    ['ENTER'] = 18, -- INPUT_CELLPHONE_SELECT
    ['BACKSPACE'] = 177, -- INPUT_CELLPHONE_CANCEL
    ['SPACE'] = 22, -- INPUT_JUMP
    ['LSHIFT'] = 21, -- INPUT_SPRINT
    ['LCTRL'] = 36, -- INPUT_DUCK
    ['LALT'] = 19, -- INPUT_CHARACTER_WHEEL
    ['TILDE'] = 243, -- Alias para ~
    ['SHIFT'] = 21, -- Alias para LSHIFT
    ['CTRL'] = 36, -- Alias para LCTRL
    ['ALT'] = 19 -- Alias para LALT
}

-- ==========================================================
-- 2. FUNCIÓN DE INICIO y GESTIÓN DE FRAMEWORK
-- ==========================================================

-- Enviar configuración inicial al NUI
Citizen.CreateThread(function()
    while true do
        if NetworkIsSessionStarted() then
            SendNUIMessage({
                type = 'config',
                data = Config
            })
            break
        end
        Citizen.Wait(100)
    end
end)

-- ==========================================================
-- 3. LÓGICA DE CARGA DE ESTADO (KVP)
-- ==========================================================

Citizen.CreateThread(function()
    -- Esperamos un momento para asegurar que Config está cargado
    Citizen.Wait(500)

    -- Usamos un KVP (Key-Value Pair) para guardar la configuración del jugador
    local savedData = GetResourceKvpString('DPTextUISettings')

    if savedData and savedData ~= "" then
        -- Asumo que tienes una librería JSON (como ox_lib, o el JSON nativo de tu framework)
        -- Si usas un JSON nativo de Lua, asegúrate de que esté cargado en tu fxmanifest
        playerSettings = json.decode(savedData)

        if Config.Debug then
            print('^2[DP-TextUI] Ajustes guardados encontrados y cargados.^0')
        end
    else
        -- Valores por defecto (mantienen consistencia con DEFAULT_SETTINGS en script.js)
        playerSettings = {
            soundToggle = true,
            volume = 50,
            position = 'center-left',
            x = Config.Position.x, -- Usa el valor por defecto de config.lua
            y = Config.Position.y -- Usa el valor por defecto de config.lua
        }
        if Config.Debug then
            print('^3[DP-TextUI] No hay ajustes guardados, usando valores por defecto.^0')
        end
    end

    -- Aplicar la posición guardada al Config global, que se usa para posicionar las TextUI
    if playerSettings.x and playerSettings.y then
        Config.Position.x = playerSettings.x
        Config.Position.y = playerSettings.y
        if Config.Debug then
            print(string.format('^2[DP-TextUI] Posición inicial aplicada: X=%.3f, Y=%.3f^0', Config.Position.x,
                Config.Position.y))
        end
    end
end)

-- Función para mezclar tablas
local function TableMerge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t1[k] or false) == "table" then
            TableMerge(t1[k] or {}, t2[k] or {})
        else
            t1[k] = v
        end
    end
    return t1
end

-- Modifica la función GetKeyName para mantener consistencia
local function GetKeyName(key)
    local keyMappings = {
        ['E'] = 'E',
        ['F'] = 'F',
        ['G'] = 'G',
        ['~'] = 'TILDE',
        ['ENTER'] = 'ENTER',
        ['BACKSPACE'] = 'BACKSPACE',
        ['SPACE'] = 'SPACE',
        ['LSHIFT'] = 'SHIFT',
        ['LCTRL'] = 'CTRL',
        ['LALT'] = 'ALT'
    }
    return keyMappings[key] or string.upper(key)
end

local function ShowNotification(msg, type, length)
    if framework == 'qb' and QBCore then
        QBCore.Functions.Notify(msg, type or 'primary', length or 5000)
    elseif framework == 'esx' and ESX then
        ESX.ShowNotification(msg)
    else
        -- Modo standalone
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(true, true)
    end
end

-- Calcular posición Y basado en cuántos UIs hay activos
function CalculateYOffset()
    local count = 0
    local baseY = Config.Position.y

    -- Primero contar cuántos elementos hay activos
    for _ in pairs(activeUIs) do
        count = count + 1
    end

    -- Calcular posición basada solo en el orden, no en el contenido
    return baseY - (Config.Spacing * (count - 1))
end

-- Recalcular posiciones cuando se elimina un UI
function RecalculatePositions()
    local sortedUIs = {}
    -- Primero recolectamos todos los UIs activos
    for _, ui in pairs(activeUIs) do
        table.insert(sortedUIs, ui)
    end

    -- Ordenamos por posición Y original (de menor a mayor, que es de abajo hacia arriba)
    table.sort(sortedUIs, function(a, b)
        return (a.yOffset or 0) < (b.yOffset or 0)
    end)

    -- Reasignamos posiciones manteniendo el orden pero ajustando el espaciado
    for i, ui in ipairs(sortedUIs) do
        local newY = Config.Position.y - (Config.Spacing * (i - 1))
        if math.abs(ui.yOffset - newY) > 0.001 then
            ui.yOffset = newY
            SendNUIMessage({
                type = 'update',
                id = ui.id,
                data = {
                    yOffset = ui.yOffset
                }
            })
        end
    end
end

-- ==========================================================
-- 3. GESTIÓN DEL FRAMEWORK E INICIALIZACIÓN
-- ==========================================================

-- Funciones que estaban en utils.lua
local function DetectFramework()
    if Config.Framework ~= 'auto' then
        return Config.Framework
    end

    if GetResourceState('qb-core') == 'started' then
        return 'qb'
    elseif GetResourceState('es_extended') == 'started' then
        return 'esx'
    else
        print('^1[DP-TextUI] No se detectó ningún framework compatible. Usando modo standalone.^0')
        return 'standalone'
    end
end

-- Inicialización
Citizen.CreateThread(function()
    framework = DetectFramework()

    if framework == 'qb' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif framework == 'esx' then
        while ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj)
                ESX = obj
            end)
            Wait(100)
        end
    end

    if Config.Debug then
        print(string.format('^2[DP-TextUI] Framework detectado: %s^0', framework))
    end

    -- Enviar configuración inicial al NUI
    while true do
        if NetworkIsSessionStarted() then
            SendNUIMessage({
                type = 'config',
                data = Config
            })
            break
        end
        Citizen.Wait(100)
    end
end)

-- ==========================================================
-- 4. LÓGICA PRINCIPAL DEL DP-TextUI (Mostrar/Ocultar y Remover)
-- ==========================================================

-- Eliminar UI y reajustar posiciones
function RemoveUI(id)
    if activeUIs[id] then
        -- Guardamos la posición Y original para referencia
        local removedPosition = activeUIs[id].yOffset

        -- Eliminamos el UI
        SendNUIMessage({
            type = 'remove',
            id = id
        })

        -- Marcamos como eliminado inmediatamente
        activeUIs[id] = nil

        -- Ajustamos posiciones de los elementos restantes
        for _, ui in pairs(activeUIs) do
            if ui.yOffset < removedPosition then
                ui.yOffset = ui.yOffset + Config.Spacing
                SendNUIMessage({
                    type = 'update',
                    id = ui.id,
                    data = {
                        yOffset = ui.yOffset
                    }
                })
            end
        end
    end
end

-- Export para mostrar UI
local function MostrarUI(id, action, key, hold, duration)
    if activeUIs[id] then
        if Config.Debug then
            print(string.format('^3[DP-TextUI] ID %s ya existe, actualizando...^0', id))
        end
        RemoveUI(id)
    end

    local uiData = {
        id = id,
        action = action,
        key = GetKeyName(key),
        hold = hold or false,
        duration = duration or 0,
        x = Config.Position.x,
        yOffset = CalculateYOffset(),
        startTime = nil -- Lo usaremos para calcular el progreso
    }

    activeUIs[id] = uiData
    SendNUIMessage({
        type = 'create',
        data = uiData
    })
end

-- Export para ocultar UI
local function OcultarUI(id)
    if id then
        RemoveUI(id)
    else
        -- Si no se proporciona ID, eliminar todos
        for k, _ in pairs(activeUIs) do
            RemoveUI(k)
        end
    end
end

-- ==========================================================
-- 5. MANEJO DE INPUTS (Pulsación y Mantener Pulsado)
-- ==========================================================

-- Comprobar inputs de teclas
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        for id, ui in pairs(activeUIs) do
            local key = ui.key:upper()
            local controlCode = controlMappings[key]

            if controlCode and ui.hold then
                if IsControlPressed(0, controlCode) then
                    -- Iniciar acción si no estaba en progreso
                    if not ui.inProgress then
                        ui.inProgress = true
                        ui.startTime = GetGameTimer()
                        if ui.holdOptions and ui.holdOptions.onStart then
                            ui.holdOptions.onStart()
                        end
                    end

                    -- Calcular progreso
                    local progress = (GetGameTimer() - ui.startTime) / ui.duration * 100
                    progress = math.min(progress, 100)

                    -- Actualizar barra
                    SendNUIMessage({
                        type = 'progress',
                        id = id,
                        progress = progress
                    })

                    -- Comprobar si se completó
                    if progress >= 100 then
                        if ui.holdOptions then
                            if ui.holdOptions.onComplete then
                                ui.holdOptions.onComplete()
                            end
                            if ui.holdOptions.notifyComplete then
                                ShowNotification(ui.holdOptions.notifyComplete, ui.holdOptions.notifyType,
                                    ui.holdOptions.notifyLength)
                            end
                        end
                        RemoveUI(id)
                    end
                elseif ui.inProgress then
                    -- Acción cancelada
                    ui.inProgress = false
                    SendNUIMessage({
                        type = 'progress',
                        id = id,
                        progress = 0
                    })
                    if ui.holdOptions then
                        if ui.holdOptions.onCancel then
                            ui.holdOptions.onCancel()
                        end
                        if ui.holdOptions.notifyCancel and framework == 'qb' then
                            QBCore.Functions.Notify(ui.holdOptions.notifyCancel, 'error', ui.holdOptions.notifyLength)
                        end
                    end
                end
            elseif IsControlJustReleased(0, controlCode) then
                TriggerEvent('DP-TextUI:ActionPressed', id)
            end
        end
    end
end)

AddEventHandler('DP-TextUI:ActionCompleted', function(id)
    if activeUIs[id] and activeUIs[id].hold then
        -- Resetear el progreso cuando se completa
        SendNUIMessage({
            type = 'progress',
            id = id,
            progress = 0
        })
        activeUIs[id].startTime = nil
    end
end)

-- ==========================================================
-- 6. LÓGICA DEL MENÚ DE AJUSTES (Settings UI)
-- ==========================================================

-- Función para manejar la apertura de la UI
local function OpenSettingsUI()
    if not isSettingsUIOpen then
        isSettingsUIOpen = true
        SetNuiFocus(true, true)

        -- Enviar los ajustes guardados/cargados al JS para que el formulario se inicialice
        SendNUIMessage({
            type = Config.SettingsUI.OpenNuiEvent,
            settings = playerSettings -- ENVIAR LOS AJUSTES PERSISTENTES
        })

        if Config.Debug then
            print('^2[DP-TextUI] UI de ajustes abierta.^0')
        end
    end
end

-- Función para manejar el cierre de la UI
local function CloseSettingsUI()
    if isSettingsUIOpen then
        isSettingsUIOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({
            type = Config.SettingsUI.CloseNuiEvent
        })
        if Config.Debug then
            print('^2[DP-TextUI] UI de ajustes cerrada.^0')
        end
    end
end

-- Registrar el comando para abrir la UI
Citizen.CreateThread(function()
    -- Esperamos un momento para asegurar que Config está cargado
    Citizen.Wait(500)

    RegisterCommand(Config.SettingsUI.Command, function(source, args, rawCommand)
        OpenSettingsUI()
    end, false) -- 'false' indica que no se requiere permiso de administrador por defecto

    if Config.Debug then
        print(string.format('^2[DP-TextUI] Comando de ajustes registrado: /%s^0', Config.SettingsUI.Command))
    end
end)

-- Manejar el cierre desde la tecla ESC (o la configurada en CloseKey)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0) -- Bucle rápido para detectar inputs

        if isSettingsUIOpen then
            -- Prevenir que el juego detecte otros inputs mientras la UI está abierta
            DisableAllControlActions(0)

            -- Detectar la tecla de cierre configurada (por defecto ESC = 20)
            if IsControlJustReleased(0, Config.SettingsUI.CloseKey) then
                CloseSettingsUI()
            end
        end
    end
end)

-- Manejar el cierre desde la propia NUI (e.g., al pulsar la 'X')
RegisterNuiCallback('closeSettingsUI', function(data, cb)
    CloseSettingsUI()
    cb('ok') -- Callback para la función JS
end)

-- ** NUEVO CALLBACK: Recibir ajustes del JS y guardarlos **
RegisterNuiCallback('saveClientSettings', function(data, cb)
    -- 1. Llama al callback de JS inmediatamente para que la UI no se bloquee
    cb('ok')

    Citizen.CreateThread(function()
        -- Opcional: una pequeña espera para asegurar el contexto del hilo.
        Citizen.Wait(10)

        -- 2. Actualizar las variables de configuración
        playerSettings.soundToggle = data.soundToggle
        playerSettings.volume = data.volume
        playerSettings.position = data.position
        playerSettings.x = data.x
        playerSettings.y = data.y

        Config.Position.x = data.x
        Config.Position.y = data.y

        -- 4. Notificar al NUI para que re-renderice la posición
        SendNUIMessage({
            type = 'updatePosition',
            x = Config.Position.x,
            y = Config.Position.y
        })
    end)
end)

-- ==========================================================
-- 7. EXPORTS PARA OTROS SCRIPTS
-- ==========================================================

exports('MostrarUI', MostrarUI)
exports('OcultarUI', OcultarUI)
exports('OpenSettingsUI', OpenSettingsUI)
exports('CloseSettingsUI', CloseSettingsUI)

-- Export avanzado para acciones de mantener pulsado
exports('MostrarUIHold', function(id, text, key, duration, options)
    local defaultOptions = {
        onStart = nil,
        onComplete = nil,
        onCancel = nil,
        notifyComplete = nil,
        notifyCancel = nil,
        notifyType = 'success',
        notifyLength = 5000
    }

    options = options and TableMerge(defaultOptions, options) or defaultOptions

    MostrarUI(id, text, key, true, duration)
    activeUIs[id].holdOptions = options
end)
