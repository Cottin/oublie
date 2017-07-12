{has, sortBy} = R = require 'ramda' #auto_require:ramda

# When you want to be sure that the cache has been flushed (and published)
# before you're doing something.
ensureCacheFlush = () ->
	p = new Promise (res) ->
		setTimeout res, 250
	p.meta = 'ensureCacheFlush'
	return p

RestaurantListView_ = ({ui: {sortBy}}, {restaurantsSorted}) ->
	rests: restaurantsSorted
	sortBy: sortBy
	actions:
		sortBy: (sortBy) -> yield {UI: {sortBy: sortBy.toLowerCase()}}
		select: (id) -> yield {UI: {selected: id}}

RestaurantView_ = ({}, {selectedRestaurant}) ->
	rest: selectedRestaurant
	actions:
		newReview: () ->
			emptyReview = {stars: 1, text: '', user: '',
			restaurant: selectedRestaurant.id}
			yield {UI: {isEditReview: true}}

RestaurantEditView_ = ({}, {selectedRestaurant}) ->
	restaurant: selectedRestaurant

ReviewEditView_ = ({$review}, {selectedRestaurant}) ->
	review: $review
	restaurant: selectedRestaurant
	actions:
		cancel: ->
			yield {UI: {isEditReview: false}}
		create: (review) ->
			yield {Do: {commit: 'Review', id: $review.id, strategy: 'OP'}}
			yield ensureCacheFlush()
			yield {UI: {isEditReview: false}}
		change: (delta) ->
			yield {Do: {modify: 'Review', id: $review.id, delta}}
	

#auto_export:phlox
module.exports = {
	RestaurantListView_: {dataDeps: ['ui.sortBy'], stateDeps: ['restaurantsSorted'], f: RestaurantListView_},
	RestaurantView_: {dataDeps: [], stateDeps: ['selectedRestaurant'], f: RestaurantView_},
	RestaurantEditView_: {dataDeps: [], stateDeps: ['selectedRestaurant'], f: RestaurantEditView_},
	ReviewEditView_: {dataDeps: ['$review'], stateDeps: ['selectedRestaurant'], f: ReviewEditView_}
}