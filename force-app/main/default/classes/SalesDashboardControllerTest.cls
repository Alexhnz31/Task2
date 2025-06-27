@IsTest
public class SalesDashboardControllerTest {

    @TestSetup
    static void makeData() {
        // Создание аккаунтов
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Test Account 1'),
            new Account(Name = 'Test Account 2'),
            new Account(Name = 'Test Account 3')
        };
        insert accounts;

        // Создание продуктов
        List<Product2> products = new List<Product2>{
            new Product2(Name = 'Product A', IsActive = true),
            new Product2(Name = 'Product B', IsActive = true)
        };
        insert products;

        // Получаем стандартную прайсбуку
        Id standardPricebookId = Test.getStandardPricebookId();
        
        // Записи стандартной прайсбуки
        List<PricebookEntry> standardPricebookEntries = new List<PricebookEntry>{
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = products[0].Id,
                UnitPrice = 100,
                IsActive = true
            ),
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = products[1].Id,
                UnitPrice = 200,
                IsActive = true
            )
        };
        insert standardPricebookEntries;

        // Создание кастомной прайсбуки
        Pricebook2 customPricebook = new Pricebook2(Name = 'Test Custom Price Book', IsActive = true);
        insert customPricebook;

        // Записи кастомной прайсбуки
        List<PricebookEntry> customPricebookEntries = new List<PricebookEntry>{
            new PricebookEntry(
                Pricebook2Id = customPricebook.Id,
                Product2Id = products[0].Id,
                UnitPrice = 100,
                IsActive = true
            ),
            new PricebookEntry(
                Pricebook2Id = customPricebook.Id,
                Product2Id = products[1].Id,
                UnitPrice = 200,
                IsActive = true
            )
        };
        insert customPricebookEntries;

        // Сделки
        List<Opportunity> opportunities = new List<Opportunity>{
            new Opportunity(
                Name = 'Opp 1 - Acc 1 - Closed Won',
                AccountId = accounts[0].Id,
                StageName = 'Closed Won',
                CloseDate = Date.today().addDays(7),
                Amount = 500,
                Pricebook2Id = customPricebook.Id
            ),
            new Opportunity(
                Name = 'Opp 2 - Acc 1 - Closed Won',
                AccountId = accounts[0].Id,
                StageName = 'Closed Won',
                CloseDate = Date.today().addDays(14),
                Amount = 1000,
                Pricebook2Id = customPricebook.Id
            ),
            new Opportunity(
                Name = 'Opp 3 - Acc 2 - Closed Lost',
                AccountId = accounts[1].Id,
                StageName = 'Closed Lost',
                CloseDate = Date.today().addDays(21),
                Amount = 250,
                Pricebook2Id = customPricebook.Id
            )
        };
        insert opportunities;

        // Товары к сделкам
        List<OpportunityLineItem> olis = new List<OpportunityLineItem>{
            new OpportunityLineItem(
                OpportunityId = opportunities[0].Id,
                Quantity = 2,
                UnitPrice = 100,
                PricebookEntryId = customPricebookEntries[0].Id
            ),
            new OpportunityLineItem(
                OpportunityId = opportunities[0].Id,
                Quantity = 1,
                UnitPrice = 200,
                PricebookEntryId = customPricebookEntries[1].Id
            ),
            new OpportunityLineItem(
                OpportunityId = opportunities[1].Id,
                Quantity = 5,
                UnitPrice = 100,
                PricebookEntryId = customPricebookEntries[0].Id
            ),
            new OpportunityLineItem(
                OpportunityId = opportunities[2].Id,
                Quantity = 1,
                UnitPrice = 200,
                PricebookEntryId = customPricebookEntries[1].Id
            )
        };
        insert olis;
    }

    @IsTest
    static void testGetAllAccountsWithOpportunities_NoAccountId() {
        Test.startTest();
        List<SalesDashboardController.AccountWrapper> accountWrappers =
            SalesDashboardController.getAllAccountsWithOpportunities(null);
        Test.stopTest();

        System.assertEquals(2, accountWrappers.size(), 'Должно быть 2 аккаунта с закрытыми сделками.');

        // Verify the first account
        SalesDashboardController.AccountWrapper acc1 = accountWrappers[0];
        System.assertEquals(2, acc1.opportunities.size(), 'Account 1 should have 2 opportunities');
        System.assertEquals(1500.0, acc1.totalAmount, 'Account 1 total amount should be 1500');
    }

    @IsTest
    static void testGetAllAccountsWithOpportunities_WithAccountId() {
        Id accountId = [SELECT Id FROM Account WHERE Name = 'Test Account 1' LIMIT 1].Id;

        Test.startTest();
        List<SalesDashboardController.AccountWrapper> result =
            SalesDashboardController.getAllAccountsWithOpportunities(accountId);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return exactly 1 account');
        System.assertEquals('Test Account 1', result[0].name, 'Account name should match');
        System.assertEquals(2, result[0].opportunities.size(), 'Should have 2 opportunities');
        System.assertEquals(1500.0, result[0].totalAmount, 'Total amount should be 1500');
    }

    @IsTest
    static void testGetOpportunityProducts() {
        Id oppId = [SELECT Id FROM Opportunity WHERE Name = 'Opp 1 - Acc 1 - Closed Won' LIMIT 1].Id;

        Test.startTest();
        List<OpportunityLineItem> products = SalesDashboardController.getOpportunityProducts(oppId);
        Test.stopTest();

        System.assertEquals(2, products.size(), 'Should return 2 products');
        System.assertEquals('Product A', products[0].Product2.Name, 'First product should be Product A');
        System.assertEquals('Product B', products[1].Product2.Name, 'Second product should be Product B');
    }
}