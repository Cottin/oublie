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

					console.log 1
					console.log {val}
					val_ = if type(val) == 'Array' then _toMap 'id', val else val
					now = Date.now()
					console.log 2
					val_ = if type(val) == 'Array' then _toMap 'id', val else val
					expires = Date.now() + expiry * 1000
					console.log 3
					r_ = {expires, query: r}
					# TODO: don't add to queries if it's an id query!
					newArrayOrAppend = (x) -> if isNil(x) then [r_] else append r_, x
					console.log 4
					console.log {val_}
					spec =
						objects: {"#{entity}": {$merge: val_}}
						queries: {"#{entity}": newArrayOrAppend}
						ids: {"#{entity}": {$merge: map(always(expires), val_)}}
					console.log 5
					@data = change spec, @data
					console.log 6
					@_dev_dataChanged?(@data)

				.catch (err) =>
					console.error err
					throw new Error 'Not yet implemented'

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
