if exists (select * from dbo.SyncConfig where TargetTable not like 'UnitTest%')
begin
   select *
   into dbo.SyncConfig_backup
   from dbo.SyncConfig
end

if object_id('dbo.SyncConfig') is not NULL
   and object_id('dbo.SyncConfig_backup') is not null
BEGIN
    exec ('drop table dbo.SyncConfig');
END
go

create table dbo.SyncConfig
(TargetDatabase varchar(128) not null
,TargetSchema varchar(128) not null
,TargetTable varchar(128) not null

,SourceDatabase varchar(128) not null
,SourceSchema varchar(128) not null
,SourceTable varchar(128) not null
,SourceUpdateDateColumn varchar(128) null
,PrimaryKeyColumns xml not null --what is the primary key for this table?

-- categorization columns
,ProcessMode varchar(32) not null -- only support type-2 and type-1
,TableGroup varchar(128) null

-- Surrogate Key (SK) information. The name of the SK mapping table, and the column name used for SKs
,SurrogateTable varchar(128) not null
,SurrogateKeyColumn varchar(128) not null

-- type-2 columns
,TargetBeginDateColumn varchar(128) null --if specified, this is for a type-2 table
,TargetEndDateColumn varchar(128) null --if specified, this is for a type-2 table

-- type-1 columns
,TargetActiveColumn varchar(128) null

-- type-1 and type-2 columns
,TargetCreateDateColumn varchar(128) null
,TargetUpdateDateColumn varchar(128) null

-- enable/disable bits
,IsActive bit not null  --whether to process this table
,IsSourceCleanupAfterRun bit not null --  if enabled, the sync procedure will clean up the source data after a successful run
,IsSourceToLoadCopy bit not null --if true, will copy source data to a 'load' table. Useful for de-duplication performance
,IsDiff bit not null -- if true, will do a 'diff' to identify which rows have changed. Useful to minimize updates to the target table

-- reconcile, and state information
,ReconcileTable varchar(128) null --if specified, use this for reconciling the data
,SourceMaxLoadDate datetime null -- the max(SourceUpdateDateColumn) for the last successful run
,constraint ProcessModeColumnCheck check ((TargetActiveColumn is not null and TargetUpdateDateColumn is not null 
                                             and SourceUpdateDateColumn is not null and TargetCreateDateColumn is not null) 
                                      or  (TargetBeginDateColumn is not null and TargetEndDateColumn is not null
                                             and TargetUpdateDateColumn is not null and TargetCreateDateColumn is not null))
,constraint SyncConfigProcessModeCheck check (ProcessMode in ('Type-2','Type-1'))
,constraint SyncConfigSurrogateKeyCheck check ((SurrogateKeyColumn is not null and SurrogateTable is not null)
                                          or (SurrogateKeyColumn is null and SurrogateTable is null ))
,constraint SyncConfigPK primary key clustered (TargetTable,TargetSchema,TargetDatabase)
)
go

insert into dbo.SyncConfig
(   [TargetDatabase]
   ,[TargetSchema]
   ,[TargetTable]
   ,[SourceDatabase]
   ,[SourceSchema]
   ,[SourceTable]
   ,[SourceUpdateDateColumn]
   ,[IsActive]
   ,[ProcessMode]
   ,[PrimaryKeyColumns]
   ,[TableGroup]
   ,[SurrogateTable]
   ,[SurrogateKeyColumn]
   ,[TargetBeginDateColumn]
   ,[TargetEndDateColumn]
   ,[TargetActiveColumn]
   ,[TargetCreateDateColumn]
   ,[TargetUpdateDateColumn]
   ,[IsSourceCleanupAfterRun]
   ,[ReconcileTable]
   ,[SourceMaxLoadDate]
)
select
   [TargetDatabase]
   ,[TargetSchema]
   ,[TargetTable]
   ,[SourceDatabase]
   ,[SourceSchema]
   ,[SourceTable]
   ,[SourceUpdateDateColumn]
   ,[IsActive]
   ,[ProcessMode]
   ,[PrimaryKeyColumns]
   ,[TableGroup]
   ,[SurrogateTable]
   ,[SurrogateKeyColumn]
   ,[TargetBeginDateColumn]
   ,[TargetEndDateColumn]
   ,[TargetActiveColumn]
   ,[TargetCreateDateColumn]
   ,[TargetUpdateDateColumn]
   ,[IsSourceCleanupAfterRun]
   ,[ReconcileTable]
   ,[SourceMaxLoadDate]
from dbo.SyncConfig_backup
go

if exists 
(
   select TargetDatabase
      ,TargetSchema
      ,TargetTable
   from dbo.SyncConfig
   where TargetTable not like 'UnitTest%'

   except

   select TargetDatabase
      ,TargetSchema
      ,TargetTable
   from dbo.SyncConfig_backup
)
begin
   raiserror('WARNING! Not all tables may have been copied back into SyncConfig',16,1)
end
go


