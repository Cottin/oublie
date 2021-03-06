assert = require 'assert'
{assoc, clone, drop, empty, flip, gt, has, lte, merge, test, values, where} = require 'ramda' #auto_require:ramda
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

Oublie = require './Oublie'
utils = require './utils'

o1 = {id: 1, a: 'a1'}
o2 = {id: 2, a: 'a2'}
o3 = {id: 3, a: 'a3'}
o4 = {id: 4, a: 'a4'}

o1_ = {id: 1, a: 'a1_'}
o2_ = {id: 2, a: 'a2_'}
o3_ = {id: 3, a: 'a3_'}
o4_ = {id: 4, a: 'a4_'}

class App
	constructor: ->
		@cache = new Oublie
			pub: @pub
			remote: @remote
			data:
				objects:
					o:
						# o1 here is just for testing and should maybe not arise.
						# i.e. when the query that got o1 here expires, o1 should expire too
						1: o1
						2: o2
					# 	4: o4
				queries:
					o: [
						{ts: Date.now(), query: {one: 'o', where: {id: 2}}}
					# 	# {ts: Date.now(), query: {one: 'o', where: {a: 'a2'}}}
					# 	# {ts: Date.now(), query: {many: 'o', where: {id: {gt: 4}}}}
					# 	# {ts: Date.now(), query: {many: 'o', where: {id: {lte: 4}}}}
					]
				ids:
					o:
						1: Date.now() + 20
						2: Date.now() + 20
				diff:
					o:
						2: {id: 2, a: 'a2'}
					# 	4: Date.now()


		@log = []
		
	sub: (key, query, strategy, expiry) ->
		@cache.sub key, query, strategy, expiry

	do: (query, strategy) ->
		@cache.do query, strategy

	pub: (key, delta) =>
		@log.push {pub: {"#{key}": clone(delta)}} # todo: fix this properly

	remote: (key, query) =>
		@log.push {remote: {key, query}}
		serverData = {o: {1: o1_, 2: o2_, 3: o3_, 4: o4_}}
		return new Promise (res) =>
			res toRamda(query)(serverData)

	getData: -> @cache._dev_getData()


describe 'Oublie', ->
	describe 'sub', ->
		# it 'duplicate', ->
		# 	throws /subscription already exists/, ->
		# 		app = new App()
		# 		app.sub('a', {one: 'o', id: 1, _: 'LO'})
		# 		app.sub('a', {one: 'o', id: 1, _: 'LO'})
		describe 'edge cases', ->
			it 'remote returns null', (done) ->
				app = new App()
				app.sub 'o', {one: 'o', where: {a: 'qwe'}}, 'PE', 2
				waitFor 1, done, ->
					deepEq [
						{pub: {o: {val: undefined, sync: 'rw'}}}
						{remote: {key: 'o', query: {one: 'o', where: {a: 'qwe'}}}}
						{pub: {o: {val: {$assoc: null}, sync: 'rd'}}}
					], app.log

			it 'key is nil', ->
				app = new App()
				throws /key must be a string for subscription/, ->
					app.sub {one: 'o', id: 2}

			it 'query is nil', ->
				app = new App()
				throws /query must be an object for subscription/, ->
					app.sub 'o'

			# hard to test since toRamda returns null instead of [] / {}
			# it 'remote returns empty ([] or {})', (done) ->


		describe 'many', ->
			describe 'query', ->
				describe 'LO', ->
					it 'miss', ->
						app = new App()
						app.sub 'o', {one: 'o', where: {a: 'a3'}}, 'LO'
						deepEq [
							{pub: {o: {val: null, sync: null}}}
						], app.log

					it 'hit', ->
						app = new App()
						app.sub 'a', {one: 'o', where: {a: 'a2'}}, 'LO'
						deepEq [
							{pub: {a: {val: {$assoc: {2: o2}}, sync: null}}}
						], app.log

				describe 'OP 0', ->
					it 'not cached', (done) ->
						t0 = Date.now()
						app = new App()
						app.sub 'o', {one: 'o', where: {id: 1}}, 'OP', 0
						waitFor 1, done, ->
							deepEq [
								{pub: {o: {val: null, sync: 'rw'}}}
								{remote: {key: 'o', query: {one: 'o', where: {id: 1}}}}
								{pub: {o: {sync: 'rd', val: {$assoc: {1: o1_}}}}}
							], app.log
							{queries} = app.getData()
							{query, expires} = queries.o[1]
							deepEq {one: 'o', where: {id: 1}}, query
							t1 = Date.now()
							eq true, (expires >= t0 && expires <= t1)

					it 'cached', (done) ->
						t0 = Date.now()
						app = new App()
						app.sub 'o', {one: 'o', where: {id: 2}}, 'OP', 0
						waitFor 1, done, ->
							deepEq [
								{pub: {o: {val: {$assoc: {2: o2}}, sync: null}}}
							], app.log

				describe 'VO 0', ->
					it 'not cached', (done) ->
						t0 = Date.now()
						app = new App()
						app.sub 'o', {one: 'o', where: {id: 1}}, 'VO', 0
						waitFor 1, done, ->
							deepEq [
								{pub: {o: {val: {$assoc: {1: o1}}, sync: 'rw'}}}
								{remote: {key: 'o', query: {one: 'o', where: {id: 1}}}}
								{pub: {o: {sync: 'rd', val: {$assoc: {1: o1_}}}}}
							], app.log
							{queries} = app.getData()
							{query, expires} = queries.o[1]
							deepEq {one: 'o', where: {id: 1}}, query
							t1 = Date.now()
							eq true, (expires >= t0 && expires < t1)

					it 'cached', (done) ->
						t0 = Date.now()
						app = new App()
						app.sub 'o', {one: 'o', where: {id: 2}}, 'VO', 0
						waitFor 1, done, ->
							deepEq [
								{pub: {o: {val: {$assoc: {2: o2}}, sync: null}}}
							], app.log

				# 		it 'hit', (done) ->
				# 			app = new App()
				# 			app.sub 'o', {one: 'o', where: {id: 2}, _:'OP0'}
				# 			waitFor 1, done, ->
				# 				deepEq [
				# 					{pub: {o: {val: {$assoc: {2: o2}}, sync: 'rw'}}}
				# 					{remote: {key: 'o', query: {one: 'o', where: {id: 2}}}}
				# 					{pub: {o: {sync: 'rd', val: {$assoc: {2: o2_}}}}}
				# 				], app.log
				# 				deepEq {one: 'o', where: {id: 2}}, app.getData().queries.o[0]

		describe 'new', ->
			it 'simple case', ->
				app = new App()
				app.sub 'o', {new: 'o', values: {a: 'a5'}}
				deepEq [
					{pub: {o: {val: {$assoc: {id: '_0', a: 'a5'}}, sync: undefined}}}
				], app.log
				{diff} = app.getData()
				deepEq {id: '_0', a: 'a5'}, diff.o._0

		describe 'edit', ->
			it 'throws if object not there', ->
				app = new App()
				throws /Cannot edit non-existing object/, ->
					app.sub 'o', {edit: 'o', id: 3}

			it 'simple case', ->
				app = new App()
				app.sub 'o', {edit: 'o', id: 2}
				deepEq [
					{pub: {o: {val: {$assoc: {id: 2, a: 'a2'}}, sync: undefined}}}
				], app.log
				{diff} = app.getData()
				deepEq {id: 2, a: 'a2'}, diff.o[2]

		describe 'modify', ->
			it 'throws if subscription not there', ->
				app = new App()
				throws /no 'edit' or 'new' subscription with key '\$o'/, ->
					app.do {modify: '$o', delta: {a: 'a2$'}}

			it 'throws if subscription has no id', ->
				app = new App()
				app.sub '$o', {many: 'o'}, 'LO'
				throws /id in query at '\$o' is nil/, ->
					app.do {modify: '$o', delta: {a: 'a2$'}}

			it 'throws if subscription is not edit or new', ->
				app = new App()
				app.sub '$o', {one: 'o', id: 2}, 'LO'
				throws /does not seem to be a edit or new query/, ->
					app.do {modify: '$o', delta: {a: 'a2$'}}

			it 'simple case', ->
				app = new App()
				app.sub '$o', {edit: 'o', id: 2}
				app.do {modify: '$o', delta: {a: 'a2$'}}
				deepEq [
					{pub: {$o: {val: {$assoc: {id: 2, a: 'a2'}}, sync: undefined}}}
					{pub: {$o: {val: {a: 'a2$'}}}}
				], app.log
				{diff} = app.getData()
				deepEq {id: 2, a: 'a2$'}, diff.o[2]

		describe 'commit', ->
			it 'throws if subscription not there', ->
				app = new App()
				throws /no 'edit' or 'new' subscription with key '\$o'/, ->
					app.do {commit: '$o'}

			it 'throws if subscription has no id', ->
				app = new App()
				app.sub '$o', {many: 'o'}, 'LO'
				throws /id in query at '\$o' is nil/, ->
					app.do {commit: '$o'}

			it 'throws if subscription is not edit or new', ->
				app = new App()
				app.sub '$o', {one: 'o', id: 2}, 'LO'
				throws /does not seem to be a edit or new query/, ->
					app.do {commit: '$o'}

			it 'throws if no strategy', ->
				app = new App()
				app.sub '$o', {edit: 'o', id: 2}, 'LO'
				throws /commit query missing strategy/, ->
					app.do {commit: '$o'}

			# it.only 'medium case LO', ->
			# 	app = new App()
			# 	app.sub 'a', {many: 'o'}, 'LO'
			# 	app.sub 'b', {many: 'o', id: [1, 2]}, 'LO'
			# 	app.sub 'c', {one: 'o', where: {a: 'a2'}}, 'LO'
			# 	app.sub 'd', {many: 'o'}, 'LO'

			# 	app.sub '$o', {edit: 'o', id: 2}
			# 	app.do {modify: '$o', delta: {a: 'a2$'}}

			# 	app.do {commit: '$o'}, 'LO'
			# 	console.log app.log
			# 	deepEq [
			# 		{pub: {a: {val: {$merge: {2: {id: 2, a: 'a2$'}}}}}}
			# 	], drop(6, app.log)
			# 	{objects} = app.getData()
			# 	deepEq {id: 2, a: 'a2$'}, objects.o[2]

			# it 'throws if subscription has no id', ->
			# 	app = new App()
			# 	app.sub '$o', {many: 'o'}, 'LO'
			# 	throws /id in query at '\$o' is nil/, ->
			# 		app.do {modify: '$o', delta: {a: 'a2$'}}

			# it 'throws if subscription is not edit or new', ->
			# 	app = new App()
			# 	app.sub '$o', {one: 'o', id: 2}, 'LO'
			# 	throws /does not seem to be a edit or new query/, ->
			# 		app.do {modify: '$o', delta: {a: 'a2$'}}

			# it 'sim', ->
			# 	app = new App()
			# 	app.sub '$o', {edit: 'o', id: 2}
			# 	app.do {modify: '$o', delta: {a: 'a2$'}}
			# 	throws /no 'edit' or 'new' subscription with key '\$o'/, ->
			# 		app.do {modify: '$o', delta: {a: 'a2$'}}





