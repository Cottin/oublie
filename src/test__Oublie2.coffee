assert = require 'assert'
{assoc, clone, flip, where} = require 'ramda' #auto_require:ramda
{change, $assoc} = require 'ramda-extras'
{toRamda} = require 'popsiql'

eq = flip assert.strictEqual
deepEq = flip assert.deepStrictEqual
throws = (re, f) -> assert.throws f, re

waitFor = (ms, done, f) ->
	setTimeout ->
		f()
		done()
	, ms

Oublie = require './Oublie2'

serverData =
	0: o: {1: {id: 1, p: 'a0'}, 2: {id: 2, p: 'b0'}, 3: {id: 3, p: 'c0'}, 4: {id: 4, p: 'd0'}}
	1: o: {1: {id: 1, p: 'a1'}, 2: {id: 2, p: 'b1'}, 3: {id: 3, p: 'c1'}, 4: {id: 4, p: 'd1'}}
	2: o: {1: {id: 1, p: 'a2'}, 2: {id: 2, p: 'b2'}, 3: {id: 3, p: 'c2'}, 4: {id: 4, p: 'd2'}}
	3: o: {1: {id: 1, p: 'a3'}, 2: {id: 2, p: 'b3'}, 3: {id: 3, p: 'c3'}, 4: {id: 4, p: 'd3'}}

class App
	constructor: ->
		@remoteCount = 0
		@cache = new Oublie
			pub: @pub
			remote: @remote
			# data:
			# 	objects:
			# 		o:
			# 			1: o1
			# 	reads:
			# 	writes: {}
			# 	queries:
			# 	ids:
			# 		o:
			# 			1: Date.now() + 20
			# 			2: Date.now() + 20
			# 	diff:
			# 		o:
			# 			2: {id: 2, a: 'a2'}
			# 		# 	4: Date.now()


		@log = []
		
	sub: (key, query, strategy, expiry) ->
		@cache.sub key, query, strategy, expiry

	do: (query, strategy) ->
		@cache.do query, strategy

	pub: (key, delta) =>
		@log.push {pub: {"#{key}": clone(delta)}} # todo: fix this properly

	remote: (key, query) =>
		@remoteCount++
		@log.push {remote: {key, query}}
		serverData = {o: {1: o1_, 2: o2_, 3: o3_, 4: o4_}}
		return new Promise (res) =>
			res toRamda(query)(serverData)

	getData: -> @cache._dev_getData()


describe.only 'Oublie2', ->
	describe 'sub', ->
		describe 'one', ->
			describe 'LO', ->
				it 'miss', ->
					app = new App()
					app.sub 'o', {one: 'o', where: {a: 'a0'}}, 'LO'
					deepEq [
						{pub: {o: null}}
					], app.log







