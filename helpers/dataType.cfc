component extends="base" accessors="true"{

	public string function detectValueDataType( required value ){
		// Numeric must precede date test
		// Golden default rule: treat numbers with leading zeros as STRINGS: not numbers (lucee) or dates (ACF);
		// Do not detect booleans: leave as strings
		if( REFind( "^0[\d]+", arguments.value ) )
			return "string";
		if( IsNumeric( arguments.value ) )
			return "numeric";
		if( library()._IsDate( arguments.value ) )
			return "date";
		if( Trim( arguments.value ).IsEmpty() )
			return "blank";
		return "string";
	}

	public string function getCellValueTypeFromQueryColumnType( required string type, required cellValue ){
		switch( arguments.type ){
			case "DOUBLE":
				return "numeric";
			case "DATE": case "TIME": case "BOOLEAN":
				return arguments.type.LCase();
		}
		if( IsSimpleValue( arguments.cellValue ) && !Len( arguments.cellValue ) )//NB don't use member function: won't work if numeric
			return "blank";
		return "string";
	}

	public boolean function isString( required input ){
		return IsInstanceOf( arguments.input, "java.lang.String" );
	}

	/* Data type overriding */

	public void function checkDataTypesArgument( required struct args ){
		if( arguments.args.KeyExists( "datatypes" ) && datatypeOverridesContainInvalidTypes( arguments.args.datatypes ) )
			Throw( type=library().getExceptionType(), message="Invalid datatype(s)", detail="One or more of the datatypes specified is invalid. Valid types are #validCellOverrideTypes().ToList( ', ' )# and the columns they apply to should be passed as an array" );
	}

	public void function convertDataTypeOverrideColumnNamesToNumbers( required struct datatypeOverrides, required array columnNames ){
		for( var type in arguments.datatypeOverrides ){
			var columnRefs = arguments.datatypeOverrides[ type ];
			//NB: DO NOT SCOPE datatypeOverrides and columnNames vars inside closure!!
			columnRefs.Each( function( value, index ){
				if( !IsNumeric( value ) ){
					var columnNumber = ArrayFindNoCase( columnNames, value );//ACF won't accept member function on this array for some reason
					columnRefs.DeleteAt( index );
					columnRefs.Append( columnNumber );
					datatypeOverrides[ type ] = columnRefs;
				}
			});
		}
	}

	public void function setCellDataTypeWithOverride(
		required workbook
		,required cell
		,required cellValue
		,required numeric cellIndex
		,required struct datatypeOverrides
		,string defaultType
	){
		var cellTypeOverride = getCellTypeOverride( arguments.cellIndex, arguments.datatypeOverrides );
		if( cellTypeOverride.Len() ){
			if( cellTypeOverride == "auto" ){
				getCellHelper().setCellValueAsType( arguments.workbook, arguments.cell, arguments.cellValue );
				return;
			}
			if( valueCanBeSetAsType( arguments.cellValue, cellTypeOverride ) ){
				getCellHelper().setCellValueAsType( arguments.workbook, arguments.cell, arguments.cellValue, cellTypeOverride );
				return;
			}
		}
		// if no override, use an already set default (i.e. query column type)
		if( arguments.KeyExists( "defaultType" ) ){
			getCellHelper().setCellValueAsType( arguments.workbook, arguments.cell, arguments.cellValue, arguments.defaultType );
			return;
		}
		// default autodetect
		getCellHelper().setCellValueAsType( arguments.workbook, arguments.cell, arguments.cellValue );
	}

	/* Private */

	private boolean function datatypeOverridesContainInvalidTypes( required struct datatypeOverrides ){
		for( var type in arguments.datatypeOverrides ){
			if( !isValidCellOverrideType( type ) || !IsArray( arguments.datatypeOverrides[ type ] ) )
				return true;
		}
		return false;
	}

	private string function getCellTypeOverride( required numeric cellIndex, required struct datatypeOverrides ){
		var columnNumber = ( arguments.cellIndex +1 );
		for( var type in arguments.datatypeOverrides ){
			if( arguments.datatypeOverrides[ type ].Find( columnNumber ) )
				return type;
		}
		return "";
	}

	private boolean function isValidCellOverrideType( required string type ){
		return validCellOverrideTypes().FindNoCase( arguments.type );
	}

	private array function validCellOverrideTypes(){
		return [ "numeric", "string", "date", "time", "boolean", "auto" ];
	}

	private boolean function valueCanBeSetAsType( required value, required type ){
		//when overriding types, check values can be cast as numbers or dates
		switch( arguments.type ){
			case "numeric":
				return IsNumeric( arguments.value );
			case "date": case "time":
				return library()._IsDate( arguments.value );
			case "boolean":
				return IsBoolean( arguments.value );
		}
		return true;
	}

}