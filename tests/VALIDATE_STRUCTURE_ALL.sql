set echo on 
spool logs/VALIDATE_STRUCTURE_ALL.log
--
def SCHEMA = HR
--
@@VALIDATE_STRUCTURE &SCHEMA &SCHEMA.1
--
def SCHEMA = SH
--
@@VALIDATE_STRUCTURE &SCHEMA &SCHEMA.1
--
def SCHEMA = OE
--
@@VALIDATE_STRUCTURE &SCHEMA &SCHEMA.1
--
def SCHEMA = PM
--
@@VALIDATE_STRUCTURE &SCHEMA &SCHEMA.1
--
def SCHEMA = IX
--
@@VALIDATE_STRUCTURE &SCHEMA &SCHEMA.1
--
def SCHEMA = BI
--
@@VALIDATE_STRUCTURE &SCHEMA &SCHEMA.1
--
quit
