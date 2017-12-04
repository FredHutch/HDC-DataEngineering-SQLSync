# Type 2, 'Diff'


## Performance Analysis




#### Index Recommendations

**Compression**

Use row compression for ***all*** tables and indexes. The additional CPU cost is minimal, and the reduction in I/O (both memory and disk) more than offsets for it. The result is usually a modest performance boost.

**Source table**

The ideal index is a clustered index on the source primary key columns. That would allow dramatically reduce the cost of a sort to create the primary key ranker in the 'Load SQL' query.

**Surrogate Key Table**

The ideal index is a clustered primary key index on the source primary key. See the [example configuration](/docs/sample-config-type-1.sql) for an example. his is because its main use is for clustered seeks during a join to load the target table, and the seeks are on the source primary key

**Target Table**

The ideal index for the target table is a clustered primary key index on the surrogate key. See the [example configuration](/docs/sample-config-type-1.sql) for an example.

Also, because index maintenance slows down writes, please create as few indexes as possible. That's a classic balancing act. 






