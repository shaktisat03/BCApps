// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace System.Apps.AppSource;

using System.Environment.Configuration;
using System.Globalization;
using System.Azure.Identity;
using System.Environment;
using System.Azure.KeyVault;
using System.Apps;

codeunit 2515 "AppSource Product Manager"
{
    Access = Internal;

    var
        environmentInformation: Codeunit "Environment Information";
        catalogProductsUriLbl: label 'https://catalogapi.azure.com/products', Locked = true;
        catalogApiVersionLbl: label 'api-version=2023-05-01-preview', Locked = true;
        orderbyDispayNameLbl: label 'orderby=displayName asc', Locked = true;
        marketAndLanguageLbl: Label 'market=%1&language=%2', Comment = '%1 ISO market, %2 ISO language', Locked = true;
        productTypeFilterLbl: Label '$filter=productType eq ''DynamicsBC''', Locked = true;
        productListSelectLbl: Label '$select=uniqueProductId,displayName,publisherId,publisherDisplayName,publisherType,ratingAverage,ratingCount,productType,popularity,privacyPolicyUri,lastModifiedDateTime', Locked = true;


    #region Product helpers 
    /// <summary>
    /// Opens the AppSource product page in Microsoft AppSource, for the specified unique product id.
    /// </summary>
    /// <param name="uniqueProductIdValue">The Unique Product ID of the product to show in Microsoft App Source</param>
    procedure OpenInAppSource(uniqueProductIdValue: Text)
    var
        appSourceListingUriLbl: Label 'https://appsource.microsoft.com/en-us/product/dynamics-365-business-central/%1', Comment = '%1=Url Query Content';
    begin
        Hyperlink(StrSubstNo(appSourceListingUriLbl, uniqueProductIdValue));
    end;

    /// <summary>
    /// Opens the AppSource product details page for the specified unique product id.
    /// </summary>
    /// <param name="uniqueProductIdValue"></param>
    procedure OpenProductDetailsPage(uniqueProductIdValue: Text)
    var
        productDetailsPage: Page "AppSource Product Details";
        offer: JsonObject;
    begin
        offer := GetProductDetails(uniqueProductIdValue);
        productDetailsPage.SetOffer(offer);
        productDetailsPage.RunModal();
    end;

    /// <summary>
    /// Extracts the AppId from the Unique Product ID.
    /// </summary>
    /// <param name="uniqueProductIdValue">The Unique Product ID of the product as defined in Microsoft App Source</param>
    /// <returns>AppId found in the Product ID</returns>
    procedure ExtractAppIdFromUniqueProductId(uniqueProductIdValue: Text): Text[36]
    var
        appIdPos: Integer;
    begin
        appIdPos := StrPos(uniqueProductIdValue, 'PAPPID.');
        if (appIdPos > 0) then
            exit(CopyStr(uniqueProductIdValue, appIdPos + 7, 36));
        exit('');
    end;

    /// <summary>
    /// Installs the product with the specified AppId.
    /// </summary>
    procedure InstallProduct(appIdToInstall: Guid)
    var
        extensionManagement: Codeunit "Extension Management";
    begin
        extensionManagement.InstallMarketplaceExtension(appIdToInstall);
    end;
    #endregion

    /// <summary>
    /// Get all offers from a remote server and adds them to the AppSource Product table.
    /// </summary>
    procedure GetOffersAndPopulateRecord(var appSourceProductRec: record "AppSource Product"): Text
    var
        nextPageLink: text;
        language: Text[2];
        market: Text[2];
    begin
        ResolveMarketAndLanguage(market, language);

        nextPageLink := ConstructProductListUri(market, language);

        repeat
            nextPageLink := DownloadAndAddNextPageProducts(nextPageLink, appSourceProductRec);
        until nextPageLink = '';
    end;

    /// <summary>
    /// Get specific product details from.
    /// </summary>
    local procedure GetProductDetails(uniqueIdentifier: Text): JsonObject
    var
        httpClient: HttpClient;
        httpRequest: HttpRequestMessage;
        httpResponse: HttpResponseMessage;
        offerData: JsonObject;
        responseText: Text;
        clientRequestId: Guid;
        telemetryDictionary: Dictionary of [Text, Text];
    begin
        clientRequestId := CreateGuid();
        PopulateTelemetryDictionary(clientRequestId, uniqueIdentifier, telemetryDictionary);
        Session.LogMessage('AL:AppSource-GetOffer', 'Requesting offer data for', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::All, telemetryDictionary);
        SetCommonHeaders(httpRequest, clientRequestId);
        httpRequest.SetRequestUri(ConstructProductUri(uniqueIdentifier, 'US', 'en'));
        httpRequest.Method := 'GET';
        if httpClient.Send(httpRequest, httpResponse) then begin
            httpResponse.Content.ReadAs(responseText);
            offerData.ReadFrom(responseText);
            exit(offerData);
        end;
    end;

    local procedure DownloadAndAddNextPageProducts(nextPageLink: Text; var appSourceProductRec: record "AppSource Product"): Text
    var
        httpClient: HttpClient;
        httpRequest: HttpRequestMessage;
        httpResponse: HttpResponseMessage;
        myoffers: JsonObject;
        responseText: Text;
        offer: JsonObject;
        offerArray: JsonArray;
        offerToken: JsonToken;
        offerTokenItem: JsonToken;
        i: Integer;
        clientRequestId: Guid;
        telemetryDictionary: Dictionary of [Text, Text];
    begin
        clientRequestId := CreateGuid();
        PopulateTelemetryDictionary(clientRequestId, '', telemetryDictionary);
        Session.LogMessage('AL:AppSource-NextPageOffers', 'Requesting offer data for', Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::All, telemetryDictionary);

        SetCommonHeaders(httpRequest, clientrequestId);
        httpRequest.SetRequestUri(nextPageLink);
        httpRequest.Method := 'GET';
        if httpClient.Send(httpRequest, httpResponse) then begin
            httpResponse.Content.ReadAs(responseText);
            myoffers.ReadFrom(responseText);
            if (myoffers.Get('items', offerToken)) then begin
                offerArray := offerToken.AsArray();
                for i := 0 to offerArray.Count() do
                    if (offerArray.Get(i, offerTokenItem)) then begin
                        offer := offerTokenItem.AsObject();
                        InsertOffer(offer, appSourceProductRec);
                    end
            end;
            exit(GetStringValue(myoffers, 'nextPageLink'));

            // TODO: Handle error cases
            //else
            //
            // 400 Invalid language : <Language>  => try again with en
            // 400 Invalid market: <market>   => try again with US
        end;

        exit('');
    end;

    local procedure SetCommonHeaders(var httpRequest: HttpRequestMessage; clientRequestId: Guid)
    var
        microsoftEntraTenant: codeunit "Azure AD Tenant";
        httpHeaders: HttpHeaders;
    begin
        httpRequest.GetHeaders(httpHeaders);
        httpHeaders.Add('X-API-Key', GetAPIKey());
        httpHeaders.Add('x-ms-client-tenant-id', microsoftEntraTenant.GetAadTenantId());
        httpHeaders.Add('x-ms-app', 'Dynamics 365 Business Central');
        httpHeaders.Add('x-ms-client-request-id', clientRequestId);
    end;

    local procedure ConstructProductListUri(market: text; language: text): Text
    begin
        exit(
            catalogProductsUriLbl
            + '?' + catalogApiVersionLbl
            + '&' + orderbyDispayNameLbl
            + '&' + productTypeFilterLbl
            + '&' + productListSelectLbl
            + '&' + StrSubstNo(marketAndLanguageLbl, market, language)
        );
    end;

    local procedure ConstructProductUri(uniqueIdentifier: Text; market: Text; language: Text): Text
    begin
        exit(
            catalogProductsUriLbl
            + '/' + uniqueIdentifier
            + '?' + catalogApiVersionLbl
            + '&' + StrSubstNo(marketAndLanguageLbl, market, language)
        );
    end;


    #region Telemetry helpers
    local procedure PopulateTelemetryDictionary(requestId: Text; uniqueIdentifier: text; var telemetryDictionary: Dictionary of [Text, Text])
    begin
        PopulateTelemetryDictionary(requestId, telemetryDictionary);
        telemetryDictionary.Add('UniqueIdentifier', uniqueIdentifier);
    end;

    local procedure PopulateTelemetryDictionary(requestId: Text; var telemetryDictionary: Dictionary of [Text, Text])
    begin
        telemetryDictionary.Add('RequestId', requestId);
    end;
    #endregion

    #region JSon Helper Functions
    procedure GetDecimalValue(var JsonObject: JsonObject; propertyName: Text): Decimal
    var
        jsonValue: JsonValue;
    begin
        if GetJSonValue(JsonObject, propertyName, jsonValue) then
            exit(jsonValue.AsDecimal());
        exit(0);
    end;

    procedure GetIntegerValue(var JsonObject: JsonObject; propertyName: Text): Integer
    var
        jsonValue: JsonValue;
    begin
        if GetJSonValue(JsonObject, propertyName, jsonValue) then
            exit(jsonValue.AsInteger());
        exit(0);
    end;

    procedure GetDateTimeValue(var JsonObject: JsonObject; propertyName: Text): DateTime
    var
        jsonValue: JsonValue;
    begin
        if GetJSonValue(JsonObject, propertyName, jsonValue) then
            exit(jsonValue.AsDateTime());
        exit(0DT);
    end;

    procedure GetStringValue(var JsonObject: JsonObject; propertyName: Text): Text
    var
        jsonValue: JsonValue;
    begin
        if GetJSonValue(JsonObject, propertyName, jsonValue) then
            exit(jsonValue.AsText());
        exit('');
    end;

    procedure GetBooleanValue(var JsonObject: JsonObject; propertyName: Text): Boolean
    var
        jsonValue: JsonValue;
    begin
        if GetJSonValue(JsonObject, propertyName, jsonValue) then
            exit(jsonValue.AsBoolean());
        exit(false);
    end;

    procedure GetJSonValue(var JsonObject: JsonObject; propertyName: Text; var returnValue: JsonValue): Boolean
    var
        jsonToken: JsonToken;
    begin
        if jsonObject.Contains(propertyName) then
            if jsonObject.Get(propertyName, jsonToken) then
                if not jsonToken.AsValue().IsNull() then begin
                    returnValue := jsonToken.AsValue();
                    exit(true);
                end;
        exit(false);
    end;
    #endregion

    #region Market and language helper functions
    local procedure ResolveMarketAndLanguage(var market: Text[2]; var language: Text[2])
    var
        tempUserSettingsRecord: record "User Settings" temporary;
        userSettings: Codeunit "User Settings";
        languageManager: Codeunit Language;
        // entraTenant: Codeunit "Azure AD Tenant";
        languageName: Text;
    begin
        userSettings.GetUserSettings(Database.UserSecurityId(), tempUserSettingsRecord);
        languageName := languageManager.GetLanguageCode(tempUserSettingsRecord."Language ID");
        languageName := ConvertIso369_3_ToIso369_1(languageName);

        market := CopyStr(environmentInformation.GetApplicationFamily(), 1, 2);

        if (market = '') or (market = 'W1') then market := 'US'/*entraTenant.GetCountryLetterCode()*/;
        if language = '' then language := 'en'/*entraTenant.GetPreferredLanguage()*/;
    end;

    local procedure ConvertIso369_3_ToIso369_1(iso369_3: Text): Text[2]
    begin
        case iso369_3 of
            'abk':
                exit('ab');
            'aar':
                exit('aa');
            'afr':
                exit('af');
            'aka + 2':
                exit('ak');
            'sqi + 4':
                exit('sq');
            'amh':
                exit('am');
            'ara + 28':
                exit('ar');
            'arg':
                exit('an');
            'hye':
                exit('hy');
            'asm':
                exit('as');
            'ava':
                exit('av');
            'ave':
                exit('ae');
            'aym + 2':
                exit('ay');
            'aze + 2':
                exit('az');
            'bam':
                exit('bm');
            'bak':
                exit('ba');
            'eus':
                exit('eu');
            'bel':
                exit('be');
            'ben':
                exit('bn');
            'bis':
                exit('bi');
            'bos':
                exit('bs');
            'bre':
                exit('br');
            'bul':
                exit('bg');
            'mya':
                exit('my');
            'cat':
                exit('ca');
            'cha':
                exit('ch');
            'che':
                exit('ce');
            'nya':
                exit('ny');
            'zho + 16':
                exit('zh');
            'chu':
                exit('cu');
            'chv':
                exit('cv');
            'cor':
                exit('kw');
            'cos':
                exit('co');
            'cre + 6':
                exit('cr');
            'hrv':
                exit('hr');
            'ces':
                exit('cs');
            'dan':
                exit('da');
            'div':
                exit('dv');
            'nld':
                exit('nl');
            'dzo':
                exit('dz');
            'eng':
                exit('en');
            'epo':
                exit('eo');
            'est + 2':
                exit('et');
            'ewe':
                exit('ee');
            'fao':
                exit('fo');
            'fij':
                exit('fj');
            'fin':
                exit('fi');
            'fra':
                exit('fr');
            'fry':
                exit('fy');
            'ful + 9':
                exit('ff');
            'gla':
                exit('gd');
            'glg':
                exit('gl');
            'lug':
                exit('lg');
            'kat':
                exit('ka');
            'deu':
                exit('de');
            'ell':
                exit('el');
            'kal':
                exit('kl');
            'grn + 5':
                exit('gn');
            'guj':
                exit('gu');
            'hat':
                exit('ht');
            'hau':
                exit('ha');
            'heb':
                exit('he');
            'her':
                exit('hz');
            'hin':
                exit('hi');
            'hmo':
                exit('ho');
            'hun':
                exit('hu');
            'isl':
                exit('is');
            'ido':
                exit('io');
            'ibo':
                exit('ig');
            'ind':
                exit('id');
            'ina':
                exit('ia');
            'ile':
                exit('ie');
            'iku + 2':
                exit('iu');
            'ipk + 2':
                exit('ik');
            'gle':
                exit('ga');
            'ita':
                exit('it');
            'jpn':
                exit('ja');
            'jav':
                exit('jv');
            'kan':
                exit('kn');
            'kau + 3':
                exit('kr');
            'kas':
                exit('ks');
            'kaz':
                exit('kk');
            'khm':
                exit('km');
            'kik':
                exit('ki');
            'kin':
                exit('rw');
            'kir':
                exit('ky');
            'kom + 2':
                exit('kv');
            'kon + 3':
                exit('kg');
            'kor':
                exit('ko');
            'kua':
                exit('kj');
            'kur + 3':
                exit('ku');
            'lao':
                exit('lo');
            'lat':
                exit('la');
            'lav + 2':
                exit('lv');
            'lim':
                exit('li');
            'lin':
                exit('ln');
            'lit':
                exit('lt');
            'lub':
                exit('lu');
            'ltz':
                exit('lb');
            'mkd':
                exit('mk');
            'mlg + 11':
                exit('mg');
            'msa + 36':
                exit('ms');
            'mal':
                exit('ml');
            'mlt':
                exit('mt');
            'glv':
                exit('gv');
            'mri':
                exit('mi');
            'mar':
                exit('mr');
            'mah':
                exit('mh');
            'mon + 2':
                exit('mn');
            'nau':
                exit('na');
            'nav':
                exit('nv');
            'nde':
                exit('nd');
            'nbl':
                exit('nr');
            'ndo':
                exit('ng');
            'nep + 2':
                exit('ne');
            'nor + 2':
                exit('no');
            'nob':
                exit('nb');
            'nno':
                exit('nn');
            'iii':
                exit('ii');
            'oci':
                exit('oc');
            'oji + 7':
                exit('oj');
            'ori + 2':
                exit('or');
            'orm + 4':
                exit('om');
            'oss':
                exit('os');
            'pli':
                exit('pi');
            'pus + 3':
                exit('ps');
            'fas + 2':
                exit('fa');
            'pol':
                exit('pl');
            'por':
                exit('pt');
            'pan':
                exit('pa');
            'que + 43':
                exit('qu');
            'ron':
                exit('ro');
            'roh':
                exit('rm');
            'run':
                exit('rn');
            'rus':
                exit('ru');
            'sme':
                exit('se');
            'smo':
                exit('sm');
            'sag':
                exit('sg');
            'san':
                exit('sa');
            'srd + 4':
                exit('sc');
            'srp':
                exit('sr');
            'sna':
                exit('sn');
            'snd':
                exit('sd');
            'sin':
                exit('si');
            'slk':
                exit('sk');
            'slv':
                exit('sl');
            'som':
                exit('so');
            'sot':
                exit('st');
            'spa':
                exit('es');
            'sun':
                exit('su');
            'swa + 2':
                exit('sw');
            'ssw':
                exit('ss');
            'swe':
                exit('sv');
            'tgl':
                exit('tl');
            'tah':
                exit('ty');
            'tgk':
                exit('tg');
            'tam':
                exit('ta');
            'tat':
                exit('tt');
            'tel':
                exit('te');
            'tha':
                exit('th');
            'bod':
                exit('bo');
            'tir':
                exit('ti');
            'ton':
                exit('to');
            'tso':
                exit('ts');
            'tsn':
                exit('tn');
            'tur':
                exit('tr');
            'tuk':
                exit('tk');
            'twi':
                exit('tw');
            'uig':
                exit('ug');
            'ukr':
                exit('uk');
            'urd':
                exit('ur');
            'uzb + 2':
                exit('uz');
            'ven':
                exit('ve');
            'vie':
                exit('vi');
            'vol':
                exit('vo');
            'wln':
                exit('wa');
            'cym':
                exit('cy');
            'wol':
                exit('wo');
            'xho':
                exit('xh');
            'yid + 2':
                exit('yi');
            'yor':
                exit('yo');
            'zha + 16':
                exit('za');
            'zul':
                exit('zu');
        end;

        exit('');
    end;
    #endregion

    local procedure InsertOffer(var offer: JsonObject; var marketPlaceoffer: Record "AppSource Product")
    begin
        marketplaceoffer.Init();
        marketPlaceoffer.UniqueProductId := CopyStr(GetStringValue(offer, 'uniqueProductId'), 1, MaxStrLen(marketPlaceoffer.UniqueProductId));
        marketPlaceoffer.DisplayName := CopyStr(GetStringValue(offer, 'displayName'), 1, MaxStrLen(marketPlaceoffer.DisplayName));
        marketPlaceoffer.PublisherId := CopyStr(GetStringValue(offer, 'publisherId'), 1, MaxStrLen(marketPlaceoffer.PublisherId));
        marketPlaceoffer.PublisherDisplayName := CopyStr(GetStringValue(offer, 'publisherDisplayName'), 1, MaxStrLen(marketPlaceoffer.PublisherDisplayName));
        marketPlaceoffer.PublisherType := CopyStr(GetStringValue(offer, 'publisherType'), 1, MaxStrLen(marketPlaceoffer.PublisherType));
        marketPlaceoffer.RatingAverage := GetDecimalValue(offer, 'ratingAverage');
        marketPlaceoffer.RatingCount := GetIntegerValue(offer, 'ratingCount');
        marketPlaceoffer.ProductType := CopyStr(GetStringValue(offer, 'productType'), 1, MaxStrLen(marketPlaceoffer.ProductType));
        marketPlaceoffer.Popularity := GetDecimalValue(offer, 'popularity');
        marketPlaceoffer.LastModifiedDateTime := GetDateTimeValue(offer, 'lastModifiedDateTime');

        marketPlaceoffer.AppId := ExtractAppIdFromUniqueProductId(marketPlaceoffer.UniqueProductId);

        if marketPlaceoffer.UniqueProductId = '' then
            marketPlaceoffer.UniqueProductId := FORMAT(CreateGuid());

        if not marketPlaceoffer.Insert() then begin
            marketPlaceoffer.UniqueProductId := marketPlaceoffer.UniqueProductId + FORMAT(CreateGuid());
            marketPlaceoffer.Insert();
        end;
    end;

    [NonDebuggable]
    local procedure GetAPIKey(): SecretText
    var
        keyVault: codeunit "Azure Key Vault";
        s: text;
        apiKey: SecretText;
    begin
        if not environmentInformation.IsSaaS() then
            Error('Not Supported On Premises');

        keyVault.GetAzureKeyVaultSecret('MS-AppSource-ApiKey', s);
        apiKey := s;
        exit(apiKey);
    end;
}