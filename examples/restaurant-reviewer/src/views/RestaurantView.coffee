{DOM: {div, a}, createElement: _} = React = require 'react'
PureRenderMixin = require 'react-addons-pure-render-mixin'
{connect} = require 'phlox'
{fmap, fmapObjIndexed} = require 'ramda-extras' #auto_require:ramda-extras
{isNil, map, range, test} = require 'ramda' #auto_require:ramda
cn = require 'classnames'

# to move: react-coffee
createComp = (f, name) ->
	React.createClass
		displayName: name
		# mixins: [PureRenderMixin]
		render: -> f @props, @context

createComps = (connect, o) ->
	fmapObjIndexed o, (f, k) ->
		comp = createComp f, k
		if test /_$/, k then connect comp, k
		else comp

RestaurantView = ({rest, actions: ac}) ->
	if isNil(rest)
		return div {}, 'Select a restaurant to the left'

	div {className: 'rv'},
		renderRest rest
		div {className: 'rv__add-review', onClick: ac.newReview}, 'ADD REVIEW'
		map renderReview, rest.reviews

renderRest = ({name, stars, address, desc, color}) ->
	div {},
		div {className: 'rv__title'}, name
		div {className: 'rv__address'}, address
		div {className: 'rv__desc'}, desc
		div {className: 'rv__rating', style: {background: color}}, stars

renderReview = ({id, text, stars, date, user}) ->
	div {key: id, className: 'rev'},
		renderUser user
		div {className: 'rev__right'},
			div {className: 'rev__text'}, text
			div {className: 'rev__bottom'},
				div {className: 'rev__date'}, date
				renderRating stars

renderUser = ({name, color, initials}) ->
	div {className: 'usr'},
		div
			className: 'usr__initials'
			style: {background: color}
		, initials
		div {className: 'usr__name'}, name

renderRating = (stars) ->
	div {className: 'rat'},
		fmap range(0, stars), -> '★'
		fmap range(stars, 5), -> '☆'




RestaurantView_ = RestaurantView

module.exports = createComps connect, {RestaurantView_}






