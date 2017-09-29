
-- This file is generated by the DataFiller free software.
-- This software comes without any warranty whatsoever.
-- Use at your own risk. Beware, this script may destroy your data!
-- License is GPLv3, see http://www.gnu.org/copyleft/gpl.html
-- Get latest version from http://www.coelho.net/datafiller.html

-- Data generated by: /usr/local/bin/datafiller
-- Version 2.0.1-dev (r832 on 2015-11-01)
-- For postgresql on 2017-05-03T12:34:39.879063 (UTC)
-- 
-- fill table data.user (2)
\echo # filling table data.user (2)
COPY data.user (id,email,"password") FROM STDIN (FREEZE ON);
a8399449-3f2f-47ce-b59b-bf7502658d86	alice@email.com	pass
1d2759f8-879e-45f7-82ae-b77183fff549	bob@email.com	pass
\.
-- 
-- fill table data.todo (6)
\echo # filling table data.todo (6)
COPY data.todo (id,todo,private,owner_id) FROM STDIN (FREEZE ON);
1	item_1	FALSE	a8399449-3f2f-47ce-b59b-bf7502658d86
2	item_2	TRUE	a8399449-3f2f-47ce-b59b-bf7502658d86
3	item_3	FALSE	a8399449-3f2f-47ce-b59b-bf7502658d86
4	item_4	TRUE	1d2759f8-879e-45f7-82ae-b77183fff549
5	item_5	TRUE	1d2759f8-879e-45f7-82ae-b77183fff549
6	item_6	FALSE	1d2759f8-879e-45f7-82ae-b77183fff549
\.
-- 
-- restart sequences
--ALTER SEQUENCE data.user_id_seq RESTART WITH 3;
--ALTER SEQUENCE data.todo_id_seq RESTART WITH 7;
-- 
-- analyze modified tables
ANALYZE data.user;
ANALYZE data.todo;
