# Concepts

# Concepts

### Table Groups

Table groups are organizing/grouping values, so you can easily process several times in sequence with one command. 

For example, let's say you configured the Order, OrderStatus, and Address table syncs to be in a table group named 'Orders'. You could sync all three tables over using the following command:

```
exec dbo.ProcessTables @TableGroup='Orders'
```


### Surrogate Keys

The sync utility has the ability to create surrogate keys (SKs), which are integer values mapped to a primary key value. These SKs are stored in a surrogate key table, populated by the [UpdateSurrogateKeys](/UpdateSurrogateKeys.sql) sproc.

This is defined via the 'SurrogateTable' and 'SurrogateKeyColumn' values in the SyncConfig table. These are required attributes. 


### 'Windowed' Loading

The source table can have rows added to it while the sync is happening. To support this loads are done by filtering the rows based on the SourceUpdateDateColumn.

For example, let's say we're loading from TableName, and it has a source update-date column value named SourceUpdateDateColumn. The last time the table was loaded was 2017-11-01. The current date is 2017-12-01. The select query will be something like:

```
SELECT * FROM Src.TableName WHERE SourceUpdateDateColumn >= 2017-11-01 AND SourceUpdateDateColumn <= 2017-12-01 .
```

This way, if a load comes along and adds rows, they won't be seen by the current load.


### Cleanup

'Cleanup' is the process of deleting data from the source table after a load is complete.

For example, let's say we're loading from Src.TableName, and it has a source update-date column value named SourceUpdateDateColumn. The current load finished, and had a max(source update-date) of 2017-12-01. The cleanup query will be:

```
DELETE FROM Src.TableName WHERE SourceUpdateDateColumn <= 2017-12-01 
```



### Parameters Common to Many of the Stored Procedures

@Debug - Since this code is heavy on dynamic SQL, it's helpful to see what queries are being run. If you pass in @Debug=1 to these procedures, they will return the queries to run, and will not execute them.


### System Columns

There are some columns that are required and used by the sync utility, on both the source and target tables. 

**Source Columns**

'SourceUpdateDateColumn' is a datetime column that identifies when a source row has been added/changed. It should have datetime values that are always increasing, even if they are in the past.

**Type-1 Columns**

'TargetUpdateDateColumn' refers to a datetime column on the target table of a sync that is updated whenever a row is added/updated. 
'TargetActiveColumn' refers to a bit column on the target a table of a sync that is says whether a row is present in the source or not. 1 means the row is present in the source, 0 means it was deleted from the source.

**Type-2 Columns**

'TargetBeginDateColumn' refers to a datetime column on the target table of a sync that shows when the row was first detected in the source data.
'TargetEndDateColumn' refers to a datetime column on the target table of a sync that shows the last time a row was detected in the source data. For currently active rows, the value is '9999-12-31', i.e. ('the future'). 
'TargetUpdateDateColumn' refers to a datetime column on the target table of a sync that is updated whenever a row is added/updated. 



### Reconciliation

TBD

