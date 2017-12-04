# Getting Started




#### Table Requirements for a Sync

* The target table must have a primary key defined
* The source table must have a datetime column that identifies when new rows are added to it.
* A surrogate key must be defined
* The target table, surrogate key table, source table, and (optional) reconcile table must be created manually.


## Setting Up Your First Sync

There are 6 steps to set up your first sync.

1. Fix custom code
2. Pick names for things.
3. Create the source and target tables
4. Create a sync configuration
5. Run it in debug mode
6. Run it for real


## Setting Up Your First Diff

There are 6 steps to set up your first diff.

1. Fix custom code
2. Pick names for things.
3. Create the source and target tables
4. Create a diff configuration
5. Run it in debug mode
6. Run it for real






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
