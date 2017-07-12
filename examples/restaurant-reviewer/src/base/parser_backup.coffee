popsiql = require 'popsiql'

createTree = (app) ->

	# Data:
	# 	change: ({delta}) -> app.change delta

	Write: -> (delta) -> app.change delta
	UI: -> (delta) -> app.change {ui: delta}



	# Api: ->
	# 	URL = 'http://localhost:3030/api'
	# 	popsiqlToREST: (query) ->
	# 		to

	# 	get: (url) ->
	# 		res = yield fetch url
	# 		json = yield res.json()
	# 		return json

	# 	post: (url, body) ->
	# 		req =
	# 			method: 'post'
	# 			body: JSON.stringify(body)
	# 			headers: new Headers({'Content-Type': 'application/json'}) 
	# 			mode: 'cors'
	# 			redirect: 'follow'
	# 		res = yield fetch url, req
	# 		json = yield res.json()
	# 		return json

	# 	put: (url, body) ->
	# 		req =
	# 			method: 'put'
	# 			body: JSON.stringify(body)
	# 			headers: new Headers({'Content-Type': 'application/json'}) 
	# 			mode: 'cors'
	# 			redirect: 'follow'
	# 		res = yield fetch url, req
	# 		json = yield res.json()
	# 		return json

	# 	get__: ({type, id}) ->
	# 		url = URL + '/' + type + if id then '/' + id else ''
	# 		res = yield fetch url
	# 		json = yield res.json()
	# 		return json
	# 	post__: ({type, data}) ->
	# 		url = URL + '/' + type
	# 		req =
	# 			method: 'post'
	# 			body: JSON.stringify(data)
	# 			headers: new Headers({'Content-Type': 'application/json'}) 
	# 			mode: 'cors'
	# 			redirect: 'follow'
	# 		res = yield fetch url, req
	# 		json = yield res.json()
	# 		return json

	Api: -> ({method, url, body}) ->
		baseUrl = 'http://localhost:3030/api/'

		req =
			method: method
			body: if !isNil body then JSON.stringify body
			headers: new Headers({'Content-Type': 'application/json'}) 
			mode: 'cors'
			redirect: 'follow'
		res = yield fetch "#{baseUrl}#{url}", req
		json = yield res.json()
		return json

	Cache:
		pub: ({key, delta}) ->
			yield {Write: {"#{key}": delta}}
		remote: ({key, query}) =>
			{method, url, body} = popsiql.toRest query
			val = yield {Api: {method, url, body}}
			return val # if processing needed before feeding the cache, do it here



	# kanske tänka om det här lite. Vi har inte modeller, vi har en enklare
	# arkitektur utan cachning
	Model:
		Read: ({type}) ->
			yield {Write: {sync: {"#{type}": {read: true}}}}
			try
				os = yield {Api: 'get', type}
				yield {Write: {sync: {"#{type}": {read: false}}}}
				# yield {Write: {"sync/#{type}/read": false}} <- nice idea?
				# only needed if we want some kind of caching:
				# yield {Write: {"#{type}": os}}
				return os
			catch err
				yield {Write: {sync: {"#{type}": {read: err}}}}
				# yield {Data: 'change', delta: {Customer: {1: {$assoc: data}}
				# yield {Write: {Customer: {1: {$assoc: data}}}}
				# yield {Write: {'Customer/1': {$assoc: data}}}}
				# yield {Write: {'Customer/1': $assoc(data)}}}
		Create: ({type, data}) ->
			o = yield {Api: 'post', type, data}
			return o
			


	Restaurant:
		get: ->
			return yield {Model: 'Read', type: 'Restaurant'}

	Review:
		get: ->
			return yield {Model: 'Read', type: 'Review'}
		create: ({data}) ->
			o = yield {Model: 'Create', type: 'Review', data}
			yield {Write: {reviews: {"#{o.id}": {$assoc: o}}}}
			# app.forceQuery 'reviews'
			return o


module.exports = createTree
