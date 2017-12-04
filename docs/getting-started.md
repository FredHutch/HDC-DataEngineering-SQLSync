# Getting Started

This page will guide you through the process of getting started with the SQL Sync utility. 

First, you need to decide if you want to do a *sync* or a *diff*. A sync is a way to maintain a [Type-1 table](https://en.wikipedia.org/wiki/Slowly_changing_dimension#Type_1:_overwrite), which shows *what is currently in the source*, plus *what has been deleted*. A diff is a way to maintain a [Type-2 table](https://en.wikipedia.org/wiki/Slowly_changing_dimension#Type_2:_add_new_row), which shows *what is currently in the source, and everything that has been there before*. 

If you're not sure about what you want, please read about [Slowly Changing Dimensions](https://en.wikipedia.org/wiki/Slowly_changing_dimension).


In addition, the SQL Sync utility requires a few things to be true about your source data before you can start:

1. Your source data should have a primary key of some kind. If you have duplicate rows you can't tell apart *with no key*, then you need to fix that problem first. 
2. The source table must have a datetime column that identifies when new rows are added to it.

...Ready to continue? Great!



## Setting Up Your First Sync

There are 6 steps to set up your first sync.

1. Implement custom code
2. Pick names for things.
3. Create the source and target tables
4. Create a sync configuration
5. Run it in debug mode
6. Run it for real


## Setting Up Your First Diff

There are 6 steps to set up your first diff.

1. Implement custom code
2. Pick names for things.
3. Create the source and target tables
4. Create a diff configuration
5. Run it in debug mode
6. Run it for real



### Implement Custom Code


### Pick Names for Things


### Create the source and target tables

The target table, surrogate key table, source table, and (optional) reconcile table must be created manually.

A surrogate key must be defined

The target table must have a primary key defined

### Create a sync configuration

To set up a sync, follow this checklist:

**Sync Config Checklist**

1. Enter the sync configuration into dbo.SyncConfig. See the description below, 'Configuring a Sync'
2. Create the target table, if it doesn't already exist. Note: the target table must have a primary key defined
3. If you want to have the sync create surrogate keys, create a surrogate key table (if it doesn't already exist)
4. If you want to do a reconciliation, create the reconciliation table (if it doesn't already exist)

To configure a table synchronization, you must enter a row into the dbo.SyncConfig table. Each row in that table has all the metadata/configuration to synchronize 1 table (source-to-target).

There is a [raw configuration template](/docs/config-template.sql) as well as an [example configuration](/docs/sample-config-type-1.sql).



### Create a diff configuration


### Run in Debug Mode


### Run it for real
