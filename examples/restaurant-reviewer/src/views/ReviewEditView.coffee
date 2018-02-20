{createElement: _, DOM: {div, input, br, select, option}} = React = require 'react' #auto_require:react
PureRenderMixin = require 'react-addons-pure-render-mixin'
{connect} = require 'phlox'
{fmapObjIndexed} = require 'ramda-extras' #auto_require:ramda-extras
{isNil, test} = require 'ramda' #auto_require:ramda
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

ReviewEditView = ({review, restaurant, actions: ac}) ->
# ReviewEditView = ({review, restaurant}) ->
	if isNil review
		return div {}

	div {className: 'revi'},
		div {className: 'revi__title-label'}, 'NEW REVIEW'
		div {className: 'revi__title'}, 'La Neta'

		br()
		br()
		div {className: 'revi__item'},
			div {className: 'revi__label'}, 'Stars'
			select {value: review.stars,
			onChange: (e) -> ac.change(stars: +e.target.value)},
				option {value: 1}, '1'
				option {value: 2}, '2'
				option {value: 3}, '3'
				option {value: 4}, '4'
				option {value: 5}, '5'

		div {className: 'revi__item'},
			div {className: 'revi__label'}, 'Text'
			input {className: 'revi__input', type: 'text', value: review.text,
			onChange: (e) -> ac.change({text: e.target.value})}

		div {className: 'revi__item'},
			div {className: 'revi__label'}, 'User'
			input {className: 'revi__input', type: 'text', value: review.user,
			onChange: (e) -> ac.change({user: e.target.value})}

		br()
		br()
		div {className: 'revi__buttons'},
			div {onClick: ac.cancel}, 'CANCEL'
			div {onClick: -> ac.create(review)}, 'SAVE'



ReviewEditView_ = ReviewEditView
module.exports = createComps connect, {ReviewEditView_}






