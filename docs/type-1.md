# Type 1, 'Sync'


## Performance Analysis




#### Index Recommendations

**Compression**

Use row compression for ***all*** tables and indexes. The additional CPU cost is minimal, and the reduction in I/O (both memory and disk) more than offsets for it. The result is usually a modest performance boost.

For sync processes, all else being equal, the result was a 0% runtime difference, using only 84% of the original I/O. That will scale more efficiently.

**Source table**

The ideal index is a clustered index on the source update-date column. That would allow for a clustered seek rather than a scan. Otherwise a table scan will be performed.

**Surrogate Key Table**

The ideal index is a clustered primary key index on the source primary key. See the [example configuration](/docs/sample-config-type-1.sql) for an example. This is because its main use is for clustered seeks during a join to load the target table, and the seeks are on the source primary key. 

**Target Table**

The ideal index for the target table is a clustered primary key index on the surrogate key. See the [example configuration](/docs/sample-config-type-1.sql) for an example.

Also, because index maintenance slows down writes, please create as few indexes as possible. That's a classic balancing act. 






