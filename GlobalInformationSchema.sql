if object_id('dbo.GlobalInformationSchema') is not NULL
BEGIN
    exec ('drop view dbo.GlobalInformationSchema');
END
go

create view dbo.GlobalInformationSchema
as
SELECT *
FROM <DATABASE_NAME>.INFORMATION_SCHEMA.COLUMNS

UNION ALL

SELECT *
FROM <DATABASE NAME 2>.INFORMATION_SCHEMA.COLUMNS

go


select *
from dbo.GlobalInformationSchema