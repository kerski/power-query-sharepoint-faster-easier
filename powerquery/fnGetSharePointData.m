let
  func = (Fields as table, optional FilterQuery as text) as table =>
    let
      _X = (Fields as table) as table =>
        let

          // Define internal function                           
          _GetJsonFromSharePoint = (url as text) as record =>
            let

              //Set Options and odata/json response                                     
              Options = [RelativePath = url, Headers = [Accept = "application/json;odata=verbose"]],
              RawData = Web.Contents(SharePoint_URL, Options),
              Json = Json.Document(RawData)
            in
              Json[d],

          // Build Query String                                                             
          QueryString =
              let
                #"Grouped Rows" = Table.Group(
                    Fields,
                    {},
                    {
                    {"$Select", each Text.Combine(List.Distinct([Select Parameter]), ","), type text},
                    // Take distinct items to remove duplicate secondary lookups
                    {"$Expand", each Text.Combine(List.Distinct([Expand Parameter]),","), type nullable text},
                    {"List Name", each List.Min([List Name]), type text}
                    }
                ),
                #"Added Custom" = Table.AddColumn(
                    #"Grouped Rows",
                    "Query String",
                    each "/_api/lists/GetByTitle('"
                    & [List Name]
                    & "')/items?$select="
                    & [#"$Select"]
                    & "&$expand="
                    & [#"$Expand"]
                    & "&$top=5000"
                ),
                QueryString = #"Added Custom"{0}[Query String],
                // Handle if Filter Query was provided                                      
                QueryString2 =
                  if FilterQuery <> null and FilterQuery <> "" then
                    QueryString & "&$filter=" & FilterQuery
                  else
                    QueryString
              in
                QueryString2,          
          // Build Base URL for API Call                                  
          BaseUrlLength = Text.Length(SharePoint_URL),  
          // Make API Calls
          InitialResults = List.Generate(
              () =>
                  let
                      response = _GetJsonFromSharePoint(QueryString),
                      nextLink = response[__next]?
                  in
                      [
                          Request = response[results],
                          NextLink = nextLink,
                          Done = false
                      ],
              each not [Done],
              each
                  let
                      nextPage = if [NextLink] <> null then _GetJsonFromSharePoint(Text.Range([NextLink], BaseUrlLength)) else null,
                      newNextLink = if nextPage <> null then nextPage[__next]? else null
                  in
                      [
                          Request = List.Buffer(nextPage[results]),
                          NextLink = newNextLink,
                          Done = nextPage = null
                      ],
              each [Request]
          ),
          CombinedResults = List.Combine(InitialResults),
          // Call Recursively if Next Link exists                                       
          Result =
              let

                //Get ls of internal and exteral names                                      
                LstInternalNames = Table.ToList(Table.SelectColumns(Table.SelectRows(Fields, each [#"Table Expand Argument - Internal Name"] <> null and [#"Table Expand Argument - Internal Name"] <> ""),{"Table Expand Argument - Internal Name"})),
                // Filter out null or empty expansion values
                LstDisplayNames = Table.ToList(Table.SelectColumns(Table.SelectRows(Fields, each [#"Table Expand Argument - Display Name"] <> null and [#"Table Expand Argument - Display Name"] <> ""),{"Table Expand Argument - Display Name"})),
                // Convert list of records to table                                   
                #"Converted to Table" = Table.FromList(
                  CombinedResults,
                  Splitter.SplitByNothing(),
                  null,
                  null,
                  ExtraValues.Error
                ),
                // Row Count Check
                RowCount = Table.RowCount(#"Converted to Table"),
                // Check Row Count, if Zero then return just Display Names as a table, else Expand based on fields supplied.                                   
                #"Expanded Column1" = if RowCount = 0 then #table(LstDisplayNames,{}) else Table.ExpandRecordColumn(
                  #"Converted to Table",
                  "Column1",
                  LstInternalNames,
                  LstDisplayNames
                )
              in
                #"Expanded Column1"
        in
         Result
    in
      _X(Fields),
  documentation = [
    Documentation.Name = " fnGetSharePointData ",
    Documentation.Description
      = " Returns data from a SharePoint list when supplied a table of Fields produced by fnGetFields function.",
    Documentation.LongDescription
      = " Returns data from a SharePoint list when supplied a table of Fields produced by fnGetFields function.  To filter the data please provide a correctly formatted OData query in the FilterQuery parameter.",
    Documentation.Category = " SharePoint ",
    Documentation.Source = "https://github.com/kerski/power-query-sharepoint-faster-easier",
    Documentation.Version = "1",
    Documentation.Author = " John Kerski ",
    Documentation.Examples = {
      [
        Description = "  ",
        Code        = " fnGetSharePointData( #table, ""Title eq 'Example'"") ",
        Result      = " {#record, #record, #record} "
      ]
    }
  ],
  Custom = Value.ReplaceType(func, Value.ReplaceMetadata(Value.Type(func), documentation))
in
  Custom
