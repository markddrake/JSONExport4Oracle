"use strict"

const { performance } = require('perf_hooks');
const util = require('util');

const YadamuWriter = require('../../common/yadamuWriter.js');
const YadamuLibrary = require('../../common/yadamuLibrary.js');
const YadamuSpatialLibrary = require('../../common/yadamuSpatialLibrary.js');

class MySQLWriter extends YadamuWriter {

  constructor(dbi,tableName,ddlComplete,status,yadamuLogger) {
    super({objectMode: true},dbi,tableName,ddlComplete,status,yadamuLogger)
  }
   
  setTableInfo(tableName) {
    super.setTableInfo(tableName)

    this.tableInfo.columnCount = this.tableInfo.columnNames.length;
    this.tableInfo.args =  '(' + Array(this.tableInfo.columnCount).fill('?').join(',')  + ')'; 

    this.transformations = this.tableInfo.targetDataTypes.map((targetDataType,idx) => {
      const dataType = YadamuLibrary.decomposeDataType(targetDataType);
       switch (dataType.type.toLowerCase()) {
        case "json" :
          return (col,idx) => {
            return typeof col === 'object' ? JSON.stringify(col) : col
       }
          break;
          case "geometry" :
            if (this.SPATIAL_FORMAT === 'GeoJSON') {
              return (col,idx) => {
                return typeof col === 'object' ? JSON.stringify(col) : col
           }
            }
            return null;
          case "boolean":
          return (col,idx) => {
            return YadamuLibrary.booleanToInt(col)
       }
          break; 
        case "date":
        case "time":
        case "datetime":
        case "timestamp":
          return (col,idx) => {
            // If the the input is a string, assume 8601 Format with "T" seperating Date and Time and Timezone specified as 'Z' or +00:00
            // Neeed to convert it into a format that avoiods use of convert_tz and str_to_date, since using these operators prevents the use of Bulk Insert.
            // Session is already in UTC so we safely strip UTC markers from timestamps
            if (typeof col !== 'string') {
              col = col.toISOString();
            }             
            col = col.substring(0,10) + ' '  + (col.endsWith('Z') ? col.substring(11).slice(0,-1) : (col.endsWith('+00:00') ? col.substring(11).slice(0,-6) : col.substring(11)))
            // Truncate fractional values to 6 digit precision
            // ### Consider rounding, but what happens at '9999-12-31 23:59:59.999999
            return col.substring(0,26);
 		  }
 		  break;
        default :
          return null
      }
    })
  }
  
  getStatistics()  {
	const results = super.getStatistics()
    results.insertMode = this.tableInfo.insertMode
 	return results;
  }

  cacheRow(row) {
 
    // Apply transformations and cache transformed row.
	
	// Use forEach not Map as transformations are not required for most columns. 
	// Avoid uneccesary data copy at all cost as this code is executed for every column in every row.

    // this.yadamuLogger.trace([this.constructor.name,'YADAMU WRITER',this.rowCounters.cached],'cacheRow()')    
	  
	this.transformations.forEach((transformation,idx) => {
      if ((transformation !== null) && (row[idx] !== null)) {
	    row[idx] = transformation(row[idx],idx)
      }
	})

    // Rows mode requires an array of column values, rather than an array of rows.

    if (this.tableInfo.insertMode === 'Rows')  {
  	  this.batch.push(...row)
    }
    else {
      this.batch.push(row)
    }

    this.rowCounters.cached++
	return this.skipTable;
  }  

  async processWarnings(results) {

    // ### Output Records that generate warnings

    let badRow = 0;

    if (results.warningCount >  0) {
      const warnings = await this.dbi.executeSQL('show warnings');
      // warnings.forEach(async (warning,idx) => {
      for (const warning of warnings) {
        if (warning.Level === 'Warning') {
          let nextBadRow = warning.Message.split('row')
          nextBadRow = parseInt(nextBadRow[nextBadRow.length-1])
          this.yadamuLogger.warning([this.dbi.DATABASE_VENDOR,this.tableInfo.tableName,this.insertMode,nextBadRow],`${warning.Code} Details: ${warning.Message}.`)
          if (badRow !== nextBadRow) {
            const columnOffset = (nextBadRow-1) * this.tableInfo.columnNames.length
            const row = this.tableInfo.insertMode === 'Rows'  ? this.batch.slice(columnOffset,columnOffset +  this.tableInfo.columnNames.length) : this.batch[nextBadRow-1]
	  	    await this.dbi.yadamu.WARNING_MANAGER.rejectRow(this.tableInfo.tableName,row);
            badRow = nextBadRow;
          }
        }
      }
    }
  }
  
  
  recodeSpatialColumns(batch,msg) {
    this.yadamuLogger.info([this.dbi.DATABASE_VENDOR,this.tableInfo.tableName,`INSERT ROWS`,this.rowCounters.cached,this.SPATIAL_FORMAT],`${msg} Converting batch to "WKT".`);
    YadamuSpatialLibrary.recodeSpatialColumns(this.SPATIAL_FORMAT,'WKT',this.tableInfo.targetDataTypes,batch,false)
  }  
  
  reportBatchError(operation,cause) {
	if (this.tableInfo.insertMode === 'Rows') {
      super.reportBatchError(operation,cause,this.batch.slice(0,this.tableInfo.columnCount),this.batch.slice(this.batch.length-this.tableInfo.columnCount,this.batch.length))
	}
	else {
   	  super.reportBatchError(operation,cause,this.batch[0],this.batch[this.batch.length-1])
	}
  }
 
  async writeBatch() {     
  
    this.rowCounters.batchCount++;
    switch (this.tableInfo.insertMode) {
      case 'Batch':
        try {
          await this.dbi.createSavePoint();
          const results = await this.dbi.executeSQL(this.tableInfo.dml,[this.batch]);
          await this.processWarnings(results);
          this.endTime = performance.now();
          await this.dbi.releaseSavePoint();
   		  this.batch.length = 0;  
          this.rowCounters.written += this.rowCounters.cached;
   		  this.rowCounters.cached = 0;
          return this.skipTable
          break;  
        } catch (cause) {
   		  this.reportBatchError(cause,'INSERT MANY',true)
          await this.dbi.restoreSavePoint(cause);
          this.yadamuLogger.warning([this.dbi.DATABASE_VENDOR,this.tableInfo.tableName,this.insertMode],`Switching to Iterative mode.`);          
          this.tableInfo.dml = this.tableInfo.dml.slice(0,-1) + this.tableInfo.args
        }
      case 'Rows':
	    let recodedBatch = false
	    while (true) {
          try {
            await this.dbi.createSavePoint();    
            const sqlStatement = `${this.tableInfo.dml} ${new Array(this.rowCounters.cached).fill(this.tableInfo.rowConstructor).join(',')}`
            const results = await this.dbi.executeSQL(sqlStatement,this.batch);
            await this.processWarnings(results);
            this.endTime = performance.now();
            await this.dbi.releaseSavePoint();
	   	    this.batch.length = 0;  
            this.rowCounters.written += this.rowCounters.cached;
	   	    this.rowCounters.cached = 0;
            return this.skipTable
          } catch (cause) {
            await this.dbi.restoreSavePoint(cause);
			// If it's a spatial error recode the entire batch and try again.
            if (cause.spatialInsertFailed() && !recodedBatch) {
              recodedBatch = true;
			  this.recodeSpatialColumns(this.batch,cause.message)
			  this.tableInfo.rowConstructor = this.tableInfo.rowConstructor.replace(/ST_GeomFromWKB\(\?\)/g,'ST_GeomFromText(?)')
			  continue;
		    }
	   	    this.reportBatchError(cause,'INSERT ROWS')
            this.yadamuLogger.warning([this.dbi.DATABASE_VENDOR,this.tableInfo.tableName,this.insertMode],`Switching to Iterative mode.`);    
            break;			
		  }
        }
      case 'Iterative':     
	    break;
      default:
    }     
		
    // Batch or Rows failed, or iterative was selected.
	
	const sqlStatement = `${this.tableInfo.dml} ${this.tableInfo.rowConstructor}`
	for (let row = 0; row < this.rowCounters.cached; row++) {
      const  nextRow = this.tableInfo.insertMode === "Rows" ? this.batch.splice(0,this.tableInfo.columnCount) : this.batch[row]
      try {
        const results = await this.dbi.executeSQL(sqlStatement,nextRow)
        await this.processWarnings(results);
  	    this.rowCounters.written++;
      } catch (cause) { 
        await this.handleIterativeError(`INSERT ONE`,cause,row,nextRow);
		if (this.skipTable) {
	      break;
		}
      }
	}

    this.tableInfo.insertMode = 'Iterative'   
    this.endTime = performance.now();
    this.batch.length = 0;  
	this.rowCounters.cached = 0;
    return this.skipTable 
  }
}

module.exports = MySQLWriter;