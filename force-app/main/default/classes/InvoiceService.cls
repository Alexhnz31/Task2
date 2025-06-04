public with sharing class InvoiceService {
    
    @AuraEnabled
    public static void generateInvoice(Id opportunityId) {
        Opportunity opp = [SELECT Id, Invoice_Number__c FROM Opportunity WHERE Id = :opportunityId];
        
        PageReference pdfPage = Page.InvoicePDF;
        pdfPage.getParameters().put('id', opportunityId);
        Blob pdfBlob = pdfPage.getContentAsPDF();
        
        String fileName = opp.Invoice_Number__c + '.pdf';
        attachFileToRecord(opportunityId, fileName, pdfBlob);
    }
    
    private static void attachFileToRecord(Id recordId, String fileName, Blob fileBody) {
        List<ContentDocumentLink> existingLinks = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId 
            AND ContentDocument.Title = :fileName
        ];
        
        if (!existingLinks.isEmpty()) {
            ContentVersion newVersion = new ContentVersion(
                ContentDocumentId = existingLinks[0].ContentDocumentId,
                VersionData = fileBody,
                Title = fileName,
                PathOnClient = fileName
            );
            insert newVersion;
        } else {
            ContentVersion cv = new ContentVersion(
                Title = fileName,
                PathOnClient = fileName,
                VersionData = fileBody,
                FirstPublishLocationId = recordId
            );
            insert cv;
        }
    }
}