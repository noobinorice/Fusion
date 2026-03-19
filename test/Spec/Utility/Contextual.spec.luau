--!strict
--!nolint LocalUnused
local task = nil -- Disable usage of Roblox's task scheduler

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = ReplicatedStorage.Fusion

local doCleanup = require(Fusion.Memory.doCleanup)
local Contextual = require(Fusion.Utility.Contextual)
local scoped = require(Fusion.Memory.scoped)
local innerScope = require(Fusion.Memory.innerScope)

return function()
	local it = getfenv().it

	it("should construct a Contextual object", function()
		local expect = getfenv().expect

		local ctx = Contextual(nil)

		expect(ctx).to.be.a("table")
		expect(ctx.type).to.equal("Contextual")
	end)

	it("should provide its default value", function()
		local expect = getfenv().expect

		local ctx = Contextual("foo")

		expect(ctx:now()).to.equal("foo")
	end)

	it("should correctly scope temporary values", function()
		local expect = getfenv().expect

		local ctx = Contextual("foo")
		expect(ctx:now()).to.equal("foo")

		local scope = scoped({})
		ctx:is("bar"):during(scope, function(scope)
			expect(ctx:now(scope)).to.equal("bar")

			ctx:is("baz"):during(scope, function(scope)
				expect(ctx:now(scope)).to.equal("baz")
				return nil
			end)

			expect(ctx:now(scope)).to.equal("bar")
			return nil
		end)

		expect(ctx:now()).to.equal("foo")
		doCleanup(scope)
	end)

	it("should allow for argument passing", function()
		local expect = getfenv().expect

		local ctx = Contextual("foo")

		local function test(scope, a, b, c, d)
			expect(a).to.equal("a")
			expect(b).to.equal("b")
			expect(c).to.equal("c")
			expect(d).to.equal("d")
			return nil
		end

		local scope = scoped({})
		ctx:is("bar"):during(scope, test, "a", "b", "c", "d")
		doCleanup(scope)
	end)

	it("should not interfere across coroutines", function()
		local expect = getfenv().expect

		local ctx = Contextual("foo")

		local scope = scoped({})
		local coro1 = coroutine.create(function()
			ctx:is("bar"):during(scope, function(scope)
				expect(ctx:now(scope)).to.equal("bar")
				coroutine.yield()
				expect(ctx:now(scope)).to.equal("bar")
				return nil
			end)
		end)

		local coro2 = coroutine.create(function()
			ctx:is("baz"):during(scope, function(scope)
				expect(ctx:now(scope)).to.equal("baz")
				coroutine.yield()
				expect(ctx:now(scope)).to.equal("baz")
				return nil
			end)
		end)

		coroutine.resume(coro1)
		expect(ctx:now(scope)).to.equal("foo")
		coroutine.resume(coro2)
		expect(ctx:now(scope)).to.equal("foo")
		coroutine.resume(coro1)
		expect(ctx:now(scope)).to.equal("foo")
		coroutine.resume(coro2)
		expect(ctx:now(scope)).to.equal("foo")

		doCleanup(scope)
	end)

	it("should allow innerScopes to get the contextual value", function()
		local expect = getfenv().expect

		local ctx = Contextual("foo")

		local scope = scoped({})
		ctx:is("bar"):during(scope, function(scope)
			local inner = innerScope(scope)
			expect(ctx:now(scope)).to.equal("bar")
		end)
		doCleanup(scope)
	end)

	it("should be the default value if incorrect scope is passed in", function()
		local expect = getfenv().expect

		local ctx = Contextual("foo")

		local scope = scoped({})
		ctx:is("bar"):during(scope, function(scope)
			local inner = innerScope(scope)
			expect(ctx:now()).to.equal("foo")
		end)
		doCleanup(scope)
	end)
end
