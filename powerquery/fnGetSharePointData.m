let
  func = (Fields as table, FilterQuery as text) =>
    let
      _X = (Fields as table, Source as any, NextAPIQuery as text) =>
        let

          // Define internal function                           
          _GetJsonFromSharePoint = (url) =>
            let

              //Set Options and odata/json response                                     
              Options = [RelativePath = url, Headers = [Accept = "application/json;odata=verbose"]],
              RawData = Web.Contents(#"SharePoint URL", Options),
              Json = Json.Document(RawData)
            in
              Json,
          // Define Next Link internal function                                     
          _GetNextLink = (jsonResults) =>
            let
              #"Converted to Table" = Record.ToTable(jsonResults),
              #"Expanded Value" = Table.ExpandRecordColumn(
                #"Converted to Table",
                "Value",
                {"__next"},
                {"Value.__next"}
              ),
              #"Removed Columns" = Table.RemoveColumns(#"Expanded Value", {"Name"})
            in
              Table.FirstValue(#"Removed Columns"),
          // Convert Table to Query String is NextAPIQuery is not supplied                                                                
          QueryString =
            if NextAPIQuery <> null and NextAPIQuery <> "" then
              NextAPIQuery
            else
              let
                #"Grouped Rows" = Table.Group(
                  Fields,
                  {},
                  {
                    {"$Select", each Text.Combine([Select Parameter], ","), type text},
                    {"$Expand", each Text.Combine([Expand Parameter], ","), type nullable text},
                    {"List Name", each List.Min([List Name]), type text}
                  }
                ),
                #"Added Custom" = Table.AddColumn(
                  #"Grouped Rows",
                  "Query String",
                  each "/_api/lists/GetByTitle('"
                    & [List Name]
                    & "')/items?$select=ID,"
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
          //With the internal functions defined, get the data                                                   
          Json = _GetJsonFromSharePoint(QueryString),
          // Convert to List                  
          Records = Json[d][results],
          // Combine results                  
          NewRecords = if Source is null then Records else List.Combine({Source, Records}),
          // Get next link, if exists                           
          NextLink = _GetNextLink(Json),
          // Build Base URL for recursive call                                    
          BaseUrlLength = Text.Length(#"SharePoint URL"),
          // Call Recursively if Next Link exists                                       
          Result =
            if NextLink is null then
              let

                //Get ls of internal and exteral names                                      
                LstInternalNames = Table.ToList(Table.SelectColumns(Fields, {"InternalName"})),
                LstDisplayNames = Table.ToList(Table.SelectColumns(Fields, {"Title"})),
                // Convert list of records to table                                   
                #"Converted to Table" = Table.FromList(
                  NewRecords,
                  Splitter.SplitByNothing(),
                  null,
                  null,
                  ExtraValues.Error
                ),
                // Expand based on fields supplied.                                   
                #"Expanded Column1" = Table.ExpandRecordColumn(
                  #"Converted to Table",
                  "Column1",
                  LstInternalNames,
                  LstDisplayNames
                )
              in
                #"Expanded Column1"
            else
              @_X(Fields, NewRecords, Text.Range(NextLink, BaseUrlLength))
        in
          Result
    in
      _X(Fields, null, ""),
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