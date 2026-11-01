-- Executes each forwarded file the way a consumer VM would (fresh globals),
-- with mocked LoadResourceFile/exports.
local function readFile(path) local f = io.open(path, 'rb'); if not f then return nil end local s = f:read('a'); f:close(); return s end
local out = print
local failures = 0
local function check(name, cond) if not cond then failures = failures + 1; out('FAIL: ' .. name) else out('ok: ' .. name) end end

local function run(file, opts)
    opts = opts or {}
    -- load() inside the wrapper uses the real global table (as in FiveM), so
    -- mocks are installed in _G and consumer globals reset per run.
    local env = _G
    env.QBShared, env.QBConfig = opts.keep and env.QBShared or nil, nil
    env.print = function() end
    env.GetConvarInt = function(_, d) return d end
    env.LoadResourceFile = function(res, path)
        if res == 'qb-core' then return readFile(path) end
        if res == 'kora_core' then return readFile('../kora_core/' .. path) end
    end
    local shared = {
        Items = { bread = { name = 'bread' } }, Jobs = { police = { grades = { ['0'] = {} } } },
        Gangs = { ballas = {} }, Vehicles = { adder = {} }, VehicleHashes = { [1] = 'adder' },
        Weapons = { w = {} }, Locations = { a = {} },
        StarterItems = { phone = { amount = 1, item = 'phone' } }, MaleNoGloves = { [0] = true }, FemaleNoGloves = { [0] = true },
    }
    env.exports = setmetatable({}, { __index = function(_, res)
        assert(res == 'qb-core')
        return setmetatable({}, { __index = function(_, fn)
            return function(_, a)
                if opts.down then error('No such export ' .. fn) end
                if fn == 'GetShared' and not opts.noGetShared then return shared[a] end
                if fn == 'GetCoreObject' then return { Shared = shared, Config = { MaxPlayers = 12 } } end
                error('No such export ' .. fn)
            end
        end })
    end })
    assert(loadfile(file))()
    return env
end

local e = run('shared/items.lua'); check('items', e.QBShared.Items.bread.name == 'bread')
e = run('shared/jobs.lua'); check('jobs', e.QBShared.Jobs.police ~= nil)
e = run('shared/gangs.lua'); check('gangs', e.QBShared.Gangs.ballas ~= nil)
e = run('shared/vehicles.lua'); check('vehicles', e.QBShared.Vehicles.adder ~= nil and e.QBShared.VehicleHashes[1] == 'adder')
e = run('shared/weapons.lua'); check('weapons', e.QBShared.Weapons.w ~= nil)
e = run('shared/locations.lua'); check('locations', e.QBShared.Locations.a ~= nil)
e = run('config.lua'); check('config', e.QBConfig.MaxPlayers == 12)
e = run('shared/items.lua', { noGetShared = true }); check('items via GetCoreObject fallback', e.QBShared.Items.bread ~= nil)
e = run('shared/items.lua', { down = true }); check('items safe when kora_core down', type(e.QBShared.Items) == 'table' and next(e.QBShared.Items) == nil)
e = run('config.lua', { down = true }); check('config fallback', e.QBConfig.Money ~= nil)

e = run('shared/main.lua')
local S = e.QBShared
check('main RandomStr', #S.RandomStr(8) == 8)
check('main RandomInt', S.RandomInt(5):match('^%d+$') ~= nil)
check('main SplitStr', #S.SplitStr('a,b,c', ',') == 3)
check('main Trim', S.Trim('  x ') == 'x')
check('main FirstToUpper', S.FirstToUpper('abc') == 'Abc')
check('main Round', S.Round(1.2345, 2) == 1.23 and S.Round(1.5) == 2)
check('main IsFunction', S.IsFunction(print) and not S.IsFunction({}))
check('main data', S.StarterItems.phone.item == 'phone' and S.MaleNoGloves[0] == true)

-- Items added after main.lua must preserve the helpers on the same QBShared.
e = run('shared/items.lua', { keep = true })
check('items keeps helpers', e.QBShared.Trim ~= nil and e.QBShared.Items ~= nil)

os.exit(failures == 0 and 0 or 1)
