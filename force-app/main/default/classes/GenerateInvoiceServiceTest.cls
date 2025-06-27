@IsTest
private class GenerateInvoiceServiceTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(7),
            AccountId = acc.Id
        );
        insert opp;
    }

    @IsTest
    static void testGenerateInvoiceCreatesContentVersion() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        // Create a dummy blob for the PDF content
        Blob dummyPdfBlob = Blob.valueOf('This is dummy PDF content for testing.');

        Test.startTest();
        // Call the internal method directly, bypassing actual PDF generation
        GenerateInvoiceService.generateInvoiceInternal(opp.Id, dummyPdfBlob);
        Test.stopTest();

        String expectedFileName = 'invoice_' + opp.Id + '.pdf';

        // Проверяем, что создан ContentVersion
        List<ContentVersion> versions = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE Title = :expectedFileName
        ];
        System.assertEquals(1, versions.size(), 'PDF-файл не создан');
        System.assertEquals(dummyPdfBlob.size(), versions[0].VersionData.size(), 'ContentVersion data size does not match dummy blob');
    }

    @IsTest
    static void testGenerateInvoiceCreatesLinkToOpportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Blob dummyPdfBlob = Blob.valueOf('Dummy content for link test.');

        Test.startTest();
        // Call the internal method directly
        GenerateInvoiceService.generateInvoiceInternal(opp.Id, dummyPdfBlob);
        Test.stopTest();

        // Проверяем, что создана привязка к Opportunity
        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opp.Id
        ];
        System.assertEquals(1, links.size(), 'Файл не привязан к Opportunity');
    }

    @IsTest
    static void testGenerateInvoiceCreatesNewVersionIfExists() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        String fileName = 'invoice_' + opp.Id + '.pdf';

        Blob initialDummyPdfBlob = Blob.valueOf('Initial dummy PDF content.');
        Blob newDummyPdfBlob = Blob.valueOf('New dummy PDF content for testing new version.');

        // Создаём первую версию документа
        ContentVersion initial = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = initialDummyPdfBlob
        );
        insert initial;

        // Получаем ContentDocumentId
        initial = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :initial.Id];

        // Привязываем к Opportunity
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = initial.ContentDocumentId,
            LinkedEntityId = opp.Id,
            ShareType = 'V'
        );
        insert cdl;

        // Установка страницы (not strictly needed here as we bypass getContentAsPDF)
        // Test.setCurrentPage(Page.InvoicePDF);
        // ApexPages.currentPage().getParameters().put('id', opp.Id);


        // Генерация новой версии
        Test.startTest();
        // Call the internal method directly with a new dummy blob
        GenerateInvoiceService.generateInvoiceInternal(opp.Id, newDummyPdfBlob);
        Test.stopTest();
 
        // Проверяем, что у ContentDocument стало две версии
        List<ContentVersion> versions = [
            SELECT Id, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :initial.ContentDocumentId
            ORDER BY CreatedDate ASC // To ensure we can check the latest version if needed
        ];
        System.assertEquals(2, versions.size(), 'Должна быть создана новая версия документа');
        // You could also assert the content of the new version if desired
        // System.assertEquals(newDummyPdfBlob.size(), versions[1].VersionData.size(), 'New version data size mismatch');
    }

    // Add a test to ensure the public @AuraEnabled method also works
    @IsTest
    static void testGenerateInvoicePublicMethod() {
        // This test will fail if you run it synchronously because of getContentAsPDF()
        // It requires an asynchronous context for getContentAsPDF()
        // However, if your actual service runs in a @future or similar context,
        // or if Salesforce relaxes this restriction in certain async contexts,
        // this test would be more relevant. For now, it will hit the same getContent error.
        // The previous tests with generateInvoiceInternal are the correct way to test the file logic.
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        // Set the VF page context for getContentAsPDF()
        Test.setCurrentPage(Page.InvoicePDF);
        ApexPages.currentPage().getParameters().put('id', opp.Id);

        Test.startTest();
        // This call will attempt to run getContentAsPDF(), which is the problematic part
        GenerateInvoiceService.generateInvoice(opp.Id);
        Test.stopTest();

        String expectedFileName = 'invoice_' + opp.Id + '.pdf';
        List<ContentVersion> versions = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE Title = :expectedFileName
        ];
        // This assertion might fail depending on how Salesforce handles this in future
        // or if there's a specific test context that allows it.
        // For current general synchronous @isTest methods, this is expected to fail.
        System.assertEquals(1, versions.size(), 'PDF file should have been created by public method.');
    }
}