-- Native return conventions model current and older Mudlet clients.
unpack = unpack or table.unpack
local rooms, hashes, reports = {[1]=true}, {}, {}
local mode = 'modern'
local messages = {}
mmp = {settings={}, editing=true, currentroom=1, echo=function(message) messages[#messages+1]=tostring(message) end}
mmp.localMapChanges = function(fn) return fn() end
function getRoomIDbyHash(hash) return hashes[hash] or -1 end
function getRoomHashByID(id)
  for hash, room in pairs(hashes) do if room == id then return hash end end
  return ''
end
testOriginal = {setRoomIDbyHash=function(id, hash)
  if mode == 'false' then return false end
  if mode ~= 'legacy' and not rooms[id] then return nil, 'invalid room' end
  for old, room in pairs(hashes) do if room == id then hashes[old]=nil end end
  if hash ~= '' or mode == 'legacy' then hashes[hash]=id end
  if mode ~= 'legacy' then return true end
end}
testService = {submit=function(change) reports[#reports+1]=change end}
local created = 0
function createRoomID() created=created+1;return created+10 end
function addRoom(id) rooms[id]=true end
function setRoomUserData() end
local centered
function centerview(id) assert(id ~= -1);centered=id end
function getRoomName(id) assert(id ~= -1);return 'Room' end
function getRoomCoordinates() return 0,0,0 end
function getRoomsByPosition() return {} end
function getRoomExits() return {} end
function echo() end
function echoLink() end
dofile(arg[1])
local function pack(...) return {n=select('#',...),...} end
local result=pack(setRoomIDbyHash(1,'abc'))
assert(result.n==1 and result[1]==true and #reports==1)
assert(setRoomIDbyHash(1,''))
assert(#reports==2 and reports[2].hash=='')
result=pack(setRoomIDbyHash(-1,'unknown'))
assert(result.n==2 and result[1]==nil and result[2]=='invalid room' and #reports==2)
mode='false'
assert(setRoomIDbyHash(1,'unknown')==false and #reports==2)
mode='legacy'
assert(pack(setRoomIDbyHash(1,'legacy')).n==0 and #reports==3)
setRoomIDbyHash(-1,'unknown')
assert(#reports==3)
mode='modern'
for _=1,3 do assert(mmp.roomidFromHash('')==-1) end
assert(created==0)
local id=mmp.roomidFromHash('valid')
assert(id==11 and mmp.roomidFromHash('valid')==id and created==1)
gmcp={Room={Info={roomhash='',exits={n='valid'},coords='1',area='Test'}}}
mmp.mappingNewroom()
mmp.speedwalking()
mmp.centerRoominfo()
assert(created==1 and centered==nil and mmp.currentroom==1)
-- An empty exit must not reach room creation or exit linking.
gmcp.Room.Info.roomhash='valid'
gmcp.Room.Info.exits={n=''}
mmp.roomexists=function(room) assert(room~=-1);return room==id end
mmp.anytolong=function(exit) return exit end
mmp.setExit=function() error('must not link empty hash') end
mmp.syncSafeRoomInfo=function() end
mmp.mappingNewroom()
assert(created==1)
-- Empty exits also cannot anchor creation of a previously unknown current room.
mmp.roomexists=function(room) assert(room~=-1);return false end
mmp.mappingNewroom()
assert(created==1)
mmp.centerRoominfo()
assert(centered==id)
-- A known neighboring room must not anchor creation for an empty current hash.
gmcp.Room.Info.roomhash=''
gmcp.Room.Info.exits={n='valid'}
mmp.mappingNewroom()
assert(created==1)
assert(#messages==0, table.concat(messages, '\n'))
print('Hash mapping regressions passed')
