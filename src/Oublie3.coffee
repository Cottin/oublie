{__, all, always, any, assoc, both, call, clone, contains, difference, either, filter, flip, fromPairs, has, head, isEmpty, isNil, keys, last, lt, map, merge, omit, once, pathEq, pickBy, reject, remove, split, test, type, update} = R = require 'ramda' #auto_require:ramda
{cc, change, yreduce, ymerge, ymap, isThenable, changedPaths, diff} = require 'ramda-extras'
popsiql = require 'popsiql'
hash = require 'object-hash'
debounce = require 'lodash.debounce'

{getEntity, getOp, validateQuery} = require './utils3'

ERR = 'Oublie Error: '

	# TOGO:
	# - [x] change
	# - publish what's need to be published (throttled or similar) = rewrite commitAndPublish
	#		- [x] rename to removeExpired
	#		- [x] removeExpired borde returnera en spec
	#		- [x] kolla om changedPaths klarar $assoc
	#		- [ ] kolla om changedPaths och diff kan göras smartare
	#		- [ ] tänk på hur det funkar om något tas bor också (ej läggs till)
	#		- [ ] gör den enklaste optimeringen, kör inte om bara ändrats lastResult, reads, etc.
	# - [ ] skulle kunna ha en semi-optimistisk som OP men läser också alltid från server
	#	- [x] rename @data to @state
	# - [x] run reads in playground and make sure it works
	# - [x] implement the other operations and test them in playground
	# - [ ] make the restaurant reviewer in oublie examples

	# Notes:
	# - edits: med commit eller direkt.. har funderat på insights och tr, svårt att anvgöra, testa commit och se hur det blir

class Oublie
	constructor: ({pub, remote}) ->
		@config = {pub, remote}
		@state = {objects: {}, ids: {}, reads: {}, writes: {}, subs: {}, edits: {}}
		@nextState = @state
		@spawnCount = 0

		# Great explanation of debounce vs. throttle:
		# https://css-tricks.com/debouncing-throttling-explained-examples/
		@commitAndPublish = debounce @__commitAndPublish, 10,
			leading: false # don't publish directly, let changes "buffer up"
			trailing: true # then when they're all buffered, publish everything at once
			maxWait: 250 # if too many changes, don't let them buffer in all eternity


	##### PUBLIC API
	# Make a new subscription to data (or pass query = null to unsubscribe)
	sub: (key, query, strategy, expiry) ->
		if isNil query
			if cc contains(key), keys, @state.subs
				@change {subs: {"#{key}": undefined}}
			else
				for entity, edits of @state.edits
					for id, edit of edits
						if edit.key == key
							@change {edits: {"#{entity}": {"#{id}": undefined}}}
			return

		validateQuery query
		switch getOp query
			when 'one' then @oneOrMany key, query, strategy, expiry
			when 'many' then @oneOrMany key, query, strategy, expiry
			when 'spawn' then @spawn key, query
			when 'edit' then @edit key, query
			when 'spawnedit' then @spawnedit key, query
			else throw new Error ERR + 'no recognized operation for sub'

	do: (query, strategy, meta) ->
		validateQuery query
		switch getOp query
			when 'modify' then @modify query, meta
			when 'revert' then @revert query, meta
			when 'commit' then @commit query, strategy, meta
			when 'remove' then @remove query, strategy, meta
			else throw new Error ERR + 'no recognized operation for do'



	##### INTERNAL OPERATIONS

	# Reads one or many objects from local cache an invokes remote if needed
	oneOrMany: (key, query, strategy, expiry) ->
		# reset sub
		@change {subs: {"#{key}": {$assoc: {query, strategy, expiry, ts: Date.now()}}}}

	spawn: (key, query) ->
		entity = getEntity query
		copy = clone (query.data || {})
		if isNil copy.id
			copy.id = "___#{@spawnCount++}"
		editData = {key, copy, original: copy, type: 'spawn'}
		@change {edits: {"#{entity}": {"#{copy.id}": editData}}}

	edit: (key, query) ->
		entity = getEntity query
		_original = @state.objects[entity]?[query.id]
		if isNil _original
			throw new Error ERR + "edit failed, no object in cache at
			#{entity}/#{query.id}"

		original = omit ['_'], _original

		copy = clone original
		editData = {key, copy, original, type: 'edit'}
		@change {edits: {"#{entity}": {"#{copy.id}": editData}}}

	spawnedit: (key, query) ->
		entity = getEntity query
		_original = @state.objects[entity]?[query.id]
		if isNil _original
			@spawn key, {spawn: entity, data: query.data}
		else
			@edit key, {edit: entity, id: query.id}

	modify: (query) ->
		entity = getEntity query
		edit = @state.edits[entity][query.id]
		if isNil edit
			console.error {query}
			throw new Error ERR + "modify failed, no object under edit at
			#{entity}/#{query.id}"

		if isNil query.delta
			console.error {query}
			throw new Error ERR + 'modify failed, query is missing a delta'

		@change {edits: {"#{entity}": {"#{query.id}": {copy: query.delta}}}}


	revert: (query) ->
		entity = getEntity query
		edit = @state.edits[entity][query.id]
		if isNil edit
			console.error {query}
			throw new Error ERR + "revert failed, no object under edit at
			#{entity}/#{query.id}"

		newCopy = clone edit.original
		@change {edits: {"#{entity}": {"#{query.id}": {copy: newCopy}}}}

	commit: (query, strategy, meta) ->
		entity = getEntity query
		edit = @state.edits[entity][query.id]
		if isNil edit
			console.error {query}
			throw new Error ERR + "commit failed, no object under edit to commit at
			#{entity}/#{query.id}"

		if strategy == 'LO'
			@change {objects: {"#{entity}": {"#{query.id}": {$assoc: edit.copy}}}}

		else if strategy == 'PE' || strategy == 'OP'
			# @change {edits: {"#{entity}": {"#{query.id}": {_: sync}}}}

			if edit.type == 'spawn'
				@change edits: {"#{entity}": {"#{query.id}": {_: 'cw'}}}
				if strategy == 'OP'
					newObj = merge edit.copy, {_: 'cw'}
					@change objects: {"#{entity}": {"#{query.id}": {$assoc: newObj}}}
							
				usesTempId = test /^___/, edit.copy.id
				data = if usesTempId then omit ['id'], edit.copy else edit.copy
				remoteQuery = {create: entity, data}
				p = runRemote(@config.remote, null, remoteQuery, meta)
					.then (val) =>
						if usesTempId
							if isNil(val) || isNil(val.id)
								throw new Error ERR + "spawned #{entity} uses tempId 
								#{edit.copy.id} and therefore expects remote to return object 
								with persistent id"

							newObj = merge edit.copy, {id: val.id}
							newOriginal = merge edit.copy, {id: val.id}
							@change
								edits: 
									"#{entity}":
										"#{edit.copy.id}": undefined
										"#{val.id}": merge edit, {type: 'edit', _: 'cd',
										copy: newObj, original: newOriginal}
								objects:
									"#{entity}":
										"#{val.id}": {$assoc: merge(newObj, {_: 'cd'})}

								if strategy == 'OP'
									@change objects: {"#{entity}": {"#{edit.copy.id}": undefined}}

								@queeueRemoveStatus entity, edit.key, [val.id], 'cd'

						else
							@change
								edits: {"#{entity}": {"#{query.id}": {_: 'cd', type: 'edit'}}}

							if strategy == 'PE'
								newObj = merge edit.copy, {_: 'cd'}
								@change objects: {"#{entity}": {"#{query.id}": {$assoc: newObj}}}
							else if strategy == 'OP'
								@change objects: {"#{entity}": {"#{query.id}": {_: 'cd'}}}

							@queeueRemoveStatus entity, edit.key, [query.id], 'cd'
				p.meta = 'remote-promise'
				return p

			else if edit.type == 'edit'
				@change {edits: {"#{entity}": {"#{query.id}": {_: 'uw'}}}}

				if strategy == 'OP'
					newObj = merge edit.copy, {_: 'uw'}
					@change objects: {"#{entity}": {"#{query.id}": {$assoc: newObj}}}

				data = omit ['_'], edit.copy
				remoteQuery = {update: entity, id: edit.copy.id, data}
				p = runRemote(@config.remote, null, remoteQuery, meta)
					.then (val) =>
						@change edits: {"#{entity}": {"#{query.id}": {_: 'ud'}}}

						if strategy == 'PE'
							newObj = merge edit.copy, {_: 'ud'}
							@change objects: {"#{entity}": {"#{query.id}": {$assoc: newObj}}}
						else if strategy == 'OP'
							@change objects: {"#{entity}": {"#{query.id}": {_: 'ud'}}}

						@queeueRemoveStatus entity, edit.key, [query.id], 'ud'
				p.meta = 'remote-promise'
				return p

		else
			throw new Error ERR + "commit doesen't support strategy #{strategy} (yet)"

		return null

	remove: (query, strategy, meta) ->
		entity = getEntity query
		local = @state.objects[entity]?[query.id]
		edit = @state.edits[entity]?[query.id]

		if isNil(local) && isNil(edit)
			console.error {query}
			throw new Error ERR + "remove failed, no local object and no object under
			edit to remove at #{entity}/#{query.id}"

		if isNil(local) && edit && edit.type == 'spawn'
			# trying to remove a spawned item that's not in 'objects' is a no-op,
			# probably user will unsubscribe from the spawn query soon after this
			return null 

		if strategy == 'LO'
			@change {objects: {"#{entity}": {"#{query.id}": undefined}}}

		else if strategy == 'PE' || strategy == 'OP'
			if edit && edit.type == 'spawn' # removal of spawns handled by no-op abolve
				throw new Error ERR + "for now, not supporting removal of
				spawned items that also exist in objects unless it's a LOcal remove"

			if edit
				@change {edits: {"#{entity}": {"#{query.id}": {_: 'dw'}}}}

			if strategy == 'OP'
				@change {objects: {"#{entity}": {"#{query.id}": {_: 'dw'}}}}

			remoteQuery = {remove: entity, id: query.id}
			p = runRemote(@config.remote, null, remoteQuery, meta)
				.then (val) =>
					if edit
						@change edits: {"#{entity}": {"#{query.id}": {_: 'dd'}}}
					@change objects: {"#{entity}": {"#{query.id}": {_: 'dd'}}}

					flip(setTimeout) 2000, =>
						if edit
							@change edits: {"#{entity}": {"#{query.id}": {_: undefined}}}
						@change objects: {"#{entity}": {"#{query.id}": undefined}}

			p.meta = 'remote-promise'
			return p

		else
			throw new Error ERR + "remove doesen't support strategy #{strategy} (yet)"

		return null


	##### INTERNAL INFRASTRUCTURE

	# Make any changes to the cache with a delta.
	# Note that you don't have to worry about publishing changes to subscribers,
	# just assume that they will be calculated and published in a somewhat optimal
	# way :)
	change: (delta) ->
		@nextState = change delta, @nextState
		# console.log 'change', delta, @nextState
		@commitAndPublish() # note that it's debounced

		# if !quiet then @commitAndPublish() # note that it's debounced

	__commitAndPublish: ->
		# By the line below, calls to @change won't effect this commit even if they
		# are async and lie on the call stack waiting for the event loop, which
		# could happen since there are function-calls inside this function.
		nextStateRef = @nextState

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
		# console.log 'delta', delta
		# console.log 'paths', pathsChanged

		unsubs = cc filter(pathEq(__, undefined, delta)),
								filter(test(/^subs.\w+$/)),
								pathsChanged

		for p in unsubs
			[_, key] = split '.', p
			@config.pub key, undefined

		unedits = cc filter(pathEq(__, undefined, delta)),
								filter(test(/^edits.\w+.\w+$/)),
								pathsChanged

		for p in unedits
			{key} = R.path split('.', p), lastState
			@config.pub key, undefined

		if isEmpty delta then return

		for key, sub of @state.subs
			@runSub @state, key, pathsChanged

		for entity, edits of @state.edits
			for id, edit of edits
				@runEdit @state, entity, id, pathsChanged

	runEdit: (state, entity, id, paths) ->
		edit = state.edits[entity][id]
		testIt = (s) -> ! cc isEmpty, filter(test(new RegExp(s))), paths
		isChanged = testIt "^edits\.#{entity}\.#{id}\.(?:key|copy|original)"
		isStatusChanged = testIt "^edits\.#{entity}\.#{id}\._"
		# console.log 'EDIT', {isChanged, isStatusChanged}

		if !isChanged && !isStatusChanged then return

		if !isChanged # only a status change
			@config.pub edit.key, {_: edit._}
			return

		else # isChanged (and maybe isStatusChanged)
			@config.pub edit.key, {$assoc: merge(edit.copy, {_: edit._})}

	runSub: (state, key, paths) ->
		sub = state.subs[key]
		entity = getEntity sub.query
		testIt = (s) -> ! cc isEmpty, filter(test(new RegExp(s))), paths
		isChanged = testIt "^subs\.#{key}\.(?:query|strategy|ts)"
		isStatusChanged = testIt "^subs\.#{key}\._"
		isAffected = testIt "^objects\.#{entity}"
		# console.log {isChanged, isStatusChanged, isAffected}

		if !isChanged && !isStatusChanged && !isAffected then return

		if !isChanged && !isAffected # only a status change
			@config.pub key, {_: sub._}
			@change {subs: {"#{key}": {last_: sub._}}}
			return

		else # either isChanged or isAffected or both is true

			if isChanged then @runRemoteRead state, sub, key

			val = switch sub.strategy
				when 'LO' then readQuery state, sub.query
				when 'PE'
					if isChanged then null
					else if isAffected
						# this is the case: if PE is reading and other sub affects the data of same entity
						# PE will be forced to run locally.
						if sub._ == 'rw' then sub.val 
						else readQuery state, sub.query
				when 'OP'
					if isChanged
						if isCached(state, sub.query) == true
							readQuery state, sub.query
						else null
					else if isAffected
						if sub._ == 'rw' then sub.val 
						else readQuery state, sub.query
				when 'VO' then readQuery state, sub.query

		ids = keys val
		hashResult = hash if isNil(val) then null else val # protect against undef
		if hashResult != sub.lastResult || sub._ != sub.last_
			@config.pub key, {$assoc: {val, _: sub._}}
			subData = {lastResult: hashResult, ids, last_: sub._}
			@change {subs: {"#{key}": subData}}

	runRemoteRead: (state, sub, key) ->
		{query, strategy, expiry} = sub
		remoteQuery = calcRemoteQuery state, query, strategy
		if !isNil remoteQuery
			@change {subs: {"#{key}": {_: 'rw'}}}

			runRemote @config.remote, key, remoteQuery
				.then (val) =>
					@change {subs: {"#{key}": {_: 'rd'}}}

					entity = getEntity query
					val_ = map ymerge({_: 'rd'}), val  
					expires = Date.now() + expiry * 1000
					@change
						objects: {"#{entity}": {$merge: val_}}
						ids: {"#{entity}": {$merge: map(always(expires), val)}}
						reads: {"#{entity}": {"#{hash(query)}": {expires, query}}}

					@queeueRemoveStatus entity, key, keys(val), 'rd'

	# Schedules a removing of done-status(es) for sub and/or entities.
	# Note: if statuses has changes from 'done' (eg. new data loading), it will
	# not remove the status
	queeueRemoveStatus: (entity, key, ids, status) =>
		flip(setTimeout) 2000, =>
			idSpec = {}
			if ids && !isEmpty ids
				for _id, o of @state.objects[entity]
					id = if type(head(ids)) == 'Number' then parseInt _id else _id
					if contains(id, ids) && o._ == status
						idSpec[id] = {_: undefined}
			if !isEmpty idSpec
				@change {objects: {"#{entity}": idSpec}}

			if key
				if @state.subs[key]?._ == status
					@change {subs: {"#{key}": {_: undefined}}}

				for entity, edits of @state.edits
					for id, edit of edits
						if edit.key == key && edit._ == status
							@change {edits: {"#{entity}": {"#{id}": {_: undefined}}}}




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
			return has query.id, (state.objects[entity] || {})
	else
		return state.reads[entity]?[hash(query)]?

# Runs the remote, makes some simple validation and returns the promise
runRemote = (remote, key, remoteQuery, meta) ->
	res = remote key, remoteQuery, meta
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
