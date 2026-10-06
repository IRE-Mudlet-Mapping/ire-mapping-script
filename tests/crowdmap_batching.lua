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
    os.remove(folder .. '/mapper.crowdmap-journal.json'); os.remove(folder .. '/mapper.crowdmap-journal.json.bak')
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
local tests = 0
local function test(name, fn) fn(); tests = tests + 1; print('PASS ' .. name) end

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
  io.open = function(path, mode) if mode == 'w' then return nil, 'disk full' end; return nativeOpen(path, mode) end
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

print(string.format('%d batching tests passed', tests))
