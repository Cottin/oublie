assert = require 'assert'
{add, call, flip, gt, gte, last, lt, lte, match, max, sort, values, where} = require 'ramda' #auto_require:ramda

eq = flip assert.strictEqual
deepEq = flip assert.deepEqual
throws = (re, f) -> assert.throws f, re

utils = require './utils'

describe 'utils', ->
	mock =
		objects:
			o:
				2:
					id: 2
					a: 'a2'
				4:
					id: 4
					a: 'a4'
		queries:
			o: [
				{expires: Date.now() + 90, query: {one: 'o', where: {a: 'a1'}}}
				{expires: Date.now() + 90, query: {one: 'o', where: {a: 'a2'}}}
				{expires: Date.now() + 90, query: {one: 'o', where: {a: {like: 'a%'}}}}
				{expires: Date.now() + 90, query: {many: 'o', where: {id: {gt: 4}}}}
				{expires: Date.now() + 90, query: {many: 'o', where: {id: {lte: 4}}}}
			]
		ids:
			o:
				2: Date.now() + 90
				4: Date.now() + 90


	q_ = (query, strategy, expiry) -> utils.query mock, query, strategy, expiry

	##############################################################################
	##############################################################################
	describe 'edge cases', ->
		it 'missing strategy', ->
			throws /No strategy given for query /, ->
				q_ {one: 'o', where: {a: 'a2'}}

		it 'invalid strategy', ->
			throws /Invalid strategy given: /, ->
				q_ {one: 'o', where: {a: 'a2'}}, 'XX'

		it 'missing key operation', ->
			throws /Invalid cache query, missing valid operation/, ->
				q_ {xxx: 'o', where: {a: 'a2'}}, 'LO'

		it 'OP missing expiry', ->
			throws /Strategies OP and VO requires an expiry/, ->
				q_ {one: 'o', where: {a: 'a2'}}, 'OP'

		it 'VO missing expiry', ->
			throws /Strategies OP and VO requires an expiry/, ->
				q_ {one: 'o', where: {a: 'a2'}}, 'VO'

		it 'start removed for local query', ->
			[l, r] = q_ {many: 'o', max: 2, start: 2}, 'VO', 0
			deepEq [{id: 2, a: 'a2'}, {id: 4, a: 'a4'}], l
			deepEq {many: 'o', max: 2, start: 2}, r

		# add the last
		# describe 'optimistic', ->
		# 	it 'nothing in query', ->
		# 		[l, r] = q_ {one: 'ppp', where: {a: 'a1'}, _:'OP0'}
		# 		eq null, l
		# 		deepEq {one: 'ppp', where: {a: 'a1'}}, r


	# ##############################################################################
	# ##############################################################################
	describe 'one', ->
		describe 'query', ->
			describe 'LO', ->
				it 'miss', ->
					[l, r] = q_ {one: 'o', where: {a: 'a1'}}, 'LO'
					eq null, l
					eq null, r

				it 'hit', ->
					[l, r] =  q_ {one: 'o', where: {a: 'a2'}}, 'LO'
					deepEq {2: {id: 2, a: 'a2'}}, l
					eq null, r

			describe 'PE', ->
				it 'miss', ->
					[l, r] = q_ {one: 'o', where: {a: 'a1'}}, 'PE'
					eq null, l
					deepEq {one: 'o', where: {a: 'a1'}}, r

				it 'hit', ->
					[l, r] = q_ {one: 'o', where: {a: 'a2'}}, 'PE'
					eq null, l
					deepEq {one: 'o', where: {a: 'a2'}}, r

			describe 'OP', ->
				describe 'cached', ->
					it 'miss', ->
						[l, r] = q_ {one: 'o', where: {a: 'a1'}}, 'OP', 0
						eq null, l
						eq null, r

					it 'hit', ->
						[l, r] = q_ {one: 'o', where: {a: 'a2'}}, 'OP', 10
						deepEq {2: {id: 2, a: 'a2'}}, l
						eq null, r

				describe 'non-cached', ->
					it 'miss', ->
						[l, r] = q_ {one: 'o', where: {a: 'a3'}}, 'OP', 2
						eq null, l
						deepEq {one: 'o', where: {a: 'a3'}}, r

					it 'hit', ->
						[l, r] = q_ {one: 'o', where: {a: 'a4'}}, 'OP', 0
						deepEq null, l
						deepEq {one: 'o', where: {a: 'a4'}}, r

			describe 'VO', ->
				describe 'VO', ->
					describe 'cached', ->
						it 'miss', ->
							[l, r] = q_ {one: 'o', where: {a: 'a1'}}, 'OP', 7
							eq null, l
							eq null, r

						it 'hit', ->
							[l, r] = q_ {one: 'o', where: {a: 'a2'}}, 'OP', 0
							deepEq {2: {id: 2, a: 'a2'}}, l
							eq null, r

					describe 'non-cached', ->
						it 'miss', ->
							[l, r] = q_ {one: 'o', where: {a: 'a3'}}, 'OP', 0
							eq null, l
							deepEq {one: 'o', where: {a: 'a3'}}, r

						it 'hit', ->
							[l, r] = q_ {one: 'o', where: {a: 'a4'}}, 'OP', 1
							deepEq null, l
							deepEq {one: 'o', where: {a: 'a4'}}, r


			describe 'many maches', ->
				it 'LO hit', ->
					throws /one-query expects maximum one match/, ->
						q_ {one: 'o', where: {a: {like: 'a%'}}}, 'LO'
				it 'PE', ->
					[l, r] = q_ {one: 'o', where: {a: {like: 'a%'}}}, 'PE'
					eq null, l
					deepEq {one: 'o', where: {a: {like: 'a%'}}}, r
				it 'OP', ->
					throws /one-query expects maximum one match/, ->
						q_ {one: 'o', where: {a: {like: 'a%'}}}, 'OP', 0

		describe 'one id', ->
			describe 'LO', ->
				it 'miss', ->
					[l, r] = q_ {one: 'o', id: [1]}, 'LO'
					eq null, l
					eq null, r

				it 'hit', ->
					[l, r] = q_ {one: 'o', id: [2]}, 'LO'
					deepEq {2: {id: 2, a: 'a2'}}, l
					eq null, r

			describe 'PE', ->
				it 'miss', ->
					[l, r] = q_ {one: 'o', id: [1]}, 'PE'
					eq null, l
					deepEq {one: 'o', id: [1]}, r

				it 'hit', ->
					[l, r] = q_ {one: 'o', id: [2]}, 'PE'
					eq null, l
					deepEq {one: 'o', id: [2]}, r

			describe 'OP', ->
				# NOTE: with one id it if it's indexed => it's a hit
				describe 'cached', ->
					it 'hit', ->
						[l, r] = q_ {one: 'o', id: [2]}, 'OP', 0
						deepEq {2: {id: 2, a: 'a2'}}, l
						deepEq null, r

				describe 'non-cached', ->
					it 'miss', ->
						[l, r] = q_ {one: 'o', id: 1}, 'OP', 10
						eq null, l
						deepEq {one: 'o', id: 1}, r

			describe 'VO', ->
				# NOTE: with one id it if it's indexed => it's a hit
				describe 'indexed', ->
					it 'hit', ->
						[l, r] = q_ {one: 'o', id: 2}, 'VO', 2
						deepEq {2: {id: 2, a: 'a2'}}, l
						deepEq null, r

				describe 'non-indexed', ->
					it 'miss', ->
						[l, r] = q_ {one: 'o', id: [1]}, 'VO', 0
						eq null, l
						deepEq {one: 'o', id: [1]}, r


		describe 'multiple ids', ->
			it 'LO', ->
				throws /cannot have multiple ids in call to 'one'/, ->
					q_ {one: 'o', id: [1, 2]}, 'LO'

			it 'PE', ->
				throws /cannot have multiple ids in call to 'one'/, ->
					q_ {one: 'o', id: [1, 2]}, 'PE'

			it 'OP', ->
				throws /cannot have multiple ids in call to 'one'/, ->
					q_ {one: 'o', id: [1, 2]}, 'OP', 0


	# ##############################################################################
	# ##############################################################################
	describe 'many', ->
		describe 'query', ->
			describe 'LO', ->
				it 'miss', ->
					[l, r] = q_ {many: 'o', where: {id: {gt: 4}}}, 'LO'
					eq null, l
					eq null, r

				it 'hit', ->
					[l, r] =  q_ {many: 'o', where: {id: {lte: 4}}}, 'LO'
					deepEq {2: {id: 2, a: 'a2'}, 4: {id: 4, a: 'a4'}}, l
					eq null, r

			describe 'PE', ->
				it 'miss', ->
					[l, r] = q_ {many: 'o', where: {id: {gt: 4}}}, 'PE'
					eq null, l
					deepEq {many: 'o', where: {id: {gt: 4}}}, r

				it 'hit', ->
					[l, r] =  q_ {many: 'o', where: {id: {lte: 4}}}, 'PE'
					deepEq null, l
					deepEq {many: 'o', where: {id: {lte: 4}}}, r

			describe 'OP', ->
				describe 'cached', ->
					it 'miss', ->
						[l, r] = q_ {many: 'o', where: {id: {gt: 4}}}, 'OP', 0
						eq null, l
						eq null, r

					it 'hit', ->
						[l, r] = q_ {many: 'o', where: {id: {lte: 4}}}, 'OP', 8
						deepEq {2: {id: 2, a: 'a2'}, 4: {id: 4, a: 'a4'}}, l
						eq null, r

				describe 'non-cached', ->
					it 'miss', ->
						[l, r] = q_ {many: 'o', where: {id: {lt: 2}}}, 'OP', 1
						eq null, l
						deepEq {many: 'o', where: {id: {lt: 2}}}, r

					it 'hit', ->
						[l, r] = q_ {many: 'o', where: {id: {gte: 2}}}, 'OP', 0
						eq null, l
						deepEq {many: 'o', where: {id: {gte: 2}}}, r

			describe 'VO', ->
				describe 'cached', ->
					it 'miss', ->
						[l, r] = q_ {many: 'o', where: {id: {gt: 4}}}, 'VO', 9
						eq null, l
						eq null, r

					it 'hit', ->
						[l, r] = q_ {many: 'o', where: {id: {lte: 4}}}, 'VO', 0
						deepEq {2: {id: 2, a: 'a2'}, 4: {id: 4, a: 'a4'}}, l
						eq null, r

				describe 'non-cached', ->
					it 'miss', ->
						[l, r] = q_ {many: 'o', where: {id: {lt: 2}}}, 'VO', 0
						eq null, l
						deepEq {many: 'o', where: {id: {lt: 2}}}, r

					it 'hit', ->
						[l, r] = q_ {many: 'o', where: {id: {gte: 2}}}, 'VO', 2
						deepEq {2: {id: 2, a: 'a2'}, 4: {id: 4, a: 'a4'}}, l
						deepEq {many: 'o', where: {id: {gte: 2}}}, r

			describe 'sort', ->
				describe 'LO', ->
					it 'miss', ->
						[l, r] = q_ {many: 'o', where: {id: {gt: 4}}, sort: [{a: 'desc'}]}, 'LO'
						eq null, l
						eq null, r

					it 'hit', ->
						[l, r] = q_ {many: 'o', where: {id: {lte: 4}}, sort: [{a: 'desc'}]}, 'LO'
						deepEq [{id: 4, a: 'a4'}, {id: 2, a: 'a2'}], l
						eq null, r

				describe 'PE', ->
					it 'hit', ->
						[l, r] = q_ {many: 'o', where: {id: {lte: 4}}, sort: [{a: 'desc'}]}, 'PE'
						eq null, l
						deepEq {many: 'o', where: {id: {lte: 4}}, sort: [{a: 'desc'}]}, r

				# skiping OP, should be same

	# 	# 'one id' to simple => skip testing

		describe 'multiple ids', ->
			describe 'LO', ->
				it 'miss', ->
					[l, r] = q_ {many: 'o', id: [1, 3]}, 'LO'
					eq null, l
					eq null, r

				it 'hit', ->
					[l, r] = q_ {many: 'o', id: [2, 4]}, 'LO'
					deepEq {2: {id: 2, a: 'a2'}, 4: {id: 4, a: 'a4'}}, l
					eq null, r

			# skiping PE since it's too easy

			describe 'OP', ->
				it 'cached = hit (in this case)', ->
					[l, r] = q_ {many: 'o', id: [2, 4]}, 'OP', 10
					deepEq {2: {id: 2, a: 'a2'}, 4: {id: 4, a: 'a4'}}, l
					eq null, r

				it 'non-cached = miss (in this case)', ->
					[l, r] = q_ {many: 'o', id: [1, 3]}, 'OP', 0
					eq null, l
					deepEq {many: 'o', id: [1, 3]}, r

			describe 'VO, note VO behaves like OP in the id query case', ->
				it 'cached = hit (in this case)', ->
					[l, r] = q_ {many: 'o', id: [2, 4]}, 'VO', 0
					deepEq {2: {id: 2, a: 'a2'}, 4: {id: 4, a: 'a4'}}, l
					eq null, r

				it 'non-cached = miss (in this case)', ->
					[l, r] = q_ {many: 'o', id: [1, 3]}, 'VO', 8
					eq null, l
					deepEq {many: 'o', id: [1, 3]}, r

	describe 'toReadQuery', ->
		describe 'one', ->
			it 'one id', ->
				res = utils.toReadQuery {one: 'o', id: 2}
				deepEq {get: 'o', where: {id: 2}}, res

			it 'many ids', ->
				res = utils.toReadQuery {one: 'o', id: [1, 2]}
				deepEq {get: 'o', where: {id: {in: [1, 2]}}}

			
	# describe 'new', ->
	# 	describe 'edge cases', ->
	# 		it 'not local', ->
	# 			throws /new queries need local strategy/, ->
	# 				q_ {new: 'o', values: {a: 'a5'}}, 'PE'
	# 	it.only 'simple case', ->
	# 			[l, r] = q_ {new: 'o', values: {a: 'a5'}}, 'LO'
	# 			deepEq {new: 'o', values: {a: 'a5'}}, l
	# 			eq null, r

