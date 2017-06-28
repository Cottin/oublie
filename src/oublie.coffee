{add, always, append, assoc, clone, evolve, has, isNil, keys, map, mapObjIndexed, merge, omit, reject, type} = require 'ramda' #auto_require:ramda
{change, yfilter, isThenable} = require 'ramda-extras'

utils = require './utils'

ERR = 'Oublie Error: '

_toMap = (k, xs) ->
	o = {}
	for x in xs
		o[x[k]] = x
	return o

class Oublie
	constructor: ({pub, remote, data}) ->
		@config = {pub, remote}
		@subs = {}
		@data = data || {objects: {}, queries: {}, ids: {}}

	sub: (key, query, strategy, expiry) ->
		# if has key, @subs
		# 	throw new Error 'subscription already exists for key' + key
		if isNil(key) || type(key) != 'String'
			throw new Error "key must be a string for subscription, given: #{key}"

		if isNil(query) || type(query) != 'Object'
			throw new Error "query must be an object for subscription, given: #{query}"

		@subs[key] = query

		@removeExpiredItems()

		entity = query.one || query.many || query.all || query.new || query.edit

		if has 'new', query
			newObj = merge {id: '_0'}, query.values
			spec =
				diff: {"#{entity}": {$merge: {"#{newObj.id}": newObj}}}
			@config.pub key, {val: {$assoc: newObj}, sync: undefined}
			@data = change spec, @data
			@_dev_dataChanged?(@data)
			return

		else if has 'edit', query
			if ! @data.objects[entity]?[query.id]?
				throw new Error 'Cannot edit non-existing object: #{entity}:#{query.id}'
			toEdit = clone @data.objects[entity][query.id]
			spec =
				diff: {"#{entity}": {$merge: {"#{toEdit.id}": toEdit}}}
			@config.pub key, {val: {$assoc: toEdit}, sync: undefined}
			@data = change spec, @data
			@_dev_dataChanged?(@data)
			return



		[l, r] = utils.query @data, query, strategy, expiry

		val = if !isNil(l) then {$assoc: l}
		sync = if !isNil(r) then 'rw'
		@config.pub key, {sync, val}

		if !isNil(r)
			res = @config.remote(key, r)
			if !isThenable res
				throw new Error ERR + 'remote function needs to return a promise'

			res.then (val) =>
					@config.pub key, {val: {$assoc: val}, sync: 'rd'}

					if isNil(val) then return

					val_ = if type(val) == 'Array' then _toMap 'id', val else val
					now = Date.now()
					val_ = if type(val) == 'Array' then _toMap 'id', val else val
					expires = Date.now() + expiry * 1000
					r_ = {expires, query: r}
					# TODO: don't add to queries if it's an id query!
					newArrayOrAppend = (x) -> if isNil(x) then [r_] else append r_, x
					spec =
						objects: {"#{entity}": {$merge: val_}}
						queries: {"#{entity}": newArrayOrAppend}
						ids: {"#{entity}": {$merge: map(always(expires), val_)}}
					@data = change spec, @data
					@_dev_dataChanged?(@data)

				.catch (err) =>
					console.error err
					throw new Error 'Not yet implemented'

	do: (query, strategy) ->
		@removeExpiredItems()

		if has('modify', query) || has('commit', query)
			key = query.modify || query.commit
			sub = @subs[key]
			if isNil sub
				console.error 'error for query:', query
				throw new Error "no 'edit' or 'new' subscription with key '#{key}'"

			if isNil sub.id
				console.error 'error for query:', query
				throw new Error "id in query at '#{key}' is nil"

			entity = sub.edit || sub.new
			if isNil entity
				console.error 'error for query:', query
				throw new Error "query at #{key} does not seem to be a edit or new query"

			if has 'modify', query
				@config.pub key, {val: query.delta}
				spec =
					diff: {"#{entity}": {"#{sub.id}": query.delta}}
				@data = change spec, @data
				@_dev_dataChanged?(@data)
				return

			else if has 'commit', query
				if isNil strategy
					console.log 'error for query:', query
					throw new Error 'commit query missing strategy'

				[l, r] = utils.exec query, strategy

				if strategy == 'LO' || strategy == 'OP'
					@data = change {objects: l}, @data
					@_dev_dataChanged?(@data)


				if strategy == 'PE' || strategy == 'OP'
					res = @config.remote(key, r)
					if !isThenable res
						throw new Error ERR + 'remote function needs to return a promise'

					res.then (val) =>

						# spec =
						# 	objects: {"#{entity}": {$merge: val_}}
						# 	queries: {"#{entity}": newArrayOrAppend}
						# 	ids: {"#{entity}": {$merge: map(always(expires), val_)}}

						@data = change {objects: l}, @data
						@_dev_dataChanged?(@data)

	removeExpiredItems: () ->
		now = Date.now()
		removeExpiredIds = (objects, k) =>
			expiredIds = yfilter @data.ids[k], (x) -> x < now
			return omit keys(expiredIds), objects

		spec =
			objects: mapObjIndexed removeExpiredIds
			queries: mapObjIndexed reject ({expires}) -> expires < now
			ids: mapObjIndexed reject (x) -> x < now

		@data = evolve spec, @data
		@_dev_dataChanged?(@data)


	_dev_getData: -> @data
					
module.exports = Oublie
