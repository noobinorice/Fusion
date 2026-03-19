--!strict
--!nolint LocalUnused
--!nolint LocalShadow
local task = nil -- Disable usage of Roblox's task scheduler

--[[
    Time-based contextual values, to allow for transparently passing values down
	the call stack.
]]

local Package = script.Parent.Parent
local innerScope = require(script.Parent.Parent.Memory.innerScope)
local Types = require(Package.Types)
local External = require(Package.External)
-- Logging
local parseError = require(Package.Logging.parseError)

export type Self<T> = Types.Contextual<T> & {
	_valuesNow: { [Types.Scope]: { value: T } },
	_defaultValue: T,
}

local class = {}
class.type = "Contextual"

local METATABLE = table.freeze({ __index = class })
local WEAK_KEYS_METATABLE = table.freeze({ __mode = "k" })

local function Contextual<T>(defaultValue: T): Types.Contextual<T>
	local self: Self<T> = setmetatable({
		-- if we held strong references to threads here, then if a thread was
		-- killed before this contextual had a chance to finish executing its
		-- callback, it would be held strongly in this table forever
		_valuesNow = setmetatable({}, WEAK_KEYS_METATABLE),
		_defaultValue = defaultValue,
	}, METATABLE) :: any

	return self
end

--[[
	Returns the current value of this contextual.
]]
function class.now<T>(self: Self<T>, scope: Types.Scope<{ _getParent: () -> ()? }>?): T
	local scope = scope
	local value = nil
	while typeof(value) ~= "table" and scope do
		value = self._valuesNow[scope]
		if scope._getParent then
			scope = scope._getParent()
		else
			break
		end
	end
	if typeof(value) ~= "table" then
		return self._defaultValue
	else
		return value.value
	end
end

--[[
	Temporarily assigns a value to this contextual.
]]
function class.is<T>(self: Self<T>, newValue: T)
	local methods = {}

	function methods.during<S, T, A...>(
		_: any, -- during is called with colon syntax but we don't care
		scope: Types.Scope & S,
		callback: (scope: Types.Scope & S, A...) -> T,
		...: A...
	): T
		local inner = innerScope(scope)
		self._valuesNow[inner] = { value = newValue }
		table.insert(inner, function()
			self._valuesNow[inner] = nil
		end)
		local ok, value = xpcall(callback, parseError, inner, ...)
		if not ok then
			External.logError("callbackError", value :: any)
		end
		return value
	end

	return methods
end

table.freeze(class)
return Contextual
