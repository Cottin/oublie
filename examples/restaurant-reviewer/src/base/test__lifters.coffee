assert = require 'assert'
{flip, merge, sortBy} = require 'ramda' #auto_require:ramda
{change} = require 'ramda-extras'

lifters = require './lifters'
mockData = require './mockData'
mockState = require './mockState'

eq = flip assert.equal
deepEq = flip assert.deepEqual
throws = (f) -> assert.throws f, Error


describe 'lifters', ->
	describe 'restaurantsSorted', ->
		{f} = lifters.restaurantsSorted
		it 'simple case', ->
			res = f mockData, mockState
			eq 'Martins Gröna', res[3].name 
		it 'sortBy stars, and correct avg. and color', ->
			res = f merge(mockData, {ui: {sortBy: 'stars'}}), mockState
			eq 'La Neta', res[1].name
			eq 3.7, res[1].stars
			eq '#6128BC', res[1].color

	describe 'selectedRestaurant', ->
		{f} = lifters.selectedRestaurant
		it 'simple case', ->
			res = f mockData, mockState
			eq 'Rolfs Kök', res.name

		it 'null cases', ->
			res = f mockData, merge(mockState, {restaurantsSorted: null})
			eq null, res

			res = f change({ui: {selected: undefined}}, mockData), mockState
			eq null, res


	describe 'reviewItems', ->
		{f} = lifters.reviewItems
		it 'simple case', ->
			res = f mockData, mockState
			eq 1, res[1].restaurant

			expected = {name: 'Martin', initials: 'M', color: '#D78DDA'}
			deepEq expected, res[1].user




