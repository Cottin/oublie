{__, all, always, assoc, clone, contains, difference, flip, fromPairs, has, isEmpty, isNil, keys, lt, map, merge, omit, pick, pickBy, reject, type, update, where, without} = require 'ramda' #auto_require:ramda
{cc, toStr, change, ymerge, yfilter, isThenable, foldObj} = require 'ramda-extras'
popsiql = require 'popsiql'
hash = require 'object-hash'

ERR = 'Oublie Error: '

_getEntity = (query) ->
	{spawn, edit, modify, commit, revert, undo, refresh} = query
	return spawn || edit || modify || commit || revert || undo || refresh ||
					popsiql.getEntity(query)

_getOp = (query) ->
	hasIt = has __, query
	if hasIt 'spawn' then 'spawn'
	else if hasIt 'edit' then 'edit'
	else if hasIt 'modify' then 'modify'
	else if hasIt 'commit' then 'commit'
	else if hasIt 'revert' then 'revert'
	else if hasIt 'undo' then 'undo'
	else if hasIt 'refresh' then 'refresh'
	else popsiql.getOp query

_validate = (query) ->
	if has 'start', query
		throw new Error ERR + 'no support for start (yet?)'

class Oublie
	constructor: ({pub, remote}) ->
		@config = {pub, remote}
		@data = {objects: {}, ids: {}, reads: {}, writes: {}, subs: {}, edits: {}}
		@spawnCount = 0

		# flip(setInterval) 2000, =>
		# 	if window.requestIdleCallback
		# 		window.requestIdleCallback(@removeExpired)
		# 	else
		# 		@removeExpired()

	sub: (key, query, strategy, expiry) ->
		_validate query
		op = _getOp query
		if op == 'one' then @oneOrMany(key, query, strategy, expiry)
		else if op == 'many' then @oneOrMany(key, query, strategy, expiry)
		else if op == 'spawn' then @spawn(key, query)
		else if op == 'edit' then @edit(key, query)
		else
			throw new Error ERR + 'no recognized operation for sub'

	do: (query, strategy) ->
		_validate query
		op = _getOp query
		if op == 'modify' then @modify(query)
		else if op == 'revert' then @revert(query)
		else if op == 'commit' then @commit(query, strategy)
		else
			throw new Error ERR + 'no recognized operation for do'

	spawn: (key, query) ->
		entity = _getEntity query
		copy = clone (query.values || {})
		if isNil copy.id
			copy.id = "___#{@spawnCount++}"
		edit = {key, copy, type: 'spawn'}

		@data.edits[entity] ?= {}
		@data.edits[entity][copy.id] = edit
		@config.pub key, {$assoc: copy}
		@_dev_dataChanged?(@data)

	edit: (key, query) ->
		entity = _getEntity query
		_original = @data.objects[entity]?[query.id]
		if isNil _original
			throw new Error ERR + "edit failed, no object in cache at
			#{entity}/#{query.id}"
		
		original = omit ['_'], _original

		if @data.subs[entity][key]
			delete @data.subs[entity][key]

		copy = clone original
		@data.edits[entity] ?= {}
		@data.edits[entity][copy.id] = {key, copy, original, type: 'edit'}

		@config.pub key, {$assoc: copy}
		@_dev_dataChanged?(@data)


	modify: (query) ->
		entity = _getEntity query
		edit = @data.edits[entity][query.id]
		if isNil edit
			console.error {query}
			throw new Error ERR + "modify failed, no object under edit at
			#{entity}/#{query.id}"

		if isNil query.delta
			console.error {query}
			throw new Error ERR + 'modify failed, query is missing a delta'

		spec = {edits: {"#{entity}": {"#{query.id}": {copy: query.delta}}}}
		# spec = {"edits/#{entity}/#{query.id}/copy": query.delta}
		@data = change spec, @data
		@config.pub edit.key, query.delta
		@_dev_dataChanged?(@data)

	revert: (query) ->
		entity = _getEntity query
		edit = @data.edits[entity][query.id]
		if isNil edit
			console.error {query}
			throw new Error ERR + "revert failed, no object under edit at
			#{entity}/#{query.id}"

		edit.copy = clone edit.original
		@config.pub edit.key, {$assoc: edit.copy}
		@_dev_dataChanged?(@data)

	requireEdit: (query) ->
		editObj = @data.edits[entity][id]
		if isNil editObj
			console.error {query}
			op = _getOp query
			throw new Error ERR + "#{op} failed, no object under edit at 
			#{entity}/#{id}"

		entity = _getEntity query
		return {entity, id: query.id, edit}

	commit2: (query, strategy) ->
		# TOGO!
		{entity, id, edit} = @requireEdit query

		pureCopy = omit ['_'], edit.copy
		if strategy == 'LO'
			@change {objects: {"#{entity}": {"#{id}": {$assoc: edit.copy}}}}
		else if strategy == 'PE'
			@change {edits: {"#{entity}": {"#{id}": {copy: {_: edit.type+'w'}}}}}

			@remote null, {update: entity, id, data: pureCopy}
				.then (val) =>
					newObj = merge edit.copy, {_: 'wd'}
					@change
						edit: {"#{entity}": {"#{id}": {copy: newObj}}}
						objects: {"#{entity}": {"#{id}": {$assoc: newObj}}}


	commit: (query, strategy) ->
		entity = _getEntity query
		edit = @data.edits[entity][query.id]
		if isNil edit
			console.error {query}
			throw new Error ERR + "commit failed, no object under edit to commit at
			#{entity}/#{query.id}"

		sync = switch edit.type
			when 'spawn' then 'cw'
			when 'edit' then 'uw'

		if strategy == 'LO'
			spec = {objects: {"#{entity}": {"#{query.id}": {$assoc: edit.copy}}}}
			@data = change spec, @data
			@_dev_dataChanged?(@data)
			@rerunSubs(entity)
		else if strategy == 'PE'
			edit.copy._ = sync
			@_dev_dataChanged?(@data)
			@config.pub edit.key, edit.copy


			if edit.type == 'spawn'
				data = omit ['_', 'id'], edit.copy
				remoteQuery = {create: enitity, data}
				throw new Error 'TODO'
			else if edit.type == 'edit'
				data = omit ['_'], edit.copy
				remoteQuery = {update: entity, id: edit.copy.id, data}
				# @runRemoteWrite remoteQuery, strategy
				res = @config.remote(null, remoteQuery)
				if !isThenable res
					throw new Error ERR + 'remote function needs to return a promise'
				res.then (val) =>
					@updateStatusEdit(entity, edit.copy.id, edit.key, 'wd')
					newObj = merge edit.copy, {_: 'wd'}
					spec = {objects: {"#{entity}": {"#{query.id}": {$assoc: newObj}}}}
					@data = change spec, @data
					@_dev_dataChanged?(@data)
					@config.pub edit.key, newObj
					@rerunSubs(entity)
		else
			throw new Error ERR + "commit doesen't support strategy #{strategy} (yet)"






	# TODO:
	# @read är det localAndRemote mån tro? Nej. Det är antagligen readNonExpired!!

	runRemoteRead: (key, remoteQuery, originalQuery, strategy, expiry) ->
		res = @config.remote(key, remoteQuery)
		if !isThenable res
			throw new Error ERR + 'remote function needs to return a promise'
		res.then @handleRemoteRead(key, remoteQuery, originalQuery, strategy, expiry)

	runRemoteWrite: (remoteQuery, strategy) ->
		res = @config.remote(null, remoteQuery)
		if !isThenable res
			throw new Error ERR + 'remote function needs to return a promise'
		res.then @handleRemoteWrite(remoteQuery, strategy)

	updateStatusSub: (entity, key, status) ->
		@data.subs[entity][key]._ = status
		@_dev_dataChanged?(@data)
		@config.pub key, {_: status}

	updateStatusEdit: (entity, id, key, status) ->
		@data.edits[entity][id]._ = status
		@_dev_dataChanged?(@data)
		@config.pub key, {_: status}

	oneOrMany: (key, query, strategy, expiry) ->
		entity = _getEntity query
		@data.subs[entity] ?= {}
		@data.subs[entity][key] = {query} # reset sub
		@_dev_dataChanged?(@data)
		@removeExpired()

		[l, r] = @localAndRemote2 query, strategy
		if !isNil r
			@updateStatusSub(entity, key, 'rw')
			@runRemoteRead(key, r, query, strategy, expiry)
		if !isNil l then @runSub(entity, key)
		else @resetSub(entity, key)
		# @runSubs(entity)
		# TODO: this must be wrong? for PE? or? maybe not



		# entity = _getEntity query
		# @data.subs[entity][key] = {query} # reset sub
		# @removeExpired()
		# [l, r] = @localAndRemote query, strategy
		# if strategy == 'LO'
		# 	if isNil l then @config.pub key, null
		# 	else @config.pub key, {$assoc: l}
		# 	@data.subs[entity][key].
		# else
		# 	if isNil l
		# 		if isNil r then @config.pub key, null # this case shouldnt really happen
		# 		else @config.pub key, {_: 'rw'}
		# 	else
		# 		if isNil r then @config.pub key, {$assoc: l}
		# 		else @config.pub key, merge(l, {_: 'rw'})

		# if isNil r then return
		# res = @config.remote(key, r)
		# if !isThenable res
		# 	throw new Error ERR + 'remote function needs to return a promise'

		# res.then @handleRemoteRead(key, query, strategy, expiry)

	handleRemoteWrite: (query, strategy) -> (val) =>
		entity = _getEntity query
		op = _getOp query

		@updateStatusSub(entity, key, 'rd')

		# TODO: update cache with val if val exists




	handleRemoteRead: (key, query, originalQuery, strategy, expiry) -> (val) =>
		entity = _getEntity query
		op = _getOp query

		@updateStatusSub(entity, key, 'rd')

		if isNil val then val = {}

		if type(val) != 'Object'
			console.error {query, remoteResponse: val}
			throw new Error ERR + 'remote should return an object, see docs/remote.'

		if op == 'one'
			if keys(val).length != 1
				console.error {query, remoteResponse: val}
				throw new Error ERR + 'one-query expects a map (object) with one key =
				the objects ids, see docs/remote.'

		val_ = map ymerge({_: 'rd'}), val  

		expires = Date.now() + expiry * 1000
		delta =
			objects: {"#{entity}": {$merge: val_}}
			ids: {"#{entity}": {$merge: map(always(expires), val)}}
			reads: {"#{entity}": {"#{hash(query)}": {expires, query: originalQuery}}}
			# subs: {"#{entity}": {"#{key}": {lastResult: hash(val), ids: keys(val)}}}
			# note, lastResult in subs is always without _ since it's used to
			# determine if the query has been asked to the server recently, not to
			# keep track of sync status
			# note 2, could have a pending: hash(val) on subs so question cannot
			# be asked while that same query already is being asked => better then to
			# look at the query instead
		@data = change delta, @data
		@_dev_dataChanged?(@data)
		@rerunSubs(entity)

		flip(setTimeout) 2000, =>
			# @removeExpired()
			@removeStatus entity, keys(val), 'rd'
			@removeStatusSub entity, key, 'rd'
			@rerunSubs(entity)


	# localAndRemote: (query, strategy) ->
	# 	switch strategy
	# 		when 'LO' then [@readAll(query), null]
	# 		when 'PE' then [null, query]
	# 		when 'OP'
	# 			if @isCached(query) == true then [@readAll(query), null]
	# 			else [null, query]
	# 		when 'VO'
	# 			l = @readAll query
	# 			cacheResult = @isCached query
	# 			if cacheResult == true then [l, null]
	# 			else if type(cacheResult) == 'Array'
	# 				# only fetch the missing from remote
	# 				newQuery = merge query, {id: cacheResult}
	# 				return [l, newQuery]
	# 			else [l, query]

	localAndRemote2: (query, strategy) ->
		# TOGO: kolla på readme och tänk om utifrån ny removeExpired
		switch strategy
			when 'LO' then [query, null]
			when 'PE' then [null, query]
			when 'OP'
				if @isCached(query) == true then [query, null]
				else [null, query]
			when 'VO'
				cacheResult = @isCached query
				if cacheResult == true then [query, null]
				else if type(cacheResult) == 'Array'
					# only fetch the missing from remote
					newQuery = merge query, {id: cacheResult}
					return [query, newQuery]
				else [query, query]

	readAll: (query) ->
		res = popsiql.toRamda(query)(@data.objects)
		if isNil res then {}
		else if type(res) == 'Array'
			cc fromPairs, map((o) -> [o.id, o]), res
		else res

	# NOTE: kanske ta bort denna. Om något är expired men en sub fortfarande använder datan,
	# 			då kanske nya queries också ska kunna fråga efter samma data?
	#				Det kanske är lättare att bara ha kvar denna och bara göra det mer komplicerat om detta beteende verkar jobbigt.
	# 	NOTE: man måste nog lagra id i subs annars vet man aldrig vad som är ok att ta bort från objects

	# readNonExpired: (query) ->
	# 	# NOTE: one-frågor måste också returnera en map
	# 	result = popsiql.toRamda(query)(@data.objects)
	# 	@data.ids[_getEntity(query)]
	# 	# TOGO antagligen?

	# if id-query: true if all ids are in 'objects', else array of missing ids
	# if normal query: true if query is in 'reads', else false
	isCached: (query) ->
		entity = _getEntity query
		if has 'id', query
			if type(query.id) == 'Array'
				if type(query.id[0]) == 'Number'
					existingKeys = map parseInt, keys(@data.objects[entity] || {}) 
				else
					existingKeys = keys(@data.objects[entity] || {}) 
				missing = difference query.id, existingKeys
				return if isEmpty missing then true else missing
			else
				return has query.id, @data.objects[entity]
		else
			return @data.reads[entity]?[hash(query)]?


	isStillUsed: (entity) -> (id) =>
		for key, sub of @data.subs[entity]
			if sub.ids && contains id, sub.ids then return true
		return false

	# Removes expired reads and removes expired ids from ids and objects
	# if they are not still un use by a sub.
	removeExpired: =>
		now = Date.now()
		idsToRemove = {}
		readsToRemove = {}

		for entity, ids of @data.ids
			expiredIds = cc keys, pickBy(lt(__, now)), ids
			expiredIdsNotInUse = reject @isStillUsed(entity), expiredIds
			if isNil(expiredIdsNotInUse) || isEmpty(expiredIdsNotInUse)
				continue

			idsToRemove[entity] ?= {}

			for id in expiredIdsNotInUse
				idsToRemove[entity][id] = undefined

		for entity, reads of @data.reads
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
			return
		@data = change spec, @data
		@_dev_dataChanged?(@data)


	# Does three things:
	# 	1. reruns queries from subs (by using readAll)
	#		-----. removes expired objects that are not in result from subs TODO!!!------
	#		3. publishes results of subs if they have changed

	runSub: (entity, key) ->
		sub = @data.subs[entity][key]
		result = @readAll sub.query
		sync = pick ['_'], sub
		result_ = merge result, sync
		hashResult = hash(result_)
		if hashResult != sub.lastResult
			if _getOp(sub.query) == 'one'
				# if 'one', extract obj to make handling easier
				result__ = merge result[keys(result)[0]], sync
				@config.pub key, {$assoc: result__}
			else
				@config.pub key, {$assoc: result_}
			sub.lastResult = hashResult
			sub.ids = keys result
			@_dev_dataChanged?(@data)

	resetSub: (entity, key) ->
		sub = @data.subs[entity][key]
		sync = pick ['_'], sub
		result = merge {}, sync
		hashResult = hash(result)
		if hashResult != sub.lastResult
			@config.pub key, {$assoc: result}
			sub.lastResult = hashResult
			sub.ids = []
			@_dev_dataChanged?(@data)

	rerunSubs: (entity) ->
		for key, sub of @data.subs[entity]
			@runSub(entity, key)

	# runEdit: (entity, id) ->
	# 	edit = @data.edits[entity][id]
	# 	if isNil edit
	# 		throw new Error ERR + "runEdit failed, no object under #{entity}/#{id}"
	# 	@config.pub edit.key, edit.copy

	# rerunEdits: (entity) ->
	# 	for id, edit of @data.edits[entity]
	# 		@runEdit(entity, id)


		# # TOGO!!
		# toChange = {}
		# yforEachObjIndexed @data.subs[entity], ({query, lastResult}, k) =>
		# 	result = @readAll query
		# 	if hash(result) != lastResult
		# 		@config.pub k, {$assoc: result}
		# 		toChange[k] = {lastResult: result}
		# @data = change {subs: {"#{entity}": toChange}}

	removeStatus: (entity, ids, status) ->
		for id, o of @data.objects[entity]
			if contains(id, ids) && o._ == status
				delete o._
				@_dev_dataChanged?(@data)

		# for id, o of @data.edits[entity]
		# 	if contains(id, ids) && o.copy._ == status
		# 		delete o.copy._
		# 		@_dev_dataChanged?(@data)

	removeStatusSub: (entity, key, status) ->
		sub = @data.subs[entity][key]
		if sub._ == status
			delete sub._
			@_dev_dataChanged?(@data)

module.exports = Oublie



# ---- dep line

# don't handle id queries separetly, not too big upside and makes it more complex
# 	isCached: (query) ->
		# entity = _getEntity query
		# if has('one', query) && has('id', query)
		# 	return @data.ids[entity]?[query.id]?
		# else
		# 	return @data.reads[entity]?[hash(query)]?




		

		# val_ = merge val, {_: 'rd'}

		# 	delta =
		# 		objects: {"#{entity}": {"#{val.id}": {$assoc: val_}}}
		# 		ids: {"#{entity}": {"#{val.id}": expires}}
		# 		reads: {"#{entity}": {"#{hash(query)}": {expires, query}}}
		# 		subs: {"#{entity}": {"#{key}": {query, lastResult: hash(val)}}}
		# 	@data = change delta, @data


		# else if op == 'many'
		# 	if type(val) != 'Object'
		# 		console.error {query, remoteResponse: val}
		# 		throw new Error ERR + 'many-query expects a map (object) where keys
		# 		are objects ids (TODO: support arrays).'

		# 	val_ = map ymerge({_: 'rd'}), val
		# 	delta =
		# 		objects: {"#{entity}": {$merge: val_}}
		# 		ids: {"#{entity}": {$merge: map(always(expires), val)}}
		# 		reads: {"#{entity}": {"#{hash(query)}": {expires, query}}}
		# 		subs: {"#{entity}": {"#{key}": {query, lastResult: hash(val)}}}
		# 	@data = change delta, @data
