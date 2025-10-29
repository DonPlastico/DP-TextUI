fx_version 'adamant'
game 'gta5'

author 'DP-Scripts'
description 'Sistema de TextUI avanzado para qb-core y esx'
version '1.0.0'

shared_script 'config.lua'
client_script {
    'client/main.lua',
    -- 'client/example.lua',
}

-- La página principal del TextUI se mantiene
ui_page 'ui/index.html'

files {
    -- Archivos para la TextUI principal (index.html, style.css, script.js)
    'ui/index.html', 
    'ui/style.css', 
    'ui/script.js',
    'ui/notification.ogg'
}
