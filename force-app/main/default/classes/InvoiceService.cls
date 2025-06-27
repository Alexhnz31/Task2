public with sharing class InvoiceService {
    // Static variable to hold mock PDF content for testing
    private static Blob mockPdfContent = null;
    
    // Method to set mock PDF content for testing
    @TestVisible
    private static void setMockPdfGenerator(Blob mockPdf) {
        mockPdfContent = mockPdf;
    }
    
    /**
     * @AuraEnabled
     * Generates an invoice PDF for a given Opportunity and attaches it to the record.
     * The filename will be in the format 'INV-######.pdf', relying on the Invoice_Number__c field.
     * If Invoice_Number__c is null, it falls back to 'INV-' + OpportunityId + '.pdf'.
     *
     * @param opportunityId The ID of the Opportunity for which to generate the invoice.
     */
    @AuraEnabled
    public static void generateInvoice(Id opportunityId) {
        // Query the Opportunity to get the Invoice_Number__c.
        // It's crucial this field is populated (ideally by an Autonumber) for the desired filename format.
        Opportunity opp = [SELECT Id, Invoice_Number__c FROM Opportunity WHERE Id = :opportunityId];
        
        Blob pdfBlob;
        if (Test.isRunningTest() && mockPdfContent != null) {
            // Use mock PDF during tests for predictable behavior and to avoid callouts (getContentAsPDF is a callout)
            pdfBlob = mockPdfContent;
        } else {
            // Generate real PDF in non-test context from the Visualforce page
            PageReference pdfPage = Page.InvoicePDF; // Reference to your Visualforce page
            pdfPage.getParameters().put('id', opportunityId); // Pass the Opportunity ID to the VF page controller
            
            // Generate the PDF content. This is a callout and can be slow.
            // Consider making this @future or Queueable if generating many PDFs.
            pdfBlob = pdfPage.getContentAsPDF();
        }
        
        // Construct the filename: 'INV-######.pdf'
        // Assumes Invoice_Number__c is an Autonumber field configured as 'INV-{000000}'
        // If it's only '{000000}', you'd prepend 'INV-' here.
        String fileName = opp.Invoice_Number__c != null 
                          ? opp.Invoice_Number__c + '.pdf' // Use the Autonumber directly
                          : 'INV-' + opportunityId + '.pdf'; // Fallback if Autonumber is not yet set
        
        attachFileToRecord(opportunityId, fileName, pdfBlob);
    }
    
    /**
     * Attaches a file (Blob) to a given record.
     * If a file with the same name already exists, a new version is created.
     * Otherwise, a new ContentVersion and ContentDocumentLink are created.
     *
     * @param recordId The ID of the record to which the file should be attached.
     * @param fileName The desired filename (e.g., "Invoice-001.pdf").
     * @param fileBody The Blob containing the file content.
     */
    private static void attachFileToRecord(Id recordId, String fileName, Blob fileBody) {
        // Query for existing ContentDocumentLinks with the same LinkedEntityId and file Title
        List<ContentDocumentLink> existingLinks = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId 
            AND ContentDocument.Title = :fileName // Check by file title for existing documents
            LIMIT 1 // We only need to find one to know if it exists
        ];
        
        if (!existingLinks.isEmpty()) {
            // If a file with the same name (title) is already linked to this record,
            // create a new ContentVersion (a new version of the existing ContentDocument).
            ContentVersion newVersion = new ContentVersion(
                ContentDocumentId = existingLinks[0].ContentDocumentId, // Link to the existing document
                VersionData = fileBody,      // The new file content
                Title = fileName,            // Keep the same title
                PathOnClient = fileName,     // Recommended to match Title for proper display
                // If you want to track changes, you might increment the VersionNumber or add a description
                Description = 'New version generated on ' + System.now().format('MM/dd/yyyy HH:mm')
            );
            insert newVersion;
        } else {
            // If no file with this name is linked to the record, create a new one.
            // This involves creating a ContentVersion first, which then automatically creates a ContentDocument.
            ContentVersion cv = new ContentVersion(
                Title = fileName,            // Title of the file
                PathOnClient = fileName,     // Path for download (should match Title)
                VersionData = fileBody,      // The file content
                FirstPublishLocationId = recordId // Automatically links the new ContentDocument to the record
            );
            insert cv;
            // A ContentDocumentLink is automatically created by Salesforce when FirstPublishLocationId is set.
        }
    }
}