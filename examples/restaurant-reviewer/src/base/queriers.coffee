{} = R = require 'ramda' #auto_require:ramda

_ = (query, strategy, expiry) -> {query, strategy, expiry}

restaurants = ({}, {}) ->
	_ {many: 'Restaurant'}, 'OP', 20*60

reviews = ({}, {}) ->
	_ {many: 'Review'}, 'OP', 20*60

$review = ({ui: {selected, isEditReview}}, {}) ->
	if !isEditReview then return null
	emptyReview = {stars: 1, text: '', user: '', restaurant: selected}
	_ {spawn: 'Review', data: emptyReview}

#auto_export:phlox
module.exports = {
	restaurants: {dataDeps: [], stateDeps: [], f: restaurants},
	reviews: {dataDeps: [], stateDeps: [], f: reviews},
	$review: {dataDeps: ['ui.isEditReview', 'ui.selected'], stateDeps: [], f: $review}
}