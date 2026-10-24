fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Lennart'
name 'len_fishing'
description 'len_fishing - ESX fishing system with ox_inventory integration'
version '1.0.0'

dependencies {
    'es_extended',
    'ox_inventory'
}

shared_scripts {
    'config.lua',
    'locales/init.lua',
    'locales/en.lua',
    'locales/de.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
