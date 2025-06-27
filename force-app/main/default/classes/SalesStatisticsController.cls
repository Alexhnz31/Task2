public with sharing class SalesStatisticsController {
    @AuraEnabled(cacheable=true)
    public static AccountSearchResult getAccountOpportunities(
        Id accountId,
        String searchTerm,
        Decimal minAmount,
        Integer pageSize,
        Integer pageNumber
    ) {
        // Устанавливаем значения по умолчанию
        if (pageSize == null || pageSize < 1) pageSize = 10;
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        
        // Подготовка переменных для запроса
        String query = 'SELECT Id, Name, ' +
                      '(SELECT Id, Name, Amount, StageName, CloseDate, CreatedDate ' +
                      'FROM Opportunities WHERE StageName = \'Closed Won\') ' +
                      'FROM Account';
        
        List<String> conditions = new List<String>();
        Map<String, Object> queryParams = new Map<String, Object>();
        
        // Добавляем условия фильтрации
        if (accountId != null) {
            conditions.add('Id = :accountId');
            queryParams.put('accountId', accountId);
        }
        
        if (String.isNotBlank(searchTerm)) {
            conditions.add('Name LIKE :searchTerm');
            queryParams.put('searchTerm', '%' + String.escapeSingleQuotes(searchTerm) + '%');
        }
        
        // Добавляем условия в запрос
        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        query += ' ORDER BY Name';
        
        // Получаем аккаунты без пагинации для фильтрации по сумме
        List<Account> allAccounts = Database.query(query);
        List<AccountSummary> filteredAccounts = new List<AccountSummary>();
        
        // Фильтруем аккаунты по минимальной сумме
        for (Account acc : allAccounts) {
            Decimal totalAmount = 0;
            List<OpportunitySummary> opps = new List<OpportunitySummary>();
            
            for (Opportunity opp : acc.Opportunities) {
                if (opp.Amount != null) {
                    totalAmount += opp.Amount;
                    opps.add(new OpportunitySummary(opp));
                }
            }
            
            // Добавляем аккаунт только если есть opportunities и сумма соответствует фильтру
            if (!opps.isEmpty() && (minAmount == null || totalAmount >= minAmount)) {
                filteredAccounts.add(new AccountSummary(acc, totalAmount, opps));
            }
        }
        
        // Применяем пагинацию к уже отфильтрованному списку
        Integer totalRecords = filteredAccounts.size();
        Integer offset = (pageNumber - 1) * pageSize;
        Integer endIndex = Math.min(offset + pageSize, totalRecords);
        
        List<AccountSummary> paginatedAccounts = new List<AccountSummary>();
        for (Integer i = offset; i < endIndex; i++) {
            paginatedAccounts.add(filteredAccounts[i]);
        }
        
        return new AccountSearchResult(paginatedAccounts, totalRecords, pageSize, pageNumber);
    }

    @AuraEnabled(cacheable=true)
    public static List<OpportunityProductSummary> getOpportunityProducts(Id opportunityId) {
        List<OpportunityProductSummary> result = new List<OpportunityProductSummary>();
        for (OpportunityLineItem oli : [
            SELECT Id, Quantity, TotalPrice, PricebookEntry.Name, Product2.Name
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
        ]) {
            result.add(new OpportunityProductSummary(oli));
        }
        return result;
    }

    // Вспомогательные классы остаются без изменений
    public class AccountSearchResult {
        @AuraEnabled public List<AccountSummary> accounts { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }

        public AccountSearchResult(List<AccountSummary> accounts, Integer totalRecords, Integer pageSize, Integer pageNumber) {
            this.accounts = accounts;
            this.totalRecords = totalRecords;
            this.pageSize = pageSize;
            this.pageNumber = pageNumber;
        }
    }

    public class AccountSummary {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public List<OpportunitySummary> opportunities { get; set; }

        public AccountSummary(Account acc, Decimal totalAmount, List<OpportunitySummary> opportunities) {
            this.id = acc.Id;
            this.name = acc.Name;
            this.totalAmount = totalAmount;
            this.opportunities = opportunities;
        }
    }

    public class OpportunitySummary {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String nameUrl { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String stageName { get; set; }
        @AuraEnabled public Date closeDate { get; set; }
        @AuraEnabled public DateTime createdDate { get; set; }

        public OpportunitySummary(Opportunity opp) {
            this.id = opp.Id;
            this.name = opp.Name;
            this.nameUrl = '/' + opp.Id;
            this.amount = opp.Amount;
            this.stageName = opp.StageName;
            this.closeDate = opp.CloseDate;
            this.createdDate = opp.CreatedDate;
        }
    }

    public class OpportunityProductSummary {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal totalPrice { get; set; }
        @AuraEnabled public String productName { get; set; }

        public OpportunityProductSummary(OpportunityLineItem oli) {
            this.id = oli.Id;
            this.name = oli.PricebookEntry?.Name;
            this.quantity = oli.Quantity;
            this.totalPrice = oli.TotalPrice;
            this.productName = oli.Product2?.Name;
        }
    }
}