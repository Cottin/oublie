React = require 'react'
{div} = React.DOM

colorToColor = (s, selected) ->
	switch s
		when 'blue' then '#A2D3EE'
		when 'lightblue' then '#B6F1FF'
		when 'green' then '#A3EEA2'
		when 'yellowgreen'
			if selected then '#8CB159' else '#CEEEA2'
		when 'red' then '#FFB6B6'
		when 'yellow' then '#FFECB6'
		when 'orange' then '#FCDED0'
		when 'purple' then '#F4DBFF'
		when 'darkpurple' then '#D0D8FD'

Square = React.createClass
	render: ->
		{color, title, h, w, center, selected, onClick, pointer} = @props
		containerStyle = 
			display: 'flex'
			flexDirection: 'column'
			flexGrow: 1
			marginRight: '1vw'
			height: h
			width: w
		style =
			backgroundColor: colorToColor color, selected
			display: 'flex'
			flexDirection: 'column'
			flexGrow: 1
			padding: 10
			justifyContent: if center then 'center'
			alignItems: if center then 'center'
			fontFamily: 'RobotoSlab-Regular'
			fontSize: 13
			color: '#373737'
			cursor: if pointer then 'pointer'
		div {style: containerStyle},
			if title then renderTitle title
			div {style, onClick}, @props.children

renderTitle = (title) ->
	style =
		fontFamily: 'Avenir-Light'
		fontSize: 11
		color: '#787878'
		marginBottom: 2

	div {style}, title

module.exports = Square
