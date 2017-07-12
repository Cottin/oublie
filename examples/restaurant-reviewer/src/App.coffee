{DOM: {div}, createElement: _} = React = require 'react'
{RestaurantListView_} = require './views/RestaurantListView'
{RestaurantView_} = require './views/RestaurantView'
{RestaurantEditView_} = require './views/RestaurantEditView'
{ReviewEditView_} = require './views/ReviewEditView'
{PhloxProvider} = require 'phlox'


App = React.createClass
	render: ->
		div {},
			_ PhloxProvider, {phlox: @props.phlox},
				div {className: 'app__root'},
					_ RestaurantListView_
					_ RestaurantView_
					# _ RestaurantEditView_
					_ ReviewEditView_

module.exports = App


