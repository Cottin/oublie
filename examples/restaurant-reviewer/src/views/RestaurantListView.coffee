{DOM: {div, a}, createClass, createElement: _} = React = require 'react'
PureRenderMixin = require 'react-addons-pure-render-mixin'
{connect} = phlox = require 'phlox'
{fmapObjIndexed} = require 'ramda-extras' #auto_require:ramda-extras
{map, sort, sortBy, test} = require 'ramda' #auto_require:ramda
cn = require 'classnames'


# to move: react-coffee
createComp = (f, name) ->
	createClass
		displayName: name
		# mixins: [PureRenderMixin]
		render: -> f @props, @context

createComps = (connect, o) ->
	fmapObjIndexed o, (f, k) ->
		comp = createComp f, k
		if test /_$/, k then connect comp, k
		else comp

RestaurantListView = ({rests = [], sortBy, actions: ac}) ->
	div {className: 'rlv'},
		div {className: 'rlv__search'},
			div {className: 'b'}, 'Sort by:'
			renderLink(ac) 'Stars', sortBy
			renderLink(ac) 'Name', sortBy
		div {className: 'rlv__list'},
			map renderRest(ac), rests

renderLink = (ac) -> (name, sort) ->
	isActive = sort == name.toLowerCase()
	a
		className: cn {link: !isActive}
		onClick: -> if !isActive then ac.sortBy(name)
	,
		name

renderRest = (ac) -> ({id, name, stars, address, isSelected, color}) ->
	className = cn
		rlv__li: true
		selected: isSelected
	div {key: id, className, onClick: -> ac.select(id)},
		div {style: {color}, className: 'rlv__rating'}, stars
		div {},
			div {}, name
			div {className: 'rlv__address'}, address


RestaurantListView_ = RestaurantListView

module.exports = createComps connect, {RestaurantListView_}






