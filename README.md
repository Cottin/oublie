# oublie

Forget about state management, just query for your objects instead!

- Do you like Redux or flux but are tired of your app consisting of 80% boilerplate code and tests for state-magement?
- Do you like the idea behind GraphQL and Relay but not really ready to completely change the way you write backends and frontends.

oublie is a simple cache where you declaritivly query for your data and pass a load strategy and a cache expiry...

What? Exampels!

Customers with 10 employees or less, optimistic load, 10 seconds expiry:

```
oublie.sub({many: 'Customer', where: {employees: {lte: 10}}}, 'OP', 10)
```

Customer with id=5, pessemistic load, 60 seconds expiry:

```
oublie.sub({one: 'Customer', id: 5}")}, 'PE', 60)
```

- What are these queries?
  They are just simple javascript objects. Oubile uses a superset of [popsiql](https://github.com/Cottin/popsiql)-queries. 

- What strategies are there?
  'LO' = local, 'PE' = pessemistic, 'OP' = optimistic, 'VO' = very optimistic

See more examples in the [playground](...)
Find out more in the docs below.


# Docs

Comming soon...
