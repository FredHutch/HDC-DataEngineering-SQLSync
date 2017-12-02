# Type 2, 'Diff'


## Performance Analysis




#### Index Recommendations

**Source table**

The ideal index is a clustered index on the source update-date column. That would allow for a clustered seek rather than a scan. Otherwise a table scan will be performed.

**Surrogate Key Table**

The ideal index is a clustered primary key index on the source primary key. See the [example configuration](/docs/sample-config-type-1.sql) for an example.

**Target Table**

The ideal index for the target table is a clustered primary key index on the source primary key. See the [example configuration](/docs/sample-config-type-1.sql) for an example.

Also, because index maintenance slows down writes, please create as few indexes as possible. That's a classic balancing act. 






