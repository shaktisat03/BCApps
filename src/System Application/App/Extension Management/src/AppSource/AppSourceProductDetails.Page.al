// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.AppSource;

using System.Apps;

/// <summary>
/// App Source Offer details
/// </summary>
page 2516 "AppSource Product Details"
{
    PageType = Card;
    ApplicationArea = All;
    Editable = false;
    Caption = 'App from Microsoft AppSource';

    layout
    {
        area(Content)
        {
            group(OfferGroup)
            {
                Caption = 'Offer';

                field(Offer_UniqueId; uniqueProductId)
                {
                    Caption = 'Unique Product Id';
                    ToolTip = 'Specifies the Unique Product Id';
                    Visible = false;
                }
                field(Offer_ProductType; apm.GetStringValue(offer, 'productType'))
                {
                    Caption = 'Product Type';
                    ToolTip = 'Specifies the Product Type';
                    Visible = false;
                }
                field(Offer_DisplayName; apm.GetStringValue(offer, 'displayName'))
                {
                    Caption = 'Display Name';
                    ToolTip = 'Specifies the Display Name';
                }
                field(Offer_PublisherId; apm.GetStringValue(offer, 'publisherId'))
                {
                    Caption = 'Publisher Id';
                    ToolTip = 'Specifies the Publisher Id';
                    Visible = false;
                }
                field(Offer_PublisherDisplayName; apm.GetStringValue(offer, 'publisherDisplayName'))
                {
                    Caption = 'Publisher Display Name';
                    ToolTip = 'Specifies the Publisher Display Name';
                }
                field(Offer_PublisherType; apm.GetStringValue(offer, 'publisherType'))
                {
                    Caption = 'Publisher Type';
                    ToolTip = 'Specifies the Publisher Type';
                }
                field(Offer_Private; apm.GetBooleanValue(offer, 'isPrivate'))
                {
                    Caption = 'Private';
                    ToolTip = 'Specifies if the App is Private';
                }
                field(Offer_Discontinued; apm.GetBooleanValue(offer, 'isStopSell'))
                {
                    Caption = 'Discontinued';
                    ToolTip = 'Specifies if the App has been discontinued';
                }
                field(Offer_LastModifiedDateTime; apm.GetStringValue(offer, 'lastModifiedDateTime'))
                {
                    Caption = 'Last Modified Date Time';
                    ToolTip = 'Specifies the Last Modified Date Time';
                }
                field(Offer_Language; apm.GetStringValue(offer, 'language'))
                {
                    Caption = 'Language';
                    ToolTip = 'Specifies the Language';
                }
                field(Offer_IsInstalled; currentRecordCanBeUninstalled)
                {
                    Caption = 'Installed';
                    ToolTip = 'Specifies if the App is currently installed';
                }
            }
            group(DescriptionGroup)
            {
                ShowCaption = false;

                field(Description_Description; apm.GetStringValue(offer, 'description'))
                {
                    Caption = 'Description';
                    MultiLine = true;
                    ExtendedDatatype = RichContent;
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Description';
                }
            }

            group(RatingGroup)
            {
                field(Rating_Popularity; apm.GetStringValue(offer, 'popularity'))
                {
                    Caption = 'Popularity';
                    ToolTip = 'Specifies the Popularity';
                }
                field(Rating_RatingAverage; apm.GetStringValue(offer, 'ratingAverage'))
                {
                    Caption = 'Rating Average';
                    ToolTip = 'Specifies the Rating Average';
                }
                field(Rating_RatingCount; apm.GetStringValue(offer, 'ratingCount'))
                {
                    Caption = 'Rating Count';
                    ToolTip = 'Specifies the Rating Count';
                }
            }


            group(Links)
            {
                field(Links_LegalTermsUri; apm.GetStringValue(offer, 'legalTermsUri'))
                {
                    Caption = 'Legal Terms Uri';
                    ToolTip = 'Specifies the Legal Terms Uri';
                    ExtendedDatatype = Url;
                }
                field(Links_PrivacyPolicyUri; apm.GetStringValue(offer, 'privacyPolicyUri'))
                {
                    Caption = 'Privacy Policy Uri';
                    ToolTip = 'Specifies the Privacy Policy Uri';
                    ExtendedDatatype = Url;
                }
                field(Links_SupportUri; apm.GetStringValue(offer, 'supportUri'))
                {
                    Caption = 'Support Uri';
                    ToolTip = 'Specifies the Support Uri';
                    ExtendedDatatype = Url;
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
        }

        area(Processing)
        {
            action(OpenInAppSource)
            {
                Caption = 'View App in AppSource';
                Scope = Page;
                Image = Open;
                ToolTip = 'View App in AppSource';

                trigger OnAction()
                begin
                    apm.OpenInAppSource(uniqueProductId);
                end;
            }

            action(Install)
            {
                Caption = 'Install App';
                Scope = Page;
                Enabled = not currentRecordCanBeUninstalled;
                Image = Insert;
                ToolTip = 'Install App';

                trigger OnAction()
                begin
                    apm.InstallProduct(appId);
                end;
            }

            action(Uninstall)
            {
                Caption = 'Uninstall App';
                Scope = Page;
                Enabled = currentRecordCanBeUninstalled;
                Image = Delete;
                ToolTip = 'Uninstall App';

                trigger OnAction()
                begin
                    extensionManagement.UninstallExtension(appId, true);
                end;
            }
        }
    }

    var
        extensionManagement: Codeunit "Extension Management";
        apm: Codeunit "AppSource Product Manager";
        offer: JsonObject;
        uniqueProductId: Text;
        appId: Text;
        currentRecordCanBeUninstalled: Boolean;

    procedure SetOffer(var offerValue: JsonObject)
    begin
        offer := offerValue;
        uniqueProductId := apm.GetStringValue(offer, 'uniqueProductId');
        currentRecordCanBeUninstalled := false;
        if (appId <> '') then
            currentRecordCanBeUninstalled := extensionManagement.IsInstalledByAppId(appId);
    end;
}