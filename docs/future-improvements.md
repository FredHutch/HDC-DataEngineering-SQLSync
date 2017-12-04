# Future Improvements

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
