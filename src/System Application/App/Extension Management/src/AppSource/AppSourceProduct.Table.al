// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.AppSource;

table 2515 "AppSource Product"
{
    DataClassification = SystemMetadata;
    Access = Internal;
    TableType = Temporary;

    fields
    {
        field(1; UniqueProductId; Text[200])
        {
            Caption = 'Unique Product Id';
        }
        field(2; DisplayName; Text[250])
        {
            Caption = 'Name';
        }
        field(4; PublisherId; Text[200])
        {
            Caption = 'Publisher Id';
        }
        field(5; PublisherDisplayName; Text[250])
        {
            Caption = 'Publisher Name';
        }
        field(6; PublisherType; Text[200])
        {
            Caption = 'Publisher Type';
        }
        field(8; RatingAverage; Decimal)
        {
            Caption = 'Average Rating';
        }
        field(9; RatingCount; Integer)
        {
            Caption = '# Ratings';
        }
        field(10; ProductType; Text[200])
        {
            Caption = 'Product Type';
        }
        field(11; AppId; Text[36])
        {
            Caption = 'Application Identifier';
        }
        field(12; Popularity; Decimal)
        {
            Caption = 'Popularity';
        }
        field(14; LastModifiedDateTime; DateTime)
        {
            Caption = 'Last Modified Date Time';
        }
    }

    keys
    {
        key(UniqueId; UniqueProductId) { }
        key(DefaultSorting; DisplayName, PublisherDisplayName) { }
        key(Rating; RatingAverage, DisplayName, PublisherDisplayName) { }
        key(Popularity; Popularity, DisplayName, PublisherDisplayName) { }
        key(LastModified; LastModifiedDateTime, DisplayName, PublisherDisplayName) { }
        key(PublisherId; PublisherId, DisplayName, PublisherDisplayName) { }
    }

    fieldgroups
    {
        fieldgroup(Brick; PublisherDisplayName, DisplayName, Popularity, RatingAverage)
        {
        }
    }

    procedure ReloadAllOffers()
    var
        apm: codeunit "AppSource Product Manager";
    begin
        Rec.DeleteAll(false);
        apm.GetOffersAndPopulateRecord(Rec);

        Rec.SetCurrentKey(Rec.DisplayName);
        Rec.FindSet(false);
    end;
}