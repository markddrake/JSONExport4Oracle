set echo on
def LOGDIR = &1
spool &LOGDIR/COMPILE_ALL.log APPEND
--
def TERMOUT = &2
--
set TERMOUT &TERMOUT
--
set timing on
set feedback on
set echo on
--
ALTER SESSION SET NLS_LENGTH_SEMANTICS = 'CHAR' PLSQL_CCFLAGS = 'DEBUG:FALSE'
/
set serveroutput on
--
spool &LOGDIR/YADAMU_TEST.log
--
declare
  TABLE_NOT_FOUND EXCEPTION;
  PRAGMA EXCEPTION_INIT( TABLE_NOT_FOUND , -00942 );
begin
  execute immediate 'drop table "SCHEMA_COMPARE_RESULTS"';
exception
  when TABLE_NOT_FOUND then
    null;
  when others then  
    RAISE;
end;
/
create global temporary table SCHEMA_COMPARE_RESULTS (
  SOURCE_SCHEMA    VARCHAR2(128)
 ,TARGET_SCHEMA    VARCHAR2(128)
 ,TABLE_NAME       VARCHAR2(128)
 ,SOURCE_ROW_COUNT NUMBER
 ,TARGET_ROW_COUNT NUMBER
 ,MISSING_ROWS     NUMBER
 ,EXTRA_ROWS       NUMBER
 ,SQLERRM          CLOB
) 
ON COMMIT PRESERVE  ROWS
/
create or replace package YADAMU_TEST
AUTHID CURRENT_USER
as
  procedure COMPARE_SCHEMAS(
    P_SOURCE_SCHEMA        VARCHAR2, 
	P_TARGET_SCHEMA        VARCHAR2, 
	P_DOUBLE_PRECISION     NUMBER DEFAULT NULL, 
	P_TIMESTAMP_PRECISION  NUMBER DEFAULT 9, 
	P_ORDERED_JSON         VARCHAR2 DEFAULT 'FALSE', 
    P_XML_RULE             VARCHAR2 DEFAULT NULL,
    P_OBJECTS_RULE         VARCHAR2 DEFAULT NULL,
    P_EXCLUDE_MVIEWS       VARCHAR2 DEFAULT 'TRUE'
  );
  function JSON_COMPACT(P_JSON_INPUT CLOB) return CLOB;
  function APPLY_XML_RULE(P_XML_RULE VARCHAR2, P_XML XMLTYPE) return XMLTYPE;
end;
/
--
set TERMOUT on
--
show errors
--
set TERMOUT &TERMOUT
--
set define off
--
create or replace package body YADAMU_TEST
as
--
function JSON_COMPACT(P_JSON_INPUT CLOB)
return CLOB
as
  V_IN_STRING             BOOLEAN := FALSE;

  V_INPUT_LENGTH          INTEGER := DBMS_LOB.GETLENGTH(P_JSON_INPUT);
  V_JSON_OUTPUT           CLOB;
    
  V_OFFSET                INTEGER := 1;
  V_NEXT_QUOTE            INTEGER := DBMS_LOB.INSTR(P_JSON_INPUT,'"',1);
  V_LAST_QUOTE            INTEGER := 1;
  
  V_FRAGMENT              CLOB;
  V_FRAGMENT_LENGTH       INTEGER;
begin
  DBMS_LOB.CREATETEMPORARY(V_FRAGMENT,TRUE,DBMS_LOB.SESSION); 
  DBMS_LOB.CREATETEMPORARY(V_JSON_OUTPUT,TRUE,DBMS_LOB.SESSION); 
  while (V_NEXT_QUOTE > 0) loop
    V_FRAGMENT_LENGTH := 1 + V_NEXT_QUOTE - V_LAST_QUOTE; 
	DBMS_LOB.TRIM(V_FRAGMENT,0);
	DBMS_LOB.COPY (V_FRAGMENT,P_JSON_INPUT,V_FRAGMENT_LENGTH,1,V_LAST_QUOTE);
    if (NOT V_IN_STRING) then
      V_IN_STRING := TRUE;
	  if (DBMS_LOB.INSTR(V_FRAGMENT,' ',1) > 0) then
	    V_FRAGMENT := replace(V_FRAGMENT,' ','');
	    V_FRAGMENT_LENGTH := DBMS_LOB.GETLENGTH(V_FRAGMENT);
	  end if;
	else
	  V_IN_STRING := ((V_FRAGMENT <> '"') AND (DBMS_LOB.SUBSTR(V_FRAGMENT,2,DBMS_LOB.GETLENGTH(V_FRAGMENT)-1) = '\"'));
	end if;
      
    DBMS_LOB.APPEND(V_JSON_OUTPUT,V_FRAGMENT);
	V_OFFSET := V_OFFSET + V_FRAGMENT_LENGTH;
	V_LAST_QUOTE := V_NEXT_QUOTE+1;
    V_NEXT_QUOTE := DBMS_LOB.INSTR(P_JSON_INPUT,'"',V_LAST_QUOTE);
	
  end loop;
  
  DBMS_LOB.TRIM(V_FRAGMENT,0);
  DBMS_LOB.COPY (V_FRAGMENT,P_JSON_INPUT,DBMS_LOB.GETLENGTH(P_JSON_INPUT),1,V_LAST_QUOTE);
  V_FRAGMENT := replace(V_FRAGMENT,' ','');
  V_FRAGMENT_LENGTH := DBMS_LOB.GETLENGTH(V_FRAGMENT);
  DBMS_LOB.APPEND(V_JSON_OUTPUT,V_FRAGMENT);
  DBMS_LOB.FREETEMPORARY(V_FRAGMENT);
  return V_JSON_OUTPUT;

end;
--
function APPLY_XML_RULE(P_XML_RULE VARCHAR2,P_XML XMLTYPE)
return XMLTYPE
as
  V_ORDERED_ATTRIBUTES   VARCHAR2(4000);
  V_UNORDERED_ATTRIBUTES VARCHAR2(4000);
  V_ROOT_NAME            VARCHAR2(128);
  V_ROOT_NMSPC           VARCHAR2(4000);
  
  V_SERIALIZED_XML       CLOB;
  V_XML                  XMLType;

  V_FIRST_SPACE          PLS_INTEGER;
  V_END_OPEN_TAG         PLS_INTEGER;
  
  XSL_SNOWFLAKE_VARIANT    XMLTYPE := XMLTYPE(
'<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="node()">
		<xsl:copy>
			<xsl:for-each select="@*[name() != ''xml:space'']">
				<xsl:sort order="ascending" select="name()"/>
				<xsl:attribute name="{name(.)}" namespace="{namespace-uri(.)}">
     	          <xsl:choose>
				    <xsl:when test="number(.) = number(.)">
			          <xsl:value-of select="number(.)"/>
		            </xsl:when>
		            <xsl:otherwise>
			          <xsl:value-of select="."/>
		            </xsl:otherwise>
		          </xsl:choose>
				</xsl:attribute>
			</xsl:for-each>
			<xsl:apply-templates select="node()"/>
		</xsl:copy>
	</xsl:template>
	<xsl:template match="comment()"/>
	<xsl:template match="processing-instruction()" />
	<xsl:template match="text()">
		<xsl:choose>
			<xsl:when test="string-length(normalize-space(.))=0">
				<xsl:value-of select="."/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:call-template name="trim">
					<xsl:with-param name="str" select="."/>
				</xsl:call-template>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template name="trim">
		<xsl:param name="str"/>
	    <xsl:variable name="leftTrim" select="string-length(normalize-space(substring($str,1,1)))=0"/>
	    <xsl:variable name="rightTrim" select="string-length(normalize-space(substring($str,string-length($str),1)))=0"/>
	    <xsl:choose>
	      <xsl:when test="$leftTrim and $rightTrim">
			<xsl:call-template name="trim">
				<xsl:with-param name="str" select="substring($str,2,string-length($str)-1)"/>
			</xsl:call-template>
	      </xsl:when>
	      <xsl:when test="$leftTrim">
			<xsl:call-template name="trim">
				<xsl:with-param name="str" select="substring($str,2,string-length($str))"/>
			</xsl:call-template>
	      </xsl:when>
	      <xsl:when test="$rightTrim">
			<xsl:call-template name="trim">
				<xsl:with-param name="str" select="substring($str,1,string-length($str)-1)"/>
			</xsl:call-template>
	      </xsl:when>
     	  <xsl:when test="number($str) = number($str)">
			<xsl:value-of select="number($str)"/>
		  </xsl:when>
		  <xsl:otherwise>
			 <xsl:value-of select="$str"/>
		  </xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:stylesheet>'
);

  XSL_STRIP_XML_DECLARATION   XMLTYPE := XMLTYPE(
'<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" omit-xml-declaration="no" />
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>'
);

begin
  V_XML := P_XML;
  case 
    when (P_XML_RULE = 'SNOWFLAKE_VARIANT') then

      -- Compensate for Snowflake's XML Fidelity issues including:
	  --   alphabetical ordering of attributes, including namespace definitions
	  --   removal of XML declaration
	  --   removal of leading & trailing whitespace from text() nodes
	  --   removal of trailing zeroes in from text() nodes
      --   removal of comments
      --   removal processing instructions. 
	  --   addition of trailing zeroes in numeric fractional attribute values
	  --   addition of xml:space="preserve" attributes
	  --   strips all insignificant whitespace

	  begin
  		select ROOT_NAME, ROOT_NMSPC, ' ' || LISTAGG(ATTR_NAME || '="' || ATTR_VALUE || '"',' ')  WITHIN GROUP (ORDER BY ATTR_NAME) 
	      into V_ROOT_NAME, V_ROOT_NMSPC, V_ORDERED_ATTRIBUTES
	      from XMLTABLE(
		         '/*' passing V_XML
		  	     columns
			       ROOT_NAME   VARCHAR2(128) path 'fn:name(.)'
			      ,ROOT_NMSPC VARCHAR2(4000) path 'fn:namespace-uri(.)'
				  ,DOCUMENT          XMLTYPE path '.'
			   ) x,
		       XMLTABLE(
				 '/*/@*' passing x.DOCUMENT
		         columns 
				   ATTR_NAME  VARCHAR2(128)  path 'fn:name(.)',
				   ATTR_VALUE VARCHAR2(4000) path '.'
		       )
		 group by ROOT_NAME, ROOT_NMSPC;

        select XMLSERIALIZE(DOCUMENT V_XML as CLOB)
		  into V_SERIALIZED_XML 
		  from dual;

		V_FIRST_SPACE :=  INSTR(V_SERIALIZED_XML,' ');
		V_END_OPEN_TAG := INSTR(V_SERIALIZED_XML,'>');
		V_UNORDERED_ATTRIBUTES := SUBSTR(V_SERIALIZED_XML,V_FIRST_SPACE,V_END_OPEN_TAG-V_FIRST_SPACE);

		if (SUBSTR(V_UNORDERED_ATTRIBUTES,LENGTH(V_UNORDERED_ATTRIBUTES),1) = '/') then           
		  V_ORDERED_ATTRIBUTES := V_ORDERED_ATTRIBUTES + '/';
		end if;
		
		V_SERIALIZED_XML := REPLACE(V_SERIALIZED_XML,V_UNORDERED_ATTRIBUTES,V_ORDERED_ATTRIBUTES);
		V_XML := XMLTYPE(V_SERIALIZED_XML);
	    
      exception
		when NO_DATA_FOUND then
		  -- No attributes to normalize
		  NULL;
	    when OTHERS then 
		  DBMS_OUTPUT.PUT_LINE(V_SERIALIZED_XML);
		  RAISE;
	  end;
	  V_XML := P_XML.transform(XSL_SNOWFLAKE_VARIANT);		
	when (P_XML_RULE = 'STRIP_XML_DECLARATION') then
	  V_XML := P_XML.transform(XSL_SNOWFLAKE_VARIANT);		
	when (P_XML_RULE = 'SERIALIZE_AS_BLOB') then
	  --
	  -- Serialize the XML as a BLOB and generate a new XML from the result.
	  -- This will add an XML Declaration if the document does not alreay have one. 
	  -- It may also change the value of any existing XML declaration in the source document
	  -- Used in 11.2 in place of STRIP_XML_DECLARATION to avoid ORA-03113
	  --
	  select XMLTYPE(XMLSERIALIZE(CONTENT P_XML AS BLOB ENCODING 'UTF-8'),NLS_CHARSET_ID('AL32UTF8'))
	    into V_XML 
		from dual;
	  --
  end case;		  
  return V_XML;
end;
--  
procedure COMPARE_SCHEMAS(
  P_SOURCE_SCHEMA       VARCHAR2, 
  P_TARGET_SCHEMA       VARCHAR2, 
  P_DOUBLE_PRECISION    NUMBER DEFAULT NULL, 
  P_TIMESTAMP_PRECISION NUMBER DEFAULT 9, 
  P_ORDERED_JSON        VARCHAR2 DEFAULT 'FALSE', 
  P_XML_RULE            VARCHAR2 DEFAULT NULL,
  P_OBJECTS_RULE        VARCHAR2 DEFAULT NULL,
  P_EXCLUDE_MVIEWS      VARCHAR2 DEFAULT 'TRUE'
)
as
  TABLE_NOT_FOUND EXCEPTION;
  PRAGMA EXCEPTION_INIT( TABLE_NOT_FOUND , -00942 );
    
  V_HASH_METHOD      NUMBER := 0;
  V_TIMESTAMP_LENGTH NUMBER := 20 + P_TIMESTAMP_PRECISION;
  V_ORDERING_CLAUSE   VARCHAR2(16) := '';

  
  
  cursor getTableList
  is
  select aat.TABLE_NAME
        ,LISTAGG(
           case 
             when ((V_HASH_METHOD < 0) and atc.DATA_TYPE in ('SDO_GEOMETRY','XMLTYPE','ANYDATA','BLOB','CLOB','NCLOB','JSON')) then
    		   NULL
             when ((atc.DATA_TYPE like 'TIMESTAMP(%)') and (DATA_SCALE > P_TIMESTAMP_PRECISION)) then
               'substr(to_char(t."' || atc.COLUMN_NAME || '",''YYYY-MM-DD"T"HH24:MI:SS.FF9''),1,' || V_TIMESTAMP_LENGTH || ') "' || atc.COLUMN_NAME || '"'
			 when ((atc.DATA_TYPE in ('BINARY_DOUBLE')) and (P_DOUBLE_PRECISION is not NULL)) then
			   '(t."' || atc.COLUMN_NAME || '",' || P_DOUBLE_PRECISION || ') "' || atc.COLUMN_NAME || '"'
             when atc.DATA_TYPE = 'BFILE' then
	           'case when t."' || atc.COLUMN_NAME || '" is NULL then NULL else OBJECT_SERIALIZATION.SERIALIZE_BFILE(t."' || atc.COLUMN_NAME || '") end "' || atc.COLUMN_NAME || '"'
		     when (atc.DATA_TYPE = 'SDO_GEOMETRY') then
			   /*
			   **
			   ** Avoid performance issue with SDO_GEOMETRY operators used in 12.2 and earlier. Skip generation of spatial value.
			   **
			   */
			   --
			   $IF DBMS_DB_VERSION.VER_LE_11_2 $THEN
			   --
			   'NULL "' || atc.COLUMN_NAME || '"'
			   --
			   $ELSIF DBMS_DB_VERSION.VER_LE_12_2 $THEN
			   --
			   'NULL "' || atc.COLUMN_NAME || '"'
			   --
			   $ELSE
			   --
			   'case '||
   			     'when t."' ||  atc.COLUMN_NAME || '" is NULL then NULL ' ||
                 'when t."' ||  atc.COLUMN_NAME || '".ST_isValid() = 1 then dbms_crypto.HASH(t."' ||  atc.COLUMN_NAME || '".get_WKB(),' || V_HASH_METHOD || ') ' ||
                 'when SDO_GEOM.VALIDATE_GEOMETRY_WITH_CONTEXT(t."' ||  atc.COLUMN_NAME || '",0.00001) in (''NULL'',''13032'') then NULL ' ||
                 'else dbms_crypto.HASH(t."' || atc.COLUMN_NAME || '".get_WKB(),' || V_HASH_METHOD || ')  ' ||
               'end "' || atc.COLUMN_NAME || '"'
			   --
			   $END
			   --
             when atc.DATA_TYPE = 'XMLTYPE' then
    		   -- 'case when t."' || atc.COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(XMLSERIALIZE(CONTENT t."' || atc.COLUMN_NAME || '" as  BLOB ENCODING ''UTF-8''),' || V_HASH_METHOD || ') end "' || atc.COLUMN_NAME || '"'
			   'case when t."' || atc.COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(XMLSERIALIZE(CONTENT '  ||
			   case 
			     when (P_XML_RULE is NULL) then
				   't."' || atc.COLUMN_NAME || '"'
				 else 
				   'YADAMU_TEST.APPLY_XML_RULE(''' || P_XML_RULE || ''',t."' || atc.COLUMN_NAME || '")'
			   end
			   || '  AS CLOB),' || V_HASH_METHOD || ') end "' || atc.COLUMN_NAME || '"'
			 
			 /*
			 **
			 ** Order JSON when required. Ordering is typically required when the JSON has been stored in an engine that uses a binary format which does not preserve the order of the keys inside an object
             ** Examples where ordering is necessary include Oracle20C Binary JSON or Snowflake VARIANT data type.
			 **
			 ** Oracle11g and 12.1 do not support JSON processing so ordering is not possbile Cannot differentiate between a BLOB, CHAR or VARCHAR column containing text and one containing JSON
			 ** Oracle12.2 supports JSON ordering via an undocumented extension to JSON_QUERY. JSON_QUERY is restricted to returning VARCHAR2(4000) or VARCHAR2(32767). Ordering documents > 8K causes intermittant ORA-3113 errors to be raised.
			 ** Oracle18c supports JSON ordering via an undocumented extension to JSON_QUERY. Ordering documents causes intermittant ORA-3113 errors to be raised.
			 ** Oracle19c supports JSON Ordering using JSON_SERIALIZE
			 **
			 */
		     
			 $IF YADAMU_FEATURE_DETECTION.JSON_PARSING_SUPPORTED $THEN     
			 --
			 -- 11.x  and 12.1 do not satisfy JSON_PARSING_SUPPORTED. 
			 --
		     when atc.DATA_TYPE = 'JSON' then
              -- Oracle20c and Later
	           'case when t."' || atc.COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(JSON_SERIALIZE(t."' || atc.COLUMN_NAME || '" returning BLOB ' || V_ORDERING_CLAUSE || '),' || V_HASH_METHOD || ') end "' || atc.COLUMN_NAME || '"'
  		     when jc.FORMAT is not NULL then
			  -- JSON column of type VARCHAR, CLOB or BLOB
    	       $IF DBMS_DB_VERSION.VER_LE_12_2 $THEN
      	      --
		      -- Ordering is not supported in 12.2 x as ORDERING may cause 3113 if any document in the table exceeds 8K
			  -- Cannot reliably order docments < 8K as JSON formatting may change the size of the source and target documents.
			  -- Use JSON_COMPACT to remove insignifcant whitespace and compare results.
			  --
               'case ' || 
               '  when t."' || atc.COLUMN_NAME || '" is NULL then ' || 
               '    NULL ' || 
               '  else ' || 
			   case 
				 when atc.DATA_TYPE = 'BLOB' then
		         '    dbms_crypto.HASH(YADAMU_TEST.JSON_COMPACT(TO_CLOB(t."' || atc.COLUMN_NAME || '")),' || V_HASH_METHOD || ') end /* JSON 12C BLOB NO ORDERING */ "'
			     else 
				 '    dbms_crypto.HASH(YADAMU_TEST.JSON_COMPACT(t."' || atc.COLUMN_NAME || '"),' || V_HASH_METHOD || ') end /* JSON 12C CLOB/VARCHAR2 NO ORDERING */ "'
		       end  || atc.COLUMN_NAME || '"'
               $ELSIF DBMS_DB_VERSION.VER_LE_18 $THEN
              --				   
			  -- Order and convert to BLOB using JSON_QUERY. Ordering disabled in Oracle 18c
              -- 
			   'case when t."' || atc.COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(JSON_QUERY(t."' || atc.COLUMN_NAME || '", ''$'' returning BLOB),' || V_HASH_METHOD || ') end /* JSON 18C NO ORDERING */ "' || atc.COLUMN_NAME || '"'
			  --
			   $ELSE /* 19c */
			  -- Order and convert to BLOB using JSON_SERIALIZE
	           'case when t."' || atc.COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(JSON_SERIALIZE(t."' || atc.COLUMN_NAME || '" returning BLOB  ' || V_ORDERING_CLAUSE || '),' || V_HASH_METHOD || ') end /* JSON 19C ORDERED */"' || atc.COLUMN_NAME || '"'
			  --
			   $END
			 --
			 $END
			 --
		     when atc.DATA_TYPE = 'ANYDATA' then
		       'case when t."' || atc.COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(XMLSERIALIZE(CONTENT XMLTYPE(t."' || atc.COLUMN_NAME || '") AS BLOB encoding ''UTF-8''),' || V_HASH_METHOD || ') end "' || atc.COLUMN_NAME || '"'
		     when atc.DATA_TYPE in ('BLOB')  then
   		       'case when t."' || atc.COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(t."' || atc.COLUMN_NAME || '",' || V_HASH_METHOD || ') end /* BLOB  */ "' || atc.COLUMN_NAME || '"'
			 when atc.DATA_TYPE in ('CLOB','NCLOB')  then
		        'case when t."' || atc.COLUMN_NAME || '" is NULL then NULL when DBMS_LOB.GETLENGTH("' || atc.COLUMN_NAME || '") = 0 then NULL else dbms_crypto.HASH(t."' || atc.COLUMN_NAME || '",' || V_HASH_METHOD || ') end /* CLOB */ "' || atc.COLUMN_NAME || '"'
		     when ((TYPECODE  = 'OBJECT') and (atc.DATA_TYPE not in ('XMLTYPE','ANYDATA','RAW'))) then
			   case 
			     when (P_OBJECTS_RULE = 'OMIT_OBJECTS') then
				   'NULL "' || atc.COLUMN_NAME || '"'	
				 else 
			       'case when t."' || atc.COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(XMLSERIALIZE(CONTENT XMLTYPE(t."' || atc.COLUMN_NAME || '")  AS CLOB),' || V_HASH_METHOD || ') end "' || atc.COLUMN_NAME || '"'			    
			   end
		     when ((TYPECODE  = 'COLLECTION') and (atc.DATA_TYPE not in ('XMLTYPE','ANYDATA','RAW'))) then
			   case
  		         when (P_OBJECTS_RULE = 'OMIT_OBJECTS') then
				   'NULL "' || atc.COLUMN_NAME || '"'	
				 else 
  			       'case when t."' || atc.COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(XMLSERIALIZE(CONTENT XMLTYPE(ANYDATA.convertCollection(t."' || atc.COLUMN_NAME || '"))  AS CLOB),' || V_HASH_METHOD || ') end "' || atc.COLUMN_NAME || '"'			    
			   end 
             else
	     	   't."' || atc.COLUMN_NAME || '"'
		   end,
		',') 
		 WITHIN GROUP (ORDER BY INTERNAL_COLUMN_ID, atc.COLUMN_NAME) COLUMN_LIST
        ,LISTAGG(
           case 
             when ((V_HASH_METHOD < 0) and atc.DATA_TYPE in ('"MDSYS"."SDO_GEOMETRY"','XMLTYPE','BLOB','CLOB','NCLOB','JSON')) then
    		   '"' || atc.COLUMN_NAME || '"'
             else 
               NULL
		   end,
		',') 
		 WITHIN GROUP (ORDER BY INTERNAL_COLUMN_ID, atc.COLUMN_NAME) LOB_COLUMN_LIST
        $IF YADAMU_FEATURE_DETECTION.JSON_PARSING_SUPPORTED $THEN     
        ,MAX(case when jc.FORMAT is not NULL then 1 else 0 end)  "HAS_JSON_COLUMNS"
        $END
  from ALL_ALL_TABLES aat
       inner join ALL_TAB_COLS atc
	           on atc.OWNER = aat.OWNER
	          and atc.TABLE_NAME = aat.TABLE_NAME
       left outer join ALL_TYPES at
	                on at.TYPE_NAME = atc.DATA_TYPE
                   and at.OWNER = atc.DATA_TYPE_OWNER   
       left outer join ALL_MVIEWS amv
		            on amv.OWNER = aat.OWNER
		           and amv.MVIEW_NAME = aat.TABLE_NAME
       $IF DBMS_DB_VERSION.VER_LE_11_2 $THEN
       left outer join ALL_EXTERNAL_TABLES axt
	                on axt.OWNER = aat.OWNER
	               and axt.TABLE_NAME = aat.TABLE_NAME
       $END
       $IF YADAMU_FEATURE_DETECTION.JSON_PARSING_SUPPORTED $THEN               
       left outer join ALL_JSON_COLUMNS jc
                 on jc.COLUMN_NAME = atc.COLUMN_NAME
                AND jc.TABLE_NAME = atc.TABLE_NAME
                and jc.OWNER = atc.OWNER
       $END 
 where aat.STATUS = 'VALID'
   and aat.DROPPED = 'NO'
   and aat.TEMPORARY = 'N'
$IF DBMS_DB_VERSION.VER_LE_11_2 $THEN
   and axt.TYPE_NAME is NULL
$ELSE
   and aat.EXTERNAL = 'NO'
$END
   and aat.NESTED = 'NO'
   and aat.SECONDARY = 'N'
   and (aat.IOT_TYPE is NULL or aat.IOT_TYPE = 'IOT')
   and (
	    ((aat.TABLE_TYPE is NULL) and ((atc.HIDDEN_COLUMN = 'NO') and ((atc.VIRTUAL_COLUMN = 'NO') or ((atc.VIRTUAL_COLUMN = 'YES') and (atc.DATA_TYPE = 'XMLTYPE')))))
        or
	    ((aat.TABLE_TYPE is not NULL) and (atc.COLUMN_NAME in ('SYS_NC_OID$','SYS_NC_ROWINFO$')))
	    or
		((aat.TABLE_TYPE = 'XMLTYPE') and (atc.COLUMN_NAME in ('ACLOID', 'OWNERID')))
       )
	and aat.OWNER = P_SOURCE_SCHEMA
    --  and ((TYPECODE is NULL) or (at.TYPE_NAME = 'XMLTYPE') or (at.TYPE_NAME = 'SDO_GEOMETRY'))
	and case
         when P_EXCLUDE_MVIEWS = 'FALSE' then 1
	       when P_EXCLUDE_MVIEWS = 'TRUE' and amv.MVIEW_NAME is NULL then 1
		   else 0
  		 end = 1 
  group by aat.TABLE_NAME;
  
  V_SQL_STATEMENT     CLOB;
  P_SOURCE_COUNT      NUMBER := 0;
  P_TARGET_COUNT      NUMBER := 0;
  V_SQLERRM           CLOB;
  
  V_STYLESHEET        XMLTYPE;
  V_WITH_CLAUSE       VARCHAR2(256);
  V_XSL_TABLE_CLAUSE  VARCHAR(256);
  
begin

  if (P_ORDERED_JSON = 'TRUE') then 
    V_ORDERING_CLAUSE := 'ORDERED';
  end if;

 -- Use EXECUTE IMMEDIATE to get the HASH Method Code so we do not get a compile error if accesss has not been granted to DBMS_CRYPTO

  begin
   --
    $IF YADAMU_FEATURE_DETECTION.JSON_PARSING_SUPPORTED $THEN
   --
    execute immediate 'begin :1 := DBMS_CRYPTO.HASH_SH256; end;'  using OUT V_HASH_METHOD;
   --
    $ELSE
   --
    execute immediate 'begin :1 := DBMS_CRYPTO.HASH_MD5; end;'  using OUT  V_HASH_METHOD;
   --
    $END
   --
  exception
    when OTHERS then
      V_HASH_METHOD := -1;
  end;

  begin
    execute immediate 'truncate table "SCHEMA_COMPARE_RESULTS"';
  exception
    when TABLE_NOT_FOUND then
      null;
    when others then  
      RAISE;
  end;

   
  for t in getTableList loop

    if ((V_HASH_METHOD < 0) and (t.LOB_COLUMN_LIST is not NULL)) then
      V_SQLERRM := '''Warning : Package DBMS_CRYPTO is required to compare the following columns: ' || t.LOB_COLUMN_LIST || '.''';
    else
     -- Not a TYPO: NULL is a string in this case.
      V_SQLERRM := 'NULL';
    end if;
    
    V_SQL_STATEMENT := 'insert into SCHEMA_COMPARE_RESULTS ' || YADAMU_UTILITIES.C_NEWLINE
                    || 'with ' 
                    || 'TABLE_COMPARE_RESULTS as (' || YADAMU_UTILITIES.C_NEWLINE
                    || 'select ''' || P_SOURCE_SCHEMA  || ''' "SOURCE_SCHEMA" ' || YADAMU_UTILITIES.C_NEWLINE
                    || '      ,''' || P_TARGET_SCHEMA  || ''' "TARGET_SCHEMA" ' || YADAMU_UTILITIES.C_NEWLINE
                    || '      ,'''  || t.TABLE_NAME || '''  "TABLE_NAME" ' || YADAMU_UTILITIES.C_NEWLINE
                    || '      ,(select count(*) from "' || P_SOURCE_SCHEMA  || '"."' || t.TABLE_NAME || '") "SOURCE_ROWS" '  || YADAMU_UTILITIES.C_NEWLINE
                    || '      ,(select count(*) from "' || P_TARGET_SCHEMA  || '"."' || t.TABLE_NAME || '") "TARGET_ROWS" '  || YADAMU_UTILITIES.C_NEWLINE
                    || '      ,(select count(*) from (select ' || t.COLUMN_LIST || ' from "' || P_SOURCE_SCHEMA  || '"."' || t.TABLE_NAME || '" t' || V_XSL_TABLE_CLAUSE || ' MINUS select ' || t.COLUMN_LIST || ' from  "' || P_TARGET_SCHEMA  || '"."' || t.TABLE_NAME || '" t' || V_XSL_TABLE_CLAUSE || ')) "MISSING_ROWS"'  || YADAMU_UTILITIES.C_NEWLINE
                    || '      ,(select count(*) from (select ' || t.COLUMN_LIST || ' from "' || P_TARGET_SCHEMA  || '"."' || t.TABLE_NAME || '" t' || V_XSL_TABLE_CLAUSE || ' MINUS select ' || t.COLUMN_LIST || ' from  "' || P_SOURCE_SCHEMA  || '"."' || t.TABLE_NAME || '" t' || V_XSL_TABLE_CLAUSE || ')) "EXTRA_ROWS"'  || YADAMU_UTILITIES.C_NEWLINE
					|| '  from dual' || YADAMU_UTILITIES.C_NEWLINE
					|| ')' || YADAMU_UTILITIES.C_NEWLINE
                    || 'select SOURCE_SCHEMA, TARGET_SCHEMA, TABLE_NAME, SOURCE_ROWS, TARGET_ROWS, MISSING_ROWS, EXTRA_ROWS, NULL' || YADAMU_UTILITIES.C_NEWLINE                    
                    || '  from TABLE_COMPARE_RESULTS';

	begin
      EXECUTE IMMEDIATE V_SQL_STATEMENT;
    exception 
      when OTHERS then
        V_SQLERRM := SQLERRM || ' SQL: ' || V_SQL_STATEMENT;					  
        begin 
          V_SQL_STATEMENT := 'select count(*) from "' || P_SOURCE_SCHEMA  || '"."' || t.TABLE_NAME || '"';
		  execute immediate V_SQL_STATEMENT into P_SOURCE_COUNT;
        exception
          when others then
            V_SQLERRM := SQLERRM;					  
            P_SOURCE_COUNT := -1;
        end;
        begin 
          V_SQL_STATEMENT := 'select count(*) from "' || P_TARGET_SCHEMA  || '"."' || t.TABLE_NAME || '"';
          execute immediate V_SQL_STATEMENT into P_TARGET_COUNT;
        exception
          when others then
            V_SQLERRM := SQLERRM;            
            $IF DBMS_DB_VERSION.VER_LE_11_2 $THEN
           -- Check if the ORA-xxxxx message appears twice in SQLERRM.
            if (INSTR(SUBSTR(V_SQLERRM,11),SUBSTR(V_SQLERRM,1,10)) > 0) then
              V_SQLERRM := SUBSTR(V_SQLERRM,1,INSTR(SUBSTR(V_SQLERRM,11),SUBSTR(V_SQLERRM,1,10))+8);         
            end if;
            $END
            P_TARGET_COUNT := -1;
        end;
        V_SQL_STATEMENT := 'insert into SCHEMA_COMPARE_RESULTS values (:1,:2,:3,:4,:5,:6,:7,:8)';
        execute immediate V_SQL_STATEMENT using P_SOURCE_SCHEMA, P_TARGET_SCHEMA, t.TABLE_NAME, P_SOURCE_COUNT, P_TARGET_COUNT, -1, -1, V_SQLERRM;
    end;
  end loop;
exception
  when OTHERS then 
	RAISE;
end;
--
end;
/
set define on
--
set TERMOUT on
--
show errors
--
set TERMOUT &TERMOUT
--
create or replace public synonym YADAMU_TEST for YADAMU_TEST
/
spool &LOGDIR/install/COMPILE_ALL.log APPEND
--
desc YADAMU_TEST
--
spool off
--
exit
