popsiql = require 'popsiql'
{has, isNil, omit} = R = require 'ramda' #auto_require:ramda
{isThenable} = require 'ramda-extras'

pwrap = (promise, meta) ->
	promise.meta = meta
	return promise

createTree = (app, cache) ->

	Write: -> (delta) -> app.change delta
	UI: -> (delta) -> app.change {ui: delta}

	Api: -> ({method, url, body}) ->
		baseUrl = 'http://localhost:3030/api/'

		req =
			method: method
			body: if !isNil body then JSON.stringify body
			headers: new Headers({'Content-Type': 'application/json'}) 
			mode: 'cors'
			redirect: 'follow'
		res = yield pwrap fetch("#{baseUrl}#{url}", req), "#{baseUrl}#{url}"
		json = yield pwrap res.json(), 'json-parse'
		return json

	Cache:
		# reactions FROM the cache
		pub: ({key, delta}) ->
			yield {Write: {"#{key}": delta}}
		remote: ({key, query}) =>
			{method, url, body} = popsiql.toRest query
			val = yield {Api: {method, url, body}}
			return val # if processing needed before feeding the cache, do it here

		# calls TO the cache
		sub: ({key, query, strategy, expiry}) ->
			cache.sub key, query, strategy, expiry
		do: ({query, strategy}) ->
			# if has 'modify', query then cache.do query, strategy, {stack: @stack}
			# else yield cache.do query, strategy, {stack: @stack}
			# cache.do query, strategy, {stack: @stack}
			cache.do query, strategy, {stack: @stack}
			# res = cache.do query, strategy, {stack: @stack}
			# if isThenable res then yield res

	# Shorthands
	Do: -> (_query) ->
		{strategy} = _query
		query = omit ['strategy'], _query
		yield {Cache: 'do', query, strategy}

module.exports = createTree
