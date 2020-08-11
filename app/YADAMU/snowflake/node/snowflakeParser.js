"use strict" 

const YadamuParser = require('../../common/yadamuParser.js')

class SnowflakeParser extends YadamuParser {
  
  constructor(tableInfo,yadamuLogger) {
    super(tableInfo,yadamuLogger);      

    this.transformations = tableInfo.DATA_TYPE_ARRAY.map((dataType,idx) => {
	  switch (dataType) {
		 case 'XML':
		    // Replace xsl:preserve with xml:preserve
		   return (row,idx)  => {
             row[idx] = row[idx].replace(/xsl:space/g,'xml:space')
		   }     
         case 'TIMESTAMP_NTZ':		   
		    // Replace 10000-01-01 with
		   return (row,idx)  => {
             row[idx] = row[idx].startsWith('10000-01-01') ? `9999-12-31T23:59:59.${'9'.repeat(parseInt(tableInfo.SIZE_CONSTRAINT_ARRAY[idx]))}+00:00` : row[idx]
		   }     
         default:
  		   return null;
      }
    })

    this.rowTransformation = this.transformations.every((currentValue) => { currentValue === null}) ? (row) => {} : (row) => {
      this.transformations.forEach((transformation,idx) => {
        if ((transformation !== null) && (row[idx] !== null)) {
          transformation(row,idx)
        }
      }) 
    }
  }
  
  async _transform (data,encoding,callback) {
    // Snowflake generates object based output, not array based outout. Transform object to array based on columnList
    this.counter++;
    data = Object.values(data)
	data.forEach((val,idx) => {
	   if (data[idx] === 'NULL') {
		 data[idx] = null;
	   }
       if (Buffer.isBuffer(data[idx])) {
         delete data[idx].toStringSf
         delete data[idx].getFormat
       }
	})
    this.rowTransformation(data)
	this.push({data : data})
    callback();
  }
}

module.exports = SnowflakeParser