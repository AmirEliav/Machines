SET QUOTED_IDENTIFIER ON

GO

 

CREATE TABLE [dbo].[MachineScoreEvents](

       [EventId] [int] IDENTITY(1,1) NOT NULL,

       [MachineId] [uniqueidentifier] NULL,

       [Score] [decimal](5, 2) NULL,

       [MachineGroup] [smallint] NULL,

       [ReportTime] [datetime2](7) NULL,

PRIMARY KEY CLUSTERED

(

       [EventId] ASC

)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

) ON [PRIMARY]

GO

 

ALTER TABLE [dbo].[MachineScoreEvents]  WITH CHECK ADD  CONSTRAINT [CHK_MachineScoreEvents_Score] CHECK  (([Score]>=(0) AND [Score]<=(100)))

GO

 

ALTER TABLE [dbo].[MachineScoreEvents] CHECK CONSTRAINT [CHK_MachineScoreEvents_Score]

GO

 

CREATE NONCLUSTERED INDEX [IX_MachineScoreEvents__Score_MachineGroup]

ON [dbo].[MachineScoreEvents] ([Score],[MachineGroup])

INCLUDE ([EventId],[MachineId],[ReportTime])

GO

 

 

 

CREATE TABLE [dbo].[ReportTimeLastSent](

[ReportTime] [datetime2](7) not NULL)

 

GO 

 

CREATE Procedure usp_FillMachineScoreEventsTbl

as

begin

		Set NoCount on
		
       declare @i int =0

      

       if exists (select 1 from MachineScoreEvents)

              truncate table MachineScoreEvents

 

       while @i< 100

 

       begin

 

       INSERT INTO [dbo].[MachineScoreEvents]

                        ([MachineId]

                        ,[Score]

                        ,[MachineGroup]

                        ,[ReportTime])

              select top 10000 newid() as [MachineId]

                        ,convert(decimal(5,2),rand(checksum(newid()))*(100.00)) as[Score]

                        ,convert(int,rand(checksum(newid()))*100) +1 as [MachineGroup]

                        ,dateadd(MILLISECOND,RAND(checksum(newid()))*(-86400000),getdate()) as [ReportTime]

                        from sys.columns c1

                           cross join sys.columns c2;

              set @i =@i+1

       end

end

 

 

 
GO
 

 

CREATE Procedure usp_SendMachineDetailsToADX

as

begin


declare  @tmp  table

(

       [EventId] [int] NOT NULL,

       [MachineId] [uniqueidentifier] NULL,

       [Score] [decimal](5, 2) NULL,

       [MachineGroup] [smallint] NULL,

       [ReportTime] [datetime2](7) NULL

) 

 

if 1 =2

begin

select

cast( null as int)[EventId],

cast( null as uniqueidentifier) [MachineId] ,

cast( null as decimal(5, 2)) [Score],

cast( null as smallint) [MachineGroup],

cast( null as datetime2(7) ) [ReportTime]

end

 

 

 

insert into @tmp

(

[EventId],

[MachineId],

[Score],

[MachineGroup],

[ReportTime]

)

select

mse. [EventId]

,mse.[MachineId]

,mse.[Score]

,mse.[MachineGroup]

,mse.[ReportTime]

from

[dbo].[MachineScoreEvents]  mse

join

(

select m.MachineGroup,max(m.Score) as maxscore

from [dbo].[MachineScoreEvents] m

left join [dbo].[ReportTimeLastSent] t on m.ReportTime=t.ReportTime

where t.ReportTime is null

group by m.MachineGroup )  MaxMse on mse.MachineGroup=MaxMse.MachineGroup and mse.Score=MaxMse.maxscore

 

select [EventId],[MachineId],[Score],[MachineGroup],[ReportTime]

from @tmp

order by MachineGroup

 

 

insert into [dbo].[ReportTimeLastSent]

select distinct ReportTime 
from @tmp

 

end