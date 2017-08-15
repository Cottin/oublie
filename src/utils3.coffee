{__, has, none, remove} = require 'ramda' #auto_require:ramda
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

#auto_export:none_
module.exports = {ERR, getEntity, getOp, validateQuery}