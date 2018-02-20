{compose, curry, filter, find, has, head, isEmpty, isNil, mean, merge, pluck, prop, reverse, sortBy, toLower, type, values, whereEq} = R = require 'ramda' #auto_require:ramda
{cc, fmap, fmapObjIndexed} = require 'ramda-extras' #auto_require:ramda-extras

denorm = curry (data, o) ->
	fmapObjIndexed o, (v, k) ->
		if ! has k, data then return v

		if type(v) == 'Array'
			return fmap (i) ->
				if has i, data[k] then data[k][i]
				else i

		if has v, data[k] then data[k][v]
		else v

denormWithMappning = curry (data, mappings, o) ->
	fmapObjIndexed o, (v, k) ->
		newData = mappings


restaurantsSorted = ({ui: {sortBy}, restaurants}, {reviewItems}) ->
	if isNil reviewItems then return []
	restaurants_ = fmapObjIndexed restaurants.val, (v, k) ->
		rs = cc filter(whereEq({restaurant: parseInt(k)})), values, reviewItems
		stars = pluck 'stars', rs
		avg = if isEmpty stars then 0 else Math.round(mean(stars) * 10) / 10
		color = if avg >= 4.0 then '#FF217B' else '#6128BC'
		merge v, {reviews: rs, stars: avg, color}

	restaurants__ = values restaurants_
	if sortBy == 'name'
		R.sortBy compose(toLower, prop('name')), restaurants__
	else if sortBy == 'stars'
		cc reverse, R.sortBy(prop('stars')), restaurants__
	else
		restaurants__

selectedRestaurant = ({ui: {selected}}, {restaurantsSorted}) ->
	if isNil(restaurantsSorted) || isNil(selected) then return null
	find whereEq({id: selected}), restaurantsSorted


reviewItems = ({reviews}, {}) ->
	if isNil reviews then return []
	colors = ['#DAC48D', '#8DDA91', '#D78DDA', '#8DCEDA', '#F28E8E']
	fmap reviews.val, (r) ->
		user =
			name: r.user
			initials: head r.user
			color: colors[head(r.user).charCodeAt() % colors.length]
		merge r, {user}


#auto_export:phlox
module.exports = {
	restaurantsSorted: {dataDeps: ['restaurants', 'ui.sortBy'], stateDeps: ['reviewItems'], f: restaurantsSorted},
	selectedRestaurant: {dataDeps: ['ui.selected'], stateDeps: ['restaurantsSorted'], f: selectedRestaurant},
	reviewItems: {dataDeps: ['reviews'], stateDeps: [], f: reviewItems}
}