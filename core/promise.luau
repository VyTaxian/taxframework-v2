local promise = {}
promise.__index = promise

local pending = "pending"
local resolved = "resolved"
local rejected = "rejected"

function promise.new(resolver)
	local self = setmetatable({}, promise)
	self.status = pending
	self.value = nil
	self.reason = nil
	self.callbacks = {
		success = {},
		error = {},
		finally = {},
	}

	local function resolve(value)
		if self.status ~= pending then return end
		self.status = resolved
		self.value = value
		self:executeCallbacks("success")
	end

	local function reject(reason)
		if self.status ~= pending then return end
		self.status = rejected
		self.reason = reason
		self:executeCallbacks("error")
	end

	task.spawn(function()
		local success, result = pcall(resolver, resolve, reject)
		if not success and self.status == pending then
			reject(result)
		end
	end)

	return self
end

function promise:executeCallbacks(callbackType)
	if callbackType == "success" then
		for _, callback in self.callbacks.success do
			task.spawn(callback, self.value)
		end
	elseif callbackType == "error" then
		for _, callback in self.callbacks.error do
			task.spawn(callback, self.reason)
		end
	end

	for _, callback in self.callbacks.finally do
		task.spawn(callback, self.status, self.value or self.reason)
	end
end

function promise:then(onSuccess, onError)
	return promise.new(function(resolve, reject)
		local function handleResult()
			if self.status == resolved then
				if onSuccess then
					local ok, result = pcall(onSuccess, self.value)
					if ok then
						resolve(result)
					else
						reject(result)
					end
				else
					resolve(self.value)
				end
			elseif self.status == rejected then
				if onError then
					local ok, result = pcall(onError, self.reason)
					if ok then
						resolve(result)
					else
						reject(result)
					end
				else
					reject(self.reason)
				end
			end
		end

		if self.status == pending then
			table.insert(self.callbacks.success, function(value)
				self.value = value
				handleResult()
			end)

			table.insert(self.callbacks.error, function(reason)
				self.reason = reason
				handleResult()
			end)
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
			task.spawn(callback)
			if self.status == resolved then
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
