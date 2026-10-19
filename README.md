# Tax Framework v2

**A lightweight, modular Roblox framework for clean server/client architecture.**

Tax Framework v2 is a lightweight Roblox framework designed to provide organized service registration, controller management, lifecycle startup, signals, and asynchronous promise handling.

Inspired by modern Roblox frameworks, Tax prioritizes performance, readability, and maintainability without introducing unnecessary abstractions or excessive dependencies. It provides developers with a straightforward foundation for building structured Roblox experiences while retaining control over their architecture.

## Features

- Lightweight server and client architecture
- Service and controller registration
- Centralized service and controller retrieval
- `Init` and `Start` lifecycle hooks
- Custom signal implementation
- Promise-based asynchronous operations
- Promise chaining and error handling
- Modular code organization
- Roblox Studio integration
- Customizable framework structure
- Minimal dependencies
- Suitable for personal and commercial Roblox projects

## Repository Structure

```text
taxframework-v2/
├── README.md
├── LICENSE
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

Tax Framework v2 uses separate server and client entry points. Each environment should have access to its own framework modules and appropriate service or controller definitions.

### Server Structure

Place the server framework inside `ServerScriptService`.

```text
ServerScriptService/
├── TaxFramework/
│   ├── init.luau
│   ├── core/
│   │   ├── server.luau
│   │   ├── client.luau
│   │   ├── signal.luau
│   │   └── promise.luau
│   ├── Services/
│   │   └── Service1.luau
│   └── Controllers/
│       └── Controller1.luau
└── ServerBootstrap.server.luau
```

### Client Structure

Place the client framework inside `StarterPlayerScripts`.

```text
StarterPlayer/
└── StarterPlayerScripts/
    ├── TaxFrameworkClient/
    │   ├── init.luau
    │   ├── core/
    │   │   ├── server.luau
    │   │   ├── client.luau
    │   │   ├── signal.luau
    │   │   └── promise.luau
    │   ├── Services/
    │   │   └── Service1.luau
    │   └── Controllers/
    │       └── Controller1.luau
    └── ClientBootstrap.client.luau
```

**Important:** Use the same module names and paths as those referenced by your `require` statements. The server and client should initialize independently, and server-only code must not be exposed to clients unnecessarily.

## Core Modules

### Root Entry Point

The root entry point exposes the framework's public API.

**Location:** `TaxFramework/init.luau`

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
    return server.createController(definition)
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
    return server.getController(name)
end

function tax.getClientService(name)
    return client.getService(name)
end

function tax.getClientController(name)
    return client.getController(name)
end

return tax
```

### Server Core

**Location:** `TaxFramework/core/server.luau`

The server core handles server-side registration, lifecycle execution, and registry access.

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

### Client Core

**Location:** `TaxFrameworkClient/core/client.luau`

The client core handles client-side registration, lifecycle execution, and registry access.

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

**Location:** `TaxFramework/core/signal.luau`

Signals provide lightweight event handling within the current execution environment.

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

**Location:** `TaxFramework/core/promise.luau`

The promise module provides asynchronous resolution and rejection, result chaining, error handling, finalization, and awaiting.

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

**Location:** `TaxFramework/Services/Service1.luau`

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

**Location:** `TaxFramework/Controllers/Controller1.luau`

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

Tax Framework v2 uses two lifecycle hooks.

### `Init()`

Runs during the initialization phase. Use it to prepare state, configure internal systems, and establish dependencies.

### `Start()`

Runs after initialization. Use it to connect events, begin runtime operations, and activate systems.

The framework processes initialization hooks before startup hooks for its registered services and controllers.

## Signals Usage

```lua
local tax = require(game.ServerScriptService.TaxFramework)

local updated = tax.signal()

updated:Connect(function(value)
    print("Received:", value)
end)

updated:Fire("Hello from Tax")
```

Signals are local to the environment in which they are created. They do not automatically replicate between the server and client. Use Roblox networking objects such as `RemoteEvent` when cross-boundary communication is required.

## Promises Usage

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

Tax Framework v2 is designed for developers who want a structured Roblox development environment without the overhead of a large framework.

It provides:

- A clear separation of server and client responsibilities
- Predictable lifecycle execution
- Organized service and controller registration
- Lightweight event handling
- Asynchronous promise utilities
- An architecture that can be extended as projects grow

## Contributing

Contributions may be submitted through the repository, subject to maintainer approval and the applicable license.

Before submitting changes:

- Keep implementations lightweight and readable.
- Preserve the separation between server and client responsibilities.
- Avoid unnecessary dependencies.
- Test changes in Roblox Studio.
- Document significant behavioral changes.
- Do not introduce code that violates the repository license.

Submitting a contribution does not automatically grant permission to relicense or redistribute the framework beyond the applicable license terms.

## License and Usage Restrictions

Tax Framework v2 is distributed under the **Tax Framework Source-Available License v1.0**.

Copyright (c) 2026 Tax Framework. All rights reserved.

This license grants limited permission to use and modify Tax Framework v2 under the conditions described below. It is a restrictive source-available license and is not an OSI-approved open-source license.

### 1. Permitted Use

Subject to compliance with this license, you may:

- Use the framework in personal Roblox projects.
- Integrate the framework into commercial Roblox games.
- Modify the source code for your own projects.
- Maintain private forks for personal or team development.
- Distribute Roblox games and experiences that incorporate the framework.
- Fix bugs, optimize performance, and extend functionality within your projects.

### 2. Prohibited Activities

Without prior written permission from the copyright holder, you may not:

- **Redistribute the framework:** Publish, upload, mirror, or distribute the original or modified framework source code as a standalone framework or framework package.
- **Resell the framework:** Sell, sublicense, lease, or commercially distribute the framework itself as a standalone product.
- **Repackage the framework:** Rebrand or republish the framework, in whole or in substantial part, as your own competing framework.
- **Claim authorship:** Falsely claim that you originally created Tax Framework v2 or authored source code written by the original developer.
- **Remove attribution:** Remove or alter existing copyright notices and applicable license references in copies of the framework source code.
- **Apply conflicting licenses:** Re-license the original framework code or purport to grant third parties rights that conflict with this license.
- **Misrepresent affiliation:** Claim to be an official maintainer, developer, or authorized distributor without permission.

### 3. Modification and Attribution

You may modify the framework for permitted use within your own projects.

Original copyright notices and applicable license references must remain intact in copies of the framework source code.

Modified versions must not be falsely presented as the official, unmodified Tax Framework v2 release.

### 4. Commercial Use

Commercial use is permitted when Tax Framework v2 is incorporated into a game or other permitted project.

This permission does not grant the right to sell or distribute the framework itself as a standalone product, whether modified or unmodified.

### 5. Ownership and Intellectual Property

The original framework source code and associated intellectual property remain the property of their respective copyright holder.

This license grants limited usage rights only. It does not transfer copyright ownership or grant trademark rights.

Third-party components, if any, remain subject to their own applicable licenses.

### 6. Termination

Permission granted under this license terminates automatically if you materially violate its terms, subject to applicable law.

Upon termination, you must cease activities that are no longer authorized by this license.

### 7. Disclaimer of Warranty

Tax Framework v2 is provided "AS IS", without warranties of any kind, express or implied, to the fullest extent permitted by law.

To the extent permitted by applicable law, the copyright holder is not liable for claims, damages, or other liabilities arising from the use or inability to use the framework.

### 8. Permission Requests

Requests for exceptions, standalone redistribution rights, relicensing, or other permissions must be submitted to the copyright holder through the official repository or another officially designated contact method.

Exceptions are valid only when expressly authorized in writing by the copyright holder.

### 9. Acceptance

By exercising the permissions granted by this license, you agree to comply with its applicable terms.

**Important:** This license is intended to restrict redistribution of the framework source code while allowing use within Roblox projects. It is not a substitute for legal advice. For enforceable licensing terms, publish the complete license in the repository's `LICENSE` file and obtain appropriate legal review before distribution.
