require 'whatwg-fetch'

React = require 'react'
ReactDOM = require 'react-dom'
Pawpaw = require 'pawpaw'
{Phlox} = require 'phlox'
Oublie = require 'oublie'
{all, isNil, over, sortBy, without} = R = require 'ramda' #auto_require:ramda

viewModels = require './base/viewModels'
queriers = require './base/queriers'
lifters = require './base/lifters'
createTree = require './base/parser'
require './style.css'
App = React.createFactory require('./App')


initialData =
	ui: {sortBy: 'name'}
	sync: {}

cache = new Oublie
	pub: (key, delta) => parser.exec {Cache: 'pub', key, delta}
	remote: (key, query, meta) =>
		if meta && meta.stack
			parser.execManually {Cache: 'remote', key, query}, null, meta.stack
		else
			parser.exec {Cache: 'remote', key, query}

cache._dev_dataChanged = (data) =>
	req =
		method: 'PUT'
		body: JSON.stringify data
		headers: new Headers({'Content-Type': 'application/json'}) 
		mode: 'cors'
		redirect: 'follow'

	fetch "http://localhost:3001/dev/data/cache?shouldOverwrite=true", req

onQuery = (cacheQuery, key) ->
	if isNil cacheQuery
		parser.exec {Cache: 'sub', key, query: null}
		return
	{query, strategy, expiry} = cacheQuery
	parser.exec {Cache: 'sub', key, query, strategy, expiry}

onAction = (action, args, meta) ->
	parser.execIter action, args, meta

phlox = new Phlox {viewModels, queriers, parser, lifters, onQuery, onAction, initialData}
phlox._dev_stateChanged = (data) ->
	req =
		method: 'PUT'
		body: JSON.stringify data
		headers: new Headers({'Content-Type': 'application/json'}) 
		mode: 'cors'
		redirect: 'follow'

	fetch "http://localhost:3001/dev/data/state?shouldOverwrite=true", req

parser = new Pawpaw createTree(phlox, cache)
parser.logLevel = 999

window.app = phlox

# Showing how you can mock viewModels.
# By doing so, you can develop all of your views before you decide how lifters,
# queriers, viewModels and your general data architechture should look like.
window.mock =
	viewModels: ->
		viewModels =
			RestaurantListView_:
				rests: [
						id: 1, name: 'La Neta (mocked)', address: 'Drottninggatan 132', stars: 5.0, color: 'pink',
						desc: 'Our tacos and quesadillas perfect catering for corporate events or private parties. We even have vegetarian, vegan, gluten-free and lactose-free options.'
					,
						id: 2, name: 'Rolfs Kök (mocked)', address: 'Tegnérgatan 41', stars: 4.9, color: 'teal',
						desc: 'Rolfs Kitchen repaired only food that we like ourselves. It is based on simplicity and quality, without fuss and frills. Here are the joy of food and the atmosphere is more important than trends and what is "in" or "out".'
					,
						id: 3, name: 'Underbar (mocked)', address: 'Drottninggatan 102', stars: 4.8, color: 'lime',
						desc: 'Libanon i Stockholm'
					,
						id: 4, name: 'Martins Gröna (mocked)', address: 'Regeringsgatan 91', stars: 4.7, color: 'red',
						desc: 'Martin Green is a vegetarian lunch restaurant situated in central Stockholm. Since 1998 we have served vegetarian food using fresh ingredients and spices from all over the world with much love.'
					,
						id: 5, name: 'Indian Garden (mocked)', address: 'Västgötagatan 18', stars: 4.6, color: 'blue',
						desc: 'Rezaul Karim, founder and owner of Indian Garden. Born in Bangladesh in 1975 and came to Sweden 19 years old. Even as a child in Bangladesh, he showed a great interest in cooking and spent much time alongside his mother in the kitchen.'
					]
				sortBy: 'stars'
			RestaurantView_: null
				# rest: selectedRestaurant
			RestaurantEditView_: null
			ReviewEditView_: null

		phlox.mock {viewModels}

# http://stackoverflow.com/questions/41448596/shortcut-to-clear-console-in-chrome-dev-tools-without-having-dev-tools-focused/41448862#41448862
doc_keyUp = (e) ->
	if (e.ctrlKey && e.keyCode == 68)
		console.clear()
document.addEventListener 'keyup', doc_keyUp, false

ReactDOM.render(App({phlox}), document.getElementById('root'))

if module.hot
	module.hot.accept ['./base/viewModels', './base/queriers', './base/lifters'], (updated) ->
		nextViewModels = require './base/viewModels'
		nextQueriers = require './base/queriers'
		nextLifters = require './base/lifters'
		phlox.reinitialize {viewModels: nextViewModels, queriers: nextQueriers, lifters: nextLifters}
