public with sharing class GenerateInvoiceService {

    // Static variable to hold mock PDF content for testing
    // This is managed internally by the generateInvoiceInternal method's testBlob parameter now.
    // private static Blob mockPdfContent = null; 

    // The @AuraEnabled method that external calls (e.g., LWC) will use.
    @AuraEnabled
    public static void generateInvoice(Id oppId) {
        // Calls the internal method with a null testBlob, triggering real PDF generation.
        generateInvoiceInternal(oppId, null);
    }

    /**
     * Internal method to generate an invoice, allowing for a test Blob to be injected during tests.
     *
     * @param oppId The ID of the Opportunity.
     * @param testBlob Optional. A Blob to use instead of generating a real PDF during tests.
     */
    @TestVisible
    private static void generateInvoiceInternal(Id oppId, Blob testBlob) {
        // Query the Opportunity to get its Invoice_Number__c.
        // It's recommended that Invoice_Number__c is an Auto Number field with a format like 'INV-{000000}'.
        Opportunity opp = [SELECT Id, Invoice_Number__c FROM Opportunity WHERE Id = :oppId];
        
        Blob pdfBlob;
        if (testBlob != null) {
            // Use the provided mock PDF content during tests
            pdfBlob = testBlob;
        } else {
            // Generate real PDF content from the Visualforce page in a non-test context
            PageReference pdfPage = Page.InvoicePDF;
            pdfPage.getParameters().put('id', oppId);
            pdfBlob = pdfPage.getContentAsPDF(); // This is a callout
        }

        // --- Filename Generation Logic ---
        // Construct the filename in the desired format: INV-######.pdf
        // If Invoice_Number__c is null (e.g., Opportunity not yet saved and Autonumber not generated),
        // it falls back to 'INV-' + OpportunityId + '.pdf'.
        // This assumes Invoice_Number__c is an Autonumber field configured as 'INV-{000000}'.
        // If your Autonumber is only '{000000}', you might need to explicitly prepend 'INV-'.
        String fileName = (opp.Invoice_Number__c != null && opp.Invoice_Number__c.startsWith('INV-'))
                          ? opp.Invoice_Number__c + '.pdf'
                          : 'INV-' + (opp.Invoice_Number__c != null ? opp.Invoice_Number__c : opp.Id) + '.pdf';
        // Note: The above ensures "INV-" prefix and uses the Autonumber if present,
        // otherwise falls back to Opportunity ID. If your Autonumber sometimes doesn't have "INV-",
        // you might need more complex logic to pad with zeros as discussed previously.
        // For simplicity and robustness, configuring the Autonumber in Salesforce as INV-{000000} is best.

        attachFileToOpportunity(oppId, fileName, pdfBlob);
    }

    /**
     * Attaches a file (Blob) to a specific Opportunity record.
     * It checks for existing ContentDocumentLinks to the Opportunity with the same filename.
     * If found, it creates a new ContentVersion. Otherwise, it creates a new ContentVersion
     * and links it to the Opportunity.
     *
     * @param oppId The ID of the Opportunity to which the file should be attached.
     * @param fileName The desired filename (e.g., "INV-000001.pdf").
     * @param fileBody The Blob containing the file content.
     */
    private static void attachFileToOpportunity(Id oppId, String fileName, Blob fileBody) {
        // Query for existing ContentDocumentLinks that link to THIS Opportunity AND have a ContentDocument
        // with the specified Title (filename). This is more precise than just checking by Title globally.
        List<ContentDocumentLink> existingLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :oppId
            AND ContentDocument.Title = :fileName
            LIMIT 1 // We only need to know if one exists for this opportunity
        ];

        if (!existingLinks.isEmpty()) {
            // If a file with the same name is already linked to this specific Opportunity,
            // create a new version of that existing ContentDocument.
            ContentVersion newVersion = new ContentVersion(
                ContentDocumentId = existingLinks[0].ContentDocumentId, // Link to the existing document
                VersionData = fileBody,      // The new file content
                Title = fileName,            // Keep the same title
                PathOnClient = fileName,     // Recommended to match Title for proper display in Files home
                Description = 'Generated invoice updated on ' + System.now().format('yyyy-MM-dd HH:mm')
            );
            insert newVersion;
            System.debug('Created new version of existing invoice: ' + fileName + ' for Opportunity: ' + oppId);
        } else {
            // If no file with this name is linked to this Opportunity, create a new one.
            // First, create the ContentVersion. Salesforce automatically creates a ContentDocument from this.
            ContentVersion cv = new ContentVersion(
                VersionData = fileBody,
                Title = fileName,
                PathOnClient = fileName,
                FirstPublishLocationId = oppId // This automatically creates a ContentDocumentLink to oppId
            );
            insert cv;
            System.debug('Created new invoice: ' + fileName + ' and linked to Opportunity: ' + oppId);

            // You no longer need this block:
            // cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
            // ContentDocumentLink cdl = new ContentDocumentLink(
            //     ContentDocumentId = cv.ContentDocumentId,
            //     LinkedEntityId = oppId,
            //     ShareType = 'V'
            // );
            // insert cdl;
            // Because setting FirstPublishLocationId on ContentVersion automatically handles the linking.
        }
    }
}