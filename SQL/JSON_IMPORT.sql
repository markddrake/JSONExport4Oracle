--
/*
** De-serialize serialized data
*/
create or replace package JSON_IMPORT
AUTHID CURRENT_USER
as
  C_VERSION_NUMBER constant NUMBER(4,2) := 1.0;
--  
  TYPE T_SQL_OPERATION_REC is RECORD (
    OWNER           VARCHAR2(128)
   ,TABLE_NAME      VARCHAR2(128)
   ,SQL_STATEMENT   CLOB
   ,SQLCODE         NUMBER
   ,RESULT          VARCHAR2(4000)
   ,STATUS          VARCHAR2(4000)
  );
   
  TYPE T_SQL_OPERATIONS_TAB is TABLE of T_SQL_OPERATION_REC;

  SQL_OPERATIONS_TABLE   T_SQL_OPERATIONS_TAB; 
  
  C_SUCCESS          CONSTANT VARCHAR2(32) := 'SUCCESS';
  C_FATAL_ERROR      CONSTANT VARCHAR2(32) := 'FATAL';
  C_WARNING          CONSTANT VARCHAR2(32) := 'WARNING';
  C_IGNOREABLE       CONSTANT VARCHAR2(32) := 'IGNORE';

  procedure DATA_ONLY_MODE(P_DATA_ONLY_MODE BOOLEAN);
  procedure DDL_ONLY_MODE(P_DDL_ONLY_MODE BOOLEAN);

  function IMPORT_VERSION return NUMBER deterministic;
  
  function GENERATE_DESERIALIZATION_FUNTIONS(P_OWNER VARCHAR2,P_TABLE_NAME VARCHAR2,P_DESERIALIZATION_FUNCTIONS CLOB) return CLOB;
  procedure IMPORT_JSON(P_JSON_DUMP_FILE IN OUT NOCOPY CLOB,P_TARGET_SCHEMA VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA'));
  function IMPORT_JSON(P_JSON_DUMP_FILE IN OUT NOCOPY CLOB,P_TARGET_SCHEMA VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA')) return CLOB;
  function IMPORT_DML_LOG return T_SQL_OPERATIONS_TAB pipelined;
  
end;
/
show errors
--
create or replace package body JSON_IMPORT 
as
-- 
  C_NEWLINE         CONSTANT CHAR(1) := CHR(10);
  C_SINGLE_QUOTE    CONSTANT CHAR(1) := CHR(39);
  
  G_INCLUDE_DATA    BOOLEAN := TRUE;
  G_INCLUDE_DDL     BOOLEAN := FALSE;
--
function GET_MILLISECONDS(P_START_TIME TIMESTAMP, P_END_TIME TIMESTAMP) 
return NUMBER
as
  V_INTERVAL INTERVAL DAY TO SECOND := P_END_TIME - P_START_TIME;
begin
  return (((((((extract(DAY FROM V_INTERVAL) * 24)  + extract(HOUR FROM  V_INTERVAL)) * 60 ) + extract(MINUTE FROM V_INTERVAL)) * 60 ) + extract(SECOND FROM  V_INTERVAL)) * 1000);
end;
--
procedure DATA_ONLY_MODE(P_DATA_ONLY_MODE BOOLEAN)
as
begin
  if (P_DATA_ONLY_MODE) then
	G_INCLUDE_DDL := false;
  else
	G_INCLUDE_DDL := true;
  end if;
end;
--
procedure DDL_ONLY_MODE(P_DDL_ONLY_MODE BOOLEAN)
as
begin
  if (P_DDL_ONLY_MODE) then
	G_INCLUDE_DATA := false;
  else
	G_INCLUDE_DATA := true;
  end if;
end;
--
function IMPORT_VERSION return NUMBER deterministic
as
begin
  return C_VERSION_NUMBER;
end;
--
function IMPORT_DML_LOG return T_SQL_OPERATIONS_TAB pipelined
as
  cursor getRecords
  is
  select *
    from TABLE(SQL_OPERATIONS_TABLE);
begin
  for r in getRecords loop
    pipe row (r);
  end loop;
end;
--
procedure SET_CURRENT_SCHEMA(P_TARGET_SCHEMA VARCHAR2)
as
  USER_NOT_FOUND EXCEPTION ; PRAGMA EXCEPTION_INIT( USER_NOT_FOUND , -01435 );
  V_SQL_STATEMENT CONSTANT VARCHAR2(4000) := 'ALTER SESSION SET CURRENT_SCHEMA = ' || P_TARGET_SCHEMA;
begin
  if (SYS_CONTEXT('USERENV','CURRENT_SCHEMA') <> P_TARGET_SCHEMA) then
    execute immediate V_SQL_STATEMENT;
  end if;
end;
--
function GENERATE_DISABLE_CONSTRAINT_DDL(P_TARGET_SCHEMA VARCHAR2)
return T_SQL_OPERATIONS_TAB
as
  V_SQL_OPERATIONS T_SQL_OPERATIONS_TAB;
begin
  select OWNER
        ,TABLE_NAME
		,'ALTER TABLE "' || P_TARGET_SCHEMA || '"."' || TABLE_NAME  || '" DISABLE CONSTRAINT "' || CONSTRAINT_NAME || '"'
	    ,NULL
	    ,NULL
		,NULL
    bulk collect into V_SQL_OPERATIONS
    from ALL_CONSTRAINTS
   where OWNER = P_TARGET_SCHEMA 
	 AND constraint_type = 'R';   
    return V_SQL_OPERATIONS;
end;
--
function GENERATE_ENABLE_CONSTRAINT_DDL(P_TARGET_SCHEMA VARCHAR2)
return T_SQL_OPERATIONS_TAB
as
  V_SQL_OPERATIONS T_SQL_OPERATIONS_TAB;
begin
  select OWNER
        ,TABLE_NAME
		,'ALTER TABLE "' || P_TARGET_SCHEMA || '"."' || TABLE_NAME  || '" ENABLE CONSTRAINT "' || CONSTRAINT_NAME || '"' 
		,NULL
		,NULL
		,NULL
    bulk collect into V_SQL_OPERATIONS
    from ALL_CONSTRAINTS
   where OWNER = P_TARGET_SCHEMA 
	 AND constraint_type = 'R';   
    return V_SQL_OPERATIONS;
end;
--
function GENERATE_DESERIALIZATION_FUNTIONS(P_OWNER VARCHAR2,P_TABLE_NAME VARCHAR2,P_DESERIALIZATION_FUNCTIONS CLOB)
return CLOB
as
  V_DESERIALIZATION_FUNCTIONS CLOB;
  V_CURRENT_OFFSET            PLS_INTEGER := 1;
  V_NEXT_SEPERATOR            PLS_INTEGER;
  V_FUNCTION_NAME             VARCHAR2(130);
begin
  if (P_DESERIALIZATION_FUNCTIONS = '"OBJECTS"') then 
    return OBJECT_SERIALIZATION.DESERIALIZE_TABLE_TYPES(P_OWNER,P_TABLE_NAME);
  else
    DBMS_LOB.CREATETEMPORARY(V_DESERIALIZATION_FUNCTIONS,TRUE,DBMS_LOB.CALL);
    loop
      V_NEXT_SEPERATOR:= instr(P_DESERIALIZATION_FUNCTIONS,',',V_CURRENT_OFFSET); 
      exit when (V_NEXT_SEPERATOR < 1);
      V_FUNCTION_NAME  := substr(P_DESERIALIZATION_FUNCTIONS,V_NEXT_SEPERATOR - V_CURRENT_OFFSET,V_CURRENT_OFFSET);
	  if (V_FUNCTION_NAME = '"CHAR2BFILE"') then 
	    DBMS_LOB.APPEND(V_DESERIALIZATION_FUNCTIONS,TO_CLOB(OBJECT_SERIALIZATION.CODE_CHAR2BFILE));
	    CONTINUE;
	  end if;
	  if  (V_FUNCTION_NAME = '"HEXBINARY2BLOB"') then
	    DBMS_LOB.APPEND(V_DESERIALIZATION_FUNCTIONS,TO_CLOB(OBJECT_SERIALIZATION.CODE_HEXBINARY2BLOB));
	    CONTINUE;
	  end if;
      V_CURRENT_OFFSET := V_NEXT_SEPERATOR + 1;
    end loop;
  end if; 
  return V_DESERIALIZATION_FUNCTIONS;
end;
--
function GENERATE_DML_STATEMENTS(P_JSON_DUMP_FILE IN OUT NOCOPY CLOB,P_TARGET_SCHEMA VARCHAR2)
return T_SQL_OPERATIONS_TAB
as
  V_SQL_OPERATIONS T_SQL_OPERATIONS_TAB;
begin
  select OWNER
        ,TABLE_NAME
        ,'insert ' ||
		 case 
		   when DESERIALIZATION_FUNCTIONS is NULL
		     then ''
			 else ' /*+ WITH_PLSQL */ '
		 end ||
	    'into "' || TABLE_NAME ||'"(' || SELECT_LIST || ')' || C_NEWLINE ||
		 case 
		   when DESERIALIZATION_FUNCTIONS is NULL 
		   then to_clob('')
		   else 'with ' || C_NEWLiNE || JSON_IMPORT.GENERATE_DESERIALIZATION_FUNTIONS(P_TARGET_SCHEMA,TABLE_NAME,DESERIALIZATION_FUNCTIONS)
		 end ||	  
		 'select ' || INSERT_SELECT_LIST || C_NEWLINE ||
		 '  from JSON_TABLE(' || C_NEWLINE ||
	     '         :JSON,' || C_NEWLINE ||
		 '         ''$.data."' || TABLE_NAME || '"[*]''' || C_NEWLINE ||
		 '         COLUMNS(' || C_NEWLINE ||  COLUMN_PATTERNS || C_NEWLINE || '))' 
	    ,NULL
	    ,NULL
		,NULL
	bulk collect into V_SQL_OPERATIONS
    from JSON_TABLE(
	        P_JSON_DUMP_FILE,
			'$.metadata.*' 
			COLUMNS (
			  OWNER                        VARCHAR2(128) PATH '$.owner'
			, TABLE_NAME                   VARCHAR2(128) PATH '$.tableName'
            $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN   
			,  SELECT_LIST                          CLOB PATH '$.columns'
			,  INSERT_SELECT_LIST                   CLOB PATH '$.insertSelectList'
            ,  COLUMN_PATTERNS                      CLOB PATH '$.columnPatterns'
			$ELSIF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
			,  SELECT_LIST               VARCHAR2(32767) PATH '$.columns'
			,  INSERT_SELECT_LIST        VARCHAR2(32767) PATH '$.insertSelectList'
			,  COLUMN_PATTERNS           VARCHAR2(32767) PATH '$.columnPatterns'
			$ELSE
			,  SELECT_LIST                VARCHAR2(4000) PATH '$.columns'
			,  INSERT_SELECT_LIST         VARCHAR2(4000) PATH '$.insertSelectList'
			,  COLUMN_PATTERNS            VARCHAR2(4000) PATH '$.columnPatterns'
			$END
			,  DESERIALIZATION_FUNCTIONS  VARCHAR2(4000) PATH '$.deserializationFunctions'
			)
		  );
    return V_SQL_OPERATIONS;
end;
--
procedure MANAGE_MUTATING_TABLE(P_SQL_OPERATION IN OUT NOCOPY T_SQL_OPERATION_REC, P_JSON_DUMP_FILE IN OUT NOCOPY CLOB)
as
  V_SQL_STATEMENT         CLOB;
  V_SQL_FRAGMENT          VARCHAR2(1024);
  V_JSON_TABLE_OFFSET     NUMBER;

  V_START_TIME   TIMESTAMP(6);
  V_END_TIME     TIMESTAMP(6);
  V_ROW_COUNT    NUMBER;
begin
   V_SQL_FRAGMENT := 'declare' || C_NEWLINE
                  || '  cursor JSON_TO_RELATIONAL' || C_NEWLINE
				  || '  is' || C_NEWLINE
				  || '  select *' || C_NEWLINE
				  || '    from ';
			     
   DBMS_LOB.CREATETEMPORARY(V_SQL_STATEMENT,TRUE,DBMS_LOB.CALL);	
   DBMS_LOB.WRITEAPPEND(V_SQL_STATEMENT,LENGTH(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
   V_JSON_TABLE_OFFSET := DBMS_LOB.INSTR(P_SQL_OPERATION.SQL_STATEMENT,' JSON_TABLE(');
   DBMS_LOB.COPY(V_SQL_STATEMENT,P_SQL_OPERATION.SQL_STATEMENT,((DBMS_LOB.GETLENGTH(P_SQL_OPERATION.SQL_STATEMENT)-V_JSON_TABLE_OFFSET)+1),DBMS_LOB.GETLENGTH(V_SQL_STATEMENT)+1,V_JSON_TABLE_OFFSET);
 

   V_SQL_FRAGMENT := ';' || C_NEWLINE
                  || '  type T_JSON_TABLE_ROW_TAB is TABLE of JSON_TO_RELATIONAL%ROWTYPE index by PLS_INTEGER;' || C_NEWLINE
				  || '  V_ROW_BUFFER T_JSON_TABLE_ROW_TAB;' || C_NEWLINE
				  || '  V_ROW_COUNT PLS_INTEGER := 0;' || C_NEWLINE
				  || 'begin' || C_NEWLINE
				  || '  open JSON_TO_RELATIONAL;' || C_NEWLINE
				  || '  loop' || C_NEWLINE
				  || '    fetch JSON_TO_RELATIONAL' || C_NEWLINE
				  || '    bulk collect into V_ROW_BUFFER LIMIT 25000;' || C_NEWLINE
				  || '    exit when V_ROW_BUFFER.count = 0;' || C_NEWLINE
				  || '    V_ROW_COUNT := V_ROW_COUNT + V_ROW_BUFFER.count;' || C_NEWLINE
				  -- || '    forall i in 1 .. V_ROW_BUFFER.count' || C_NEWLINE
				  || '    for i in 1 .. V_ROW_BUFFER.count loop' || C_NEWLINE
				  || '      insert into "' || P_SQL_OPERATION.TABLE_NAME || '"' || C_NEWLINE
				  || '      values V_ROW_BUFFER(i);'|| C_NEWLINE
				  || '    end loop;'|| C_NEWLINE
				  || '    commit;' || C_NEWLINE
				  || '  end loop;' || C_NEWLINE
				  || '  :2 := V_ROW_COUNT;' || C_NEWLINE
                  || 'end;' || C_NEWLINE;

   DBMS_LOB.WRITEAPPEND(V_SQL_STATEMENT,LENGTH(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
   P_SQL_OPERATION.SQL_STATEMENT := V_SQL_STATEMENT;

   V_START_TIME := SYSTIMESTAMP;
   execute immediate P_SQL_OPERATION.SQL_STATEMENT using P_JSON_DUMP_FILE, out V_ROW_COUNT;
   V_END_TIME := SYSTIMESTAMP;		
   P_SQL_OPERATION.RESULT := JSON_OBJECT( 'startTine' value SYS_EXTRACT_UTC(V_START_TIME), 'endTime' value SYS_EXTRACT_UTC(V_END_TIME), 'elaspsedTimeMs' value GET_MILLISECONDS(V_START_TIME,V_END_TIME), 'recordCount'  value V_ROW_COUNT);
   P_SQL_OPERATION.STATUS := C_SUCCESS;

exception

  when OTHERS then
	P_SQL_OPERATION.RESULT := JSON_OBJECT('stack' value DBMS_UTILITY.format_error_stack);	   
    P_SQL_OPERATION.STATUS := C_FATAL_ERROR;
end;
--
procedure REFRESH_MATERIALIZED_VIEWS(P_TARGET_SCHEMA VARCHAR2)
as
  V_MVIEW_COUNT NUMBER;
  V_MVIEW_LIST  VARCHAR2(32767);
begin
  select COUNT(*), LISTAGG('"' || MVIEW_NAME || '"',',') WITHIN GROUP (ORDER BY MVIEW_NAME) 
    into V_MVIEW_COUNT, V_MVIEW_LIST
    from ALL_MVIEWS
   where OWNER = P_TARGET_SCHEMA;
   
  if (V_MVIEW_COUNT > 0) then
    DBMS_MVIEW.REFRESH(V_MVIEW_LIST);
  end if;
end;
--
procedure IMPORT_JSON(P_JSON_DUMP_FILE IN OUT NOCOPY CLOB,P_TARGET_SCHEMA VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA'))
as
  MUTATING_TABLE EXCEPTION ; PRAGMA EXCEPTION_INIT( MUTATING_TABLE , -04091 );
  
  V_CURRENT_SCHEMA           CONSTANT VARCHAR2(128) := SYS_CONTEXT('USERENV','CURRENT_SCHEMA');
  
  V_OBJECT_DESERIALIZER  CLOB;
  V_SQL_STATEMENT        CLOB;

  V_START_TIME TIMESTAMP(6);
  V_END_TIME   TIMESTAMP(6);  
begin
  SET_CURRENT_SCHEMA(P_TARGET_SCHEMA);
  
  if (G_INCLUDE_DDL) then
    JSON_EXPORT_DDL.APPLY_DDL_STATEMENTS(P_JSON_DUMP_FILE,P_TARGET_SCHEMA);
  end if;
  
  
  if (G_INCLUDE_DATA) then
    SQL_OPERATIONS_TABLE := GENERATE_DISABLE_CONSTRAINT_DDL(P_TARGET_SCHEMA) 
  	                      MULTISET UNION ALL
  	   				      GENERATE_DML_STATEMENTS(P_JSON_DUMP_FILE,P_TARGET_SCHEMA)
  						  MULTISET UNION ALL
  						  GENERATE_ENABLE_CONSTRAINT_DDL(P_TARGET_SCHEMA);
  							
    for i in 1 .. SQL_OPERATIONS_TABLE.count loop
      begin
  	  if instr(SQL_OPERATIONS_TABLE(i).SQL_STATEMENT,'ALTER') = 1 then
  	    V_START_TIME := SYSTIMESTAMP;
        execute immediate SQL_OPERATIONS_TABLE(i).SQL_STATEMENT; 
    	V_END_TIME := SYSTIMESTAMP;		
  		SQL_OPERATIONS_TABLE(i).RESULT := JSON_OBJECT( 'startTine' value SYS_EXTRACT_UTC(V_START_TIME), 'endTime' value SYS_EXTRACT_UTC(V_END_TIME), 'elaspsedTimeMs' value GET_MILLISECONDS(V_START_TIME,V_END_TIME));
  		SQL_OPERATIONS_TABLE(i).STATUS := C_SUCCESS;
        else
  		V_START_TIME := SYSTIMESTAMP;
        execute immediate SQL_OPERATIONS_TABLE(i).SQL_STATEMENT using P_JSON_DUMP_FILE;  
  	  	V_END_TIME := SYSTIMESTAMP;		
     	SQL_OPERATIONS_TABLE(i).RESULT := JSON_OBJECT( 'startTine' value SYS_EXTRACT_UTC(V_START_TIME), 'endTime' value SYS_EXTRACT_UTC(V_END_TIME), 'elaspsedTimeMs' value GET_MILLISECONDS(V_START_TIME,V_END_TIME), 'recordCount'  value TO_CHAR(SQL%ROWCOUNT));
  		commit;
  		SQL_OPERATIONS_TABLE(i).STATUS := C_SUCCESS;	
        end if;
      exception
        when MUTATING_TABLE then
          MANAGE_MUTATING_TABLE(SQL_OPERATIONS_TABLE(i),P_JSON_DUMP_FILE);		
        when others then
  	    SQL_OPERATIONS_TABLE(i).RESULT := JSON_OBJECT('stack' value DBMS_UTILITY.format_error_stack);	
  		SQL_OPERATIONS_TABLE(i).STATUS := C_FATAL_ERROR;
  	end;
    end loop;
    REFRESH_MATERIALIZED_VIEWS(P_TARGET_SCHEMA);
  end if;  
  SET_CURRENT_SCHEMA(V_CURRENT_SCHEMA);
exception
  when OTHERS then
    SET_CURRENT_SCHEMA(V_CURRENT_SCHEMA);
	RAISE;
end;
--
$IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN   
--
function GENERATE_IMPORT_LOG
return CLOB
as
   V_IMPORT_LOG CLOB;
begin
  select JSON_OBJECT(
           'ddl' value 
		     ( 
		       select JSON_ARRAYAGG(
			             JSON_OBJECT(
			               'status' value STATUS, 
				           'sql'    value SQL_STATEMENT, 
				           'result' value TREAT(RESULT as JSON)
						   returning CLOB
			             )
						 returning CLOB
			           )
	           from table(JSON_EXPORT_DDL.IMPORT_DDL_LOG)
			)
	      ,'dml' value 
		    (
			  select JSON_ARRAYAGG(
			           JSON_OBJECT(
					     'table'  value TABLE_NAME,
		                 'status' value STATUS, 
				         'sql'    value SQL_STATEMENT, 
				         'result' value TREAT(RESULT as JSON)
 					     returning CLOB
			           )
					   returning CLOB
			         )
	           from table(JSON_IMPORT.IMPORT_DML_LOG)
		   ) 
		   returning CLOB
		 )
    into V_IMPORT_LOG
    from dual;	 
  return V_IMPORT_LOG;
end;
--
$ELSE
--
function GENERATE_IMPORT_LOG
return CLOB
as
  JSON_ARRAY_OVERFLOW EXCEPTION; PRAGMA EXCEPTION_INIT (JSON_ARRAY_OVERFLOW, -40478);
  V_IMPORT_LOG CLOB;
   
  cursor ddlLogRecords
  is
  select JSON_OBJECT(
		   'status' value STATUS, 
		   'sql'    value SQL_STATEMENT, 
		   'result' value JSON_QUERY(RESULT,'$')
--  
           $IF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
           returning VARCHAR2(32767)
           $ELSE
           returning VARCHAR2(4000)
           $END  
--  
         ) LOG_RECORD
    from table(JSON_EXPORT_DDL.IMPORT_DDL_LOG);
	 
   cursor dmlLogRecords
   is
   select JSON_OBJECT(
             'table'  value TABLE_NAME,
			 'status' value STATUS, 
			 'sql'    value SQL_STATEMENT, 
  		     'result' value JSON_QUERY(RESULT,'$')
--  
           $IF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
           returning VARCHAR2(32767)
           $ELSE
           returning VARCHAR2(4000)
           $END  
--  
		  ) LOG_RECORD
	 from table(JSON_IMPORT.IMPORT_DML_LOG);
	
  V_JSON_DOCUMENT CLOB;
  V_JSON_FRAGMENT VARCHAR2(4000);
  
  V_FIRST_ITEM    BOOLEAN := TRUE;
  V_START_TABLE_DATA NUMBER;
begin
  DBMS_LOB.CREATETEMPORARY(V_JSON_DOCUMENT,TRUE,DBMS_LOB.CALL);

  V_JSON_FRAGMENT := '{"ddl":[';
  DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,length(V_JSON_FRAGMENT),V_JSON_FRAGMENT);

  V_FIRST_ITEM := TRUE;
  for i in ddlLogRecords loop
    if (not V_FIRST_ITEM) then
      DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,1,',');
    end if;
    V_FIRST_ITEM := FALSE;
    DBMS_LOB.APPEND(V_JSON_DOCUMENT,i.LOG_RECORD);
  end loop;

  V_JSON_FRAGMENT := ',"dml":[';
  DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,length(V_JSON_FRAGMENT),V_JSON_FRAGMENT);
  
  V_FIRST_ITEM := TRUE;
  for i in dmlLogRecords loop
    if (not V_FIRST_ITEM) then
      DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,1,',');
    end if;
    V_FIRST_ITEM := FALSE;
    DBMS_LOB.APPEND(V_JSON_DOCUMENT,i.LOG_RECORD);
  end loop;
  DBMS_LOB.WRITEAPPEND(V_JSON_DOCUMENT,2,']}');  
  return V_JSON_DOCUMENT;
end;
--
$END
--
function IMPORT_JSON(P_JSON_DUMP_FILE IN OUT NOCOPY CLOB,P_TARGET_SCHEMA VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA'))
return CLOB
as
begin
  IMPORT_JSON(P_JSON_DUMP_FILE, P_TARGET_SCHEMA);
  return GENERATE_IMPORT_LOG();
end;  
--
end;
/
show errors
--