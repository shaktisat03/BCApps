// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace System.Apps.AppSource;

using System.Apps;

/// <summary>
/// Lost of Offers retrieved from AppSource
/// </summary>
page 2515 "AppSource Product List"
{
    PageType = List;
    Caption = 'Microsoft AppSource apps';
    ApplicationArea = All;
    UsageCategory = Administration;
    Editable = false;
    AdditionalSearchTerms = 'Extension,Marketplace,Management,App,Customization,Personalization,Install,Publish,Extend';

    SourceTable = "AppSource Product";
    SourceTableView = sorting(DisplayName);
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(Repeater)
            {
                field(DisplayName; Rec.DisplayName)
                {
                    DrillDown = true;
                    ToolTip = 'Specifies the Display Name';

                    trigger OnDrillDown()
                    begin
                        apm.OpenProductDetailsPage(Rec.UniqueProductId);
                    end;
                }
                field(UniqueProductId; Rec.UniqueProductId)
                {
                    Visible = false;
                    ToolTip = 'Specifies the Unique Product Id';
                }
                field(PublisherId; Rec.PublisherId)
                {
                    Visible = false;
                    ToolTip = 'Specifies the Publisher Id';
                }

                field(PublisherDisplayName; Rec.PublisherDisplayName)
                {
                    ToolTip = 'Specifies the Publisher Display Name';
                }
                field(Installed; currentRecordCanBeUninstalled)
                {
                    Caption = 'Installed';
                    ToolTip = 'Specifies if this App is installed';
                }
                field(RatingAverage; Rec.RatingAverage)
                {
                    ToolTip = 'Specifies the Rating Average';
                }
                field(Popularity; Rec.Popularity)
                {
                    ToolTip = 'Specifies the Popularity index';
                }
                field(RatingCount; Rec.RatingCount)
                {
                    ToolTip = 'Specifies the number of times this has been rated';
                    Visible = false;
                }
                field(LastModifiedDateTime; Rec.LastModifiedDateTime)
                {
                    ToolTip = 'Specifies the date and time this was last modified';
                }
                field(AppId; Rec.AppId)
                {
                    ToolTip = 'Specifies the App Id';
                    Visible = false;
                }
                field(PublisherType; Rec.PublisherType)
                {
                    ToolTip = 'Specifies the Publisher Type';
                }
            }
        }
    }

    actions
    {
        area(Promoted)
        {
            actionref(Open_Promoted; OpenInAppSource) { }
            actionref(Install_Promoted; Install) { }
            actionref(Uninstall_Promoted; Uninstall) { }
            actionref(Refresh_Promoted; UpdateOffers) { }
        }

        area(Processing)
        {
            action(OpenInAppSource)
            {
                Caption = 'View app in AppSource';
                Scope = RepeaterRow;

                Image = OpenWorksheet;
                ToolTip = 'View app in AppSource';

                trigger OnAction()
                begin
                    apm.OpenInAppSource(Rec.UniqueProductId);
                end;
            }

            action(Install)
            {
                Caption = 'Install app';
                Scope = RepeaterRow;

                Enabled = not currentRecordCanBeUnInstalled;

                Image = Insert;
                ToolTip = 'Install app';

                trigger OnAction()
                begin
                    apm.InstallProduct(Rec.AppId);
                end;
            }

            action(Uninstall)
            {
                Caption = 'Uninstall app';
                Scope = RepeaterRow;

                Enabled = currentRecordCanBeUnInstalled;

                Image = Delete;
                ToolTip = 'Uninstall app';

                trigger OnAction()
                begin
                    extensionManagement.UninstallExtension(Rec.AppId, true);
                end;
            }
        }

        area(Navigation)
        {
            action(UpdateOffers)
            {
                Caption = 'Refresh list from Microsoft AppSource';
                Scope = Page;
                ToolTip = 'Refreshes the list by downloading the latest apps from Microsoft AppSource';
                Image = Refresh;

                trigger OnAction()
                begin
                    Rec.ReloadAllOffers();
                    CurrPage.Update();
                end;

            }
        }
    }

    views
    {
        view("TopRated")
        {
            Caption = 'Top rated apps';
            Filters = where(RatingAverage = filter(>= 4));
            OrderBy = descending(RatingAverage);
        }

        view("Popular")
        {
            Caption = 'Popular apps';
            OrderBy = descending(Popularity);
        }

        view("Resent Updates")
        {
            Caption = 'Recently changed apps';
            OrderBy = descending(LastModifiedDateTime);
        }
    }

    var
        extensionManagement: Codeunit "Extension Management";
        apm: Codeunit "AppSource Product Manager";
        currentRecordCanBeUninstalled: Boolean;

    trigger OnOpenPage()
    begin
        rec.ReloadAllOffers();
        ;
    end;

    trigger OnAfterGetCurrRecord()
    begin
        currentRecordCanBeUninstalled := false;
        if (Rec.AppId <> '') then
            currentRecordCanBeUninstalled := extensionManagement.IsInstalledByAppId(rec.AppId);
    end;
}