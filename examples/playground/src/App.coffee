React = require 'react'
{NICE, SUPER_NICE} = require './colors'
{div, a, br, textarea, pre, input} = React.DOM
Counter = React.createFactory require('./Counter')
Square = React.createFactory require('./Square')
{F, always, clone, gt, has, lt, lte, match, max, merge, none, replace, sort, test, values, where} = require 'ramda' #auto_require:ramda
{change} = require 'ramda-extras'
data = require './data'
Oublie = require 'oublie'
{toRamda} = require 'popsiql'


App = React.createClass
	getInitialState: ->
		delay: 1
		query: "{many: 'Customer', where: {employees: {lt: 100}}}"
		result: null
		cache: null
		data: data
		error: false
		strategy: 'PE' 
		expiry: 1

	componentWillMount: ->
		document.body.style.backgroundColor = "#F7F7F7"
		@cache = new Oublie
			pub: (key, delta) =>
				console.log 'pub', {key, delta}
				newResult = change clone(delta), @state.result
				@setState {result: newResult}
			remote: (key, query) =>
				console.log 'remote', {key, query}
				return new Promise (res) =>
					respond = => res toRamda(query)(@state.data)
					setTimeout respond, @state.delay * 1000
		@cache._dev_dataChanged = (data) =>
			@setState {cache: data}

	exec: ->
		@setState {error: null}
		query = '(' + @state.query + ')'
		try
			query_ = eval(query)
		catch ex
			console.log @state.query
			console.log ex
			@setState {error: 'Not valid javascript object...'}
			return

		# if ! has '_', query_
		# 	@setState {error: 'Missing strategy, use green box in top right corner'}
		# 	return

		console.log 'exec', query_, @state.strategy, @state.expiry
		try
			@cache.sub 'app', query_, @state.strategy, @state.expiry
		catch ex
			console.log @state.query
			console.log ex
			@setState {error: 'Error in cache, check console'}
			return

	render: ->
		style =
			width: '90vw'
			maxWidth: 1200
			display: 'flex'
			flexDirection: 'column'
		outerStyle =
			display: 'flex'
			justifyContent: 'center'
		div {style: outerStyle},
			div {style},
				Row {},
					Square {color: 'blue', title: 'Reads'},
						div {style: {fontSize: 10, color: '#787878'}}, 'Basic'
						Link {onClick: @setQuery("{many: 'Customer'}")}, 'Many customers'
						Link {onClick: @setQuery("{one: 'Customer', id: 5}")}, 'One customer'
						Link {onClick: @setQuery("{many: 'Person', id: [2,3,4]}")}, 'Many persons using ids'

						br()
						div {style: {fontSize: 10, color: '#787878'}}, 'With predicates'
						Link {onClick: @setQuery("{many: 'Customer', where: {employees: {lte: 10}}}")}, 'Customers with 10 employees or less'
						Link {onClick: @setQuery("{many: 'Person', where: {name: {like: '%h%'}}}")}, 'People with an "h" in their name'
						Link {onClick: @setQuery("{many: 'Person', where: {age: {lt: 30}, salary: {gt: 1000000}}}")}, 'Rich people under 30 (there are none)'
					Square {color: 'blue', title: 'Reads with sort, max and start'},
						Link {onClick: @setQuery("{many: 'Customer', sort: 'name'}")}, 'Customers by name'
						Link {onClick: @setQuery("{many: 'Person', sort: 'name', max: 2}")}, 'People by name, max 2'
						Link {onClick: @setQuery("{many: 'Person', sort: 'age', max: 2}")}, 'People by age, max 2'
						Link {onClick: @setQuery("{many: 'Person', sort: [{age: 'asc'}, {salary: 'desc'}]}")}, 'People by age asc then salary desc'
						Link {onClick: @setQuery("{many: 'Person', sort: 'name', max: 2, start: 2}")}, 'People by name, max 2, start 2'
					Square {color: 'blue', title: 'Writes'},
						Link {onClick: @setQuery("{new: 'Person', values: {name: '', age: 0, position: null, job: null, salary: null}}")}, 'New person (always local)'
						Link {onClick: @setQuery("{edit: 'Person', id: 2}")}, 'Edit person (id: 2)'
					Square {color: 'green', title: 'Chooooose a strategy for you query!'},
						Link {color: 'green', onClick: @setStrategy('LO')}, 'Local'
						Link {color: 'green', onClick: @setStrategy('PE', 2)}, 'Pessimistic 2s'
						Link {color: 'green', onClick: @setStrategy('OP', 5)}, 'Optimistic 5s'
						Link {color: 'green', onClick: @setStrategy('VO', 0)}, 'Very Optimistic 0s'
						Link {color: 'green', onClick: @setStrategy('VO', 60)}, 'Very Optimistic 60s'
				Row {},
					Square {color: 'lightblue', w: '60vw'},
						Textarea
							value: @state.query
							onChange: (e) => @setState {query: e.currentTarget.value}
							fontSize: 13
							rows: 4
					Square {color: 'lightblue', title: 'Strategy', center: true},
						Input {value: @state.strategy, fontSize: 15, size: 2, onChange: (e) => @setState({strategy: e.currentTarget.value})}
					Square {color: 'lightblue', title: 'Expiry(s)', center: true},
						Input {value: @state.expiry, fontSize: 15, size: 2, onChange: (e) => @setState({expiry: e.currentTarget.value})}
					Square {color: 'red', center: 1, w: 50, pointer: 1,
					onClick: @exec}, 'Exec!'
					SquareGroup {title: 'Simulated server delay:'},
						renderDelay 0, @state.delay, @onChangeDelay
						renderDelay 1, @state.delay, @onChangeDelay
						renderDelay 5, @state.delay, @onChangeDelay
				Row {},
					if @state.error
						div {style: {fontFamily: 'Avenir-Light', color: 'red'}}, @state.error
				br()
				br()
				Row {},
					Square {color: 'yellow', title: 'Result'},
						Code {}, @state.result && JSON.stringify(@state.result, null, 2)
					Square {color: 'orange', title: 'Cache'},
						Code {}, @state.cache && JSON.stringify(@state.cache, null, 2)
				br()
				Row {},
					Square {color: 'purple', title: 'Data on simulated server'},
						Code {}, JSON.stringify(@state.data, null, 2)

	onChangeDelay: (delay) ->
		@setState {delay}

	setStrategy: (strategy, expiry) ->  =>
		@setState {strategy, expiry}
		# str = @state.query
		# strategy_ = "_:'#{strategy}'}"
		# if test /_:(.*)}/, str
		# 	newStr = str.substr(0, match(/_:(.*)}/, str).index) + strategy_
		# else
		# 	newStr = replace /}\s*$/, ', ' + strategy_, str

		# @setState {query: newStr}

	setQuery: (query) -> =>
		@setState {query}

renderDelay = (delay, selectedDelay, onChange) ->
	selected = selectedDelay == delay
	Square {color: 'yellowgreen', center: 1, w: 10, h: 60, selected,
	pointer: 1, onClick: -> onChange(delay)}, delay + 's'






##### HELPERS #########################
Code = React.createFactory React.createClass
	render: ->
		{fontSize} = @props
		style = 
			fontFamily: 'Consolas'
			fontSize: fontSize || 11
			color: '#373737'
		pre {style}, @props.children

Textarea = React.createFactory React.createClass
	render: ->
		{value, rows, fontSize, onChange} = @props
		style = 
			background: 'none'
			border: 'none'
			fontFamily: 'Consolas'
			fontSize: fontSize || 11
			color: '#373737'
			outline: 'none !important'
		textarea {value, style, rows, onChange}

Input = React.createFactory React.createClass
	render: ->
		{value, fontSize, onChange, size} = @props
		style = 
			background: 'none'
			border: 'none'
			fontFamily: 'Consolas'
			fontSize: fontSize || 11
			color: '#373737'
			outline: 'none !important'
		input {value, style, onChange, size}

SquareGroup = React.createFactory React.createClass
	render: ->
		{title} = @props
		style = 
			display: 'flex'
			flexDirection: 'column'
			flexGrow: 1
			marginRight: '1vw'
		titleStyle =
			fontFamily: 'Avenir-Light'
			fontSize: 11
			color: '#787878'
			marginBottom: 2
		groupStyle =
			display: 'flex'
			flexDirection: 'row'
		div {style},
			div {style: titleStyle}, title
			div {style: groupStyle}, @props.children

Row = React.createFactory React.createClass
	render: ->
		style =
			display: 'flex'
			flexDirection: 'row'
			justifyContent: 'space-between'
			marginBottom: '1vw'
		div {style}, @props.children

Link = React.createFactory React.createClass
	render: ->
		{color} = @props
		style =
			fontFamily: 'RobotoSlab-Light'
			fontSize: 13
			color: if color == 'green' then '#0F761C' else '#352FE2'
			cursor: 'pointer'
			tabIndex: -1

		a merge({style}, @props), @props.children

module.exports = App
