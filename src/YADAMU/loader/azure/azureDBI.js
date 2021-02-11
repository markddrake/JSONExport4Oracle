"use strict" 

const { BlobServiceClient } = require('@azure/storage-blob');
const path = require('path')
const Stream = require('stream')


const CloudDBI = require('../node/cloudDBI.js');
const DBIConstants = require('../../common/dbiConstants.js');
const YadamuConstants = require('../../common/yadamuConstants.js');
const YadamuLibrary = require('../../common/yadamuLibrary.js')

const AzureConstants = require('./azureConstants.js');
const AzureStorageService = require('./azureStorageService.js');

/*
**
** YADAMU Database Inteface class skeleton
**
*/

class AzureDBI extends CloudDBI {
 
  /*
  **
  ** Extends CloudDBI enabling operations on Azure Blob Containers rather than a local file system.
  ** 
  ** !!! Make sure your head is wrapped around the following statements before touching this code.
  **
  ** An Export operaton involves reading data from the Azure Blob store
  ** An Import operation involves writing data to the Azure Blob store
  **
  */

  static #_YADAMU_DBI_PARAMETERS

  static get YADAMU_DBI_PARAMETERS()  { 
	this.#_YADAMU_DBI_PARAMETERS = this.#_YADAMU_DBI_PARAMETERS || Object.freeze(Object.assign({},DBIConstants.YADAMU_DBI_PARAMETERS,AzureConstants.DBI_PARAMETERS))
	return this.#_YADAMU_DBI_PARAMETERS
  }
   
  get YADAMU_DBI_PARAMETERS() {
	return AzureDBI.YADAMU_DBI_PARAMETERS
  }

  get DATABASE_KEY()          { return AzureConstants.DATABASE_KEY};
  get DATABASE_VENDOR()       { return AzureConstants.DATABASE_VENDOR};
  get SOFTWARE_VENDOR()       { return AzureConstants.SOFTWARE_VENDOR};

  get STORAGE_ID() {
    this._CONTAINER = this._CONTAINER || (() => { 
	  const container = this.parameters.CONTAINER || this.azureOptions.container || AzureConstants.CONTAINER
	  this._CONTAINER = YadamuLibrary.macroSubstitions(container, this.yadamu.MACROS).split(path.sep).join(path.posix.sep) 
	  return this._CONTAINER
	})();
	return this._CONTAINER
  }
  
  constructor(yadamu) {
    // Export File Path is a Directory for in Load/Unload Mode
    super(yadamu)
	this.azureOptions = {}
  }   
  
  async createConnectionPool() {
	// this.yadamuLogger.trace([this.constructor.name],`BlobServiceClient.fromConnectionString()`)
    this.cloudConnection = BlobServiceClient.fromConnectionString(this.connectionProperties);
	this.cloudService = new AzureStorageService(this.cloudConnection,this.STORAGE_ID,{},this.yadamuLogger)
  }
  
  parseContents(fileContents) {
    return JSON.parse(fileContents.toString())
  }
  
  async finalize() {
	await Promise.all(Array.from(this.cloudService.writeOperations));
	super.finalize()
  }
  
  classFactory(yadamu) {
	return new AzureDBI(yadamu)
  }
    
}

module.exports = AzureDBI
 