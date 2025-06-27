@IsTest
private class InvoiceServiceTest {
    @TestSetup
    static void setupTestData() {
        // Создаем тестовые данные без попытки обновления Invoice_Number__c
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Closed Won',
            CloseDate = Date.today()
        );
        insert testOpp;
    }

    @IsTest
    static void testGenerateInvoiceCreatesNewFile() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        Blob mockPdf = Blob.valueOf('Test PDF Content');
        String expectedFileName = 'INV-' + testOpp.Id + '.pdf'; // Ожидаемое имя файла
        
        Test.startTest();
        InvoiceService.setMockPdfGenerator(mockPdf);
        InvoiceService.generateInvoice(testOpp.Id);
        Test.stopTest();
        
        // Проверяем результаты
        List<ContentVersion> versions = [SELECT Id, Title, PathOnClient, VersionData FROM ContentVersion];
        System.assertEquals(1, versions.size(), 'Должен быть создан один файл');
        System.assertEquals(expectedFileName, versions[0].PathOnClient, 'Имя файла должно соответствовать шаблону');
        System.assertEquals('Test PDF Content', versions[0].VersionData.toString(), 'Содержимое файла должно совпадать');
    }

    @IsTest
    static void testGenerateInvoiceUpdatesExistingFile() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        String fileName = 'INV-TEST-UPDATE.pdf'; // Используем фиксированное имя для теста
        Blob initialPdf = Blob.valueOf('Initial PDF');
        
        // Создаем первоначальный файл
        ContentVersion initialCv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = initialPdf,
            FirstPublishLocationId = testOpp.Id
        );
        insert initialCv;
        
        Test.startTest();
        InvoiceService.setMockPdfGenerator(Blob.valueOf('Updated PDF'));
        InvoiceService.generateInvoice(testOpp.Id);
        Test.stopTest();
        
        // Проверяем, что создана новая версия
        List<ContentVersion> versions = [SELECT Id, VersionData FROM ContentVersion 
                                       WHERE PathOnClient = :fileName 
                                       ORDER BY CreatedDate DESC];
        System.assertEquals(2, versions.size(), 'Должна быть создана новая версия файла');
        System.assertEquals('Updated PDF', versions[0].VersionData.toString(), 'Содержимое должно быть обновлено');
    }

    @IsTest
    static void testGenerateInvoiceWithInvalidId() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            InvoiceService.generateInvoice('001000000000000'); // Неверный ID
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof QueryException, 'Ожидалось QueryException');
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Должно быть выброшено исключение при неверном ID');
    }

    @IsTest
    static void testFileAttachmentFunctionality() {
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        Blob firstPdf = Blob.valueOf('First Version');
        Blob secondPdf = Blob.valueOf('Second Version');
        
        Test.startTest();
        // Первый вызов - создание файла
        InvoiceService.setMockPdfGenerator(firstPdf);
        InvoiceService.generateInvoice(testOpp.Id);
        
        // Второй вызов - обновление файла
        InvoiceService.setMockPdfGenerator(secondPdf);
        InvoiceService.generateInvoice(testOpp.Id);
        Test.stopTest();
        
        // Проверяем, что создан один документ с двумя версиями
        List<ContentVersion> versions = [SELECT Id, VersionData FROM ContentVersion 
                                       ORDER BY CreatedDate];
        System.assertEquals(2, versions.size(), 'Должно быть две версии файла');
        System.assertEquals('First Version', versions[0].VersionData.toString(), 
                          'Первая версия должна содержать правильные данные');
        System.assertEquals('Second Version', versions[1].VersionData.toString(), 
                          'Вторая версия должна содержать обновленные данные');
        
        // Дополнительная проверка, что это версии одного документа
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion]) {
            contentDocumentIds.add(cv.ContentDocumentId);
        }
        System.assertEquals(1, contentDocumentIds.size(), 
                          'Все версии должны принадлежать одному документу');
    }
}