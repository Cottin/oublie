{__, all, always, any, assoc, both, call, contains, difference, either, filter, flip, fromPairs, has, isEmpty, isNil, keys, last, lt, map, merge, once, pathEq, pickBy, reject, remove, replace, split, test, type, union, uniq} = R = require 'ramda' #auto_require:ramda
{cc, change, yreduce, ymerge, ymap, isThenable, changedPaths, diff} = require 'ramda-extras'
popsiql = require 'popsiql'
hash = require 'object-hash'
debounce = require 'lodash.debounce'

{getEntity, getOp, validateQuery} = require './utils3.coffee'

ERR = 'Oublie Error: '

class Oublie
	constructor: ({pub, remote}) ->
		@config = {pub, remote}
		@state = {objects: {}, ids: {}, reads: {}, writes: {}, subs: {}, edits: {}}
		@nextState = @state
		@spawnCount = 0

		# Great explanation of debounce vs. throttle:
		# https://css-tricks.com/debouncing-throttling-explained-examples/
		@commitAndPublish = debounce @__commitAndPublish, 50,
			leading: false # don't publish directly, let changes "buffer up"
			trailing: true # then when they're all buffered, publish everything at once
			maxWait: 250 # if too many changes, don't let them buffer in all eternity


	##### PUBLIC API
	# Make a new subscription to data (or pass query = null to unsubscribe)
	sub: (key, query, strategy, expiry) ->
		if isNil query
			@change {subs: {"#{key}": undefined}} # unsubsrcibe
			return

		validateQuery query
		switch getOp query
			when 'one' then @oneOrMany key, query, strategy, expiry
			when 'many' then @oneOrMany key, query, strategy, expiry
			when 'spawn' then @spawn key, query
			when 'edit' then @edit key, query
			else throw new Error ERR + 'no recognized operation for sub'


	##### INTERNAL OPERATIONS

	# Reads one or many objects from local cache an invokes remote if needed
	oneOrMany: (key, query, strategy, expiry) ->
		# reset sub
		@change {subs: {"#{key}": {$assoc: {query, strategy, expiry, ts: Date.now()}}}}

		# remoteQuery = calcRemoteQuery @state, query, strategy
		# console.log 'remoteQeury', remoteQuery
		# if !isNil remoteQuery
		# 	@change {subs: {"#{key}": {_: 'rw'}}}

		# 	runRemote @config.remote, key, remoteQuery
		# 		.then (val) =>
		# 			@change {subs: {"#{key}": {_: 'rd'}}}

		# 			entity = getEntity query
		# 			# console.log 'val', val
		# 			val_ = map ymerge({_: 'rd'}), val  
		# 			expires = Date.now() + expiry * 1000
		# 			@change
		# 				objects: {"#{entity}": {$merge: val_}}
		# 				ids: {"#{entity}": {$merge: map(always(expires), val)}}
		# 				reads: {"#{entity}": {"#{hash(query)}": {expires, query}}}

		# 			@queeueRemoveStatus entity, key, keys(val)

	# TOGO:
	# - [x] change
	# - [ ] publish what's need to be published (throttled or similar) = rewrite commitAndPublish
	#		- [x] rename to removeExpired
	#		- [x] removeExpired borde returnera en spec
	#		- [x] kolla om changedPaths klarar $assoc
	#		- [ ] kolla om changedPaths och diff kan göras smartare
	#		- [ ] tänk på hur det funkar om något tas bor också (ej läggs till)
	#		- [ ] gör den enklaste optimeringen, kör inte om bara ändrats lastResult, reads, etc.
	# - [ ] skulle kunna ha en semi-optimistisk som OP men läser också alltid från server
	#	- [x] rename @data to @state
	# - [ ] run reads in playground and make sure it works
	# - [ ] implement the other operations and test them in playground
	# - [ ] make the restaurant reviewer in oublie examples

	##### INTERNAL INFRASTRUCTURE

	# Make any changes to the cache with a delta.
	# Note that you don't have to worry about publishing changes to subscribers,
	# just assume that they will be calculated and published in a somewhat optimal
	# way :)
	change: (delta) ->
		@nextState = change delta, @nextState
		console.log 'change', delta, @nextState
		@commitAndPublish() # note that it's debounced

		# if !quiet then @commitAndPublish() # note that it's debounced

	__commitAndPublish: ->
		# By the line below, calls to @change won't effect this commit even if they
		# are async and lie on the call stack waiting for the event loop, which
		# could happen since there are function-calls inside this function.
		nextStateRef = @nextState

		# spec = {}#removeExpired nextStateRef
		spec = removeExpired nextStateRef
		newState =
			if !isNil spec then change spec, nextStateRef
			else nextStateRef

		lastState = @state
		@state = newState
		# we can safely use @state from here on since only this function is allowed
		# to do assinments to @state.

		@_dev_dataChanged?(@state)

		delta = diff lastState, @state
		pathsChanged = changedPaths delta
		console.log 'delta', delta
		console.log 'paths', pathsChanged


		# unsubs = doto pathsChanged,
		# 						filter(test(/^subs.\w+\.\w+$/)),
		# 						filter (s) -> R.path(s, delta) == undefined

		# unsubs = cc filter((s) -> R.path(s, delta) == undefined),
		# 						filter(test(/^subs.\w+\.\w+$/)),
		# 						pathsChanged

		unsubs = cc filter(pathEq(__, undefined, delta)),
								filter(test(/^subs.\w+$/)),
								pathsChanged
		console.log 'unsubs', unsubs

		for s in unsubs
			[_, key] = split '.', s
			@config.pub key, undefined

		if isEmpty delta then return

		for key, sub of @state.subs
			@runSub @state, key, pathsChanged

		# changedSubs = calcChangedSubs pathsChanged
		# affectedSubs = calcAffectedSubs pathsChanged, @state
		# affectedSubsNotChanged = difference affectedSubs, changedSubs

		# if isEmpty(changedSubs) && isEmpty(affectedSubsNotChanged) then return

		# for s in changedSubs
		# 	[entity, key] = split '.', s
		# 	@runSub @state, entity, key, true

		# for s in affectedSubsNotChanged
		# 	[entity, key] = split '.', s
		# 	@runSub @state, entity, key, false
		# 	# # if shouldRunAffectedSub s
		# 	# 	@runSub s

	runSub: (state, key, paths) ->
		sub = state.subs[key]
		entity = getEntity sub.query
		testIt = (s) -> ! cc isEmpty, filter(test(new RegExp(s))), paths
		isChanged = testIt "^subs\.#{key}\.(?:query|strategy|ts)"
		isStatusChanged = testIt "^subs\.#{key}\._"
		isAffected = testIt "^objects\.#{entity}"
		console.log {isChanged, isStatusChanged, isAffected}

		if !isChanged && !isStatusChanged && !isAffected then return

		if !isChanged && !isAffected # only a status change
			@config.pub key, {_: sub._}
			@change {subs: {"#{key}": {last_: sub._}}}
			return

		else # either isChanged or isAffected or both is true

			if isChanged then @runRemote state, sub, key

			val = switch sub.strategy
				when 'LO' then readQuery state, sub.query
				when 'PE'
					if isChanged then {}
					else if isAffected
						# this is the case: if PE is reading and other sub affects the data of same entity
						# PE will be forced to run locally.
						if sub._ == 'rw' then sub.val 
						else readQuery state, sub.query
				when 'OP'
					if isChanged
						console.log 'isChanged'
						if isCached(state, sub.query) == true
							readQuery state, sub.query
						else {}
					else if isAffected
						if sub._ == 'rw' then sub.val 
						else readQuery state, sub.query
				when 'VO' then readQuery state, sub.query

		ids = keys val
		hashResult = hash val
		if hashResult != sub.lastResult || sub._ != sub.last_
			@config.pub key, {$assoc: {val, _: sub._}}
			subData = {lastResult: hashResult, ids, last_: sub._}
			@change {subs: {"#{key}": subData}}

	runRemote: (state, sub, key) ->
		{query, strategy, expiry} = sub
		remoteQuery = calcRemoteQuery state, query, strategy
		console.log 'remoteQeury', remoteQuery
		if !isNil remoteQuery
			@change {subs: {"#{key}": {_: 'rw'}}}

			runRemote @config.remote, key, remoteQuery
				.then (val) =>
					@change {subs: {"#{key}": {_: 'rd'}}}

					entity = getEntity query
					# console.log 'val', val
					val_ = map ymerge({_: 'rd'}), val  
					expires = Date.now() + expiry * 1000
					@change
						objects: {"#{entity}": {$merge: val_}}
						ids: {"#{entity}": {$merge: map(always(expires), val)}}
						reads: {"#{entity}": {"#{hash(query)}": {expires, query}}}

					@queeueRemoveStatus entity, key, keys(val)



	# # note: if isChanged == false => then it is affected
	# runSub: (state, entity, key, isChanged) ->
	# 	sub = state.subs[entity][key]
	# 	if isNil sub then return

	# 	if readOrReset sub.strategy, isChanged
	# 		val = readQuery state, sub.query
	# 	else
	# 		val = {}

	# 	ids = keys val
	# 	result = {val, _: sub._}
	# 	hashResult = hash result
	# 	if hashResult != sub.lastResult
	# 		@config.pub key, {$assoc: result}
	# 		@change {subs: {"#{entity}": {"#{key}": {lastResult: hashResult, ids}}}}

	# resetSub: (entity, key) ->
	# 	sub = @data.subs[entity][key]
	# 	if isNil sub then return

	# 	result = {val: {}, _: sub._}
	# 	hashResult = hash result
	# 	if hashResult != sub.lastResult
	# 		@config.pub key, {$assoc: result}
	# 		@change {subs: {"#{entity}": {"#{key}": {lastResult: hashResult, ids: []}}}}

	# Schedules a removing of done-status(es) for sub and/or entities.
	# Note: if statuses has changes from 'done' (eg. new data loading), it will
	# not remove the status
	queeueRemoveStatus: (entity, key, ids) =>
		flip(setTimeout) 2000, =>
			# console.log 'queeueRemoveStatus', entity, key, ids
			idSpec = {}
			if ids
				for id, o of @state.objects[entity]
					if contains(id, ids) && o._ == 'rd'
						idSpec[id] = {_: undefined}
			if !isEmpty idSpec
				@change {objects: {"#{entity}": idSpec}}

			if key
				sub = @state.subs[key]
				if sub._ == 'rd'
					@change {subs: {"#{key}": {_: undefined}}}




##### HELPERS ##################################################################

# Based on the query, the strategy and the state of the cache, calculates the
# remote query needed to be run or null if everything is already in the cache.
calcRemoteQuery = (state, query, strategy) ->
	switch strategy
		when 'LO' then null
		when 'PE' then query
		when 'OP'
			if isCached(state, query) == true then null
			else query
		when 'VO'
			cacheResult = isCached state, query
			if cacheResult == true then null
			else if type(cacheResult) == 'Array'
				# only fetch the missing from remote
				newQuery = merge query, {id: cacheResult}
				newQuery
			else query

# if id-query: true if all ids are in 'objects', else array of missing ids
# if normal query: true if query is in 'reads', else false
isCached = (state, query) ->
	# debugger
	entity = getEntity query
	if has 'id', query
		if type(query.id) == 'Array'
			if type(query.id[0]) == 'Number'
				existingKeys = map parseInt, keys(state.objects[entity] || {}) 
			else
				existingKeys = keys(state.objects[entity] || {}) 
			missing = difference query.id, existingKeys
			return if isEmpty missing then true else missing
		else
			return has query.id, state.objects[entity]
	else
		return state.reads[entity]?[hash(query)]?

# Runs the remote, makes some simple validation and returns the promise
runRemote = (remote, key, remoteQuery) ->
	res = remote key, remoteQuery
	if !isThenable res
		throw new Error ERR + 'remote function needs to return a promise'
	return res.then (val) =>
		if isNil val then val = {}

		if type(val) != 'Object'
			console.error {remoteQuery, remoteResponse: val}
			throw new Error ERR + 'remote should return an object, see docs/remote.'

		if getOp(remoteQuery) == 'one'
			if keys(val).length != 1
				console.error {remoteQuery, remoteResponse: val}
				throw new Error ERR + 'one-query expects a map (object) with one key =
				the objects ids, see docs/remote.'

		return val

# Fullfills the query by reading objects from the cache.
# Note: nils translated to {} and arrays translated to id-indexed maps
readQuery = (data, query) ->
	res = popsiql.toRamda(query)(data.objects)
	if isNil res then {} # we don't want to handle nils
	else if type(res) == 'Array'
		# We simplify things by only handling maps, when you need sorting you
		# have to do a second sorting of the data returned from oublie in a
		# "lifter" / "selector" layer in your application
		cc fromPairs, map((o) -> [o.id, o]), res
	else res

# calcChangedSubs = (paths) ->
# 	# change of lastResult and ids is not a real sub change
# 	subs = cc reject(test(/(?:\.lastResult)|(?:\.ids)$/)),
# 						filter(test(/^subs\./)), paths
# 	# subs = cc reject(test(/(?:\.lastResult)$/)), filter(test(/^subs\./)), paths
# 	return cc uniq, map(replace(/^subs\.(\w*\.\w*)\..*/, '$1')), subs

# calcAffectedSubs = (paths, state) ->
# 	objs = cc uniq, map(replace(/^objects\.(\w*)\..*/, '$1')),
# 						filter(test(/^objects\./)), paths

# 	affectedSubs = yreduce objs, [], (a, o) =>
# 		if ! has o, state.subs then a
# 		else cc union(a), map((s) -> o + '.' + s), keys, state.subs[o]

# 	return affectedSubs


# Returns a spec to retrun expired reads and ids from ids and objects
# if they are not still in use by a sub.
removeExpired = (state) ->
	now = Date.now()
	idsToRemove = {}
	readsToRemove = {}

	for entity, ids of state.ids
		expiredIds = cc keys, pickBy(lt(__, now)), ids
		expiredIdsNotInUse = reject isStillUsed(state, entity), expiredIds
		if isNil(expiredIdsNotInUse) || isEmpty(expiredIdsNotInUse)
			continue

		idsToRemove[entity] ?= {}

		for id in expiredIdsNotInUse
			idsToRemove[entity][id] = undefined

	for entity, reads of state.reads
		for hashKey, read of reads
			if read.expires < now
				readsToRemove[entity] ?= {}
				readsToRemove[entity][hashKey] = undefined

	spec = {}
	if !isEmpty(idsToRemove)
		spec.ids = idsToRemove
		spec.objects = idsToRemove
	if !isEmpty(readsToRemove)
		spec.reads = readsToRemove
	if isEmpty spec
		# console.log "removeExpired lost #{Date.now() - now} ms"
		return {}

	return spec


# Returns true if entity/id is still in use in a sub
isStillUsed = (state, entity) -> (id) ->
	for key, sub of state.subs
		subEntity = getEntity sub.query
		if subEntity == entity && sub.ids && contains(id, sub.ids)
			return true
	return false

module.exports = Oublie
