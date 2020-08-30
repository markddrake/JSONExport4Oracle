"use strict" 

const YadamuParser = require('../../common/yadamuParser.js')

class MongoParser extends YadamuParser {
  
  constructor(tableInfo,yadamuLogger) {
    super(tableInfo,yadamuLogger); 
	
    this.transformations = tableInfo.DATA_TYPE_ARRAY.map((dataType) => {
	  switch (dataType) {
		 case 'binData':
		   return (row,idx)  => {
             row[idx] = row[idx].buffer;
		   }
         case 'objectId':
		   return (row,idx)  => {
             row[idx] = Buffer.from(row[idx].toHexString(),'hex')
		   }
        default:
		  return null;
      }
    })
	
	// Use a dummy rowTransformation function if there are no transformations required.
	
    this.rowTransformation = this.transformations.every((currentValue) => { currentValue === null}) ? (row) => {} : (row) => {
      this.transformations.forEach((transformation,idx) => {
        if ((transformation !== null) && (row[idx] !== null)) {
          transformation(row,idx)
        }
      }) 
    }
		
  }
  
  async _transform (data,encoding,callback) {
	this.rowCount++;
    if (this.tableInfo.ID_TRANSFORMATION === 'STRIP') {
      delete data._id
    }
	
    switch (this.tableInfo.READ_TRANSFORMATION) {
	  case 'DOCUMENT_TO_ARRAY' :
	    data = Object.values(data)
        this.rowTransformation(data)
		break;
      default:
    }
    this.push({data:data})
    callback();
  }
}

module.exports = MongoParser