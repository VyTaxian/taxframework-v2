local signal = {}
signal.__index = signal

local function createConnection(obj, callback)
	local connection = {
		connected = true,
		signal = obj,
		callback = callback,
		index = obj._index or 0,
	}

	obj._index += 1
	obj.connections[connection.index] = connection

	function connection:disconnect()
		self.connected = false
		self.signal.connections[self.index] = nil
	end

	return connection
end

function signal.new()
	local self = setmetatable({}, signal)
	self.connections = {}
	self._index = 0
	return self
end

function signal:connect(callback)
	return createConnection(self, callback)
end

function signal:once(callback)
	local connection
	connection = self:connect(function(...)
		if connection.connected then
			connection:disconnect()
			callback(...)
		end
	end)
	return connection
end

function signal:wait()
	local thread = coroutine.running()
	local connection
	connection = self:once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function signal:fire(...)
	for index, connection in self.connections do
		if connection.connected then
			task.spawn(connection.callback, ...)
		end
	end
end

function signal:fireLocal(...)
	for index, connection in self.connections do
		if connection.connected then
			connection.callback(...)
		end
	end
end

function signal:destroy()
	table.clear(self.connections)
end

return signal
