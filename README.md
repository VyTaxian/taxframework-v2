# Tax Framework v2

Tax Framework v2 is a lightweight Roblox framework designed for clean server/client architecture, service registration, and simple lifecycle startup.

It follows the structure and organization of modern Roblox frameworks while keeping the implementation lightweight, readable, and easy to customize. Tax provides a familiar development experience without unnecessary complexity or excessive abstraction.

## Features

- Server and client startup flow
- Service registration and retrieval
- Controller registration and retrieval
- `Init` and `Start` lifecycle hooks
- Custom signal implementation
- Promise support with chaining, error handling, and awaiting
- Lightweight server/client architecture
- Modular and maintainable codebase
- Easy Roblox Studio organization
- Customizable framework structure
- Minimal framework overhead

## Repository Structure

```text
taxframework-v2/
├── README.md
├── init.luau
├── core/
│   ├── server.luau
│   ├── client.luau
│   ├── signal.luau
│   └── promise.luau
├── Services/
│   └── Service1.luau
├── Controllers/
│   └── Controller1.luau
└── examples/
    └── ...
```

## Roblox Studio Setup

### Server-Side Structure

Place the server framework inside `ServerScriptService`.

```text
ServerScriptService
├── TaxFramework
│   ├── init.luau
│   ├── core
│   │   ├── server.luau
│   │   ├── client.luau
│   │   ├── signal.luau
│   │   └── promise.luau
│   ├── Services
│   │   └── Service1.luau
│   └── Controllers
│       └── Controller1.luau
└── ServerBootstrap.server.luau
```

### Client-Side Structure

Place the client framework inside `StarterPlayerScripts`.

```text
StarterPlayer
└── StarterPlayerScripts
    ├── TaxFrameworkClient
    │   ├── init.luau
    │   ├── core
    │   │   ├── server.luau
    │   │   ├── client.luau
    │   │   ├── signal.luau
    │   │   └── promise.luau
    │   ├── Services
    │   │   └── Service1.luau
    │   └── Controllers
    │       └── Controller1.luau
    └── ClientBootstrap.client.luau
```

> **Important:** Roblox ModuleScripts should be named and organized consistently with the paths used by `require`. The server and client framework instances must be configured separately.

## Root Entry Point

Create a ModuleScript named `init.luau` inside `TaxFramework`.

**Location:** `ServerScriptService/TaxFramework/init.luau`

```lua
local signalModule = require(script.core.signal)
local promiseModule = require(script.core.promise)
local server = require(script.core.server)
local client = require(script.core.client)

local tax = {}

function tax.signal()
    return signalModule.new()
end

function tax.promise(resolver)
    return promiseModule.new(resolver)
end

function tax.createService(definition)
    return server.createService(definition)
end

function tax.createController(definition)
    return client.createController(definition)
end

function tax.startServer(config)
    return server.new(config):start()
end

function tax.startClient(config)
    return client.new(config):start()
end

function tax.getService(name)
    return server.getService(name)
end

function tax.getController(name)
    return client.getController(name)
end

function tax.getClientService(name)
    return client.getService(name)
end

function tax.getClientController(name)
    return client.getController(name)
end

return tax
```

## Server Core

Create `server.luau` inside the `core` folder.

**Location:** `ServerScriptService/TaxFramework/core/server.luau`

The server core manages server-side service and controller registration, lifecycle execution, and registry access.

```lua
local signalModule = require(script.Parent.signal)
local promiseModule = require(script.Parent.promise)

local server = {}
server.__index = server

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
        local success, err = xpcall(function()
            hook(instance)
        end, debug.traceback)

        if not success then
            warn(("Tax: failed to run %s: %s"):format(hookName, tostring(err)))
        end
    end
end

function server.createService(definition)
    definition = definition or {}

    local service = {
        name = getName(definition),
        definition = definition,
        started = false,
        signal = signalModule.new(),
    }

    serviceRegistry[service.name] = service

    return service
end

function server.createController(definition)
    definition = definition or {}

    local controller = {
        name = getName(definition),
        definition = definition,
        started = false,
        signal = signalModule.new(),
    }

    controllerRegistry[controller.name] = controller

    return controller
end

function server.new(config)
    local self = setmetatable({
        services = {},
        controllers = {},
    }, server)

    config = config or {}

    for _, definition in ipairs(config.Services or config.services or {}) do
        local service = server.createService(definition)
        self.services[service.name] = service
    end

    for _, definition in ipairs(config.Controllers or config.controllers or {}) do
        local controller = server.createController(definition)
        self.controllers[controller.name] = controller
    end

    return self
end

function server:registerService(definition)
    local service = server.createService(definition)
    self.services[service.name] = service

    return service
end

function server:registerController(definition)
    local controller = server.createController(definition)
    self.controllers[controller.name] = controller

    return controller
end

function server:start()
    for _, service in pairs(self.services) do
        if not service.started then
            runHook(service.definition, "Init")
        end
    end

    for _, controller in pairs(self.controllers) do
        if not controller.started then
            runHook(controller.definition, "Init")
        end
    end

    for _, service in pairs(self.services) do
        if not service.started then
            runHook(service.definition, "Start")
            service.started = true
        end
    end

    for _, controller in pairs(self.controllers) do
        if not controller.started then
            runHook(controller.definition, "Start")
            controller.started = true
        end
    end

    return self
end

function server.getService(name)
    return serviceRegistry[name]
end

function server.getController(name)
    return controllerRegistry[name]
end

function server.signal()
    return signalModule.new()
end

function server.promise(resolver)
    return promiseModule.new(resolver)
end

return server
```

## Client Core

Create `client.luau` inside the `core` folder.

**Location:** `StarterPlayerScripts/TaxFrameworkClient/core/client.luau`

The client core handles client-side registration, controller initialization, lifecycle execution, and client registry access.

```lua
local signalModule = require(script.Parent.signal)
local promiseModule = require(script.Parent.promise)

local client = {}
client.__index = client

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
        local success, err = xpcall(function()
            hook(instance)
        end, debug.traceback)

        if not success then
            warn(("Tax: failed to run %s: %s"):format(hookName, tostring(err)))
        end
    end
end

function client.createService(definition)
    definition = definition or {}

    local service = {
        name = getName(definition),
        definition = definition,
        started = false,
        signal = signalModule.new(),
    }

    serviceRegistry[service.name] = service

    return service
end

function client.createController(definition)
    definition = definition or {}

    local controller = {
        name = getName(definition),
        definition = definition,
        started = false,
        signal = signalModule.new(),
    }

    controllerRegistry[controller.name] = controller

    return controller
end

function client.new(config)
    local self = setmetatable({
        services = {},
        controllers = {},
    }, client)

    config = config or {}

    for _, definition in ipairs(config.Services or config.services or {}) do
        local service = client.createService(definition)
        self.services[service.name] = service
    end

    for _, definition in ipairs(config.Controllers or config.controllers or {}) do
        local controller = client.createController(definition)
        self.controllers[controller.name] = controller
    end

    return self
end

function client:registerService(definition)
    local service = client.createService(definition)
    self.services[service.name] = service

    return service
end

function client:registerController(definition)
    local controller = client.createController(definition)
    self.controllers[controller.name] = controller

    return controller
end

function client:start()
    for _, service in pairs(self.services) do
        if not service.started then
            runHook(service.definition, "Init")
        end
    end

    for _, controller in pairs(self.controllers) do
        if not controller.started then
            runHook(controller.definition, "Init")
        end
    end

    for _, service in pairs(self.services) do
        if not service.started then
            runHook(service.definition, "Start")
            service.started = true
        end
    end

    for _, controller in pairs(self.controllers) do
        if not controller.started then
            runHook(controller.definition, "Start")
            controller.started = true
        end
    end

    return self
end

function client.getService(name)
    return serviceRegistry[name]
end

function client.getController(name)
    return controllerRegistry[name]
end

function client.signal()
    return signalModule.new()
end

function client.promise(resolver)
    return promiseModule.new(resolver)
end

return client
```

## Signal Module

Create `signal.luau` inside the `core` folder.

**Location:** `TaxFramework/core/signal.luau`

The signal module provides a lightweight event system with connections, one-time listeners, yielding waits, and event dispatch.

```lua
local signal = {}
signal.__index = signal

local function createConnection(self, callback)
    local connection = {
        connected = true,
        signal = self,
        callback = callback,
        index = self._index,
    }

    self._index += 1
    self.connections[connection.index] = connection

    function connection:disconnect()
        if not self.connected then
            return
        end

        self.connected = false
        self.signal.connections[self.index] = nil
    end

    connection.Disconnect = connection.disconnect

    return connection
end

function signal.new()
    return setmetatable({
        connections = {},
        _index = 1,
    }, signal)
end

function signal:connect(callback)
    assert(type(callback) == "function", "Tax Signal expects a callback")

    return createConnection(self, callback)
end

signal.Connect = signal.connect

function signal:once(callback)
    local connection

    connection = self:connect(function(...)
        connection:disconnect()
        callback(...)
    end)

    return connection
end

function signal:wait()
    local thread = coroutine.running()

    assert(thread, "Tax Signal:wait must run in a coroutine")

    self:once(function(...)
        task.spawn(thread, ...)
    end)

    return coroutine.yield()
end

function signal:fire(...)
    for _, connection in pairs(self.connections) do
        if connection.connected then
            task.spawn(connection.callback, ...)
        end
    end
end

signal.Fire = signal.fire

function signal:fireLocal(...)
    for _, connection in pairs(self.connections) do
        if connection.connected then
            connection.callback(...)
        end
    end
end

function signal:destroy()
    for _, connection in pairs(self.connections) do
        connection:disconnect()
    end

    table.clear(self.connections)
end

signal.Destroy = signal.destroy

return signal
```

## Promise Module

Create `promise.luau` inside the `core` folder.

**Location:** `TaxFramework/core/promise.luau`

The promise module supports asynchronous execution, resolution, rejection, chaining, error handling, finalization, and awaiting results.

```lua
local promise = {}
promise.__index = promise

local pending = "pending"
local resolved = "resolved"
local rejected = "rejected"

function promise.new(resolver)
    assert(type(resolver) == "function", "Tax Promise expects a resolver")

    local self = setmetatable({
        status = pending,
        value = nil,
        reason = nil,
        callbacks = {
            success = {},
            error = {},
            finally = {},
        },
    }, promise)

    local function executeCallbacks(callbackType)
        local callbacks = self.callbacks[callbackType]

        for _, callback in ipairs(callbacks) do
            task.spawn(callback, callbackType == "success" and self.value or self.reason)
        end

        for _, callback in ipairs(self.callbacks.finally) do
            task.spawn(callback, self.status, self.value ~= nil and self.value or self.reason)
        end
    end

    local function resolve(value)
        if self.status ~= pending then
            return
        end

        self.status = resolved
        self.value = value
        executeCallbacks("success")
    end

    local function reject(reason)
        if self.status ~= pending then
            return
        end

        self.status = rejected
        self.reason = reason
        executeCallbacks("error")
    end

    task.spawn(function()
        local success, result = pcall(resolver, resolve, reject)

        if not success then
            reject(result)
        end
    end)

    return self
end

function promise:then(onSuccess, onError)
    return promise.new(function(resolve, reject)
        local function handleResult()
            if self.status == resolved then
                if not onSuccess then
                    resolve(self.value)
                    return
                end

                local success, result = pcall(onSuccess, self.value)

                if success then
                    resolve(result)
                else
                    reject(result)
                end
            elseif self.status == rejected then
                if not onError then
                    reject(self.reason)
                    return
                end

                local success, result = pcall(onError, self.reason)

                if success then
                    resolve(result)
                else
                    reject(result)
                end
            end
        end

        if self.status == pending then
            table.insert(self.callbacks.success, handleResult)
            table.insert(self.callbacks.error, handleResult)
        else
            task.spawn(handleResult)
        end
    end)
end

function promise:catch(onError)
    return self:then(nil, onError)
end

function promise:finally(callback)
    return promise.new(function(resolve, reject)
        local function handleFinally()
            local success, err = pcall(callback)

            if not success then
                reject(err)
            elseif self.status == resolved then
                resolve(self.value)
            else
                reject(self.reason)
            end
        end

        if self.status == pending then
            table.insert(self.callbacks.finally, handleFinally)
        else
            task.spawn(handleFinally)
        end
    end)
end

function promise:await()
    local thread = coroutine.running()

    self:then(
        function(value)
            task.spawn(thread, true, value)
        end,
        function(reason)
            task.spawn(thread, false, reason)
        end
    )

    return coroutine.yield()
end

return promise
```

## Example Service

Create `Service1.luau` inside the `Services` folder.

**Location:** `ServerScriptService/TaxFramework/Services/Service1.luau`

```lua
local service1 = {
    Name = "Service1",
}

function service1:Init()
    print("Service1 initialized")
end

function service1:Start()
    print("Service1 started")
end

return service1
```

## Example Controller

Create `Controller1.luau` inside the `Controllers` folder.

**Location:** `ServerScriptService/TaxFramework/Controllers/Controller1.luau`

```lua
local controller1 = {
    Name = "Controller1",
}

function controller1:Init()
    print("Controller1 initialized")
end

function controller1:Start()
    print("Controller1 started")
end

return controller1
```

## Server Startup

Create a Script named `ServerBootstrap.server.luau` inside `ServerScriptService`.

```lua
local tax = require(script.Parent.TaxFramework)

tax.startServer({
    Services = {
        require(script.Parent.TaxFramework.Services.Service1),
    },

    Controllers = {
        require(script.Parent.TaxFramework.Controllers.Controller1),
    },
})
```

## Client Startup

Create a LocalScript named `ClientBootstrap.client.luau` inside `StarterPlayerScripts`.

```lua
local tax = require(script.Parent.TaxFrameworkClient)

tax.startClient({
    Services = {
        require(script.Parent.TaxFrameworkClient.Services.Service1),
    },

    Controllers = {
        require(script.Parent.TaxFrameworkClient.Controllers.Controller1),
    },
})
```

## Lifecycle

Tax Framework uses two lifecycle hooks for initialization and startup.

### `Init()`

Called during the initialization phase. Use it to prepare state, configure dependencies, and set up internal systems before startup.

### `Start()`

Called after initialization. Use it to begin active systems, connect events, and start runtime behavior.

The framework runs initialization hooks before startup hooks for the registered services and controllers.

## Signals

Signals provide a simple way to communicate between different systems within the same execution environment.

```lua
local tax = require(game.ServerScriptService.TaxFramework)

local updated = tax.signal()

updated:Connect(function(value)
    print("Received:", value)
end)

updated:Fire("Hello from Tax")
```

Signal events are local to the environment in which they are created. They do not automatically replicate between the server and client. Use Roblox networking objects such as `RemoteEvent` when cross-boundary communication is required.

## Promises

Promises help manage asynchronous operations and handle successful results or failures.

```lua
local tax = require(game.ServerScriptService.TaxFramework)

tax.promise(function(resolve, reject)
    local success, result = pcall(function()
        return "Tax Framework ready"
    end)

    if success then
        resolve(result)
    else
        reject(result)
    end
end)
:then(function(result)
    print(result)
end)
:catch(function(err)
    warn(err)
end)
```

## Why Tax?

Tax Framework is designed to provide a clean and flexible game architecture without overcomplicating the development process.

It is useful when you want:

- Clear separation between server and client systems
- Predictable lifecycle startup
- Lightweight service and controller organization
- Simple event-driven communication
- Promise-based asynchronous workflows
- Customizable architecture without unnecessary framework overhead

## Contributing

Contributions are welcome.

When extending Tax Framework, keep the implementation lightweight, preserve the separation between server and client systems, and prioritize readable, maintainable code.

Bug fixes, performance improvements, documentation updates, and carefully designed features are encouraged.

## License

This project is open for modification and use in your own Roblox projects. Add an explicit open-source license file to the repository if you want to define the legal terms for redistribution and modification.

## Notes

Tax Framework is intentionally minimal. Its goal is not to reproduce every feature found in larger Roblox frameworks, but to provide the essential building blocks for organized and maintainable development.

Whether you are creating a small Roblox experience or a larger project with multiple systems, Tax Framework provides a lightweight foundation that can be extended as your project grows.
