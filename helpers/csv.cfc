component extends="base"{

	boolean function delimiterIsTab( required string delimiter ){
		return ArrayFindNoCase( [ "#Chr( 9 )#", "\t", "tab" ], arguments.delimiter );//CF2016 doesn't support [].FindNoCase( needle )
	}

	any function getFormat( required string delimiter ){
		if( arguments.delimiter.Len() )
			return getCsvFormatForDelimiter( arguments.delimiter );
		return library().createJavaObject( "org.apache.commons.csv.CSVFormat" )[ JavaCast( "string", "RFC4180" ) ].withIgnoreSurroundingSpaces();
	}

	array function getColumnNames( required boolean firstRowIsHeader, required array data, required numeric maxColumnCount ){
		var result = [];
		if( arguments.firstRowIsHeader )
			var headerRow = arguments.data[ 1 ];
		for( var i=1; i <= arguments.maxColumnCount; i++ ){
			if( arguments.firstRowIsHeader && !IsNull( headerRow[ i ] ) && headerRow[ i ].Len() ){
				result.Append( headerRow[ i ] );
				continue;
			}
			result.Append( "column#i#" );
		}
		return result;
	}

	array function queryToArrayForCsv( required query query, required boolean includeHeaderRow ){
		var result = [];
		var columns = getQueryHelper()._QueryColumnArray( arguments.query );
		if( arguments.includeHeaderRow )
			result.Append( columns );
		for( var row IN arguments.query ){
			var rowValues = [];
			for( var column IN columns ){
				var cellValue = row[ column ];
				if( getDateHelper().isDateObject( cellValue ) )
					cellValue = DateTimeFormat( cellValue, library().getDateFormats().DATETIME );
				if( IsValid( "integer", cellValue ) )
					cellValue = JavaCast( "string", cellValue );// prevent CSV writer converting 1 to 1.0
				rowValues.Append( cellValue );
			}
			result.Append( rowValues );
		}
		return result;
	}

	struct function parseFromString( required string csvString, required boolean trim, required any format ){
		if( arguments.trim )
			arguments.csvString = arguments.csvString.Trim();
		try{
			var parser = library().createJavaObject( "org.apache.commons.csv.CSVParser" ).parse( csvString, format );
			return dataFromParser( parser );
		}
		finally{
			if( local.KeyExists( "parser" ) )
				parser.close();
		}
	}

	struct function parseFromFile( required string path, required any format ){
		getFileHelper()
			.throwErrorIFfileNotExists( arguments.path )
			.throwErrorIFnotCsvOrTextFile( arguments.path );
		return parseFromString( FileRead( arguments.path ), false, arguments.format );
	}

	/* Private */

	private any function getCsvFormatForDelimiter( required string delimiter ){
		if( delimiterIsTab( arguments.delimiter ) )
			return library().createJavaObject( "org.apache.commons.csv.CSVFormat" )[ JavaCast( "string", "TDF" ) ];
		return library().createJavaObject( "org.apache.commons.csv.CSVFormat" )[ JavaCast( "string", "RFC4180" ) ]
			.withDelimiter( JavaCast( "char", arguments.delimiter ) )
			.withIgnoreSurroundingSpaces();//stop spaces between fields causing problems with embedded lines
	}

	private struct function dataFromParser( required any parser ){
		var result = {
			data: []
			,maxColumnCount: 0
		};
		var recordIterator = arguments.parser.iterator();
		while( recordIterator.hasNext() ){
			var row = [];
			var columnNumber = 0;
			var values = recordIterator.next().toList();
			for( var value in values ){
				columnNumber++;
				result.maxColumnCount = Max( result.maxColumnCount, columnNumber );
				row.Append( value );
			}
			result.data.Append( row );
		}
		return result;
	}

}