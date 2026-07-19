fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bsrp-characters'
author 'BS Race'
description 'BSRP character creator + spawn selector — saves skin to bsrp_players.skin (clothing compatible)'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/skin.lua',
}

client_scripts {
    'client/skin.lua',
    'client/creator.lua',
    'client/select.lua',
    'client/spawn.lua',
    'client/main.lua',
}

server_script 'server/main.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

-- Soft framework: exports.bsrp when started (no hard dep — restart freely)

