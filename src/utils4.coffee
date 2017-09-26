{__, empty, has, init, isEmpty, isNil, none, omit, remove, test} = require 'ramda' #auto_require:ramda
popsiql = require 'popsiql'

ERR = 'Oublie Error: '

getEntity = (query) ->
	{spawn, edit, modify, commit, revert, undo, refresh, remove, spawnedit} = query
	return spawn || edit || modify || commit || revert || undo || refresh ||
					remove || spawnedit || popsiql.getEntity(query)

getOp = (query) ->
	hasIt = has __, query
	if hasIt 'spawn' then 'spawn'
	else if hasIt 'edit' then 'edit'
	else if hasIt 'modify' then 'modify'
	else if hasIt 'commit' then 'commit'
	else if hasIt 'revert' then 'revert'
	else if hasIt 'undo' then 'undo'
	else if hasIt 'refresh' then 'refresh'
	else if hasIt 'remove' then 'remove'
	else if hasIt 'spawnedit' then 'spawnedit'
	else popsiql.getOp query

validateQuery = (query) ->
	if has 'start', query
		throw new Error ERR + 'no support for start (yet?)'

init = (x) -> isNil x
wait = (x) ->
	if isNil x then return false
	return test /[crud]w$/, x._
done = (x) ->
	if isNil x then return false
	return test /[crud]d$/, x._
empty = (x) ->
	if isNil x then return false
	return isEmpty omit(['_'], x)

error = (x) -> return false

#auto_export:none_
module.exports = {ERR, getEntity, getOp, validateQuery, init, wait, done, empty, error}