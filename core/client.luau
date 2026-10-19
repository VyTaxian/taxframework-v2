local signalModule = require(script.Parent.signal)
local promiseModule = require(script.Parent.promise)

local Client = {}
Client.__index = Client

local serviceRegistry = {}
local controllerRegistry = {}

local function getName(definition)
	if type(definition) ~= "table" then
		return "Unnamed"
	end

	return definition.Name or definition.name or "Unnamed"
end

local function runHook(instance, hookName)
	if type(instance) ~= "table" then
		return
	end

	local hook = instance[hookName] or instance[hookName:lower()]
	if type(hook) == "function" then
		local ok, err = xpcall(function()
			return hook(instance)
		end, debug.traceback)

		if not ok then
			warn(("Tax: failed to run %s: %s"):format(hookName, tostring(err)))
		end
	end
end

function Client.createService(definition)
	local service = setmetatable({
		name = getName(definition),
		definition = definition or {},
		started = false,
		signal = signalModule.new(),
	}, Client)

	serviceRegistry[service.name] = service
	return service
end

function Client.createController(definition)
	local controller = setmetatable({
		name = getName(definition),
		definition = definition or {},
		started = false,
		signal = signalModule.new(),
	}, Client)

	controllerRegistry[controller.name] = controller
	return controller
end

function Client.new(config)
	local self = setmetatable({}, Client)
	self.services = {}
	self.controllers = {}

	local serviceList = config and (config.Services or config.services) or {}
	local controllerList = config and (config.Controllers or config.controllers) or {}

	for _, serviceDef in ipairs(serviceList) do
		local service = Client.createService(serviceDef)
		self.services[service.name] = service
	end

	for _, controllerDef in ipairs(controllerList) do
		local controller = Client.createController(controllerDef)
		self.controllers[controller.name] = controller
	end

	return self
end

function Client.registerService(self, definition)
	local service = Client.createService(definition)
	self.services[service.name] = service
	return service
end

function Client.registerController(self, definition)
	local controller = Client.createController(definition)
	self.controllers[controller.name] = controller
	return controller
end

function Client.start(self, config)
	if config then
		self.services = {}
		self.controllers = {}

		for _, serviceDef in ipairs(config.Services or config.services or {}) do
			local service = Client.createService(serviceDef)
			self.services[service.name] = service
		end

		for _, controllerDef in ipairs(config.Controllers or config.controllers or {}) do
			local controller = Client.createController(controllerDef)
			self.controllers[controller.name] = controller
		end
	end

	for _, service in pairs(self.services) do
		if service and not service.started then
			runHook(service.definition, "Init")
			runHook(service.definition, "Start")
			service.started = true
		end
	end

	for _, controller in pairs(self.controllers) do
		if controller and not controller.started then
			runHook(controller.definition, "Init")
			runHook(controller.definition, "Start")
			controller.started = true
		end
	end

	return self
end

function Client.getService(name)
	return serviceRegistry[name]
end

function Client.getController(name)
	return controllerRegistry[name]
end

function Client.signal()
	return signalModule.new()
end

function Client.promise(resolver)
	return promiseModule.new(resolver)
end

return Client
