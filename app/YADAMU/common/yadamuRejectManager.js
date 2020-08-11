"use strict"   

const fs = require('fs');
const path = require('path');

const DBWriter = require('./dbWriter.js');
const YadamuLogger = require('./yadamuLogger.js');
const FileDBI = require('../file/node/fileDBI.js');

class YadamuRejectManager {
  
  constructor(yadamu,usage,filename) {

    this.yadamu = yadamu
    this.usage = usage
    this.filename = filename;
	this.dbi = new FileDBI(yadamu,filename)
	this.dbi.initialize()
	// Use a NULL Logger in production.
    // this.logger =  YadamuLogger.consoleLogger();
	this.logger = YadamuLogger.nulLogger();
    this.writer = new DBWriter(this.dbi,this.logger);
	this.recordCount = 0
	this.tableWriter = undefined
  }
  
  setSystemInformation(systemInformation) {
	this.systemInformation = systemInformation
  }
  
  setMetadata(metadata) {
	this.metadata = metadata
  }
  
  async rejectRow(tableName,data) {

	if (this.recordCount === 0) {
      const errorFolderPath = path.dirname(this.filename);
      fs.mkdirSync(errorFolderPath, { recursive: true });
      await this.writer.initialize()  
      this.writer.write({systemInformation: this.systemInformation})
	  this.writer.write({metadata: this.metadata})
	  await this.writer.ddlComplete;
	  this.tableWriter = this.dbi.getOutputStream(tableName,this.writer.ddlComplete)
      this.tableWriter.checkColumnCount = () => {}
	  this.tableWriter.setTableInfo(tableName);
	}
	else {
	  if (tableName !== this.tableWriter.tableName) {
    	await new Promise((resolve,reject) => {
		  this.tableWriter.end(null,null,() => {
            resolve()
          })
        })		
		this.tableWriter = this.dbi.getOutputStream(tableName)
		this.tableWriter.checkColumnCount = () => {}
        this.tableWriter.setTableInfo(tableName);
		// Disable Column Count Checks
	  }
	}
    await new Promise((resolve,reject) => {this.tableWriter.write({data: data},null,() => {resolve()})})
    this.recordCount++;
  }
  
  async close() {
	if (this.recordCount > 0) {
      await new Promise((resolve,reject) => {
		this.tableWriter.end(null,null,() => {
          resolve()
        })
      })		
	  await new Promise((resolve,reject) => {
	    this.writer.end(null,null,() => {
          resolve()
        })
      })		
	  await this.dbi.finalize()    
      await this.logger.close()
      this.yadamu.LOGGER.info([this.usage],`${this.recordCount} records written to "${this.filename}"`)
	}
  }
}
    
module.exports = YadamuRejectManager;


