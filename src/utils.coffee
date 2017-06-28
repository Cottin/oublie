{all, any, assoc, call, difference, dissoc, has, isEmpty, isNil, keys, map, match, max, merge, none, omit, remove, test, type, update, where, whereEq} = R = require 'ramda' #auto_require:ramda
popsiql = require 'popsiql'
{cc, minIn} = require 'ramda-extras'

_getEntity = (query) ->
	{all, edit} = query
	return all || edit || popsiql.getEntity(query)

# toReadQuery = (query) ->
# 	q_ = omit ['one', 'many', 'all', 'id'], query
# 	q__ = assoc 'get', _getEntity(query), q_
# 	if ! has('id', query) then return q__

# 	if type(query.id) == 'Array'
# 		return merge q__, {where: {id: {in: query.id}}}
# 	else
# 		return merge q__, {where: {id: query.id}}

_read = (cache, query) ->
	# pagination make things more complex, and if you want to support start
	# we need more advanced indexing. For now, let's just remove start on local
	# queries. That should anyway support all use-cases in all apps we have today
	# IDEA: maybe we should remove start! ...and instead you just declare max
	# and cache figures out how to optimize the query by adding start. For later..
	if has 'start', query then query = dissoc 'start', query 

	return popsiql.toRamda(query)(cache.objects)

_isCached = (cache, query) ->
	if query.id
		# todo: handle ids that are not int
		ids = cc map(parseInt), keys, cache.ids[_getEntity(query)]
		wantedIds = if type(query.id) == 'Array' then query.id else [query.id]
		return cc isEmpty, difference(wantedIds), ids
	else
		return any whereEq({query}), (cache.queries[_getEntity(query)] || [])

_doRead = (cache, query, strategy, expiry) ->
	switch strategy
		when 'LO' then [_read(cache, query), null]
		when 'PE' then [null, query]
		when 'OP'
			if _isCached cache, query then [_read(cache, query), null]
			else [null, query]
			# l = if _isCached cache, query then _read cache, query
			# return [l, query]
		when 'VO'
			if _isCached cache, query then [_read(cache, query), null]
			else [_read(cache, query), query]

# o -> o -> [l, r]
# Takes a cache and a query and returns any cache hits as l and the remaining
# query to ask the remote as r. Note that when using strategy 'VO' we try to
# be smart by deciding if remote query is needed at all or changing the remote
# query if the original query can be partially fulfilled with the cache hits.
query = (cache, query, strategy, expiry) ->
	if isNil strategy 
		throw new Error 'No strategy given for query '
		# throw new Error 'No strategy given for query ' + JSON.stringify(query)

	if ! test /^LO$|^PE$|^OP$|^VO$/, strategy
		throw new Error 'Invalid strategy given: ' + strategy

	if test(/^OP$|^VO$/, strategy) && isNil expiry
		throw new Error 'Strategies OP and VO requires an expiry'

	if has 'one', query
		if query.id && type(query.id) == 'Array' && query.id.length > 1
			throw new Error "cannot have multiple ids in call to 'one'"

		[l, r] = _doRead cache, query, strategy, expiry
		if keys(l).length > 1
			console.error 'query:', query
			console.error "matches (#{keys(l).length}):", l
			# throwing here is a test, it might be a bad idea, keep an open mind
			throw new Error 'one-query expects maximum one match, your query had
			multiple matches in the local cache'
		return [l, r]
	else if has 'many', query then return _doRead cache, query, strategy, expiry
	else if has 'all', query then throw new Error 'all not yet implemented'

	# else if has 'new', query
	# 	if strategy != 'LO' then throw new Error 'new queries need local strategy'
	# 	return [query, null]

	throw new Error 'Invalid cache query, missing valid operation (one, many, all, 
	edit, new, newedit, merge, commit, revert, remove)'


_doCommit = (cache, query, strategy) ->
	sub = cache.subs[query.commit]
	if isNil sub
		console.log 'error with query:', query
		throw new Error "cannot commit, no subscription called #{query.commit}"

	if ! ( has('edit', sub.query) || has('new', sub.query) )
		console.log 'error with query:', query
		throw new Error "cannot commit, subscription #{query.commit} is not edit or new"

	entity = _getEntity sub.query
	{id} = sub.query

	l = {"#{entity}": {$merge: cache.diff[entity][id]}}
	r = {update: entity, id, data: cache.diff[entity][id]}

	return [l, r]

	# if strategy == 'LO' then return [l, null]
	# else if strategy == 'PE' then return [null, r]
	# else if strategy == 'OP' then return [l, r]



exec = (cache, query, strategy) ->
	if has 'commit', query then return _doCommit cache, query, strategy

	throw new Error 'Invalid cache query, missing valid operation (one, many, all, 
	edit, new, newedit, merge, commit, revert, remove)'



#auto_export:none_
module.exports = {query, exec}