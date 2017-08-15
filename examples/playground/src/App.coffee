React = require 'react'
{NICE, SUPER_NICE} = require './colors'
{div, a, br, textarea, pre, input, ul, li} = React.DOM
Counter = React.createFactory require('./Counter')
Square = React.createFactory require('./Square')
{F, __, always, clone, empty, fromPairs, gt, has, isNil, keys, lt, lte, map, match, max, merge, none, remove, replace, set, sort, test, type, update, where} = require 'ramda' #auto_require:ramda
{cc, change} = require 'ramda-extras'
data = require './data'
Oublie = require 'oublie'
popsiql = require 'popsiql'

uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
  r = Math.random() * 16 | 0
  v = if c == 'x' then r else r & 0x3 | 0x8
  v.toString 16


App = React.createClass
	getInitialState: ->
		delay: 1
		query: "{many: 'Customer', where: {employees: {lt: 100}}}"
		sub1: null
		sub2: null
		cache: null
		data: data
		error: false
		strategy: 'PE' 
		expiry: 1

	componentWillMount: ->
		document.body.style.backgroundColor = "#F7F7F7"
		@cache = new Oublie
			pub: (key, delta) =>
				# console.log 'pub', {key, delta}
				newResult = change clone(delta), @state[key]
				# console.log key, {newResult}
				@setState {"#{key}": newResult}
			remote: (key, query) =>
				# console.log 'remote', {key, query}
				return new Promise (res) =>
					respond = =>
						data = popsiql.toRamda(query)(@state.data)
						op = popsiql.getOp query
						entity = popsiql.getEntity query
						if op == 'one' || op == 'many'
							if type(data) == 'Array'
								data = cc fromPairs, map((o)-> [o.id, o]), data
							res data
						else if op == 'update'
							[data_, _] = data
							updatedObj = data_[entity][query.id]
							@setState {data: data_}
							res updatedObj
						else if op == 'create'
							if isNil query.id
								# nextId = popsiql.nextId keys(@state.data[entity])
								[data_, newId] = data
								createdObj = data_[entity][newId]
								@setState {data: data_}
								res createdObj
							else
								[data_, _] = data
								createdObj = data_[entity][query.id]
								@setState {data: data_}
								res createdObj
						else if op == 'remove'
							[data_, _] = data
							@setState {data: data_}
							res()

					setTimeout respond, @state.delay * 1000
		@cache._dev_dataChanged = (data) =>
			@setState {cache: data}

	sub1: -> @exec 'sub1'
	sub2: -> @exec 'sub2'
	do: -> @exec 'do'
	exec: (type) ->
		@setState {error: null}
		if @state.query == ''
			query_ = null
		else
			query = '(' + @state.query + ')'
			try
				query_ = eval(query)
			catch ex
				console.log @state.query
				console.log ex
				@setState {error: 'Not valid javascript object...'}
				return

		if type == 'do'
			@cache.do query_, @state.strategy
		else if type == 'sub1'
			@cache.sub 'sub1', query_, @state.strategy, @state.expiry
		else if type == 'sub2'
			@cache.sub 'sub2', query_, @state.strategy, @state.expiry
		# try
		# 	if has 'modify', query_
		# 		@cache.do query_, @state.strategy
		# 	else
		# 		@cache.sub 'app', query_, @state.strategy, @state.expiry
		# catch ex
		# 	console.log @state.query
		# 	console.log ex
		# 	@setState {error: 'Error in cache, check console'}
		# 	return

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
					Square {color: 'blue', title: 'Subscriptions'},
						div {style: {fontSize: 10, color: '#787878'}}, 'Basic reads'
						Link {onClick: @setQuery("{many: 'Customer'}")}, 'Many customers'
						Link {onClick: @setQuery("{one: 'Customer', id: 5}")}, 'One customer'
						Link {onClick: @setQuery("{many: 'Person'}")}, 'Many persons'
						Link {onClick: @setQuery("{many: 'Person', id: [2,3,4]}")}, 'Three persons using ids'
						Link {onClick: @setQuery("{many: 'Person', id: [1,2,3,4]}")}, 'Four persons using ids'

						br()
						div {style: {fontSize: 10, color: '#787878'}}, 'Reads with predicates'
						Link {onClick: @setQuery("{many: 'Customer', where: {employees: {lte: 10}}}")}, 'Customers with 10 employees or less'
						Link {onClick: @setQuery("{many: 'Person', where: {name: {like: '%g%'}}}")}, 'People with a "g" in their name'
						Link {onClick: @setQuery("{many: 'Person', where: {age: {lt: 30}, salary: {gt: 1000000}}}")}, 'Rich people under 30 (there are none)'
					Square {color: 'blue', title: '...'},
						div {style: {fontSize: 10, color: '#787878'}}, 'Reads with sort, max and start'
						Link {onClick: @setQuery("{many: 'Customer', sort: 'name'}")}, 'Customers by name'
						Link {onClick: @setQuery("{many: 'Person', sort: 'name', max: 2}")}, 'People by name, max 2'
						Link {onClick: @setQuery("{many: 'Person', sort: [{name: 'desc'}], max: 2}")}, 'People by name desc, max 2'
						Link {onClick: @setQuery("{many: 'Person', sort: 'age', max: 2}")}, 'People by age, max 2'
						Link {onClick: @setQuery("{many: 'Person', sort: [{age: 'asc'}, {salary: 'desc'}]}")}, 'People by age asc then salary desc'
						Link {onClick: @setQuery("{many: 'Person', sort: 'name', max: 2, start: 2}")}, 'People by name, max 2, start 2'

						br()
						div {style: {fontSize: 10, color: '#787878'}}, 'New & Edit'
							Link {onClick: @setQuery("{spawn: 'Person', data: {name: '', age: 0, position: null, job: null, salary: null}}")}, 'Spawn new person (always local)'
							Link {onClick: @setQuery("{spawn: 'Person', data: {id: '#{uuid}', name: '', age: 0, position: null, job: null, salary: null}}")}, 'Spawn new person with id (always local)'
							Link {onClick: @setQuery("{edit: 'Person', id: 2}")}, 'Edit person (id: 2)'
							Link {onClick: @setQuery("{spawnedit: 'Person', id: 2, data: {id: 2, name: '', age: 0, position: null, job: null, salary: null}}")}, 'Spawnedit person with id=2 (always local)'

					Square {color: 'red', title: 'Writes'},
						Link {color: 'red', onClick: @setQuery("{modify: 'Person', id: '___0', delta: {name: 'Taylor Swift', salary: 50000000, age: 27}}")}, 'Modify person under edit (assumes id=___0)'
						Link {color: 'red', onClick: @setQuery("{revert: 'Person', id: '___0'}")}, 'Revert person under edit (assumes id=___0)'
						Link {color: 'red', onClick: @setQuery("{commit: 'Person', id: '___0'}")}, 'Commit person under edit (assumes id=___0)'
						Link {color: 'red', onClick: @setQuery("{remove: 'Person', id: '___0'}")}, 'Remove person (assumes id=___0)'
						Link {color: 'red', onClick: @setQuery("{modify: 'Person', id: 2, delta: {position: 'Assistant to the traveling secretary'}}")}, 'Modify person under edit (assumes id=2)'
						Link {color: 'red', onClick: @setQuery("{revert: 'Person', id: 2}")}, 'Revert person under edit (assumes id=2)'
						Link {color: 'red', onClick: @setQuery("{commit: 'Person', id: 2}")}, 'Commit person under edit (assumes id=2)'
						Link {color: 'red', onClick: @setQuery("{remove: 'Person', id: 2}")}, 'Remove person (assumes id=2)'
					Square {color: 'green', title: 'Chooooose a strategy for you query!'},
						Link {color: 'green', onClick: @setStrategy('LO')}, 'Local'
						Link {color: 'green', onClick: @setStrategy('PE', 2)}, 'Pessimistic 2s'
						Link {color: 'green', onClick: @setStrategy('OP', 5)}, 'Optimistic 5s'
						Link {color: 'green', onClick: @setStrategy('VO', 1)}, 'Very Optimistic 1s'
						Link {color: 'green', onClick: @setStrategy('VO', 20)}, 'Very Optimistic 20s'

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
					Square {color: 'yellow', center: 1, w: 50, pointer: 1,
					onClick: @sub1}, 'Sub1!'
					Square {color: 'orange', center: 1, w: 50, pointer: 1,
					onClick: @sub2}, 'Sub2!'
					Square {color: 'red', center: 1, w: 50, pointer: 1,
					onClick: @do}, 'do!'
					SquareGroup {title: 'Simulated server delay:'},
						renderDelay 0, @state.delay, @onChangeDelay
						renderDelay 1, @state.delay, @onChangeDelay
						renderDelay 5, @state.delay, @onChangeDelay
				Row {},
					if @state.error
						div {style: {fontFamily: 'Avenir-Light', color: 'red'}}, @state.error
				br()
				Row {},
					div {style: {fontFamily: 'Avenir-Light', fontSize: 11, color: '#787878'}},
						ul {},
							li {}, 'If expiry is set to 0, the objects received from the server expires before the throttled commit will execute, so minimum expiry ~1s'
							li {}, 'To unsubscribe, subscribe to an empty string'
				br()
				Row {},
					Square {color: 'yellow', title: 'Sub 1'},
						Code {}, @state.sub1 && JSON.stringify(@state.sub1, null, 2)
					Square {color: 'orange', title: 'Sub 2'},
						Code {}, @state.sub2 && JSON.stringify(@state.sub2, null, 2)
					Square {color: 'darkpurple', title: 'Cache'},
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
		if color == 'green' then color_ = '#0F761C'
		else if color == 'red' then color_ = '#A20404'
		else color_ = '#352FE2'

		style =
			fontFamily: 'RobotoSlab-Light'
			fontSize: 13
			color: color_
			cursor: 'pointer'
			tabIndex: -1

		a merge({style}, @props), @props.children

module.exports = App
