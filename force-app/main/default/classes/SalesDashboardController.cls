public with sharing class SalesDashboardController {
    
    @AuraEnabled(cacheable=true)
    public static List<AccountWrapper> getAllAccountsWithOpportunities(Id accountId) {
        List<AccountWrapper> result = new List<AccountWrapper>();
        
        String query = 'SELECT Id, Name, (SELECT Id, Name, Amount, CloseDate, StageName ' +
                      'FROM Opportunities WHERE IsClosed = true ORDER BY CreatedDate DESC) ' +
                      'FROM Account';
        
        if (accountId != null) {
            query += ' WHERE Id = :accountId';
        } else {
            query += ' WHERE Id IN (SELECT AccountId FROM Opportunity WHERE IsClosed = true)';
        }
        
        query += ' LIMIT 1000';
        
        for (Account acc : Database.query(query)) {
            Decimal totalAmount = 0;
            List<OpportunityWrapper> oppWrappers = new List<OpportunityWrapper>();
            
            for (Opportunity opp : acc.Opportunities) {
                Decimal oppAmount = opp.Amount != null ? opp.Amount : 0;
                totalAmount += oppAmount;
                
                // Get products separately to avoid SOQL depth limitation
                List<OpportunityLineItem> products = getOpportunityProducts(opp.Id);
                
                oppWrappers.add(new OpportunityWrapper(
                    opp.Id,
                    opp.Name,
                    oppAmount,
                    opp.CloseDate,
                    opp.StageName,
                    products
                ));
            }
            
            if (!oppWrappers.isEmpty()) {
                result.add(new AccountWrapper(
                    acc.Id,
                    acc.Name,
                    totalAmount,
                    oppWrappers
                ));
            }
        }
        
        return result;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<OpportunityLineItem> getOpportunityProducts(Id opportunityId) {
        return [SELECT Id, Product2.Name, Quantity, UnitPrice, TotalPrice 
                FROM OpportunityLineItem 
                WHERE OpportunityId = :opportunityId
                ORDER BY Product2.Name];
    }
    
    public class AccountWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public List<OpportunityWrapper> opportunities;
        
        public AccountWrapper(String id, String name, Decimal totalAmount, List<OpportunityWrapper> opportunities) {
            this.id = id;
            this.name = name;
            this.totalAmount = totalAmount;
            this.opportunities = opportunities;
        }
    }
    
    public class OpportunityWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date closeDate;
        @AuraEnabled public String stageName;
        @AuraEnabled public List<OpportunityLineItem> products;
        
        public OpportunityWrapper(String id, String name, Decimal amount, Date closeDate, 
                                String stageName, List<OpportunityLineItem> products) {
            this.id = id;
            this.name = name;
            this.amount = amount;
            this.closeDate = closeDate;
            this.stageName = stageName;
            this.products = products;
        }
    }
}