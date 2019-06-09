page 99999 "Uplift Generator"
{
    PageType = NavigatePage;
    SourceTable = AllObj;
    SourceTableView = WHERE ("Object Type" = filter (Table),
                             "App Package ID" = filter ('{00000000-0000-0000-0000-000000000000}'),
                             "Object ID" = filter ('50000..2000000000'));
    Editable = true;
    UsageCategory = Administration;
    ApplicationArea = All;
    layout
    {
        area(Content)
        {
            field(Ext; ExtensionGUID)
            {
                Caption = 'Extension ID GUID';
                ApplicationArea = All;
            }
            field(FieldsFilter; FieldNumberFilter)
            {
                Caption = 'Std. Obj. Field number filter';
                ApplicationArea = All;
            }
            repeater(Rep)
            {
                Editable = false;
                field("Object ID"; "Object ID") { ApplicationArea = All; }
                field("Object Name"; "Object Name") { ApplicationArea = All; }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Generate)
            {
                Caption = 'Generate Uplifting Script';
                ApplicationArea = All;
                InFooterBar = true;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                PromotedOnly = true;
                trigger OnAction()
                begin
                    GenerateScript();
                end;
            }
        }
    }
    procedure GenerateScript()
    var
        Company: Record Company;
        Tables: Record AllObj;
        SQL1: BigText;
        SQL2: BigText;
        SQL3: BigText;
        FileName: Text;
        InS: InStream;
        OutS: OutStream;
        B: Record TempBlob;
    begin
        LF[1] := 10;
        if ExtensionGUID = '' then
            Error('Please specify a Extension GUID before continuing');

        // Step 1
        if Company.findset then
            repeat
                CurrPage.SetSelectionFilter(Tables);
                if Tables.FINDSET then
                    repeat
                        SQL1.AddText(SQLTable(ConvertName(Company.Name), ConvertName(Rec."Object Name"), 1));
                        SQL2.AddText(SQLTable(ConvertName(Company.Name), ConvertName(Rec."Object Name"), 2));
                        SQL3.AddText(SQLTable(ConvertName(Company.Name), ConvertName(Rec."Object Name"), 3));
                    until Tables.NEXT = 0;
            until Company.next = 0;
        if SQL1.Length > 0 then begin
            // Step1
            SQL1.AddText(GenerateFieldsScript(1));
            B.INIT;
            B.BLob.CreateOutStream(OutS);
            SQL1.Write(OutS);
            B.Blob.CreateInStream(InS);
            FileName := 'uplift-step1.sql';
            DownloadFromStream(InS, 'Save SQL Script', '', '', FileName);
            if confirm('Step 1 download done?') then;
            // Step2
            SQL2.AddText(GenerateFieldsScript(2));
            B.INIT;
            B.BLob.CreateOutStream(OutS);
            SQL2.Write(OutS);
            B.Blob.CreateInStream(InS);
            FileName := 'uplift-step2.sql';
            DownloadFromStream(InS, 'Save SQL Script', '', '', FileName);
            if confirm('Step 2 download done?') then;
            // Step3
            SQL3.AddText(GenerateFieldsScript(3));
            B.INIT;
            B.BLob.CreateOutStream(OutS);
            SQL3.Write(OutS);
            B.Blob.CreateInStream(InS);
            FileName := 'uplift-step3.sql';
            DownloadFromStream(InS, 'Save SQL Script', '', '', FileName);
        end;
    end;

    procedure GenerateFieldsScript(Step: Integer): Text;
    var
        F: Record Field;
        FieldList: List of [Text];
        CurrentTable: Integer;
        SQL: Text;
        Company: Record Company;
    begin
        F.SETFILTER("No.", FieldNumberFilter);
        F.SETFILTER(TableNo, '1..49999|99000750..99009999');
        if f.findset then
            repeat
                IF F.TableNo <> CurrentTable then begin
                    if CurrentTable <> 0 then begin
                        if Company.FINDSET THEN
                            repeat
                                // Generate script for table
                                SQL += GenerateTableFields(F, Company, FieldList, Step);
                            until Company.next = 0;
                    end;
                    CLEAR(FieldList);
                    CurrentTable := F.TableNo;
                end;
                FieldList.Add(F.FieldName);
            until f.next = 0;
        if CurrentTable <> 0 then
            if Company.FINDSET THEN
                repeat
                    // Generate script for table
                    SQL += GenerateTableFields(F, Company, FieldList, Step);
                until Company.next = 0;
        exit(SQL);
    end;

    procedure GenerateTableFields(var F: Record Field;
                                  var Company: Record Company;
                                  var FieldList: List of [Text];
                                  Step: Integer): Text
    var
        FieldName: Text;
        RecRef: RecordRef;
        KeyRef: KeyRef;
        FRef: FieldRef;
        FieldListStr: Text;
        NewTableName: Text;
        TableName: Text;
        TableExtensionName: Text;
        i: Integer;
        PrimaryKeyTransferList: Text;
        FieldTransferList: Text;
    begin
        RecRef.OPEN(F.TableNo);
        NewTableName := ConvertName(Company.Name) + '$' + ConvertName(RecRef.Name) + '.new';
        TableName := ConvertName(Company.Name) + '$' + ConvertName(RecRef.Name);
        TableExtensionName := ConvertName(Company.Name) + '$' + ConvertName(RecRef.Name) + '$' + ExtensionGUID;
        KeyRef := RecRef.KeyIndex(1);
        for i := 1 to KeyRef.FieldCount DO begin
            if FieldListStr <> '' then
                FieldListStr += ',';
            FRef := KeyRef.FieldIndex(i);
            FieldListStr += '[' + ConvertName(FRef.Name) + ']';
            if PrimaryKeyTransferList <> '' then
                PrimaryKeyTransferList += ',';
            PrimaryKeyTransferList += '[' + NewTableName + '].[' + ConvertName(FRef.Name) + ']=[' +
                                      TableExtensionName + '].[' + ConvertName(FRef.Name) + ']';
        END;
        for i := 1 to FieldList.Count do begin
            if FieldListStr <> '' then
                FieldListStr += ',';
            FieldList.Get(i, FieldName);
            FieldListStr += '[' + ConvertName(FieldName) + ']';
            if FieldTransferList <> '' then
                FieldTransferList += ',';
            FieldTransferList += '[' + TableExtensionName + '].[' + ConvertName(FRef.Name) + ']=[' +
                                      NewTableName + '].[' + ConvertName(FRef.Name) + ']';
        end;
        case Step of
            1:
                Exit('select ' + FieldListStr + ' into [' +
                    NewTableName + '] from [' +
                    TableName + '];' + LF);
            2:
                Exit('UPDATE [' + TableExtensionName + '] SET ' + LF +
                     FieldTransferList +
                     ' FROM [' + NewTableName + '] WHERE ' +
                     PrimaryKeyTransferList + ';' + LF);
            3:
                Exit('DROP TABLE [' + NewTableName + '];' + LF);
        end;
    end;

    procedure SQLTable(Company: Text; TableName: Text; Step: Integer): Text;
    begin
        case Step of
            1:
                exit(
                'exec sp_rename ''' +
                Company + '$' +
                TableName + ''',''' +
                Company + '$' +
                TableName + '$' +
                ExtensionGUID + '.bak'';' + LF + 'Select * Into [' +
                Company + '$' +
                TableName + '] From [' +
                Company + '$' +
                TableName + '$' +
                ExtensionGuid + '.bak] Where 1 = 2;' + LF);
            2:
                exit(
                'exec sp_rename ''[' +
                Company + '$' +
                TableName + '$' +
                ExtensionGUID + ']'',''' +
                Company + '$' +
                TableName + '$' +
                ExtensionGUID + '.bak2'';' + LF +
                'exec sp_rename ''[' +
                Company + '$' +
                TableName + '$' +
                ExtensionGUID + '.bak]'',''' +
                Company + '$' +
                TableName + '$' +
                ExtensionGUID + ''';' + LF);
            3:
                exit('DROP TABLE [' +
                Company + '$' +
                TableName + '$' +
                ExtensionGUID + '.bak2];' + LF);
        end;
    end;

    procedure ConvertName(name: Text): Text;
    var
        i: Integer;
        BadCharacters: Text;
    begin
        BadCharacters := '."\/''%][';
        for i := 1 to strlen(Name) do begin
            if strpos(BadCharacters, copystr(name, i, 1)) > 0 then
                Name[i] := '_';
        end;
        exit(Name);
    end;

    var
        ExtensionGUID: Text;
        FieldNumberFilter: Text;
        LF: Text;

}