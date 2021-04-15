<cfscript>
describe( "writeToCsv", function(){

	beforeEach( function(){
		sleep( 5 );// allow time for file operations to complete
		var data = QueryNew( "column1,column2", "VarChar,VarChar", [ [ "a","b" ], [ "c","d" ] ] );
		variables.workbooks = [ s.newXls(), s.newXlsx() ];
		workbooks.Each( function( wb ){
			s.addRows( wb, data );
		});
	});

	it( "writes a csv file from a spreadsheet object", function(){
		var expectedCsv = 'a,b#crlf#c,d';
		workbooks.Each( function( wb ){
			s.writeToCsv( wb, tempCsvPath, true );
			expect( FileRead( tempCsvPath ) ).toBe( expectedCsv );
		});
	});

	it( "allows an alternative delimiter", function(){
		var expectedCsv = 'a|b#crlf#c|d';
		workbooks.Each( function( wb ){
			s.writeToCsv( wb, tempCsvPath, true, "|" );
			expect( FileRead( tempCsvPath ) ).toBe( expectedCsv );
		});
	});

	describe( "writeToCsv throws an exception if", function(){

		it( "the path exists and overwrite is false", function(){
			FileWrite( tempCsvPath, "" );
			workbooks.Each( function( wb ){
				expect( function(){
					s.writeToCsv( wb, tempCsvPath, false );
				}).toThrow( regex="File already exists" );
			});
		});

	});	

	afterEach( function(){
		if( FileExists( tempCsvPath ) ) FileDelete( tempCsvPath );
	});

});	
</cfscript>