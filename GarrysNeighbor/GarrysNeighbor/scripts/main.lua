-- Garry's Neighbor v1.0.0
-- Hello Neighbor + Garry's Mod style sandbox
-- UE4SS Lua mod

local MOD_NAME = "GarrysNeighbor"
local props = {}
local held = nil
local enabled = true
local MOVE_STEP = 45.0
local ROT_STEP = 15.0
local SPAWN_DISTANCE = 240.0

local function isValid(obj)
    if obj == nil then return false end
    local ok, result = pcall(function() return obj:IsValid() end)
    return ok and result == true
end

local function gameThread(fn)
    ExecuteInGameThread(function()
        local ok, err = pcall(fn)
        if not ok then
            print(string.format("[%s] ERROR: %s\n", MOD_NAME, tostring(err)))
        end
    end)
end

local function getPawn()
    local ok, controller = pcall(function()
        return UEHelpers:GetPlayerController()
    end)
    if not ok or not isValid(controller) then return nil end
    local pawn = controller.Pawn
    if not isValid(pawn) then return nil end
    return pawn
end

local function cleanupProps()
    local alive = {}
    for _, actor in ipairs(props) do
        if isValid(actor) then
            table.insert(alive, actor)
        end
    end
    props = alive
    if held and not isValid(held) then
        held = nil
    end
end

local function getPlayerPose()
    local pawn = getPawn()
    if not pawn then return nil end

    local loc, rot
    if not pcall(function() loc = pawn:K2_GetActorLocation() end) or not loc then
        return nil
    end
    if not pcall(function() rot = pawn:K2_GetActorRotation() end) or not rot then
        rot = {Pitch = 0, Yaw = 0, Roll = 0}
    end
    return pawn, loc, rot
end

local function setCollisionAndMesh(actor, mesh)
    local comp = actor.StaticMeshComponent
    if not isValid(comp) then return false end

    -- SetStaticMesh is preferable when exposed; fall back to the property setter.
    local setMeshOK = pcall(function() comp:SetStaticMesh(mesh) end)
    if not setMeshOK then
        setMeshOK = pcall(function() comp.StaticMesh = mesh end)
    end
    if not setMeshOK then return false end

    -- EComponentMobility::Movable == 2 on UE4.
    pcall(function() comp.Mobility = 2 end)
    -- ECollisionEnabled::QueryAndPhysics == 3; some builds accept a direct enum value.
    pcall(function() comp:SetCollisionEnabled(3) end)
    pcall(function() actor:K2_SetActorEnableCollision(true) end)
    return true
end

local function spawnProp(meshPath, label)
    if not enabled then return end

    gameThread(function()
        local pawn, playerLoc, playerRot = getPlayerPose()
        if not pawn then
            print(string.format("[%s] Игрок ещё не готов. Зайди в уровень.\n", MOD_NAME))
            return
        end

        local world = pawn:GetWorld()
        if not isValid(world) then
            print(string.format("[%s] Не найден UWorld.\n", MOD_NAME))
            return
        end

        local actorClass = StaticFindObject("/Script/Engine.StaticMeshActor")
        if not isValid(actorClass) then
            print(string.format("[%s] StaticMeshActor недоступен в этой сборке UE4SS.\n", MOD_NAME))
            return
        end

        local mesh = LoadAsset(meshPath)
        if not isValid(mesh) then
            print(string.format("[%s] Не найден ассет: %s\n", MOD_NAME, meshPath))
            return
        end

        local yaw = tonumber(playerRot.Yaw) or 0.0
        local radians = math.rad(yaw)
        local spawnLocation = {
            X = (playerLoc.X or 0) + math.cos(radians) * SPAWN_DISTANCE,
            Y = (playerLoc.Y or 0) + math.sin(radians) * SPAWN_DISTANCE,
            Z = (playerLoc.Z or 0) + 65.0
        }
        local spawnRotation = {Pitch = 0.0, Yaw = yaw, Roll = 0.0}

        local ok, actor = pcall(function()
            return world:SpawnActor(actorClass, spawnLocation, spawnRotation)
        end)
        if not ok or not isValid(actor) then
            print(string.format("[%s] SpawnActor не создал %s.\n", MOD_NAME, label))
            return
        end

        if not setCollisionAndMesh(actor, mesh) then
            pcall(function() actor:K2_DestroyActor() end)
            print(string.format("[%s] Не удалось настроить StaticMeshComponent.\n", MOD_NAME))
            return
        end

        table.insert(props, actor)
        print(string.format("[%s] + %s | пропов: %d\n", MOD_NAME, label, #props))
    end)
end

local function nearestProp()
    cleanupProps()
    local pawn = getPawn()
    if not pawn then return nil end

    local playerLoc
    if not pcall(function() playerLoc = pawn:K2_GetActorLocation() end) or not playerLoc then
        return nil
    end

    local best, bestDistance = nil, math.huge
    for _, actor in ipairs(props) do
        local loc
        if pcall(function() loc = actor:K2_GetActorLocation() end) and loc then
            local dx = (loc.X or 0) - (playerLoc.X or 0)
            local dy = (loc.Y or 0) - (playerLoc.Y or 0)
            local dz = (loc.Z or 0) - (playerLoc.Z or 0)
            local d2 = dx * dx + dy * dy + dz * dz
            if d2 < bestDistance then
                bestDistance = d2
                best = actor
            end
        end
    end
    return best
end

local function toggleSandbox()
    enabled = not enabled
    print(string.format("[%s] Sandbox: %s\n", MOD_NAME, enabled and "ON" or "OFF"))
end

local function grabRelease()
    if not enabled then return end
    gameThread(function()
        if held and isValid(held) then
            held = nil
            print(string.format("[%s] Проп отпущен.\n", MOD_NAME))
            return
        end

        local actor = nearestProp()
        if not actor then
            print(string.format("[%s] Нет созданных пропов. Нажми 1/2/3.\n", MOD_NAME))
            return
        end

        held = actor
        print(string.format("[%s] Проп захвачен. I/J/K/L = двигать, U/O = высота, Q/E = вращать.\n", MOD_NAME))
    end)
end

local function moveHeld(dx, dy, dz, yawDelta)
    if not enabled or not held or not isValid(held) then return end

    gameThread(function()
        if not isValid(held) then
            held = nil
            return
        end

        local loc, rot
        if not pcall(function() loc = held:K2_GetActorLocation() end) or not loc then return end
        if not pcall(function() rot = held:K2_GetActorRotation() end) or not rot then
            rot = {Pitch = 0, Yaw = 0, Roll = 0}
        end

        pcall(function()
            held:K2_SetActorLocation({
                X = (loc.X or 0) + dx,
                Y = (loc.Y or 0) + dy,
                Z = (loc.Z or 0) + dz
            }, false, {}, true)
        end)

        pcall(function()
            held:K2_SetActorRotation({
                Pitch = rot.Pitch or 0,
                Yaw = (rot.Yaw or 0) + yawDelta,
                Roll = rot.Roll or 0
            }, true)
        end)
    end)
end

local function deleteNearest()
    if not enabled then return end
    gameThread(function()
        local actor = nearestProp()
        if not actor then
            print(string.format("[%s] Удалять нечего.\n", MOD_NAME))
            return
        end
        if held == actor then held = nil end
        pcall(function() actor:K2_DestroyActor() end)
        cleanupProps()
        print(string.format("[%s] Проп удалён.\n", MOD_NAME))
    end)
end

local function deleteAll()
    if not enabled then return end
    gameThread(function()
        local count = 0
        for _, actor in ipairs(props) do
            if isValid(actor) then
                count = count + 1
                pcall(function() actor:K2_DestroyActor() end)
            end
        end
        props = {}
        held = nil
        print(string.format("[%s] Удалено пропов: %d\n", MOD_NAME, count))
    end)
end

local function help()
    print("\n========== GARRY'S NEIGHBOR ==========" ..
        "\n1 = Cube | 2 = Sphere | 3 = Cylinder" ..
        "\nF1 = Sandbox ON/OFF" ..
        "\nF2 = Grab / Release ближайшего пропа" ..
        "\nI/J/K/L = двигать захваченный проп" ..
        "\nU/O = вверх / вниз" ..
        "\nQ/E = вращать" ..
        "\nF3 = удалить ближайший проп" ..
        "\nF4 = удалить все пропы" ..
        "\nH = показать помощь" ..
        "\n=======================================\n")
end

RegisterKeyBind(Key.ONE, function()
    spawnProp("/Engine/BasicShapes/Cube.Cube", "Cube")
end)
RegisterKeyBind(Key.TWO, function()
    spawnProp("/Engine/BasicShapes/Sphere.Sphere", "Sphere")
end)
RegisterKeyBind(Key.THREE, function()
    spawnProp("/Engine/BasicShapes/Cylinder.Cylinder", "Cylinder")
end)
RegisterKeyBind(Key.F1, toggleSandbox)
RegisterKeyBind(Key.F2, grabRelease)
RegisterKeyBind(Key.F3, deleteNearest)
RegisterKeyBind(Key.F4, deleteAll)
RegisterKeyBind(Key.H, help)

RegisterKeyBind(Key.I, function() moveHeld(0, MOVE_STEP, 0, 0) end)
RegisterKeyBind(Key.K, function() moveHeld(0, -MOVE_STEP, 0, 0) end)
RegisterKeyBind(Key.J, function() moveHeld(-MOVE_STEP, 0, 0, 0) end)
RegisterKeyBind(Key.L, function() moveHeld(MOVE_STEP, 0, 0, 0) end)
RegisterKeyBind(Key.U, function() moveHeld(0, 0, MOVE_STEP, 0) end)
RegisterKeyBind(Key.O, function() moveHeld(0, 0, -MOVE_STEP, 0) end)
RegisterKeyBind(Key.Q, function() moveHeld(0, 0, 0, -ROT_STEP) end)
RegisterKeyBind(Key.E, function() moveHeld(0, 0, 0, ROT_STEP) end)

ExecuteWithDelay(4000, function()
    print(string.format("[%s] Loaded. Нажми H для управления.\n", MOD_NAME))
end)
