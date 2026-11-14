fx_version 'cerulean'
game 'gta5'
use_experimental_fxv2_oal 'yes'
lua54 'yes'

name 'ox_lib'
author 'qbcore2 compatibility team; consumer modules by Overextended'
version '3.39.0'
license 'LGPL-3.0-or-later'
repository 'https://github.com/qbcore2/ox_lib'
description 'Headless ox_lib 3.39.0 compatibility surface backed by qblib'

dependencies {
    '/server:7290',
    '/onesync',
    'kora_lib',
}

files {
    'init.lua',
    'resource/settings.lua',
    'imports/**/client.lua',
    'imports/**/shared.lua',
    'locales/*.json',
    'modules/**/init.lua',
}

shared_script 'resource/init.lua'

shared_scripts {
    'resource/callbacks/shared.lua',
    'resource/version/shared.lua',
}

client_scripts {
    'resource/client.lua',
    'resource/cache/client.lua',
    'resource/locale/client.lua',
    'resource/vehicleProperties/client.lua',
    'resource/progressProps/client.lua',
    'resource/interface/client.lua',
    'resource/zoneCreator/client.lua',
    'resource/lifecycle/client.lua',
}

server_scripts {
    'imports/callback/server.lua',
    'imports/hook/shared.lua',
    'imports/registerHook/shared.lua',
    'imports/getFilesInDirectory/server.lua',
    'resource/acl/server.lua',
    'resource/server.lua',
    'resource/locale/server.lua',
    'resource/state/server.lua',
    'resource/vehicleProperties/server.lua',
    'resource/version/server.lua',
    'resource/interface/server/progress.lua',
    'resource/interface/server/txadmin.lua',
    'resource/zoneCreator/server.lua',
    'resource/lifecycle/server.lua',
}
