local folder = assert(arg[1])
-- Use Mudlet's JSON module when available. A test-only Lua literal codec
-- keeps the I/O/recovery tests runnable in CI without a JSON dependency.
local function encode(value)
  if type(value) == "table" then
    local parts = {}
    for k, v in pairs(value) do parts[#parts + 1] = "[" .. encode(k) .. "]=" .. encode(v) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif type(value) == "string" then return string.format("%q", value)
  else return tostring(value) end
end
local hasJson, json = pcall(require, "yajl")
yajl = hasJson and json or { to_string = encode, to_value = function(s) return assert(loadstring("return " .. s))() end }
local rooms, areas, labels, mapData, handlers, timers, requests, messages
local settings = { mapsource = "service", crowdmapservicesend = true, crowdmapserviceurl = "https://example.test", crowdmapservicereports = 2 }
local function clone(t)
  if type(t) ~= "table" then return t end
  local out = {}; for k, v in pairs(t) do out[k] = clone(v) end; return out
end
local function freshRoom(id, area)
  return { id = id, name = "", coordinates = {0, 0, 0}, area = area or -1, weight = 1, symbol = "", environment = -1,
    hash = "", userData = {}, exits = {}, special = {}, locks = {}, weights = {}, doors = {} }
end
function getMudletHomeDir() return folder end
function registerNamedEventHandler(_, name, event, fn) handlers[event] = handlers[event] or {}; handlers[event][name] = fn end
function tempTimer(delay, fn) timers[#timers + 1] = {delay = delay, fn = fn}; return #timers end
function getRoomName(id) return rooms[id] and rooms[id].name end
function getRoomCoordinates(id) return unpack(rooms[id].coordinates) end
function getRoomArea(id) return rooms[id].area end
function getRoomWeight(id) return rooms[id].weight end
function getRoomChar(id) return rooms[id].symbol end
function getRoomEnv(id) return rooms[id].environment end
function getRoomHashByID(id) return rooms[id].hash end
function getRoomIDbyHash(hash) for id, r in pairs(rooms) do if hash ~= "" and r.hash == hash then return id end end; return -1 end
function getRoomUserData(id, key) return rooms[id] and (rooms[id].userData[key] or "") or "" end
function getAllRoomUserData(id) return clone(rooms[id].userData) end
function getRoomExits(id) return clone(rooms[id].exits) end
function getSpecialExits(id)
  local result = {}
  for cmd, dest in pairs(rooms[id].special) do
    result[dest] = result[dest] or {}; result[dest][cmd] = rooms[id].locks[cmd] and "1" or "0"
  end
  return result
end
function getExitWeights(id) return clone(rooms[id].weights) end
function getDoors(id) return clone(rooms[id].doors) end
function getAllRoomEntrances(destination)
  local result = {}
  for id, room in pairs(rooms) do
    for _, target in pairs(room.exits) do if target == destination then result[#result + 1] = id end end
    for _, target in pairs(room.special) do if target == destination then result[#result + 1] = id end end
  end
  return result
end
function getRooms() local result = {}; for id, r in pairs(rooms) do result[id] = r.name end; return result end
function getAreaTableSwap() return clone(areas) end
function getAreaTable() local result = {}; for id, name in pairs(areas) do result[name] = id end; return result end
function getAreaRooms(area) local result = {}; for id, r in pairs(rooms) do if r.area == area then result[#result + 1] = id end end; return result end
function getMapLabels(area) local result = {}; for id, label in pairs(labels[area] or {}) do result[id] = label.Text end; return result end
function getMapLabel(area, id) return clone((labels[area] or {})[id]) end
function getAllMapUserData() return clone(mapData) end
function enableAlias() end
function disableAlias() end
local function event(name, ...)
  for _, fn in pairs(handlers[name] or {}) do fn(name, ...) end
end
local function natives()
  function addAreaName(name)
    for _, existing in pairs(areas) do if existing == name then return nil, "exists" end end
    local id = 10; while areas[id] do id = id + 1 end; areas[id] = name; return id
  end
  function setAreaName(id, name) if not areas[id] then return nil, "missing" end; areas[id] = name; return true end
  function addRoom(id, area) if rooms[id] then return false end; rooms[id] = freshRoom(id, area); return true end
  function deleteRoom(id)
    if not rooms[id] then return false end
    rooms[id] = nil
    for _, r in pairs(rooms) do
      for dir, dest in pairs(r.exits) do if dest == id then r.exits[dir] = nil end end
      for cmd, dest in pairs(r.special) do if dest == id then r.special[cmd], r.locks[cmd], r.weights[cmd] = nil, nil, nil end end
    end
    return true
  end
  -- Native C++ area deletion does not call the wrapped Lua deleteRoom.
  local nativeDeleteRoom = deleteRoom
  function deleteArea(id)
    id = tonumber(id) or getAreaTable()[id]
    if not areas[id] then return false end
    for _, roomId in ipairs(getAreaRooms(id)) do nativeDeleteRoom(roomId) end
    areas[id], labels[id] = nil, nil; return true
  end
  function setRoomName(id, name) if not rooms[id] then return false end; rooms[id].name = name; return true end
  function setRoomCoordinates(id, x, y, z) if not rooms[id] then return nil, "missing", nil, 42 end; rooms[id].coordinates = {x, y, z}; return true, nil, 42 end
  function setRoomArea(id, area) if not rooms[id] or not areas[area] then return false end; rooms[id].area = area; return true end
  function setRoomWeight(id, weight) rooms[id].weight = weight; return true end
  function setRoomChar(id, symbol) rooms[id].symbol = symbol; return true end
  function setRoomEnv(id, env) rooms[id].environment = env; return true end
  function setRoomIDbyHash(id, hash) local old = getRoomIDbyHash(hash); if old ~= -1 then rooms[old].hash = "" end; rooms[id].hash = hash; return true end
  function setRoomUserData(id, key, value) rooms[id].userData[key] = value; return true end
  function clearRoomUserDataItem(id, key) rooms[id].userData[key] = nil; return true end
  function addSpecialExit(id, dest, cmd) rooms[id].special[cmd] = dest; return true end
  function removeSpecialExit(id, cmd) rooms[id].special[cmd], rooms[id].locks[cmd], rooms[id].weights[cmd] = nil, nil, nil; return true end
  function clearSpecialExits(id) rooms[id].special, rooms[id].locks = {}, {}; return true end
  function lockSpecialExit(id, dest, cmd, lock) rooms[id].locks[cmd] = lock or nil; return true end
  function setExitWeight(id, exit, weight) rooms[id].weights[exit] = weight ~= 0 and weight or nil; return true end
  function setDoor(id, dir, status) rooms[id].doors[dir] = status ~= 0 and status or nil; return true end
  function setMapUserData(key, value) mapData[key] = value; return true end
  function clearMapUserDataItem(key) mapData[key] = nil; return true end
  function createMapLabel(area, text, temporary)
    local id = 1; labels[area] = labels[area] or {}; while labels[area][id] do id = id + 1 end
    labels[area][id] = {Text = text, X = 0, Y = 0, Z = 0, Width = 1, Height = 1,
      FgColor = {r = 255, g = 255, b = 255}, BgColor = {r = 0, g = 0, b = 0}, Temporary = temporary}
    return id
  end
  function deleteMapLabel(area, id) labels[area][id] = nil; return true end
end
local function loadScripts()
  assert(loadfile(folder .. '/batch.lua'))()
  assert(loadfile(folder .. '/service.lua'))()
  mmp.crowdmapService.wrapSetExit(mmp.setExit)
end
local function reset(keepJournal)
  if not keepJournal then
    os.remove(folder .. '/mapper.crowdmap-journal.json'); os.remove(folder .. '/mapper.crowdmap-journal.json.bak'); os.remove(folder .. '/mapper.crowdmap-journal.json.log')
  end
  rooms, areas, labels, mapData, handlers, timers, requests, messages = {}, {[-1] = 'Default', [1] = 'Test'}, {}, {}, {}, {}, {}, {}
  settings.crowdmapservicesend, settings.mapsource, settings.crowdmapserviceurl = true, 'service', 'https://example.test'
  mmp = {settings = settings, game = 'achaea', whirlString = 'whirl', editing = false,
    roomexists = function(id) return rooms[id] ~= nil end,
    echo = function(s) messages[#messages + 1] = s end, regenerateAreas = function() end, highlight_unfinished_rooms = function() end }
  gmcp = {Char = {Status = {name = 'Mapper'}}}
  function postHTTP(body, url) requests[#requests + 1] = {change = yajl.to_value(body), url = url}; return true, url end
  mmp.setExit = function(id, dest, dir) rooms[id].exits[dir] = dest ~= -1 and dest or nil; return true end
  natives(); loadScripts()
  return mmp.crowdmapService, mmp.crowdmapService.batching
end
local function toggle(mode) matches = { '', mode }; assert(loadfile(folder .. '/toggle.lua'))() end
local function pending(service)
  local out = {}; for _, e in ipairs(service.pendingChanges) do out[#out + 1] = e.change end; return out
end
local function count(changes, kind, room)
  local result = 0; for _, c in ipairs(changes) do if c.type == kind and (not room or c.roomNumber == room) then result = result + 1 end end; return result
end
local tests, failures = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  tests = tests + 1
  if ok then print('PASS ' .. name)
  else failures = failures + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end

test('repeated moves, interleaved edits and full undo', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  toggle('on')
  setRoomCoordinates(1, 3, 5, -1); setRoomName(2, 'Other'); setRoomCoordinates(1, -3, 0, -1); setRoomCoordinates(1, -2, 3, -1)
  assert(#requests == 0)
  local changes = batch.changes(service.batch); assert(#changes == 2 and count(changes, 'set-room-coordinates') == 1)
  setRoomCoordinates(1, 0, 0, 0); assert(#batch.changes(service.batch) == 1)
  toggle('off'); assert(#requests == 1 and requests[1].change.type == 'room-name')
end)
test('absent values differ from empty strings and false labels', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1); toggle('on')
  setRoomUserData(1, 'key', ''); assert(count(batch.changes(service.batch), 'modify-room-user-data') == 1)
  clearRoomUserDataItem(1, 'key'); setMapUserData('key', 'value'); clearMapUserDataItem('key')
  local label = createMapLabel(1, 'text'); deleteMapLabel(1, label)
  assert(#batch.changes(service.batch) == 0)
end)
test('temporary room and its incoming exits cancel completely', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1); toggle('on')
  addRoom(2); setRoomArea(2, 1); setRoomCoordinates(2, 5, 5, 0); mmp.setExit(1, 2, 'north'); addSpecialExit(1, 2, 'enter')
  deleteRoom(2); assert(#batch.changes(service.batch) == 0)
end)
test('deleting an existing room captures incoming exits', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  rooms[1].exits.north, rooms[1].special.enter = 2, 2
  toggle('on'); deleteRoom(2)
  local changes = batch.changes(service.batch)
  assert(count(changes, 'delete-room', 2) == 1 and count(changes, 'delete-exit', 1) == 1 and count(changes, 'delete-special-exit', 1) == 1)
end)
test('area deletion expands into room deletions before deleting area', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, -1), freshRoom(2, 1); rooms[1].exits.east = 2
  toggle('on'); deleteArea('Test')
  local changes = batch.changes(service.batch)
  assert(count(changes, 'delete-room', 2) == 1 and count(changes, 'delete-exit', 1) == 1)
  assert(changes[#changes].type == 'delete-area')
end)
test('recreating an existing room compares restored state, including resets', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1); rooms[1].name, rooms[1].userData.key = 'Original', 'Old'
  toggle('on'); deleteRoom(1); addRoom(1); setRoomArea(1, 1); setRoomName(1, 'Original'); setRoomUserData(1, 'key', 'Old')
  assert(#batch.changes(service.batch) == 0)
  clearRoomUserDataItem(1, 'key'); assert(count(batch.changes(service.batch), 'delete-room-user-data') == 1)
end)
test('new areas and all rooms precede references, including cycles', function()
  local service, batch = reset(); toggle('on'); local area = addAreaName('New')
  addRoom(1); addRoom(2); setRoomArea(1, area); setRoomArea(2, area); mmp.setExit(1, 2, 'north'); mmp.setExit(2, 1, 'south')
  local changes = batch.changes(service.batch)
  assert(changes[1].type == 'create-area' and changes[2].type == 'create-room' and changes[3].type == 'create-room')
end)
test('special exit locks, multiple commands, weights and doors collapse', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1); rooms[1].exits.north = 2
  toggle('on'); addSpecialExit(1, 2, 'jump'); addSpecialExit(1, 2, 'climb'); lockSpecialExit(1, 2, 'jump', true)
  lockSpecialExit(1, 2, 'jump', false); setExitWeight(1, 'n', 3); setExitWeight(1, 'n', 0); setDoor(1, 'n', 2); setDoor(1, 'n', 0)
  local changes = batch.changes(service.batch); assert(#changes == 2 and count(changes, 'modify-special-exit') == 2)
end)
test('localOnly, private marks and temporary exits never leak from tracked rooms', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1); toggle('on')
  setRoomCoordinates(1, 1, 1, 0)
  service.localOnly(function() setRoomName(1, 'Private'); setRoomUserData(1, 'other-private', 'secret'); addSpecialExit(1, 2, 'fly') end)
  service.trackTemporarySpecialExit(1, 2, 'fly')
  setRoomUserData(1, 'gotoMapping-private', 'secret'); setRoomWeight(1, 2)
  local changes = batch.changes(service.batch); assert(#changes == 2 and count(changes, 'set-room-coordinates') == 1 and count(changes, 'set-room-weight') == 1)
end)
test('public coordinate setters publish the entire tuple after local-only moves', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1); toggle('on')
  setRoomCoordinates(1, 1, 1, 0)
  service.localOnly(function() setRoomCoordinates(1, 9, 9, 0) end)
  setRoomCoordinates(1, 9, 10, 0)
  local changes = batch.changes(service.batch)
  assert(#changes == 1 and changes[1].x == 9 and changes[1].y == 10)
end)
test('successful and failed native return values are preserved', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1); toggle('on')
  local a, b, c = setRoomCoordinates(1, 1, 1, 0); assert(a == true and b == nil and c == 42)
  local a, b, c, d = setRoomCoordinates(99, 1, 1, 0); assert(a == nil and b == 'missing' and c == nil and d == 42)
  assert(count(batch.changes(service.batch), 'create-room', 99) == 0)
end)
test('safe updates outside mapping still submit immediately', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); setRoomName(1, 'Observed'); assert(#requests == 1 and not service.batch)
end)
test('disconnect finalizes without HTTP and next login sends', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'Final')
  event('sysDisconnectionEvent'); assert(not service.batch and #service.pendingChanges == 1 and #requests == 0)
  service = reset(true); service.batching.restore(); assert(#service.pendingChanges == 1); service.sendNext(); assert(#requests == 1)
end)
test('crash recovery uses checkpoint even with an older saved map', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomCoordinates(1, 4, 5, 6)
  service = reset(true); rooms[1] = freshRoom(1, 1); service.batching.restore()
  assert(not service.batch and #service.pendingChanges == 1); service.sendNext(); assert(requests[1].change.x == 4)
end)
test('exit saves final batch and in-flight request, acknowledgement removes it', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'Saved'); toggle('off')
  event('sysExitEvent'); service = reset(true); service.batching.restore(); service.sendNext(); assert(requests[1].change.name == 'Saved')
  event('sysPostHttpDone', requests[1].url); service = reset(true); service.batching.restore(); assert(#service.pendingChanges == 0)
end)
test('identity mismatch retains the queue without sending to another service or reporter', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'Saved'); event('sysDisconnectionEvent')
  settings.crowdmapserviceurl = 'https://other.test'
  event('sysConnectionEvent'); event('gmcp.Char.Status'); service.sendNext(); assert(#requests == 0)
  settings.crowdmapserviceurl = 'https://example.test'; gmcp.Char.Status.name = 'Other'; service.sendNext(); assert(#requests == 0)
  gmcp.Char.Status.name = 'Mapper'; service.sendNext(); assert(#requests == 1)
end)
test('frozen requests are not changed by a subsequent session', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'First'); toggle('off')
  toggle('on'); setRoomName(1, 'Second'); assert(service.inFlightEntry.change.name == 'First'); toggle('off')
  assert(#requests == 1); event('sysPostHttpDone', requests[1].url); assert(requests[2].change.name == 'Second')
end)
test('exhausted retries retain a blocked queue and explicit retry resumes it', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'Saved'); toggle('off')
  local entry = service.inFlightEntry; service.inFlightEntry, service.inFlight = nil, false; entry.attempts = service.maxAttempts
  service.handleFailure(entry, 'Failure'); assert(service.pendingChanges[1].blocked); service.sendNext(); assert(#requests == 1)
  service = reset(true); service.batching.restore(); assert(service.pendingChanges[1].blocked)
  service.retrySavedChanges(); assert(#requests == 1 and service.inFlightEntry.change.name == 'Saved')
end)
test('module reload does not double-wrap native setters', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); loadScripts(); toggle('on'); setRoomName(1, 'Changed'); toggle('off'); assert(#requests == 1)
end)
test('hash-only promotion includes the room but not placeholder bookkeeping', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1); rooms[1].userData.hashonly, rooms[1].hash = 'true', 'hash'
  toggle('on'); clearRoomUserDataItem(1, 'hashonly'); service.promoteHashOnlyRoom(1); setRoomCoordinates(1, 1, 2, 0)
  local changes = batch.changes(service.batch)
  assert(count(changes, 'create-room', 1) == 1 and count(changes, 'set-room-hash', 1) == 1)
  for _, c in ipairs(changes) do assert(c.key ~= 'hashonly') end
end)
test('failed journal writes retain the previous checkpoint and prevent posting', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'First')
  local nativeOpen = io.open
  io.open = function(path, mode) if mode:sub(1, 1) == 'w' or mode:sub(1, 1) == 'a' then return nil, 'disk full' end; return nativeOpen(path, mode) end
  setRoomName(1, 'Second'); toggle('off'); assert(#requests == 0 and #service.pendingChanges == 1)
  io.open = nativeOpen
  service = reset(true); service.batching.restore(); service.sendNext(); assert(requests[1].change.name == 'First')
end)
test('Windows replacement fallback and recovery between renames', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'First')
  local nativeRename = os.rename
  os.rename = function(from, to)
    if to == folder .. '/mapper.crowdmap-journal.json' then
      local file = io.open(to, 'r'); if file then file:close(); return nil, 'target exists' end
    end
    return nativeRename(from, to)
  end
  setRoomName(1, 'Second'); os.rename = nativeRename
  service = reset(true); service.batching.restore(); service.sendNext(); assert(requests[1].change.name == 'Second')
  -- Simulate shutdown immediately after moving the old checkpoint to backup.
  nativeRename(folder .. '/mapper.crowdmap-journal.json', folder .. '/mapper.crowdmap-journal.json.bak')
  service = reset(true); service.batching.restore(); assert(service.pendingChanges[1].change.name == 'Second')
end)
test('unreadable journal is retained and cannot be overwritten or submitted', function()
  local service = reset(); local path = folder .. '/mapper.crowdmap-journal.json'
  local file = assert(io.open(path, 'w')); file:write('broken'); file:close()
  service.batching.restore(); rooms[1] = freshRoom(1, 1); setRoomName(1, 'Changed')
  assert(#requests == 0); file = assert(io.open(path, 'r')); assert(file:read('*a') == 'broken'); file:close()
end)
test('acknowledged journal overrides a stale legacy profile queue', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'Final'); toggle('off')
  local oldPending = service.pendingForSave(); event('sysPostHttpDone', requests[1].url)
  service = reset(true); assert(loadfile(folder .. '/load.lua'))()
  mmp.loadLocks = function() return {pending_crowdmap_changes = oldPending} end
  mmp.loadOptions(); assert(#service.pendingChanges == 0 and #requests == 0)
end)
test('reconnect waits for fresh GMCP reporter information', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'Final'); event('sysDisconnectionEvent')
  assert(not mmp.editing); event('sysConnectionEvent'); service.sendNext(); assert(#requests == 0)
  event('gmcp.Char.Status'); assert(#requests == 1)
end)
test('generated changes reproduce final supported state across mixed mutations', function()
  local service, batch = reset()
  rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].exits.north = 2; rooms[1].special.enter, rooms[1].locks.enter = 2, true
  rooms[1].weights.north, rooms[1].doors.north = 3, 2; rooms[1].userData.old = 'removed'
  local startRooms, startAreas, startData = clone(rooms), clone(areas), clone(mapData)
  toggle('on'); deleteRoom(2); addRoom(2); setRoomName(2, 'Rebuilt'); setRoomArea(2, 1)
  mmp.setExit(1, 3, 'north'); addSpecialExit(1, 3, 'jump'); lockSpecialExit(1, 3, 'jump', true)
  setExitWeight(1, 'jump', 7); setDoor(1, 'north', 0); setExitWeight(1, 'north', 0)
  clearRoomUserDataItem(1, 'old'); setRoomUserData(1, 'empty', ''); setRoomName(3, 'Final')
  setRoomCoordinates(3, 1, 2, 3); setRoomCoordinates(3, 3, 2, 1)
  local area = addAreaName('New'); setRoomArea(3, area); setMapUserData('key', 'value')
  local finishRooms, finishAreas, finishData = clone(rooms), clone(areas), clone(mapData)
  local changes = batch.changes(service.batch)
  rooms, areas, mapData = startRooms, startAreas, startData
  service.suspended = true -- replay through native map behavior, without recording a second batch
  for _, c in ipairs(changes) do
    local id, kind = c.roomNumber, c.type
    if kind == 'delete-room' then deleteRoom(id)
    elseif kind == 'create-room' then addRoom(id)
    elseif kind == 'create-area' then areas[c.areaId] = c.name
    elseif kind == 'rename-area' then setAreaName(c.areaId, c.name)
    elseif kind == 'delete-area' then deleteArea(c.areaId)
    elseif kind == 'room-name' then setRoomName(id, c.name)
    elseif kind == 'set-room-area' then setRoomArea(id, c.areaId)
    elseif kind == 'set-room-weight' then setRoomWeight(id, c.weight)
    elseif kind == 'set-room-symbol' then setRoomChar(id, c.symbol)
    elseif kind == 'set-room-environment' then setRoomEnv(id, c.environmentId)
    elseif kind == 'set-room-hash' then setRoomIDbyHash(id, c.hash)
    elseif kind == 'set-room-coordinates' then setRoomCoordinates(id, c.x, c.y, c.z)
    elseif kind == 'modify-room-user-data' then setRoomUserData(id, c.key, c.value)
    elseif kind == 'delete-room-user-data' then clearRoomUserDataItem(id, c.key)
    elseif kind == 'modify-exit' then mmp.setExit(id, c.destination, c.direction)
    elseif kind == 'delete-exit' then mmp.setExit(id, -1, c.direction)
    elseif kind == 'modify-special-exit' then addSpecialExit(id, c.destination, c.exitCommand)
    elseif kind == 'delete-special-exit' then removeSpecialExit(id, c.exitCommand)
    elseif kind == 'lock-special-exit' or kind == 'unlock-special-exit' then lockSpecialExit(id, c.destination, c.exitCommand, kind == 'lock-special-exit')
    elseif kind == 'modify-exit-weight' or kind == 'modify-special-exit-weight' then setExitWeight(id, c.direction or c.exitCommand, c.weight)
    elseif kind == 'set-exit-door' then setDoor(id, c.direction, c.status)
    elseif kind == 'set-map-user-data' then setMapUserData(c.key, c.value)
    elseif kind == 'delete-map-user-data' then clearMapUserDataItem(c.key)
    else error('Unexpected change ' .. kind) end
  end
  local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
  end
  assert(same(rooms, finishRooms) and same(areas, finishAreas) and same(mapData, finishData))
end)

test('Default area labels are snapshotted for creation, deletion and undo', function()
  local service, batch = reset(); local original = createMapLabel(-1, 'Original')
  -- Finish this immediate observation before starting the mapping session.
  event('sysPostHttpDone', requests[1].url)
  toggle('on'); local added = createMapLabel(-1, 'Added'); deleteMapLabel(-1, original)
  local changes = batch.changes(service.batch)
  assert(#changes == 2 and count(changes, 'set-map-label') == 1 and count(changes, 'delete-map-label') == 1)
  for _, change in ipairs(changes) do assert(change.areaId == -1) end
  deleteMapLabel(-1, added)
  assert(count(batch.changes(service.batch), 'set-map-label') == 0)
  local _, error = setRoomCoordinates(-1, 1, 1, 0)
  assert(error == 'missing' and service.batch.rooms['-1'] == nil)
end)
test('immediate edits queued behind a request survive restart', function()
  local service = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  setRoomName(1, 'First'); setRoomName(2, 'Second'); assert(#requests == 1)
  service = reset(true); service.batching.restore()
  assert(#service.pendingChanges == 2 and service.pendingChanges[2].change.name == 'Second')
end)
test('immediate edits queued during retry backoff survive restart', function()
  local service = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  setRoomName(1, 'First'); event('sysPostHttpError', 'Network failure', requests[1].url)
  assert(service.retryPending); setRoomName(2, 'Second')
  service = reset(true); service.batching.restore()
  assert(#service.pendingChanges == 2 and service.pendingChanges[2].change.name == 'Second')
end)
test('successful public setters cancel edits already undone with localOnly', function()
  local service, batch = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  areas[2] = 'Other'; rooms[1].name, rooms[1].userData.key = 'Original', 'Old'
  rooms[1].exits.north, rooms[1].special.enter = 2, 2; mapData.key = 'Old'
  toggle('on')
  setRoomCoordinates(1, 1, 1, 0); setRoomName(1, 'New'); setRoomWeight(1, 5); setRoomUserData(1, 'key', 'New')
  setRoomArea(1, 2); setMapUserData('key', 'New'); mmp.setExit(1, 3, 'north'); addSpecialExit(1, 3, 'enter')
  lockSpecialExit(1, 3, 'enter', true); setExitWeight(1, 'north', 3); setDoor(1, 'north', 2); setAreaName(1, 'Renamed')
  service.localOnly(function()
    setRoomCoordinates(1, 0, 0, 0); setRoomName(1, 'Original'); setRoomWeight(1, 1); setRoomUserData(1, 'key', 'Old')
    setRoomArea(1, 1); setMapUserData('key', 'Old'); mmp.setExit(1, 2, 'north'); addSpecialExit(1, 2, 'enter')
    lockSpecialExit(1, 2, 'enter', false); setExitWeight(1, 'north', 0); setDoor(1, 'north', 0); setAreaName(1, 'Test')
    setRoomUserData(1, 'unrelated-private', 'secret')
  end)
  setRoomCoordinates(1, 0, 0, 0); setRoomName(1, 'Original'); setRoomWeight(1, 1); setRoomUserData(1, 'key', 'Old')
  setRoomArea(1, 1); setMapUserData('key', 'Old'); mmp.setExit(1, 2, 'north'); addSpecialExit(1, 2, 'enter')
  lockSpecialExit(1, 2, 'enter', false); setExitWeight(1, 'north', 0); setDoor(1, 'north', 0); setAreaName(1, 'Test')
  assert(#batch.changes(service.batch) == 0)
end)
test('failed checkpoints do not consume the request retry budget', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'Saved')
  service.batching.finish(true); mmp.editing = false
  local nativeOpen = io.open
  io.open = function(path, mode) if mode:sub(1, 1) == 'w' or mode:sub(1, 1) == 'a' then return nil, 'disk full' end; return nativeOpen(path, mode) end
  for _ = 1, service.maxAttempts + 2 do service.sendNext() end
  assert(#requests == 0 and service.pendingChanges[1].attempts == 0)
  io.open = nativeOpen; service.batching.checkpoint()
  service = reset(true); service.batching.restore(); assert(not service.pendingChanges[1].blocked)
  service.sendNext(); assert(#requests == 1 and service.inFlightEntry.attempts == 1)
end)
test('report threshold changes finalize and start delivering the batch', function()
  local service = reset(); rooms[1] = freshRoom(1, 1)
  assert(loadfile(folder .. '/settings.lua'))(); mmp.checkforupdate = function() end
  toggle('on'); setRoomName(1, 'Final'); settings.crowdmapservicereports = 3
  mmp.changeCrowdmapServiceMapOption(); assert(not service.batch and #requests == 1)
  toggle('off'); assert(#requests == 1)
end)
test('switching back to the saved endpoint resumes delivery', function()
  local service = reset(); rooms[1] = freshRoom(1, 1)
  assert(loadfile(folder .. '/settings.lua'))(); mmp.checkforupdate = function() end
  toggle('on'); setRoomName(1, 'Final'); settings.crowdmapserviceurl = 'https://other.test'
  mmp.changeCrowdmapServiceMapOption(); assert(#requests == 0 and #service.pendingChanges == 1)
  settings.crowdmapserviceurl = 'https://example.test'; mmp.changeCrowdmapServiceMapOption()
  assert(#requests == 1 and requests[1].change.name == 'Final')
end)

test('hash reassignment undo reconciles every projected owner without private fields', function()
  local service, batch = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].hash = 'H'; toggle('on')
  setRoomIDbyHash(2, 'H'); setRoomIDbyHash(3, 'H')
  service.localOnly(function() setRoomIDbyHash(1, 'H'); setRoomName(2, 'Private') end)
  setRoomIDbyHash(1, 'H')
  assert(#batch.changes(service.batch) == 0)
  assert(service.batch.rooms['2'].after.hash == '' and service.batch.rooms['3'].after.hash == '')
end)
test('unopenable primary journal is preserved and never replaced by a backup', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'Saved')
  local path, nativeOpen = folder .. '/mapper.crowdmap-journal.json', io.open
  local file = assert(nativeOpen(path, 'r')); local original = file:read('*a'); file:close()
  file = assert(nativeOpen(path .. '.bak', 'w')); file:write(original); file:close()
  service = reset(true); local backupReads = 0
  io.open = function(name, mode)
    if name == path and mode == 'r' then return nil, 'Permission denied', 13 end
    if name == path .. '.bak' and mode == 'r' then backupReads = backupReads + 1 end
    return nativeOpen(name, mode)
  end
  service.batching.restore()
  assert(service.batching.corrupt and service.batching.hasJournal and backupReads == 0)
  rooms[1] = freshRoom(1, 1); setRoomName(1, 'Another'); assert(#requests == 0 and not service.batching.checkpoint())
  io.open = nativeOpen
  file = assert(nativeOpen(path, 'r')); assert(file:read('*a') == original); file:close()
end)
test('unopenable backup after a missing primary also blocks checkpointing', function()
  local service = reset(); local path, nativeOpen = folder .. '/mapper.crowdmap-journal.json', io.open
  local file = assert(nativeOpen(path .. '.bak', 'w')); file:write('saved backup'); file:close()
  io.open = function(name, mode)
    if name == path .. '.bak' and mode == 'r' then return nil, 'Permission denied', 13 end
    return nativeOpen(name, mode)
  end
  service.batching.restore(); assert(service.batching.corrupt and not service.batching.checkpoint())
  io.open = nativeOpen
  file = nativeOpen(path, 'r'); assert(not file)
  file = assert(nativeOpen(path .. '.bak', 'r')); assert(file:read('*a') == 'saved backup'); file:close()
end)
test('non-ENOENT journal errors without a code are not treated as missing', function()
  local service = reset(); local nativeOpen = io.open
  io.open = function(name, mode)
    if mode == 'r' then return nil, 'Unknown open failure' end
    return nativeOpen(name, mode)
  end
  service.batching.restore(); assert(service.batching.hasJournal and service.batching.corrupt)
  assert(not service.batching.checkpoint()); io.open = nativeOpen
end)
test('edits before game identification remain local and cannot poison later batches', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1)
  mmp.game, settings.crowdmapserviceurl = false, 'https://<game>.mudmaps.community'
  toggle('on'); local messagesBefore = #messages
  setRoomName(1, 'Before login'); assert(rooms[1].name == 'Before login')
  assert(not service.batch and #service.pendingChanges == 0 and #requests == 0 and #messages == messagesBefore + 1)
  setRoomCoordinates(1, 4, 5, 6); assert(#messages == messagesBefore + 1)
  mmp.game = 'achaea'; event('gmcp.Char.Status'); setRoomName(1, 'After login'); toggle('off')
  assert(#requests == 1 and requests[1].change.name == 'After login')
  assert(requests[1].url:find('https://achaea.mudmaps.community/', 1, true))
end)
test('pre-identification shutdown does not recover an unbound queue', function()
  local service = reset(); rooms[1] = freshRoom(1, 1)
  mmp.game, settings.crowdmapserviceurl = false, 'https://<game>.mudmaps.community'
  toggle('on'); setRoomName(1, 'Local'); event('sysExitEvent')
  service = reset(true); service.batching.restore(); assert(#service.pendingChanges == 0)
  rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'New session'); toggle('off'); assert(#requests == 1)
end)
test('unidentified reporter and invalid endpoint do not create pending reports', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); gmcp.Char.Status.name = nil
  toggle('on'); setRoomName(1, 'Local'); assert(not service.batch and #service.pendingChanges == 0)
  gmcp.Char.Status.name = 'Mapper'; settings.crowdmapserviceurl = nil
  setRoomName(1, 'Still local'); assert(not service.batch and #service.pendingChanges == 0)
end)
test('bulk room deletion uses incoming lookups without enumerating unrelated rooms', function()
  local service, batch = reset(); for id = 1, 1000 do rooms[id] = freshRoom(id, 1) end
  rooms[900].exits.north, rooms[901].special.enter = 1, 1
  local nativeEntrances, nativeExits, nativeRooms = getAllRoomEntrances, getRoomExits, getRooms
  local entranceCalls, unrelatedReads = 0, 0
  getAllRoomEntrances = function(id) entranceCalls = entranceCalls + 1; return nativeEntrances(id) end
  getRoomExits = function(id) if id == 1000 then unrelatedReads = unrelatedReads + 1 end; return nativeExits(id) end
  getRooms = function() error('Full-map scan during bulk deletion') end
  toggle('on'); for id = 1, 20 do deleteRoom(id) end
  local changes = batch.changes(service.batch)
  assert(entranceCalls == 20 and unrelatedReads == 0 and count(changes, 'delete-room') == 20)
  assert(count(changes, 'delete-exit', 900) == 1 and count(changes, 'delete-special-exit', 901) == 1)
  getAllRoomEntrances, getRoomExits, getRooms = nativeEntrances, nativeExits, nativeRooms
end)
test('incoming lookups include newly added, redirected and local-only exits', function()
  local service, batch = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].exits.north = 3; toggle('on'); mmp.setExit(1, 2, 'north')
  service.localOnly(function() addSpecialExit(1, 2, 'private-enter') end)
  deleteRoom(2); local changes = batch.changes(service.batch)
  assert(count(changes, 'delete-exit', 1) == 1 and count(changes, 'delete-room', 2) == 1)
  assert(count(changes, 'delete-special-exit', 1) == 0)
end)

test('public special locks never publish private destinations', function()
  local service, batch = reset()
  rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].special.enter = 3
  toggle('on'); setRoomName(1, 'Tracked')
  service.localOnly(function() addSpecialExit(1, 2, 'enter') end)
  lockSpecialExit(1, 2, 'enter', true)
  local projected = service.batch.rooms['1'].after.special.enter
  assert(projected.destination == 3 and projected.locked == true)
  local changes = batch.changes(service.batch)
  assert(count(changes, 'modify-special-exit') == 0 and count(changes, 'lock-special-exit') == 1)
  for _, change in ipairs(changes) do if change.type == 'lock-special-exit' then assert(change.destination == 3) end end
end)
test('public special redirects preserve shared locks and default new commands to unlocked', function()
  local service, batch = reset()
  rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].special.enter, rooms[1].locks.enter = 3, true
  toggle('on'); setRoomName(1, 'Tracked')
  service.localOnly(function()
    lockSpecialExit(1, 3, 'enter', false)
    addSpecialExit(1, 3, 'private'); lockSpecialExit(1, 3, 'private', true)
  end)
  addSpecialExit(1, 2, 'enter'); addSpecialExit(1, 2, 'private')
  local projected = service.batch.rooms['1'].after.special
  assert(projected.enter.destination == 2 and projected.enter.locked)
  assert(projected.private.destination == 2 and projected.private.locked == false)
  local changes = batch.changes(service.batch)
  assert(count(changes, 'modify-special-exit') == 2 and count(changes, 'unlock-special-exit') == 0 and count(changes, 'lock-special-exit') == 0)
end)
test('locking a private-only special exit cannot create an incomplete shared command', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  toggle('on'); setRoomName(1, 'Tracked')
  service.localOnly(function() addSpecialExit(1, 2, 'private') end)
  lockSpecialExit(1, 2, 'private', true); lockSpecialExit(1, 2, 'private', false)
  assert(service.batch.rooms['1'].after.special.private == nil)
  assert(#batch.changes(service.batch) == 1)
end)
test('room deletion removes projected incoming routes hidden by private redirects', function()
  local service, batch = reset()
  rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].exits.north, rooms[1].special.enter = 3, 3
  rooms[1].weights.north, rooms[1].weights.enter, rooms[1].doors.north = 4, 5, 2
  toggle('on'); mmp.setExit(1, 2, 'north'); addSpecialExit(1, 2, 'enter')
  service.localOnly(function() mmp.setExit(1, 3, 'north'); addSpecialExit(1, 3, 'enter') end)
  deleteRoom(2)
  local projected = service.batch.rooms['1'].after
  assert(not next(projected.exits) and not next(projected.special) and not next(projected.weights) and not next(projected.doors))
  local changes = batch.changes(service.batch)
  assert(count(changes, 'delete-exit', 1) == 1 and count(changes, 'delete-special-exit', 1) == 1)
  assert(count(changes, 'modify-exit', 1) == 0 and count(changes, 'modify-special-exit', 1) == 0)
end)
test('temporary room cancellation cannot leave projected incoming references', function()
  local service, batch = reset(); rooms[1], rooms[3] = freshRoom(1, 1), freshRoom(3, 1)
  toggle('on'); addRoom(2); mmp.setExit(1, 2, 'north'); addSpecialExit(1, 2, 'enter')
  service.localOnly(function() mmp.setExit(1, 3, 'north'); addSpecialExit(1, 3, 'enter') end)
  deleteRoom(2); assert(#batch.changes(service.batch) == 0)
end)
test('room deletion preserves unrelated shared routes and their metadata', function()
  local service, batch = reset()
  rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].exits.north, rooms[1].special.enter, rooms[1].locks.enter = 3, 3, true
  rooms[1].weights.north, rooms[1].weights.enter, rooms[1].doors.north = 4, 5, 2
  toggle('on'); setRoomName(1, 'Tracked')
  service.localOnly(function() mmp.setExit(1, 2, 'north'); addSpecialExit(1, 2, 'enter') end)
  deleteRoom(2)
  local projected = service.batch.rooms['1'].after
  assert(projected.exits.north == 3 and projected.special.enter.destination == 3 and projected.special.enter.locked)
  assert(projected.weights.north == 4 and projected.weights.enter == 5 and projected.doors.north == 2)
  local changes = batch.changes(service.batch)
  assert(#changes == 2 and count(changes, 'delete-room', 2) == 1 and count(changes, 'room-name', 1) == 1)
end)
test('area deletion reconciles projected members moved out privately and their entrances', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  rooms[2].exits.north, rooms[2].special.enter = 1, 1
  toggle('on'); local area = addAreaName('Temporary'); setRoomArea(1, area)
  service.localOnly(function() setRoomArea(1, 1) end)
  deleteArea(area)
  assert(service.batch.rooms['1'].after == false)
  assert(not next(service.batch.rooms['2'].after.exits) and not next(service.batch.rooms['2'].after.special))
  local changes = batch.changes(service.batch)
  assert(#changes == 3 and count(changes, 'delete-room', 1) == 1)
  assert(count(changes, 'set-room-area') == 0 and count(changes, 'create-area') == 0)
end)
test('area deletion preserves projected members moved in privately and their entrances', function()
  local service, batch = reset(); areas[2] = 'Other'
  rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  rooms[2].exits.north, rooms[2].special.enter = 1, 1
  toggle('on'); setRoomName(1, 'Tracked'); setRoomName(2, 'Source')
  service.localOnly(function() setRoomArea(1, 2) end)
  deleteArea(2)
  assert(service.batch.rooms['1'].after.areaId == 1)
  assert(service.batch.rooms['2'].after.exits.north == 1 and service.batch.rooms['2'].after.special.enter.destination == 1)
  local changes = batch.changes(service.batch)
  assert(#changes == 3 and count(changes, 'delete-room') == 0 and count(changes, 'delete-exit') == 0 and count(changes, 'delete-area') == 1)
end)
test('failed room and area deletions leave shared projections unchanged', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1)
  toggle('on'); setRoomName(1, 'Tracked')
  local before = encode(service.batch)
  local touched = batch.before('deleteRoom', 1); batch.after(touched, false)
  assert(encode(service.batch) == before)
  touched = batch.before('deleteArea', 1); before = encode(service.batch); batch.after(touched, false)
  assert(encode(service.batch) == before and #batch.changes(service.batch) == 1)
end)
test('recovery retains reconciled shared deletions instead of native private routes', function()
  local service = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].exits.north = 3
  toggle('on'); mmp.setExit(1, 2, 'north')
  service.localOnly(function() mmp.setExit(1, 3, 'north') end)
  deleteRoom(2)
  service = reset(true); service.batching.restore()
  local changes = pending(service)
  assert(#changes == 2 and count(changes, 'delete-room', 2) == 1 and count(changes, 'delete-exit', 1) == 1)
end)

test('first-touch private redirects retain the shared destination for public locks', function()
  local service, batch = reset()
  rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].special.enter = 3
  toggle('on'); service.localOnly(function() addSpecialExit(1, 2, 'enter') end)
  lockSpecialExit(1, 2, 'enter', true)
  local changes = batch.changes(service.batch)
  assert(#changes == 1 and changes[1].type == 'lock-special-exit' and changes[1].destination == 3)
end)
test('first-touch private additions cannot be published by locking them', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  toggle('on'); service.localOnly(function() addSpecialExit(1, 2, 'private') end)
  lockSpecialExit(1, 2, 'private', true)
  assert(#batch.changes(service.batch) == 0)
end)
test('first-touch private properties and area moves stay out of public edits', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1); areas[2] = 'Other'
  toggle('on'); service.localOnly(function()
    setRoomCoordinates(1, 9, 9, 9); setRoomName(1, 'Private'); setRoomArea(1, 2)
    setRoomUserData(1, 'private', 'secret'); setAreaName(1, 'Private area'); setMapUserData('private', 'secret')
  end)
  setRoomWeight(1, 2); setAreaName(1, 'Public area'); setMapUserData('public', 'visible')
  local changes = batch.changes(service.batch)
  assert(#changes == 3 and count(changes, 'set-room-weight') == 1 and count(changes, 'rename-area') == 1 and count(changes, 'set-map-user-data') == 1)
  assert(service.batch.rooms['1'].after.areaId == 1 and service.batch.rooms['1'].after.name == '')
end)
test('private creations stay absent when public setters target them', function()
  local service, batch = reset(); toggle('on'); local area
  service.localOnly(function() addRoom(1); area = addAreaName('Private') end)
  setRoomName(1, 'Public'); setRoomWeight(1, 2); setAreaName(area, 'Public')
  assert(service.batch.rooms['1'].after == false and service.batch.areas[tostring(area)].after == false)
  assert(#batch.changes(service.batch) == 0)
end)
test('first-touch private area moves cannot hide shared members from deletion', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1); areas[2] = 'Other'
  rooms[2].exits.north = 1
  toggle('on'); service.localOnly(function() setRoomArea(1, 2) end)
  deleteArea(1)
  local changes = batch.changes(service.batch)
  assert(count(changes, 'delete-room') == 2 and count(changes, 'delete-area') == 1)
  assert(service.batch.rooms['1'].after == false and count(changes, 'set-room-area') == 0)
end)
test('first-touch private baselines survive restart without publishing private edits', function()
  local service = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].special.enter = 3
  toggle('on'); service.localOnly(function() addSpecialExit(1, 2, 'enter'); setRoomName(1, 'Private') end)
  lockSpecialExit(1, 2, 'enter', true)
  service = reset(true); service.batching.restore()
  local changes = pending(service)
  assert(#changes == 1 and changes[1].type == 'lock-special-exit' and changes[1].destination == 3)
end)

-- Exercise the shipped download callbacks, including their retry links and
-- mark migration, instead of duplicating the download state machine.
local function downloadFixture()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1)
  mmp.game = 'starmourn'
  local fixture = {public = {}, private = {}, incoming = {}, attempts = 0, warnings = 0, links = {}, fail = false}
  local filename = folder .. '/downloaded-map.dat'
  local file = assert(io.open(filename, 'w')); file:write('map'); file:close()
  mmp.crowdmapfile = filename
  mmp.crowdmapDownloadSource, mmp.crowdmapDownloadGeneration, mmp.crowdmapDownloadIdentity = 'service', 0, 'current'
  mmp.crowdmapDownloadVersion = 'v2'
  mmp.mapSourceIdentity = function() return 'current' end
  mmp.getRoomMarks = function(kind) return clone(fixture[kind]) end
  mmp.echon = mmp.echo
  mmp.disableWaterWalk = function() end
  mmp.enableWaterWalk = function() end
  mmp.recordCrowdmapVersion = function() end
  service.warnBeforeMapLoad = function() fixture.warnings = fixture.warnings + 1 end
  service.mapLoaded = function() end
  function raiseEvent() end
  function echo(s) messages[#messages + 1] = s end
  function echoLink(label, callback) fixture.links[#fixture.links + 1] = callback end
  io.exists = function(path) local f = io.open(path); if not f then return false end; f:close(); return true end
  function loadMap(path)
    assert(path == filename); fixture.attempts = fixture.attempts + 1
    if fixture.fail then return false end
    fixture.public, fixture.private = clone(fixture.incoming), {}
    rooms = {[1] = freshRoom(1, 1)}
    return true
  end
  assert(loadfile(folder .. '/download.lua'))()
  return service, batch, fixture, filename
end
local function assertNoLoadFailureMessage()
  for _, message in ipairs(messages) do
    assert(not message:find('failed to load') and not message:find('mapper open') and not message:find("Nope, didn't work"))
  end
end
test('active sessions defer downloads and retries without load-failure instructions', function()
  local service, batch, fixture, filename = downloadFixture()
  toggle('on'); mmp.downloadedFile(nil, filename)
  assert(fixture.attempts == 0 and fixture.warnings == 0 and io.exists(filename))
  assert(mmp.crowdmapLoadRetries[filename] and #fixture.links == 1)
  assertNoLoadFailureMessage()
  local context = mmp.crowdmapLoadRetries[filename]
  assert(loadstring(fixture.links[1]))()
  assert(fixture.attempts == 0 and mmp.crowdmapLoadRetries[filename] == context)
  assertNoLoadFailureMessage()
end)
test('deferred download retry preserves current private marks and current public moves', function()
  local service, batch, fixture, filename = downloadFixture()
  fixture.private = {deleted = 2, moved = 3}; fixture.public = {oldPublic = 4}
  toggle('on'); mmp.downloadedFile(nil, filename)
  fixture.private = {moved = 5, added = 6}; fixture.public = {newPublic = 7}
  fixture.incoming = {oldPublic = 4}
  toggle('off'); assert(loadstring(fixture.links[1]))()
  assert(fixture.attempts == 1 and not mmp.crowdmapLoadRetries[filename] and not io.exists(filename))
  local migrated = yajl.to_value(rooms[1].userData['gotoMapping-private'])
  assert(migrated.deleted == nil and migrated.moved == 5 and migrated.added == 6)
  assert(migrated.oldPublic == nil and migrated.newPublic == 7)
end)
test('failed download attempts refresh marks again before a successful retry', function()
  local service, batch, fixture, filename = downloadFixture()
  fixture.private = {deleted = 2, moved = 3}; fixture.public = {oldPublic = 4}; fixture.fail = true
  mmp.downloadedFile(nil, filename)
  assert(fixture.attempts == 1 and mmp.crowdmapLoadRetries[filename] and #fixture.links == 1)
  local found = false; for _, message in ipairs(messages) do if message:find('mapper open') then found = true end end; assert(found)
  mmp.retryCrowdmapLoad(filename); assert(fixture.attempts == 2 and mmp.crowdmapLoadRetries[filename])
  fixture.private = {moved = 5, added = 6}; fixture.public = {newPublic = 7}; fixture.fail = false
  mmp.retryCrowdmapLoad(filename)
  assert(fixture.attempts == 3 and not mmp.crowdmapLoadRetries[filename])
  local migrated = yajl.to_value(rooms[1].userData['gotoMapping-private'])
  assert(migrated.deleted == nil and migrated.moved == 5 and migrated.added == 6 and migrated.oldPublic == nil and migrated.newPublic == 7)
end)

test('route restoration cannot import hidden private special-exit weights', function()
  local service, batch = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].special.enter, rooms[1].weights.enter = 2, 4
  toggle('on'); service.localOnly(function()
    addSpecialExit(1, 3, 'enter'); service.trackTemporarySpecialExit(1, 3, 'enter'); setExitWeight(1, 'enter', 9)
  end)
  addSpecialExit(1, 2, 'enter')
  local changes = batch.changes(service.batch)
  assert(#changes == 0, 'restoring a route published hidden private metadata')
end)
test('replaying redirect then destination deletion preserves unchanged exit metadata', function()
  local service, batch = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].special.enter, rooms[1].locks.enter, rooms[1].weights.enter = 2, true, 4
  local baseline = clone(rooms)
  toggle('on'); addSpecialExit(1, 3, 'enter'); deleteRoom(2)
  local changes = batch.changes(service.batch)
  rooms = baseline; mmp.editing = false; service.suspended = true
  for _, change in ipairs(changes) do
    if change.type == 'delete-room' then deleteRoom(change.roomNumber)
    elseif change.type == 'modify-special-exit' then addSpecialExit(change.roomNumber, change.destination, change.exitCommand)
    elseif change.type == 'lock-special-exit' then lockSpecialExit(change.roomNumber, change.destination, change.exitCommand, true)
    elseif change.type == 'modify-special-exit-weight' then setExitWeight(change.roomNumber, change.exitCommand, change.weight)
    else error('Unexpected replay change ' .. change.type) end
  end
  assert(rooms[1].special.enter == 3 and rooms[1].locks.enter and rooms[1].weights.enter == 4,
    'room deletion erased unchanged lock/weight during replay')
end)
test('recovered immediate edits retain their original reporter and endpoint', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); setRoomName(1, 'Immediate')
  assert(#requests == 1)
  service = reset(true); gmcp.Char.Status.name = 'Another'; service.batching.restore(); service.sendNext()
  assert(#requests == 0, 'attempted immediate report sent under another character')
  gmcp.Char.Status.name = 'Mapper'; settings.crowdmapserviceurl = 'https://other.test'; service.sendNext()
  assert(#requests == 0, 'immediate report sent to another endpoint')
  settings.crowdmapserviceurl = 'https://example.test'; service.sendNext()
  assert(#requests == 1 and requests[1].change.reporter == 'Mapper')
end)
test('unknown area names preserve native unsuccessful deletion results', function()
  local service, batch = reset(); toggle('on')
  local original = getAreaRooms
  -- Mudlet's numeric-ID API rejects nil, unlike a permissive fake lookup.
  getAreaRooms = function(id) assert(type(id) == 'number', 'getAreaRooms requires a numeric area ID'); return original(id) end
  local ok, result = pcall(deleteArea, 'No such area')
  getAreaRooms = original
  assert(ok and result == false, 'snapshot lookup threw before native deleteArea could return false')
  assert(#batch.changes(service.batch) == 0)
end)
test('bulk local-only mutations serialize bounded object counts', function()
  local service, batch = reset(); local size = 120
  for id = 1, size do rooms[id] = freshRoom(id, 1) end
  toggle('on')
  local stringify, serializedRooms = yajl.to_string, 0
  yajl.to_string = function(value)
    local entries = value.session and value.session.rooms or value.rooms or {}
    for _ in pairs(entries) do serializedRooms = serializedRooms + 1 end
    return stringify(value)
  end
  local ok, err = pcall(function()
    service.localOnly(function() for id = 1, size do setRoomWeight(id, 2) end end)
  end)
  yajl.to_string = stringify
  assert(ok, err)
  assert(serializedRooms <= size * 4, 'serialized ' .. serializedRooms .. ' room entries for ' .. size .. ' edits')
  assert(#batch.changes(service.batch) == 0)
end)
test('temporary markers retire when deleted rooms or areas recreate their routes', function()
  for _, mode in ipairs({'source', 'destination', 'area'}) do
    local service, batch = reset(); areas[2] = 'Other'; rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 2)
    rooms[1].special.enter = 2; service.trackTemporarySpecialExit(1, 2, 'enter'); toggle('on')
    if mode == 'source' then deleteRoom(1); addRoom(1)
    elseif mode == 'destination' then deleteRoom(2); addRoom(2)
    else deleteArea(2); addRoom(2) end
    addSpecialExit(1, 2, 'enter')
    assert(count(batch.changes(service.batch), 'modify-special-exit', 1) == 1,
      mode .. ' deletion left a stale marker filtering the recreated public exit')
  end
end)

test('incremental recovery ignores a torn tail and keeps complete object updates', function()
  local service = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  toggle('on'); setRoomName(1, 'First'); setRoomName(2, 'Second')
  local file = assert(io.open(folder .. '/mapper.crowdmap-journal.json.log', 'a'))
  file:write('000000000100partial'); file:close()
  service = reset(true); service.batching.restore()
  local changes = pending(service)
  assert(count(changes, 'room-name', 1) == 1 and count(changes, 'room-name', 2) == 1)
  assert(not service.batching.corrupt)
end)
test('complete malformed incremental records block overwrite and sending', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); setRoomName(1, 'First')
  local path = folder .. '/mapper.crowdmap-journal.json.log'
  local file = assert(io.open(path, 'a')); file:write('000000000003bad'); file:close()
  service = reset(true); service.batching.restore(); service.sendNext()
  assert(service.batching.corrupt and not service.batching.checkpoint() and #requests == 0)
  file = assert(io.open(path)); assert(file:read('*a') == '000000000003bad'); file:close()
end)
test('old log frames cannot resurrect a finalized session after failed truncation', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  toggle('on'); setRoomName(1, 'First'); setRoomName(2, 'Second')
  local original = io.open
  io.open = function(path, mode)
    if path == folder .. '/mapper.crowdmap-journal.json.log' and mode == 'wb' then return nil, 'disk full' end
    return original(path, mode)
  end
  batch.finish(true); io.open = original
  service = reset(true); service.batching.restore()
  local changes = pending(service)
  assert(#changes == 2 and count(changes, 'room-name', 1) == 1 and count(changes, 'room-name', 2) == 1)
  assert(not service.batch)
end)
test('failed append retains dirty objects and the next full checkpoint recovers them', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  toggle('on'); setRoomName(1, 'First')
  local original = io.open
  io.open = function(path, mode) if mode == 'ab' then return nil, 'disk full' end; return original(path, mode) end
  setRoomName(2, 'Second'); io.open = original
  assert(batch.logBroken and batch.dirty.rooms['2'])
  setRoomName(1, 'Final')
  assert(not batch.logBroken)
  service = reset(true); service.batching.restore()
  local changes = pending(service)
  assert(#changes == 2)
  for _, change in ipairs(changes) do assert(change.name == (change.roomNumber == 1 and 'Final' or 'Second')) end
end)
test('incremental recovery captures deletion effects on projected sources outside native entrances', function()
  local service = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].exits.north = 3
  toggle('on'); mmp.setExit(1, 2, 'north')
  service.localOnly(function() mmp.setExit(1, 3, 'north') end)
  deleteRoom(2)
  service = reset(true); service.batching.restore()
  local changes = pending(service)
  assert(#changes == 2 and count(changes, 'delete-exit', 1) == 1 and count(changes, 'delete-room', 2) == 1)
end)
test('incremental recovery reconciles hash owners absent from native lookup', function()
  local service = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1); rooms[1].hash = 'H'
  toggle('on'); setRoomIDbyHash(2, 'H')
  service.localOnly(function() setRoomIDbyHash(1, 'H') end)
  setRoomIDbyHash(1, 'H')
  service = reset(true); service.batching.restore()
  assert(#pending(service) == 0)
end)
test('growing-session compaction keeps aggregate serialization linear', function()
  local service = reset(); local size = 1200
  for id = 1, size do rooms[id] = freshRoom(id, 1) end
  toggle('on')
  local stringify, serializedRooms = yajl.to_string, 0
  yajl.to_string = function(value)
    for _ in pairs(value.session and value.session.rooms or value.rooms or {}) do serializedRooms = serializedRooms + 1 end
    return stringify(value)
  end
  local ok, err = pcall(function() service.localOnly(function() for id = 1, size do setRoomWeight(id, 2) end end) end)
  yajl.to_string = stringify
  assert(ok, err)
  assert(serializedRooms <= size * 4, 'serialized ' .. serializedRooms .. ' room entries for ' .. size .. ' edits')
end)
test('immediate identity scopes retain legacy expiry and retry limits', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); setRoomName(1, 'Immediate')
  local saved = service.pendingForSave(); saved[1].expiresAt = os.time() - 1
  service = reset(); service.restorePendingChanges(saved)
  assert(#service.pendingChanges == 0 and service.unsentChanges == 1)
  local entry = saved[1]; entry.expiresAt = os.time() + 60; entry.attempts = service.maxAttempts
  service.handleFailure(entry, 'Failed')
  assert(#service.pendingChanges == 0 and service.unsentChanges == 2)
end)
test('public normal routes preserve shared metadata after private removal', function()
  local service, batch = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  rooms[1].exits.north, rooms[1].weights.north, rooms[1].doors.north = 2, 4, 2
  toggle('on'); service.localOnly(function()
    mmp.setExit(1, -1, 'north'); setExitWeight(1, 'north', 9); setDoor(1, 'north', 3)
  end)
  mmp.setExit(1, 2, 'north')
  assert(#batch.changes(service.batch) == 0)
  service.localOnly(function() mmp.setExit(1, -1, 'north') end)
  mmp.setExit(1, -1, 'north')
  local projected = service.batch.rooms['1'].after
  assert(not projected.exits.north and not projected.weights.north and not projected.doors.north)
end)
test('failed deletion preserves temporary markers and non-mapping successful deletion retires them', function()
  local service = reset(); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1)
  rooms[1].special.enter = 2; service.trackTemporarySpecialExit(1, 2, 'enter')
  assert(deleteRoom(999) == false and service.isTemporarySpecialExit(1, 2, 'enter'))
  service.localOnly(function() deleteRoom(2) end)
  assert(not service.isTemporarySpecialExit(1, 2, 'enter'))
end)

local function loadAreaDeletion()
  table.size = function(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
  function centerview() end
  assert(loadfile(folder .. '/mapper_aliases.lua'))()
end
local function drainDeletionTimers()
  local index = 1
  while index <= #timers do
    local timer = timers[index]; index = index + 1
    if timer.delay == 0.010 then timer.fn() end
  end
end
test('shipped chunked area deletion preserves shared rooms privately moved into the area', function()
  local service, batch = reset(); areas[2] = 'Target'
  rooms[1], rooms[2], rooms[3] = freshRoom(1, 2), freshRoom(2, 1), freshRoom(3, 1)
  rooms[3].exits.north = 2
  toggle('on'); service.localOnly(function() setRoomArea(2, 2) end)
  loadAreaDeletion()
  local original = getAreaRooms
  getAreaRooms = function(id) local ids = original(id); table.sort(ids); return ids end
  local ok, err = pcall(function() mmp.doareadelete(2); drainDeletionTimers() end)
  getAreaRooms = original
  assert(ok, err)
  local changes = batch.changes(service.batch)
  assert(service.batch.rooms['2'].after and service.batch.rooms['2'].after.areaId == 1,
    'chunk deleted a room whose shared area was outside the target')
  assert(count(changes, 'delete-room', 2) == 0 and count(changes, 'delete-exit', 3) == 0)
  assert(count(changes, 'delete-room', 1) == 1 and count(changes, 'delete-area') == 1)
end)
test('bulk room deletion visits bounded projected snapshots', function()
  local service = reset(); local size = 200
  for id = 1, size do rooms[id] = freshRoom(id, 1) end
  toggle('on')
  local original, visits = pairs, 0
  pairs = function(t)
    local iterator, state, initial = original(t)
    if not service.batch or t ~= service.batch.rooms then return iterator, state, initial end
    return function(state, last)
      local key, value = iterator(state, last)
      if key then visits = visits + 1 end
      return key, value
    end, state, initial
  end
  local ok, err = pcall(function() for id = 1, size do deleteRoom(id) end end)
  pairs = original
  assert(ok, err)
  assert(visits <= size * 4, 'visited ' .. visits .. ' accumulated snapshots for ' .. size .. ' deletions')
end)

test('projected incoming index retains duplicate destinations when one command is removed', function()
  local service, batch = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].special.first, rooms[1].special.second, rooms[1].special.other, rooms[1].exits.north = 2, 2, 3, 2
  toggle('on'); removeSpecialExit(1, 'first')
  service.localOnly(function() addSpecialExit(1, 3, 'second'); mmp.setExit(1, 3, 'north') end)
  deleteRoom(2)
  local room = service.batch.rooms['1'].after
  assert(not room.special.first and not room.special.second and not room.exits.north)
  assert(room.special.other.destination == 3)
  local changes = batch.changes(service.batch)
  assert(count(changes, 'delete-special-exit', 1) == 2 and count(changes, 'delete-exit', 1) == 1)
end)
test('projection membership index follows public moves independently of private native moves', function()
  local service, batch = reset(); areas[2] = 'Target'; rooms[1], rooms[2] = freshRoom(1, 2), freshRoom(2, 1)
  toggle('on'); setRoomArea(1, 1); setRoomArea(2, 2)
  service.localOnly(function() setRoomArea(1, 2); setRoomArea(2, 1) end)
  deleteArea(2)
  assert(service.batch.rooms['1'].after.areaId == 1 and service.batch.rooms['2'].after == false)
  local changes = batch.changes(service.batch)
  assert(count(changes, 'delete-room', 1) == 0 and count(changes, 'delete-room', 2) == 1)
end)
test('projected incoming index updates across source deletion and recreation', function()
  local service, batch = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].exits.north = 2
  toggle('on'); deleteRoom(1); addRoom(1); mmp.setExit(1, 3, 'north'); deleteRoom(2)
  assert(service.batch.rooms['1'].after.exits.north == 3)
  local changes = batch.changes(service.batch)
  assert(count(changes, 'modify-exit', 1) == 1 and count(changes, 'delete-exit', 1) == 0)
end)
test('chunked area deletion checkpoints only its shared members for crash recovery', function()
  local service = reset(); areas[2] = 'Target'; rooms[1], rooms[2], rooms[3] = freshRoom(1, 2), freshRoom(2, 1), freshRoom(3, 1)
  rooms[3].special.enter = 2
  toggle('on'); service.localOnly(function() setRoomArea(2, 2) end)
  loadAreaDeletion(); local original = getAreaRooms
  getAreaRooms = function(id) local ids = original(id); table.sort(ids); return ids end
  local ok, err = pcall(function() mmp.doareadelete(2); drainDeletionTimers() end)
  getAreaRooms = original; assert(ok, err)
  service = reset(true); service.batching.restore()
  local changes = pending(service)
  assert(count(changes, 'delete-room', 1) == 1 and count(changes, 'delete-area') == 1)
  assert(count(changes, 'delete-room', 2) == 0 and count(changes, 'delete-special-exit', 3) == 0)
end)

test('map submit during pending area chunks preserves original shared baselines', function()
  local service, batch = reset(); areas[2] = 'Target'; rooms[1], rooms[2], rooms[3] = freshRoom(1, 2), freshRoom(2, 1), freshRoom(3, 1)
  rooms[3].exits.north = 2
  toggle('on'); service.localOnly(function() setRoomArea(2, 2) end)
  loadAreaDeletion(); local original = getAreaRooms
  getAreaRooms = function(id) local ids = original(id); table.sort(ids); return ids end
  local ok, err = pcall(function()
    mmp.doareadelete(2); service.retrySavedChanges(); drainDeletionTimers(); batch.finish(true)
  end)
  getAreaRooms = original; assert(ok, err)
  local changes = pending(service)
  if service.inFlightEntry then changes[#changes + 1] = service.inFlightEntry.change end
  assert(count(changes, 'delete-room', 2) == 0, 'submission split the plan and deleted an unrelated shared room')
  assert(count(changes, 'delete-room', 1) == 1 and count(changes, 'delete-area') == 1)
end)
test('public routes to private-only destinations remain local', function()
  local service, batch = reset(); rooms[1], rooms[3] = freshRoom(1, 1), freshRoom(3, 1)
  rooms[1].exits.north, rooms[1].special.enter = 3, 3
  toggle('on'); service.localOnly(function() addRoom(2) end)
  mmp.setExit(1, 2, 'north'); addSpecialExit(1, 2, 'enter'); addSpecialExit(1, 2, 'new')
  assert(#batch.changes(service.batch) == 0, 'published a route without a shared destination room')
  assert(service.batch.rooms['1'].after.exits.north == 3 and service.batch.rooms['1'].after.special.enter.destination == 3)
end)
test('public room moves into private-only areas remain local', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1)
  toggle('on'); local area
  service.localOnly(function() area = addAreaName('Private') end)
  setRoomArea(1, area)
  assert(#batch.changes(service.batch) == 0, 'published membership without a shared destination area')
  assert(service.batch.rooms['1'].after.areaId == 1)
end)

test('turning mapping off waits for area chunks and then delivers their shared deletion', function()
  local service, batch = reset(); areas[2] = 'Target'; rooms[1], rooms[2] = freshRoom(1, 2), freshRoom(2, 1)
  toggle('on'); service.localOnly(function() setRoomArea(2, 2) end)
  loadAreaDeletion(); local original = getAreaRooms
  getAreaRooms = function(id) local ids = original(id); table.sort(ids); return ids end
  local ok, err = pcall(function()
    mmp.doareadelete(2); toggle('off')
    assert(service.batch and not mmp.editing and #requests == 0)
    drainDeletionTimers()
  end)
  getAreaRooms = original; assert(ok, err)
  assert(not service.batch and #requests == 1)
  local changes = pending(service); changes[#changes + 1] = service.inFlightEntry.change
  assert(count(changes, 'delete-room', 1) == 1 and count(changes, 'delete-area') == 1 and count(changes, 'delete-room', 2) == 0)
end)
test('map submit automatically starts delivery when pending area deletion completes', function()
  local service = reset(); areas[2] = 'Target'; rooms[1] = freshRoom(1, 2)
  toggle('on'); loadAreaDeletion(); mmp.doareadelete(2); service.retrySavedChanges()
  assert(#requests == 0 and service.batch)
  drainDeletionTimers()
  assert(#requests == 1 and not service.batch and mmp.editing)
end)
test('disconnect during a pending area operation recovers without completing timer work', function()
  local service = reset(); areas[2] = 'Target'; rooms[1], rooms[2] = freshRoom(1, 2), freshRoom(2, 1)
  toggle('on'); service.localOnly(function() setRoomArea(2, 2) end)
  loadAreaDeletion(); mmp.doareadelete(2); service.retrySavedChanges(); event('sysDisconnectionEvent')
  assert(not service.batch and #requests == 0)
  service = reset(true); service.batching.restore()
  assert(#pending(service) == 0 and not service.batch)
end)
test('deferred area work cannot collect new edits under another identity', function()
  local service, batch = reset(); areas[2] = 'Target'; rooms[1], rooms[2] = freshRoom(1, 2), freshRoom(2, 1)
  toggle('on'); loadAreaDeletion(); mmp.doareadelete(2)
  gmcp.Char.Status.name = 'Other'; setRoomName(2, 'Wrong identity')
  assert(count(batch.changes(service.batch), 'room-name', 2) == 0)
  drainDeletionTimers()
  assert(#requests == 0)
end)
test('public creation allows routes and moves after private-only objects were recreated', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1)
  toggle('on'); local privateArea
  service.localOnly(function() addRoom(2); privateArea = addAreaName('Private') end)
  service.localOnly(function() deleteRoom(2); deleteArea(privateArea) end)
  addRoom(2); local area = addAreaName('Public'); setRoomArea(1, area)
  mmp.setExit(1, 2, 'north'); addSpecialExit(1, 2, 'enter')
  local changes = batch.changes(service.batch)
  assert(count(changes, 'create-room', 2) == 1 and count(changes, 'modify-exit', 1) == 1 and count(changes, 'modify-special-exit', 1) == 1)
  assert(count(changes, 'create-area') == 1 and count(changes, 'set-room-area', 1) == 1)
end)
test('local references and memberships remain excluded after journal recovery', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); toggle('on'); local area
  service.localOnly(function() addRoom(2); area = addAreaName('Private') end)
  setRoomArea(1, area); mmp.setExit(1, 2, 'north'); addSpecialExit(1, 2, 'enter'); setRoomName(1, 'Public')
  service = reset(true); service.batching.restore()
  local changes = pending(service)
  assert(#changes == 1 and changes[1].type == 'room-name' and changes[1].name == 'Public')
end)

test('safe GMCP updates during deferred mapping-off cannot be rolled back by stale snapshots', function()
  local service = reset(); areas[2] = 'Target'; rooms[1], rooms[3] = freshRoom(1, 2), freshRoom(3, 1)
  toggle('on'); setRoomName(3, 'Old'); loadAreaDeletion(); mmp.doareadelete(2); toggle('off')
  mmp.cleanroomname = function(name) return name end; mmp.roomDetails = function() end
  function unHighlightRoom() end
  settings.gmcpmapupdates = true; gmcp.Room = {Info = {num = 3, name = 'New'}}
  assert(loadfile(folder .. '/safe_gmcp.lua'))(); event('gmcp.Room.Info'); drainDeletionTimers()
  local changes = pending(service); if service.inFlightEntry then changes[#changes + 1] = service.inFlightEntry.change end
  local names = 0
  for _, change in ipairs(changes) do
    if change.type == 'room-name' and change.roomNumber == 3 then
      names = names + 1; assert(change.name == 'New', 'deferred batch publishes stale room name ' .. change.name)
    end
  end
  assert(names == 1)
end)
test('changing endpoint preserves completion of originally scoped area deletion', function()
  local service = reset(); areas[2] = 'Target'; rooms[1], rooms[2] = freshRoom(1, 2), freshRoom(2, 2)
  assert(loadfile(folder .. '/settings.lua'))(); mmp.checkforupdate = function() end
  toggle('on'); loadAreaDeletion(); mmp.doareadelete(2)
  settings.crowdmapserviceurl = 'https://other.test'; mmp.changeCrowdmapServiceMapOption(); drainDeletionTimers()
  local changes = pending(service)
  assert(count(changes, 'delete-room') == 2 and count(changes, 'delete-area') == 1, 'endpoint change dropped native deletion work')
  assert(#requests == 0)
  for _, entry in ipairs(service.pendingChanges) do assert(entry.scope.url == 'https://example.test') end
end)
test('shipped cancellation clears pending plan and honors deferred submission', function()
  local service, batch = reset(); areas[2] = 'Target'; rooms[1], rooms[2] = freshRoom(1, 2), freshRoom(2, 2)
  toggle('on'); loadAreaDeletion(); mmp.doareadelete(2); service.retrySavedChanges()
  assert(loadfile(folder .. '/cancel_area.lua'))(); drainDeletionTimers(); batch.finish(true)
  assert(not batch.pendingArea and not service.batch, 'cancellation left deferred finalization stuck')
  assert(rooms[1] and rooms[2] and areas[2] and #requests == 0)
end)
test('private-only room existence exclusions survive map submit boundaries', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1)
  toggle('on'); service.localOnly(function() addRoom(2) end); service.retrySavedChanges()
  mmp.setExit(1, 2, 'north'); addSpecialExit(1, 2, 'enter')
  assert(#batch.changes(service.batch) == 0, 'new batch forgot private-only destination room')
end)
test('private-only area existence exclusions survive map submit boundaries', function()
  local service, batch = reset(); rooms[1] = freshRoom(1, 1); local area
  toggle('on'); service.localOnly(function() area = addAreaName('Private') end); service.retrySavedChanges()
  setRoomArea(1, area)
  assert(#batch.changes(service.batch) == 0, 'new batch forgot private-only destination area')
end)
test('public hash assignment cannot clear a previous native owners unrelated shared hash', function()
  local service, batch = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].hash, rooms[2].hash = 'H', 'K'
  toggle('on'); service.localOnly(function() setRoomIDbyHash(2, 'H') end); setRoomIDbyHash(3, 'H')
  assert(service.batch.rooms['2'].after.hash == 'K', 'native side effect erased unrelated projected hash K')
  local changes = batch.changes(service.batch)
  assert(count(changes, 'set-room-hash', 2) == 0 and count(changes, 'set-room-hash') == 2)
end)

test('cancelling after a chunk submits completed room deletions and leaves remaining area intact', function()
  local service = reset(); areas[2] = 'Target'; local size = 205
  for id = 1, size do rooms[id] = freshRoom(id, 2) end
  toggle('on'); loadAreaDeletion(); local original = getAreaRooms
  getAreaRooms = function(id) local ids = original(id); table.sort(ids); return ids end
  local ok, err = pcall(function()
    mmp.doareadelete(2); service.retrySavedChanges()
    for _, timer in ipairs(timers) do if timer.delay == 0.010 then timer.fn(); break end end
    assert(loadfile(folder .. '/cancel_area.lua'))(); drainDeletionTimers()
  end)
  getAreaRooms = original; assert(ok, err)
  assert(not service.batch and not service.batching.pendingArea and areas[2])
  assert(#getAreaRooms(2) == size - 100)
  local changes = pending(service); changes[#changes + 1] = service.inFlightEntry.change
  assert(count(changes, 'delete-room') == 100 and count(changes, 'delete-area') == 0)
end)
test('private-only existence exclusions survive recovery after session finalization', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); local area
  toggle('on'); service.localOnly(function() addRoom(2); area = addAreaName('Private') end); service.retrySavedChanges()
  service = reset(true); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1); areas[area] = 'Private'
  service.batching.restore(); toggle('on'); mmp.setExit(1, 2, 'north'); setRoomArea(1, area); setRoomName(2, 'Private update')
  assert(#service.batching.changes(service.batch) == 0)
end)
test('incremental log persists local-only exclusions before finalization', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); local area
  toggle('on'); setRoomName(1, 'Public')
  service.localOnly(function() addRoom(2); area = addAreaName('Private') end)
  service = reset(true); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1); areas[area] = 'Private'
  service.batching.restore()
  assert(service.sharedExclusions.rooms['2'] and service.sharedExclusions.areas[tostring(area)])
  toggle('on'); addSpecialExit(1, 2, 'enter'); setRoomArea(1, area)
  assert(#service.batching.changes(service.batch) == 0)
end)
test('public recreation clears exclusions durably in the incremental log', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); local area
  toggle('on'); setRoomName(1, 'Public')
  service.localOnly(function() addRoom(2); area = addAreaName('Private'); deleteRoom(2); deleteArea(area) end)
  addRoom(2); local publicArea = addAreaName('Public')
  service = reset(true); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1); areas[publicArea] = 'Public'
  service.batching.restore()
  assert(not service.sharedExclusions.rooms['2'] and not service.sharedExclusions.areas[tostring(publicArea)])
  toggle('on'); mmp.setExit(1, 2, 'north'); setRoomArea(1, publicArea)
  local changes = service.batching.changes(service.batch)
  assert(count(changes, 'modify-exit', 1) == 1 and count(changes, 'set-room-area', 1) == 1)
end)
test('immediate setters also respect persistent local-only destination exclusions', function()
  local service = reset(); rooms[1] = freshRoom(1, 1); local area
  toggle('on'); service.localOnly(function() addRoom(2); area = addAreaName('Private') end); toggle('off')
  mmp.setExit(1, 2, 'north'); addSpecialExit(1, 2, 'enter'); setRoomArea(1, area); setRoomName(2, 'Private')
  assert(#requests == 0 and #pending(service) == 0)
end)
test('successful service map replacement clears saved exclusions', function()
  local service = reset(); rooms[1] = freshRoom(1, 1)
  toggle('on'); service.localOnly(function() addRoom(2) end); toggle('off')
  service.mapLoaded()
  service = reset(true); rooms[1], rooms[2] = freshRoom(1, 1), freshRoom(2, 1); service.batching.restore()
  assert(not next(service.sharedExclusions.rooms))
  toggle('on'); mmp.setExit(1, 2, 'north')
  assert(count(service.batching.changes(service.batch), 'modify-exit', 1) == 1)
end)
test('unrelated shared hash survives native ownership side effects after recovery', function()
  local service = reset(); rooms[1], rooms[2], rooms[3] = freshRoom(1, 1), freshRoom(2, 1), freshRoom(3, 1)
  rooms[1].hash, rooms[2].hash = 'H', 'K'
  toggle('on'); service.localOnly(function() setRoomIDbyHash(2, 'H') end); setRoomIDbyHash(3, 'H')
  service = reset(true); service.batching.restore()
  local changes = pending(service)
  assert(count(changes, 'set-room-hash', 2) == 0 and count(changes, 'set-room-hash') == 2)
end)

print(string.format('%d batching tests passed; %d failed', tests - failures, failures))
if failures > 0 then os.exit(1) end
