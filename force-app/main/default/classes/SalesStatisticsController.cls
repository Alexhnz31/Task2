public with sharing class SalesStatisticsController {
    @AuraEnabled(cacheable=true)
    public static AccountSearchResult getAccountOpportunities(
        Id accountId,
        String searchTerm,
        Decimal minAmount,
        Integer pageSize,
        Integer pageNumber
    ) {
        if (pageSize == null || pageSize < 1) pageSize = 10;
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        List<AccountSummary> result = new List<AccountSummary>();
        Integer totalRecords = 0;
        List<Account> accounts;
        List<String> conditions = new List<String>();
        
        String idField = 'Id';
        String nameField = 'Name';
        String accTable = 'Account';
        String oppSubquery = 'Opportunities';
        String isClosedField = 'IsClosed';
        String trueVal = 'true';
        String amountField = 'Amount';
        String stageNameField = 'StageName';
        String closeDateField = 'CloseDate';
        String createdDateField = 'CreatedDate';
        String selectClause = 'SELECT ' + idField + ', ' + nameField + ', (SELECT ' + idField + ', ' + nameField + ', ' + amountField + ', ' + stageNameField + ', ' + closeDateField + ', ' + createdDateField + ' FROM ' + oppSubquery + ' WHERE ' + isClosedField + ' = ' + trueVal + ') FROM ' + accTable;
        String whereStr = ' WHERE ';
        String andStr = ' AND ';
        String likeStr = ' LIKE ';
        String orderBy = ' ORDER BY ' + nameField + ' LIMIT :pageSize OFFSET :offset';
        String countSelect = 'SELECT COUNT() FROM ' + accTable;
        String percent = '%';
        String slash = '/';
        // WHERE conditions
        if (accountId != null) {
            conditions.add(idField + ' = :accountId');
        }
        if (String.isNotBlank(searchTerm)) {
            String search = percent + String.escapeSingleQuotes(searchTerm) + percent;
            conditions.add(nameField + likeStr + ':search');
        }
        String baseQuery = selectClause;
        if (!conditions.isEmpty()) {
            baseQuery += whereStr + String.join(conditions, andStr);
        }
        if (accountId == null) {
            Integer offset = (pageNumber - 1) * pageSize;
            baseQuery += orderBy;
        }
        // Count total records
        String countQuery = countSelect;
        if (!conditions.isEmpty()) {
            countQuery += whereStr + String.join(conditions, andStr);
        }
        totalRecords = Database.countQuery(countQuery);
        accounts = Database.query(baseQuery);
        for (Account acc : accounts) {
            Decimal totalAmount = 0;
            List<OpportunitySummary> opps = new List<OpportunitySummary>();
            for (Opportunity opp : acc.Opportunities) {
                if (opp.Amount != null) {
                    totalAmount += opp.Amount;
                    opps.add(new OpportunitySummary(opp, slash));
                }
            }
            if (minAmount == null || totalAmount >= minAmount) {
                result.add(new AccountSummary(acc.Id, acc.Name, totalAmount, opps));
            }
        }
        return new AccountSearchResult(result, totalRecords, pageSize, pageNumber);
    }

    @AuraEnabled(cacheable=true)
    public static List<OpportunityProductSummary> getOpportunityProducts(Id opportunityId) {
        List<OpportunityProductSummary> result = new List<OpportunityProductSummary>();
        for (OpportunityLineItem oli : [SELECT Id, Quantity, TotalPrice, PricebookEntry.Name, Product2.Name FROM OpportunityLineItem WHERE OpportunityId = :opportunityId]) {
            result.add(new OpportunityProductSummary(oli));
        }
        return result;
    }

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
        public AccountSummary(Id id, String name, Decimal totalAmount, List<OpportunitySummary> opportunities) {
            this.id = id;
            this.name = name;
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
        @AuraEnabled public DateTime closeDate { get; set; }
        @AuraEnabled public DateTime createdDate { get; set; }
        public OpportunitySummary(Opportunity opp, String slash) {
            this.id = opp.Id;
            this.name = opp.Name;
            this.nameUrl = slash + opp.Id;
            this.amount = opp.Amount;
            this.stageName = opp.StageName;
            this.closeDate = DateTime.newInstance(opp.CloseDate, Time.newInstance(0, 0, 0, 0));
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
            this.name = oli.PricebookEntry != null ? oli.PricebookEntry.Name : null;
            this.quantity = oli.Quantity;
            this.totalPrice = oli.TotalPrice;
            this.productName = oli.Product2 != null ? oli.Product2.Name : null;
        }
    }
}
