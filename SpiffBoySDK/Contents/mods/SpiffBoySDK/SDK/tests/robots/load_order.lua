local order, watched = ...

local moduleOf = {}
local tops = {}
local errors = {}

--- Returns the watched module whose file is the given chunk source, or false.
local function watchedModule(source)
    local known = moduleOf[source]
    if known ~= nil then
        return known
    end
    moduleOf[source] = false
    for _, name in ipairs(watched) do
        local suffix = "/" .. name .. ".lua"
        if string.sub(source, -string.len(suffix)) == suffix then
            moduleOf[source] = name
        end
    end
    return moduleOf[source]
end

--- Records the type of each local of the top of a watched file while its main chunk runs, keeping the moment when the most of them are in scope.
local function watch()
    local info = debug.getinfo(2, "S")
    if info.what ~= "main" then
        return
    end
    local name = watchedModule(info.source)
    if not name then
        return
    end
    local snapshot, count, i = {}, 0, 1
    while true do
        local localName, value = debug.getlocal(2, i)
        if not localName then
            break
        end
        if string.sub(localName, 1, 1) ~= "(" then
            snapshot[localName] = type(value)
            count = count + 1
        end
        i = i + 1
    end
    local best = tops[name]
    if not best or count >= best.count then
        tops[name] = { count = count, locals = snapshot }
    end
end

--- Requires a module and keeps the error it raised under the watched file that failed.
local function load(name)
    ROBOT.loadFailure = nil
    local ok, problem = pcall(require, name)
    if not ok and ROBOT.loadFailure then
        local failed = watchedModule("@" .. ROBOT.loadFailure)
        if failed then
            errors[failed] = errors[failed] or tostring(problem)
        end
    end
end

debug.sethook(watch, "", 1)
for _, name in ipairs(order) do
    load(name)
end
debug.sethook()

local results = {}
for _, name in ipairs(watched) do
    results[name] = { locals = tops[name] and tops[name].locals, error = errors[name] }
end
return results
