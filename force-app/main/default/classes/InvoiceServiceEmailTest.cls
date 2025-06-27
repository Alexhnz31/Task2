@isTest
public class InvoiceServiceEmailTest {

    private static void setupTestData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;

        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb.Id,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 100
        );
        insert oli;

        Contact contact = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id,
            Phone = '1234567890',
            Email = 'test@example.com'
        );
        insert contact;

        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = contact.Id,
            Role = 'Business User',
            IsPrimary = true
        );
        insert ocr;
    }

    @isTest static void testInvoiceControllerConstructor() {
        setupTestData();

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];

        PageReference pageRef = new PageReference('/');
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', opp.Id);

        Test.startTest();
        InvoiceController controller = new InvoiceController();
        Test.stopTest();

        System.assertNotEquals(null, controller.products, 'Products list should not be null');
        System.assert(controller.products.size() > 0, 'There should be at least one product');
        System.assertEquals('Test Account', controller.accountName, 'Account name should be Test Account');
        System.assertNotEquals(null, controller.opportunityOwner, 'Opportunity owner should not be null');
        System.assertEquals('Test Contact', controller.contactName, 'Contact name should be Test Contact');
        System.assertEquals('1234567890', controller.contactPhone, 'Contact phone should match');
        System.assertEquals('test@example.com', controller.contactEmail, 'Contact email should match');
        System.assertEquals('$', controller.currencySymbol, 'Currency symbol should be $');
    }

    @isTest static void testGetPrimaryContact() {
        setupTestData();
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];

        Test.startTest();
        InvoiceController.ContactInfo contactInfo = InvoiceController.getPrimaryContact(opp.Id);
        Test.stopTest();

        System.assertEquals('Test Contact', contactInfo.name);
        System.assertEquals('test@example.com', contactInfo.email);
        System.assertEquals('1234567890', contactInfo.phone);
    }

    @isTest static void testGetEmailTemplates() {
        // В тестах EmailTemplate может быть пустым,
        // просто проверяем, что метод не падает и возвращает список
        Test.startTest();
        List<EmailTemplate> templates = InvoiceController.getEmailTemplates();
        Test.stopTest();

        System.assertNotEquals(null, templates, 'Templates list should not be null');
    }

    @isTest static void testGetEmailTemplateBody() {
        // Используем try-catch, так как в тестах нет реального шаблона
        Id fakeTemplateId = null;
        Id fakeOpportunityId = null;
        try {
            // Можно взять реальные Id из данных, если они есть
            // Но чтобы избежать ошибок, передадим null — вызов должен упасть
            Test.startTest();
            InvoiceController.getEmailTemplateBody(fakeTemplateId, fakeOpportunityId);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException due to invalid parameters');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception message should be returned');
        }
    }

    @isTest static void testGetContentDocumentLinks() {
        Account acc = new Account(Name = 'CDL Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'CDL Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        Test.startTest();
        List<InvoiceController.ContentDocumentLinkWrapper> links = InvoiceController.getContentDocumentLinks(opp.Id, 'PDF');
        Test.stopTest();

        System.assertNotEquals(null, links, 'Links list should not be null');
        System.assertEquals(0, links.size(), 'Links list should be empty without ContentDocuments');
    }

    @isTest static void testSendInvoiceEmail_NoLinks() {
        setupTestData();

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];

        Test.startTest();
        try {
            InvoiceController.sendInvoiceEmail(opp.Id, null, 'Subject', 'Body', 'test@test.com');
            System.assert(false, 'Expected AuraHandledException due to no invoice found');
        } catch (AuraHandledException e) {
            System.assertEquals('No invoice found for this opportunity', e.getMessage());
        }
        Test.stopTest();
    }
}