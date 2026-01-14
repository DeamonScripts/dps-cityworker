fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dps-cityworker'
author 'DeamonScripts & Randol'
description 'Advanced City Infrastructure & Career Simulation'
version '2.5.0'
repository 'https://github.com/DeamonScripts/dps-cityworker'

ui_page 'web/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'bridge/init.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'sv_config.lua',
    'sv_cityworker.lua',
}

client_scripts {
    'bridge/client.lua',
    'cl_cityworker.lua',
}

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
}

-- Optional: qb-core, qbx_core, or es_extended (auto-detected)

provides {
    'dps-cityworker',
}
