if object_id('dbo.SyncConfig') is not NULL
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
,SourceUpdateDateColumn varchar(128) not null

,IsActive bit not null --whether to process this table
,ProcessMode varchar(32) not null -- only support type-2 and type-1
,PrimaryKeyColumns xml not null --what is the primary key for this table?
,TableGroup varchar(128) null

-- SK information. The name of the SK mapping table, and the column name used for SKs
,SurrogateTable varchar(128) not null
,SurrogateKeyColumn varchar(128) not null

-- type-2 information
,TargetBeginDateColumn varchar(128) null --if specified, this is for a type-2 table
,TargetEndDateColumn varchar(128) null --if specified, this is for a type-2 table

-- type-1 information
,TargetActiveColumn varchar(128) null
,TargetCreateDateColumn varchar(128) null
,TargetUpdateDateColumn varchar(128) null

-- cleanup, reconcile, and state information
,CleanUpSourceAfterRun bit not null --  if enabled, the sync procedure will clean up the source data after a successful run
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


