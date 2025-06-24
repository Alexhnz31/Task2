public with sharing class GenerateInvoiceService {

    @AuraEnabled
    public static void generateInvoice(Id oppId) {
        generateInvoiceInternal(oppId, null);
    }

    /**
     *
     * @param oppId 
     * @param testBlob 
     */
    @TestVisible
    private static void generateInvoiceInternal(Id oppId, Blob testBlob) {
        Opportunity opp = [SELECT Id, Invoice_Number__c FROM Opportunity WHERE Id = :oppId];
        
        Blob pdfBlob;
        if (testBlob != null) {
            pdfBlob = testBlob;
        } else {
            PageReference pdfPage = Page.InvoicePDF;
            pdfPage.getParameters().put('id', oppId);
            pdfBlob = pdfPage.getContentAsPDF(); // This is a callout
        }

       
        String fileName = (opp.Invoice_Number__c != null && opp.Invoice_Number__c.startsWith('INV-'))
                          ? opp.Invoice_Number__c + '.pdf'
                          : 'INV-' + (opp.Invoice_Number__c != null ? opp.Invoice_Number__c : opp.Id) + '.pdf';
   

        attachFileToOpportunity(oppId, fileName, pdfBlob);
    }

    /**
     
     * @param oppId 
     * @param fileName
     * @param fileBody 
     */
    private static void attachFileToOpportunity(Id oppId, String fileName, Blob fileBody) {
       
        List<ContentDocumentLink> existingLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :oppId
            AND ContentDocument.Title = :fileName
            LIMIT 1 
        ];

        if (!existingLinks.isEmpty()) {
         
            ContentVersion newVersion = new ContentVersion(
                ContentDocumentId = existingLinks[0].ContentDocumentId, 
                VersionData = fileBody,      
                Title = fileName,           
                PathOnClient = fileName,    
                Description = 'Generated invoice updated on ' + System.now().format('yyyy-MM-dd HH:mm')
            );
            insert newVersion;
            System.debug('Created new version of existing invoice: ' + fileName + ' for Opportunity: ' + oppId);
        } else {
            
            ContentVersion cv = new ContentVersion(
                VersionData = fileBody,
                Title = fileName,
                PathOnClient = fileName,
                FirstPublishLocationId = oppId 
            );
            insert cv;
            System.debug('Created new invoice: ' + fileName + ' and linked to Opportunity: ' + oppId);

 
        }
    }
}