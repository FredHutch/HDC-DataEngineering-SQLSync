# Tests

There are several unit tests to ensure proper functionality of the SQL Sync utility. 

First, run the test setup script, [UnitTest_00_TestSetup.sql](/tests/UnitTest_00_TestSetup.sql). This creates several tables used by unit tests, and a utility stored procedure to help set up tests.

Second, run any test you like. They should each return one or more result sets showing 'Success' or 'Failure'. If the test throws an error, it's a failure.