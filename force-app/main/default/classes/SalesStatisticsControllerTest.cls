@IsTest
private class SalesStatisticsControllerTest {

    @IsTest
    static void testGetAccountOpportunities() {
        // Создаем аккаунт
        Account acc1 = new Account(Name = 'Test Account 1');
        insert acc1;

        // Создаем выигранную сделку
        Opportunity opp1 = new Opportunity(
            Name = 'Opportunity 1',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 10000,
            AccountId = acc1.Id
        );
        insert opp1;

        Opportunity opp2 = new Opportunity(
            Name = 'Opportunity 2',
            StageName = 'Closed Lost',
            CloseDate = Date.today().addDays(-10),
            Amount = 500,
            AccountId = acc1.Id
        );
        insert opp2;

        Test.startTest();

        SalesStatisticsController.AccountSearchResult resultFiltered = 
            SalesStatisticsController.getAccountOpportunities(
                acc1.Id,
                null,
                800,
                10,
                1
            );

        Test.stopTest();

        System.assertNotEquals(null, resultFiltered, 'Result should not be null');
        System.assertEquals(1, resultFiltered.accounts.size(), 'Should return 1 account');

        SalesStatisticsController.AccountSummary accSummary = resultFiltered.accounts[0];
        
        System.debug('Total amount: ' + accSummary.totalAmount);

        System.assertEquals(10000, accSummary.totalAmount, 'Total amount should match');

        System.assert(accSummary.opportunities.size() > 0, 'Opportunities list should not be empty');
        for (SalesStatisticsController.OpportunitySummary oppSummary : accSummary.opportunities) {
            System.assertNotEquals(null, oppSummary.amount, 'Amount should not be null');
            System.assertEquals('Closed Won', oppSummary.stageName, 'StageName should be Closed Won');
        }
    }
}