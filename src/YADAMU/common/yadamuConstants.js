"use strict"

const YadamuDefaults = require('./yadamuDefaults.json');

class YadamuConstants {

  static get EXTERNAL_DEFAULTS() { return YadamuDefaults };

  static get YADAMU_DEFAULTS() {
    this._YADAMU_DEFAULTS = this._YADAMU_DEFAULTS || Object.freeze({
       "YADAMU_VERSION"            : '1.0'
     , "FILE"                      : "yadamu.json"
	 , "CONFIG"                    : "config.json"
     , "MODE"                      : "DATA_ONLY"
     , "ON_ERROR"                  : "ABORT"
     , "PARALLEL"                  : 0
     , "RDBMS"                     : "file"
     , "EXCEPTION_FOLDER"          : "exceptions"
     , "EXCEPTION_FILE_PREFIX"     : "exception"
     , "REJECTION_FOLDER"          : "rejections"
     , "REJECTION_FILE_PREFIX"     : "rejection"
     , "WARNING_FOLDER"            : "warnings"
     , "WARNING_FILE_PREFIX"       : "warning"
	 , "CRYPTO_ALGORITHM"          : 'aes-192-cbc'
    })
    return this._YADAMU_DEFAULTS;
  }

  static get DEFAULT_PARAMETERS() { 
    this._DEFAULT_PARAMETERS = this._DEFAULT_PARAMETERS || Object.freeze(Object.assign({},this.YADAMU_DEFAULTS,this.EXTERNAL_DEFAULTS.yadamu))
    return this._DEFAULT_PARAMETERS
  }
  
  static get ABORT_CURRENT_TABLE() {
	this._ABORT_CURRENT_TABLE  = this._ABORT_CURRENT_TABLE || Object.freeze(['ABORT','SKIP'])
	return this._ABORT_CURRENT_TABLE
  }
  
  static get ABORT_PROCESSING() {
	this._ABORT_PROCESSING  = this._ABORT_PROCESSING || Object.freeze(['ABORT',undefined])
	return this._ABORT_PROCESSING
  }

  static get CONTINUE_PROCESSING() {
	this._CONTINUE_PROCESSING = this._CONTINUE_PROCESSING || Object.freeze(['SKIP','FLUSH'])
	return this._CONTINUE_PROCESSING
  }
  
  static get PRODUCT_SHORT_NAME()     { return 'YADAMU' }
  static get PRODUCT_NAME()           { return 'Yet Another DAta Migration Utility' }
  static get COMPANY_SHORT_NAME()     { return 'YABASC' }
  static get COMPANY_NAME()           { return 'Yet Another Bay Area Software Company' }
  static YADAMU()                     { return 'CSABAYUMADAYYADA' }
  static YADAMU2()                    { return Buffer.from(this.YADAMU).toString('hex') }
  
  static get YADAMU_VERSION()         { return this.DEFAULT_PARAMETERS.YADAMU_VERSION }
  static get FILE()                   { return this.DEFAULT_PARAMETERS.FILE }
  static get CONFIG()                 { return this.DEFAULT_PARAMETERS.CONFIG }
  static get MODE()                   { return this.DEFAULT_PARAMETERS.MODE }
  static get ON_ERROR()               { return this.DEFAULT_PARAMETERS.ON_ERROR }
  static get PARALLEL()               { return this.DEFAULT_PARAMETERS.PARALLEL }
  static get RDBMS()                  { return this.DEFAULT_PARAMETERS.RDBMS }
  static get EXCEPTION_FOLDER()       { return this.DEFAULT_PARAMETERS.EXCEPTION_FOLDER }
  static get EXCEPTION_FILE_PREFIX()  { return this.DEFAULT_PARAMETERS.EXCEPTION_FILE_PREFIX }
  static get REJECTION_FOLDER()       { return this.DEFAULT_PARAMETERS.REJECTION_FOLDER }
  static get REJECTION_FILE_PREFIX()  { return this.DEFAULT_PARAMETERS.REJECTION_FILE_PREFIX }
  static get WARNING_FOLDER()         { return this.DEFAULT_PARAMETERS.WARNING_FOLDER }
  static get WARNING_FILE_PREFIX()    { return this.DEFAULT_PARAMETERS.WARNING_FILE_PREFIX }
  static get CRYPTO_ALGORITHM()       { return this.DEFAULT_PARAMETERS.CRYPTO_ALGORITHM }
  
  static get YADAMU_DRIVERS()         { return this.EXTERNAL_DEFAULTS.drivers }
  
  static get SAVE_POINT_NAME()        { return 'YADAMU_INSERT' }
  
  static get SUPPORTED_COMPRESSION() {
    this._SUPPORTED_COMPRESSION = this._SUPPORTED_COMPRESSION || Object.freeze(["GZIP","INFLATE"])
	return this._SUPPORTED_COMPRESSION
  }
  
  static get SUPPORTED_OUTPUT_FORMAT() {
    this._SUPPORTED_OUTPUT_FORMAT = this._SUPPORTED_OUTPUT_FORMAT || Object.freeze(["JSON","CSV","ARRAY"])
	return this._OUTPUT_FORMAT
  }
  
  static get MACROS() {
	this._MACROS = this._MACROS || Object.freeze({ timestamp: new Date().toISOString().replace(/:/g,'.')})
	return this._MACROS
  }

}

module.exports = YadamuConstants