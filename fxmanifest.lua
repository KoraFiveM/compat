fx_version 'cerulean'

game 'gta5'

description 'Define zones of different shapes and test whether a point is inside or outside of the zone'

version '2.6.2'

dependency 'kora_lib'

shared_scripts {
    '@kora_lib/init.lua'
}

client_scripts {
    'client.lua',

    'BoxZone.lua',
    'EntityZone.lua',
    'CircleZone.lua',
    'ComboZone.lua',
}

server_scripts {
    'server.lua'
}
