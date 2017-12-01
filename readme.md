# The SQL Sync utility

## Configuring a table sync

To set up a sync, follow this checklist:

**Sync Config Checklist**

1. Enter the sync configuration into dbo.SyncConfig. See the description below, 'Configuring a Sync'
2. Create the target table, if it doesn't already exist. Note: the target table must have a primary key defined
3. If you want to have the sync create surrogate keys, create a surrogate key table (if it doesn't already exist)
4. If you want to do a reconciliation, create the reconciliation table (if it doesn't already exist)


#### Configuring a Sync

To configure a table synchronization, you must enter a row into the dbo.SyncConfig table. Each row in that table has all the metadata/configuration to synchronize 1 table (source-to-target).

There is a [raw configuration template](/docs/config-template.sql) as well as an [example configuration](/docs/sample-config-type-1.sql).


#### Table Requirements for a Sync

* The target table must have a primary key defined
* The source table must have a datetime column that identifies when new rows are added to it.
* A surrogate key must be defined
* The target table, surrogate key table, source table, and (optional) reconcile table must be created manually.


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


### Debug Mode

Since this code is heavy on dynamic SQL, it's helpful to see what queries are being run. If you pass in @Debug=1 to the procedures, they will return the queries to run, and will not execute them.


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



## FAQ

**Does column order matter?**

No! Never!

**What indexes are useful?**

That's a question with a long answer. Check out the [Type-1](/docs/type-1.md) and [Type-2](/docs/type-2.md) pages.

**Can the same source table be used for multiple targets?**

Yes. However, you should make sure that the 

**Can multiple sources be used to load the same target table?**

No

**Can a source table be loaded if it has no update-date column?**

Not at the moment. This could be added if it's needed.

**Can you use a view as the source?**

Sure.

**Can you use a view as the target**

Sure. 

**What types of processing are supported?**

Currently there is support only for Type-1 (non-deleting). 

The groundwork has been laid for type-2 tables but it isn't supported yet. That's the [DiffTable](/DiffTable.sql) stored procedure. 

**Can a table be sync'd if it doesn't have a primary key?**

Sort of. You don't need a primary key index defined in the source, but you must configure one in the SyncConfig table.

**What happens if there are duplicates?**

If there are duplicate entries for a single PK and source update-date value, then the sync will fail for that table.


## Future Improvements

### What if there are duplicates for a single PK and source update-date?

This is likely to require custom 'tiebreaking' logic per table. The approach that comes to mind is 'custom logic injection', done in one of two ways:

1. Specify the tiebreaking SQL (to be run in a ROWNUMBER()'s ORDER BY clause) in the SyncConfig table
2. Specify a custom stored procedure name in the SyncConfig table. Between the load and diff steps, the SyncTable procedure would call the custom procedure (perhaps using some standard parameters), which would be responsible for de-duping the load table.


### What if the source table is updating while the sync is running?

This is a concern right now. There are 3 possible approaches that have been discussed so far:

**Semaphores**

Pros: Easy to write, proven design approach

Cons: Failure-mode unlocks are tricky to build correctly, can lead to unnecessary waits

**Locking**

Another way to avoid concurrent queries (reads and writes) on the same table is to use locking. If the process loading the source table used the tablock and batchsize=0 hints, it would block on the entire table during its load. 

Conversely, if SyncTable used a (serializable) hint, it would block on the table as well.

Pros: built into SQL, small number of code changes

Cons: not extensible / easily customized. 


**Object Naming**

The final way of handling concurrent processing is using table renames, either via sp_rename or ALTER TABLE...SWITCH. In either approach, concurrent processes would block until the rename is done (which takes milliseconds), and then they could proceed uninterrupted. 


### Reconciliation

TBD
