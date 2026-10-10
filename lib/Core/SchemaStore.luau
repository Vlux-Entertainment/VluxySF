--!strict
--!optimize 2

--[[
	The one place the schema lives. Both sides load a schema buffer into it, and every API module reads from it.

	Definitions are decoded out of the buffer the first time they are asked for and cached. Asking for all of them
	decodes the rest and freezes the cache, so the public schema table ends up fully frozen.
]]

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Codec = require(script.Parent.Codec)
local FormatMessage = require(script.Parent.Parent.Utility.FormatMessage)
local Signal = require(script.Parent.Parent.Utility.Signal)
local Tables = require(script.Parent.Parent.Utility.Tables)
local Types = require(script.Parent.Parent.Types)

local GROUP_CONTAINER_NAME = "SOUNDS"
local PRELOADED_NAME = "PreloadedSounds"
local WARMED_NAME = "WarmedSounds"
local UNATTACHED_NAME = "UnattachedSounds"

local initializedSignal = Signal.new()
local preloadedSignal = Signal.new()

local loaded: Codec.Loaded? = nil
local schema: Types.SoundSchema? = nil

local groupList: { SoundGroup } = {}
local definitions: { [string]: Types.SoundDefinition } = {}
local materialized = false

local isInitialized = false
local isPreloaded = false

local SchemaStore = {}

SchemaStore.Initialized = initializedSignal
SchemaStore.Preloaded = preloadedSignal

------------------------------------------------------------------------------------------------------------------------
--LOADING---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local function buildSchema(
	loadedSchema: Codec.Loaded,
	groupContainer: SoundGroup,
	preloaded: Configuration,
	warmed: Configuration,
	unattached: Configuration
)
	local groups: { [string]: SoundGroup } = {}
	for index, groupName in ipairs(loadedSchema.GroupNames) do
		groups[groupName] = groupList[index]
	end

	local built: Types.SoundSchema = {
		SoundGroupContainer = groupContainer,
		SoundGroups = table.freeze(groups),

		PreloadedSounds = preloaded,
		WarmedSounds = warmed,
		UnattachedSounds = unattached,

		SoundDefinitions = definitions,

		PreloadNames = table.freeze(table.clone(loadedSchema.PreloadNames)),
	}
	table.freeze(built)

	loaded = loadedSchema
	schema = built
end

local function newContainer(className: string, name: string): Instance
	local container = Instance.new(className)
	container.Name = name
	container.Parent = SoundService

	return container
end

--[[
	@param schemaBuffer buffer -- The schema made by Compile.

	Loads the schema on the server. Creates the SoundGroups and the holder folders in SoundService.
]]
function SchemaStore.LoadServer(schemaBuffer: buffer)
	local loadedSchema = Codec.Load(schemaBuffer)

	local groupContainer = newContainer("SoundGroup", GROUP_CONTAINER_NAME) :: SoundGroup
	groupContainer.Volume = 1

	for index, groupName in ipairs(loadedSchema.GroupNames) do
		local group = Instance.new("SoundGroup")
		group.Name = groupName
		group.Volume = 1
		group.Parent = groupContainer

		groupList[index] = group
	end

	buildSchema(
		loadedSchema,
		groupContainer,
		newContainer("Configuration", PRELOADED_NAME) :: Configuration,
		newContainer("Configuration", WARMED_NAME) :: Configuration,
		newContainer("Configuration", UNATTACHED_NAME) :: Configuration
	)
end

--[[
	@yields

	@param schemaBuffer buffer -- The schema received from the server.

	Loads the schema on the client. Waits for the SoundGroups and holder folders the server made to replicate.
]]
function SchemaStore.LoadClient(schemaBuffer: buffer)
	local loadedSchema = Codec.Load(schemaBuffer)

	local groupContainer = SoundService:WaitForChild(GROUP_CONTAINER_NAME) :: SoundGroup

	for index, groupName in ipairs(loadedSchema.GroupNames) do
		groupList[index] = groupContainer:WaitForChild(groupName) :: SoundGroup
	end

	buildSchema(
		loadedSchema,
		groupContainer,
		SoundService:WaitForChild(PRELOADED_NAME) :: Configuration,
		SoundService:WaitForChild(WARMED_NAME) :: Configuration,
		SoundService:WaitForChild(UNATTACHED_NAME) :: Configuration
	)
end

------------------------------------------------------------------------------------------------------------------------
--READING---------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[[
	@return SoundSchema -- The public schema table.

	Returns the schema. Errors when nothing is loaded yet.
]]
function SchemaStore.GetSchema(): Types.SoundSchema
	if not schema then
		FormatMessage.Error("The schema is not loaded yet!", 3)
	end

	return schema :: Types.SoundSchema
end

--[[
	@param name string -- The sound name.

	@return SoundDefinition? -- The frozen definition, or nil when no sound has that name.

	Returns one definition, decoding it out of the buffer the first time.
]]
function SchemaStore.GetDefinition(name: string): Types.SoundDefinition?
	local definition = definitions[name]
	if definition then
		return definition
	end

	local loadedSchema = loaded
	if not loadedSchema then
		return nil
	end

	local offset = loadedSchema.Offsets[name]
	if not offset then
		return nil
	end

	local decoded, groupIndex = Codec.ReadDefinition(loadedSchema, offset)
	if groupIndex > 0 then
		(decoded.Properties :: any).SoundGroup = groupList[groupIndex]
	end

	Tables.DeepFreeze(decoded)

	if not materialized then
		definitions[name] = decoded
	end

	return decoded
end

--[[
	@return SoundDefinitions -- Every definition, keyed by name, frozen.

	Decodes every definition that has not been decoded yet, then freezes the definitions table.
]]
function SchemaStore.GetDefinitions(): Types.SoundDefinitions
	if materialized then
		return definitions
	end

	local loadedSchema = loaded
	if loadedSchema then
		for _, name in ipairs(loadedSchema.Names) do
			if not definitions[name] then
				SchemaStore.GetDefinition(name)
			end
		end
	end

	materialized = true
	table.freeze(definitions)

	return definitions
end

--[[
	@return { string } -- A new array of every sound name.

	Returns the sound names in the order they were compiled.
]]
function SchemaStore.GetNames(): { string }
	local loadedSchema = loaded
	if not loadedSchema then
		return {}
	end

	return table.clone(loadedSchema.Names)
end

--[[
	@return { string } -- The names of the sounds the client preloads on startup.
]]
function SchemaStore.GetPreloadNames(): { string }
	return SchemaStore.GetSchema().PreloadNames
end

------------------------------------------------------------------------------------------------------------------------
--STATE-----------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

--[[
	Marks the schema as ready for use and fires Initialized.
]]
function SchemaStore.SetInitialized()
	if isInitialized then
		return
	end

	isInitialized = true
	initializedSignal:Fire()
end

--[[
	@return boolean -- Whether the schema is ready for use.
]]
function SchemaStore.IsInitialized(): boolean
	return isInitialized
end

--[[
	Marks the startup preloads as finished and fires Preloaded.
]]
function SchemaStore.SetPreloaded()
	if isPreloaded then
		return
	end

	isPreloaded = true
	preloadedSignal:Fire()
end

--[[
	@return boolean -- Whether the startup preloads have finished.
]]
function SchemaStore.IsPreloaded(): boolean
	return isPreloaded
end

--[[
	@param level number? -- The stack level the error points at. Default is 3, the caller of the API function.

	Errors when the schema is not ready. Every API function that needs the schema calls this first.
]]
function SchemaStore.AssertInitialized(level: number?)
	if isInitialized then
		return
	end

	FormatMessage.Error(
		"The schema is not ready yet! Call Startup.InitServer or Startup.InitClient first, or wait with Startup.WaitForSchema.",
		level or 3
	)
end

--[[
	@param level number? -- The stack level the error points at. Default is 3, the caller of the API function.

	Errors on the server. Every client-only API function calls this first.
]]
function SchemaStore.AssertClient(level: number?)
	if RunService:IsClient() then
		return
	end

	FormatMessage.Error("This function only works on the client!", level or 3)
end

return SchemaStore
