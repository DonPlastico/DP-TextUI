Citizen.CreateThread(function()
    local coords = vector3(231.81, -792.39, 30.60)
    local inZone = false
    local activeTexts = {}
    local holdCompleted = false

    -- Evento cuando se completa la acción de mantener presionado
    AddEventHandler('DP-TextUI:ActionCompleted', function(id)
        if id == "textui_test3" then
            holdCompleted = true
            QBCore.Functions.Notify('¡Puedes soltar ahora!', 'success', 5000)
        end
    end)

    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local distance = #(playerCoords - coords)
        local waitTime = 500

        if distance <= 5.0 then
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 2.0, 255, 255,
                255, 100, false, true, 2, false, nil, nil, false)
            waitTime = 0

            if distance <= 2.0 then
                if not inZone then
                    exports['DP-TextUI']:OcultarUI()

                    -- Mostrar nuevos textos
                    exports['DP-TextUI']:MostrarUI("textui_test1", "Esto es la Prueba A", "A", false)
                    exports['DP-TextUI']:MostrarUI("textui_test2", "Como el A pero extra", "B", false)
                    exports['DP-TextUI']:MostrarUI("textui_test3", "Como el B", "C", false)

                    -- Mostrar el hold con callback para manejar su estado
                    exports['DP-TextUI']:MostrarUIHold("textui_hold", "Mantener pulsado", "E", 3000, {
                        notifyComplete = '¡Acción completada!',
                        onComplete = function()
                            holdCompleted = true
                        end
                    })

                    activeTexts = {"textui_test1", "textui_test2", "textui_test3", "textui_hold"}
                    inZone = true
                    holdCompleted = false
                end
            else
                if inZone then
                    -- Solo ocultar si no hay una acción hold en progreso
                    if not IsControlPressed(0, 38) or not holdActive then
                        for _, id in ipairs(activeTexts) do
                            exports['DP-TextUI']:OcultarUI(id)
                        end
                        activeTexts = {}
                        inZone = false
                    end
                end
            end
        else
            if inZone then
                for _, id in ipairs(activeTexts) do
                    exports['DP-TextUI']:OcultarUI(id)
                end
                activeTexts = {}
                inZone = false
            end
            Wait(waitTime)
        end

        Wait(0)
    end
end)