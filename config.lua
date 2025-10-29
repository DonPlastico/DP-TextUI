Config = {
    Framework = 'auto', -- 'auto', 'qb', 'esx'. Auto detecta automáticamente

    -- Posición ajustada para estar justo encima del minimapa
    Position = {
        x = 0.015, -- 1.5% desde la izquierda
        y = 0.68 -- 68% desde arriba
    },

    -- Espaciado entre múltiples TextUI
    Spacing = 0.045, -- Espaciado entre elementos
    Debug = false,

    -- NUEVA SECCIÓN: Configuración del Menú de Ajustes
    SettingsUI = {
        Command = 'textuisettings', -- Comando para abrir el menú: /textuisettings

        -- Tecla para cerrar el menú (opcional, pero útil)
        -- Puedes usar códigos de control de FiveM (e.g., 20 = ESC, 177 = BACKSPACE)
        CloseKey = 20, -- Código 20 es la tecla ESC

        -- Nombre del evento NUI que se activará para mostrar la UI
        OpenNuiEvent = 'DP-TextUI:Client:OpenSettingsUI',

        -- Nombre del evento NUI que se activará para ocultar la UI
        CloseNuiEvent = 'DP-TextUI:Client:CloseSettingsUI'
    }
}
