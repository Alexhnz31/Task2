public with sharing class GenerateInvoiceService {
    @AuraEnabled
    public static void generateInvoice(Id oppId) {
        Opportunity opp = [SELECT Id, Invoice_Number__c FROM Opportunity WHERE Id = :oppId];
        String fileName = opp.Invoice_Number__c + '.pdf';
        
        PageReference pdfPage = Page.InvoicePDF;
        pdfPage.getParameters().put('id', oppId);
        Blob pdfBlob = pdfPage.getContentAsPDF();

        attachFileToOpportunity(oppId, fileName, pdfBlob);
    }

    private static void attachFileToOpportunity(Id oppId, String fileName, Blob fileBody) {
        List<ContentDocument> existingDocs = [
            SELECT Id FROM ContentDocument 
            WHERE Title = :fileName LIMIT 1
        ];

        if (!existingDocs.isEmpty()) {
            ContentVersion newVersion = new ContentVersion(
                ContentDocumentId = existingDocs[0].Id,
                VersionData = fileBody,
                Title = fileName,
                PathOnClient = fileName
            );
            insert newVersion;
        } else {
            ContentVersion cv = new ContentVersion(
                VersionData = fileBody,
                Title = fileName,
                PathOnClient = fileName
            );
            insert cv;

            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId = oppId,
                ShareType = 'V'
            );
            insert cdl;
        }
    }
}