# DP-TextUI - Sistema Avanzado de Interfaz de Texto 🚀
Un sistema de TextUI moderno, optimizado y completamente personalizable para FiveM, compatible con qb-core, ESX y modo standalone.

![Demo de DP-TextUI](https://imgur.com/a/Pbr8KyB)

---

## 🔧 Instalación
1. Coloca la carpeta `DP-TextUI` en tu directorio `resources/`
2. Añade `ensure DP-TextUI` en tu `server.cfg`
3. Reinicia tu servidor

**Requisitos**:
- FiveM (Recomendado: versión más reciente)
- qb-core **o** ESX (opcional para modo standalone)

---

## ✨ Novedades en la Versión 2.0
✅ **Sistema de posicionamiento mejorado**: Ahora los elementos se reorganizan automáticamente sin superposiciones  
✅ **Animaciones fluidas**: Transiciones suaves al mostrar/ocultar elementos  
✅ **Gestión de memoria optimizada**: Eliminación limpia de elementos sin artefactos visuales  
✅ **Soporte para múltiples instancias**: Hasta 10 TextUI simultáneos con espaciado automático  
✅ **Compatibilidad mejorada**: Funciona perfectamente con todos los frameworks principales

---

## 💡 Características Clave
✔️ Sistema de IDs único para múltiples TextUI  
✔️ Soporte para acciones mantenidas con barra de progreso animada  
✔️ Posicionamiento automático y dinámico de múltiples elementos  
✔️ Compatibilidad total con qb-core y ESX (incluye adaptador de reemplazo)
✔️ Efectos visuales profesionales (pulsaciones, sombras, transiciones)  
✔️ Sistema de depuración integrado (Config.Debug = true)

---

### 🛠 Soporte Técnico
# Si encuentras problemas:
1. Verifica que el recurso esté iniciado y se llama 'DP-TextUI' (Si cambias el nombre puede dejar de funcionar).
2. Revisa la consola F8 para errores.
3. Asegúrate de usar IDs únicos.
4. Habilita Config.Debug = true para diagnóstico.
   ¡Listo para implementar! 🎉

# Mejoras principales incluidas:
1. Sección de Novedades: Destaca las mejoras que hemos implementado
2. Ejemplos más completos: Incluyendo el manejo de múltiples TextUI.
3. Código listo para usar: Ejemplos copiables directamente.
4. Organización visual: Secciones bien diferenciadas.
5. Solución completa: Incluye adaptador para reemplazar qb-core totalmente.
6. Enfoque práctico: Explicaciones concisas con ejemplos reales.

---

### 📚 Mostrar un TextUI
```lua
-- Mostrar texto simple
exports['DP-TextUI']:MostrarUI('menu_principal', 'Para abrir el menú', 'E', false)

-- Ocultar específico
exports['DP-TextUI']:OcultarUI('menu_principal')

-- Ocultar todos los TextUI
exports['DP-TextUI']:OcultarUI()

-- Manejar finalización Ejemplo simple
local holdCompleted = false

-- Evento cuando se completa la acción de mantener presionado
AddEventHandler('DP-TextUI:ActionCompleted', function(id)
    if id == "textui_test3" then
        holdCompleted = true
        QBCore.Functions.Notify('¡Puedes soltar ahora!', 'success', 5000)
    end
end)
```

## 📍 Ejemplo Avanzado con Zonas
```lua
local inZone = false
local activeTexts = {}

CreateThread(function()
    local coords = vector3(120.0, -200.0, 30.0)
    
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local distance = #(playerCoords - coords)
        local waitTime = 1000

        if distance < 3.0 then
            waitTime = 0
            if not inZone then
                -- Mostrar múltiples TextUI
                exports['DP-TextUI']:MostrarUI('npc_tienda', 'Hablar con vendedor', 'E', false)
                exports['DP-TextUI']:MostrarUI('npc_robar', 'Forzar cerradura', 'F', true, 3000)
                activeTexts = {'npc_tienda', 'npc_robar'}
                inZone = true
            end
        elseif inZone then
            -- Ocultar todos limpiamente
            for _, id in ipairs(activeTexts) do
                exports['DP-TextUI']:OcultarUI(id)
            end
            activeTexts = {}
            inZone = false
        end

        Wait(waitTime)
    end
end)
```


## 🔄 Migración desde qb-core
# Antes:
```lua
-- Mostrar
exports['qb-core']:DrawText('Presiona [E] para abrir', 'left')

-- Ocultar
exports['qb-core']:HideText()

-- O mediante eventos
TriggerEvent('qb-core:client:DrawText', 'Texto', 'left')
TriggerEvent('qb-core:client:HideText')
```

# Después (DP-TextUI):
```lua
-- Mostrar (equivalente básico)
exports['DP-TextUI']:MostrarUI('ejemplo_id', 'Texto de ejemplo', 'E', false)

-- Ocultar (equivalente)
exports['DP-TextUI']:OcultarUI('ejemplo_id')

-- Versión mejorada con más opciones
exports['DP-TextUI']:MostrarUI('menu_avanzado', 'Menú avanzado', 'F', true, 2000)
```

# Adaptador completo para qb-core:
```lua
-- Reemplazar DrawText/HideText globalmente
RegisterNetEvent('qb-core:client:DrawText')
AddEventHandler('qb-core:client:DrawText', function(text, position)
    exports['DP-TextUI']:MostrarUI('qbcomp_'..math.random(1000,9999), text, 'E', false)
end)

RegisterNetEvent('qb-core:client:HideText')
AddEventHandler('qb-core:client:HideText', function()
    exports['DP-TextUI']:OcultarUI()
end)

-- Para exports directos
local originalDrawText = exports['qb-core'].DrawText
local originalHideText = exports['qb-core'].HideText

exports('DrawText', function(text, position)
    exports['DP-TextUI']:MostrarUI('qb_text_'..math.random(100,999), text, 'E', false)
end)

exports('HideText', function()
    exports['DP-TextUI']:OcultarUI()
end)
```
