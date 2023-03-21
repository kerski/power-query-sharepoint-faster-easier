let
  Source = (ListName as text) =>
    let
      _X = (ListName) =>
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
          //With the internal functions defined, get the data                                                   
          Json = _GetJsonFromSharePoint(
            "_api/lists/GetByTitle('"
              & ListName
              & "')/fields?$select=Title,Description,InternalName,SchemaXml,TypeAsString,Group,FromBaseType"
          ),
          // Convert to List                  
          Records = Json[d][results],
          #"Converted to Table" = Table.FromList(
            Records,
            Splitter.SplitByNothing(),
            null,
            null,
            ExtraValues.Error
          ),
          #"Expanded Column1" = Table.ExpandRecordColumn(
            #"Converted to Table",
            "Column1",
            {
              "Description",
              "InternalName",
              "SchemaXml",
              "Title",
              "TypeAsString",
              "Group",
              "FromBaseType"
            },
            {
              "Description",
              "InternalName",
              "SchemaXml",
              "Title",
              "TypeAsString",
              "Group",
              "FromBaseType"
            }
          ),
          #"Removed Other Columns" = Table.SelectColumns(
            #"Expanded Column1",
            {
              "Description",
              "InternalName",
              "SchemaXml",
              "Title",
              "TypeAsString",
              "Group",
              "FromBaseType"
            }
          ),
          #"Reordered Columns" = Table.ReorderColumns(
            #"Removed Other Columns",
            {"Title", "Description", "InternalName", "SchemaXml", "TypeAsString"}
          ),
          #"Parsed XML" = Table.TransformColumns(#"Reordered Columns", {{"SchemaXml", Xml.Tables}}),
          // Filter out columns that don't make part of the custom list or will be difficult to query                                                                                           
          #"Filtered Rows1" = Table.SelectRows(
            #"Parsed XML",
            each (
              (
                [FromBaseType]
                  = false or [InternalName]
                  = "Author" or [InternalName]
                  = "Created" or [InternalName]
                  = "Editor" or [InternalName]
                  = "Modified" or [InternalName]
                  = "Title" or [InternalName]
                  = "ID"
              )
            )
              and [InternalName]
              <> "_CommentFlags" and [InternalName]
              <> "_CommentCount"
          ),
          // Get Lookup column values                           
          #"Expanded SchemaXml" = Table.ExpandTableColumn(
            #"Filtered Rows1",
            "SchemaXml",
            {"Attribute:ShowField"},
            {"SchemaXml.Attribute:ShowField"}
          ),
          #"Renamed Columns" = Table.RenameColumns(
            #"Expanded SchemaXml",
            {{"SchemaXml.Attribute:ShowField", "Lookup Field"}}
          ),
          // Prepare column to represent the select parameter for an Odata query                                                                      
          #"Add Select Parameter" = Table.AddColumn(
            #"Renamed Columns",
            "Select Parameter",
            each
              if [TypeAsString] = "Lookup" or [TypeAsString] = "LookupMulti" then
                [InternalName] & "/" & [Lookup Field]
              else if [TypeAsString] = "User" then
                [InternalName] & "/EMail," & [InternalName] & "/Title"
              else
                [InternalName]
          ),
          // Prepare column to represent the expand parameter for lookup columns in an Odata query                                                                                        
          #"Added Custom" = Table.AddColumn(
            #"Add Select Parameter",
            "Expand Parameter",
            each
              if [TypeAsString]
                = "Lookup" or [TypeAsString]
                = "LookupMulti" or [TypeAsString]
                = "User"
              then
                [InternalName]
              else
                null
          ),
          Results = Table.AddColumn(#"Added Custom", "List Name", each ListName)
        in
          Results
    in
      _X(ListName),
  documentation = [
    Documentation.Name = "fnGetFields ",
    Documentation.Description = "Returns curated list of fields for the SharePoint list provided.",
    Documentation.LongDescription
      = "This function accepts a list name and will retrieve a curated list of columns from the SharePoint site.  All custom columns from the SharePoint site are retrieved, along with the ID, Created, Created By, Modified, and Modified By fields. The additional columns that appear after calling this function are used to building the SharePoint REST API query so you don’t have to.",
    Documentation.Category = " SharePoint ",
    Documentation.Source = "https://github.com/kerski/power-query-sharepoint-faster-easier",
    Documentation.Version = "1",
    Documentation.Author = " John Kerski ",
    Documentation.Examples = {
      [Description = "  ", Code = "fnGetFields( ""List Name"") ", Result = " #table "]
    }
  ],
  Custom = Value.ReplaceType(Source, Value.ReplaceMetadata(Value.Type(Source), documentation))
in
  Custom