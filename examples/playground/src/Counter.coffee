React = require 'react'
{h1} = React.DOM

Counter = React.createClass
  getInitialState: ->
    counter: 0

  componentWillMount: ->
    @interval = setInterval (=> @tick()), 1000

  tick: ->
    @setState {counter: @state.counter + @props.increment}

  componentWillUnmount: ->
    clearInterval @interval

  render: ->
    {color, increment} = @props
    h1 {style: {color}},
      "Counter #{increment}: #{@state.counter}"

module.exports = Counter
