component extends="base" accessors="true"{

	public boolean function columnNamesContainAnInvalidVariableName( required array names ){
		for( var name IN arguments.names ){
			if( !IsValid( "variableName", name ) )
				return true;
		}
		return false;
	}

	public query function deleteHiddenColumnsFromQuery( required sheet, required query result ){
		var startIndex = ( arguments.sheet.totalColumnCount -1 );
		for( var colIndex = startIndex; colIndex >= 0; colIndex-- ){
			if( !arguments.sheet.object.isColumnHidden( JavaCast( "int", colIndex ) ) )
				continue;
			var columnNumber = ( colIndex +1 );
			arguments.result = library()._QueryDeleteColumn( arguments.result, arguments.sheet.columnNames[ columnNumber ] );
			arguments.sheet.totalColumnCount--;
			arguments.sheet.columnNames.DeleteAt( columnNumber );
		}
		return arguments.result;
	}

	public array function getQueryColumnTypeToCellTypeMappings( required query query ){
		// extract the query columns and data types
		var metadata = GetMetaData( arguments.query );
		// assign default formats based on the data type of each column
		for( var columnMetadata in metadata )
			mapQueryColumnTypeToCellType( columnMetadata );
		return metadata;
	}

	public array function getSafeColumnNames( required array columnNames ){
		var existingNames = {};
		return arguments.columnNames.Map( function( name ){
			name = makeVariableNameSafe( name );
			return makeDuplicateNameUnique( name, existingNames );
		});
	}

	public string function queryToHtml( required query query, numeric headerRow, boolean includeHeaderRow=false ){
		var result = getStringHelper().newJavaStringBuilder();
		var columns = library()._QueryColumnArray( arguments.query );
		var generateHeaderRow = ( arguments.includeHeaderRow && arguments.KeyExists( "headerRow" ) && Val( arguments.headerRow ) );
		if( generateHeaderRow ){
			result.Append( "<thead>" );
			result.Append( generateHtmlRow( columns, true ) );
			result.Append( "</thead>" );
		}
		result.Append( "<tbody>" );
		for( var row in arguments.query ){
			var rowValues = [];
			for( var column in columns )
				rowValues.Append( row[ column ] );
			result.Append( generateHtmlRow( rowValues ) );
		}
		result.Append( "</tbody>" );
		return result.toString();
	}

	public string function parseQueryColumnTypesArgument(
		required any queryColumnTypes
		,required array columnNames
		,required numeric columnCount
		,required array data
	){
		if( IsStruct( arguments.queryColumnTypes ) )
			return getQueryColumnTypesListFromStruct( arguments.queryColumnTypes, arguments.columnNames );
		if( arguments.queryColumnTypes == "auto" )
			return detectQueryColumnTypesFromData( arguments.data, arguments.columnCount );
		if( ListLen( arguments.queryColumnTypes ) == 1 ){
			//single type: use as default for all
			var columnType = arguments.queryColumnTypes;
			return RepeatString( "#columnType#,", arguments.columnCount-1 ) & columnType;
		}
		return arguments.queryColumnTypes;
	}

	public void function throwErrorIFinvalidQueryColumnTypesArgument( required queryColumnTypes ){
		if( IsStruct( arguments.queryColumnTypes ) && !arguments.KeyExists( "headerRow" ) && !arguments.KeyExists( "columnNames" ) )
			Throw( type=library().getExceptionType(), message="Invalid argument 'queryColumnTypes'.", detail="When specifying 'queryColumnTypes' as a struct you must also specify the 'headerRow' or provide 'columnNames'" );
	}

	/* Private */

	private string function detectQueryColumnTypesFromData( required array data, required numeric columnCount ){
		var types = [];
		cfloop( from=1, to=arguments.columnCount, index="local.colNum" ){
			types[ colNum ] = "";
			for( var row in arguments.data ){
				if( row.IsEmpty() || ( row.Len() < colNum ) )
					continue;//next column (ACF: empty values are sometimes just missing from the array??)
				var value = row[ colNum ];
				var detectedType = getDataTypeHelper().detectValueDataType( value );
				if( detectedType == "blank" )
					continue;//next column
				var mappedType = mapDataTypeToQueryColumnType( detectedType );
				if( types[ colNum ].Len() && mappedType != types[ colNum ] ){
					//mixed types
					types[ colNum ] = "VARCHAR";
					break;//stop processing row
				}
				types[ colNum ] = mappedType;
			}
			if( types[ colNum ].IsEmpty() )
				types[ colNum ] = "VARCHAR";
		}
		return types.ToList();
	}

	private string function makeDuplicateNameUnique( required string name, required struct existingNames ){
		if( arguments.existingNames.KeyExists( arguments.name ) ){
			arguments.existingNames[ arguments.name ]++;
			return arguments.name & arguments.existingNames[ arguments.name ];
		}
		arguments.existingNames[ arguments.name ] = 1;
		return arguments.name;
	}

	private string function makeVariableNameSafe( required string variableName ){
		//NOTE: Lucee doesn't allow currency symbols (unlike ACF)
		if( IsValid( "variableName", arguments.variableName ) )
			return arguments.variableName;
		return JavaCast( "string", arguments.variableName )
			.Trim()
			.ReplaceFirst( "^\d", "_" ) // no initial digits
			.ReplaceFirst( "^##", "Number" ) // assume initial # means number
			.ReplaceAll( "\W", "_" ) // no non-alphanumeric/underscore
			.ReplaceAll( "_{2,}", "_" ); // remove doubled up underscores
	}

	private string function mapDataTypeToQueryColumnType( required string dataType ){
		switch( arguments.dataType ){
			case "numeric": return "DOUBLE";
			case "date": return "TIMESTAMP";
			default: return "VARCHAR";
		}
	}

	private string function getQueryColumnTypesListFromStruct( required struct types, required array sheetColumnNames ){
		var result = [];
		for( var columnName IN arguments.sheetColumnNames ){
			result.Append( arguments.types.KeyExists( columnName )? arguments.types[ columnName ]: "VARCHAR" );
		}
		return result.ToList();
	}

	private void function mapQueryColumnTypeToCellType( required struct columnMetadata ){
		var columnType = arguments.columnMetadata.typeName?: "";// typename is missing in ACF if not specified in the query
		switch( columnType ){
			case "DATE": case "TIMESTAMP": case "DATETIME": case "DATETIME2":
				arguments.columnMetadata.cellDataType = "DATE";
			return;
			case "TIME":
				arguments.columnMetadata.cellDataType = "TIME";
			return;
			/* Note: Excel only supports "double" for numbers. Casting very large DECIMIAL/NUMERIC or BIGINT values to double may result in a loss of precision or conversion to NEGATIVE_INFINITY / POSITIVE_INFINITY. */
			case "DECIMAL": case "BIGINT": case "NUMERIC": case "DOUBLE": case "FLOAT": case "INT": case "INTEGER": case "REAL": case "SMALLINT": case "TINYINT":
				arguments.columnMetadata.cellDataType = "DOUBLE";
			return;
			case "BOOLEAN": case "BIT":
				arguments.columnMetadata.cellDataType = "BOOLEAN";
			return;
			default: arguments.columnMetadata.cellDataType = "STRING";
		}
	}

	private string function generateHtmlRow( required array values, boolean isHeader=false ){
		var result = getStringHelper().newJavaStringBuilder();
		result.Append( "<tr>" );
		var columnTag = arguments.isHeader? "th": "td";
		for( var value in arguments.values ){
			if( getDateHelper().isDateObject( value ) || library()._IsDate( value ) )
				value = DateTimeFormat( value, library().getDateFormats().DATETIME );
			result.Append( "<#columnTag#>#value#</#columnTag#>" );
		}
		result.Append( "</tr>" );
		return result.toString();
	}

}