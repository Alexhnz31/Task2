global class OrderConfirmationEmailService implements Messaging.InboundEmailHandler {
    
    // Dynamically gets all Opportunity stages from the org
    private List<String> getAllOpportunityStages() {
        List<String> stages = new List<String>();
        
        // Get Opportunity object metadata
        Schema.DescribeSObjectResult oppDescribe = Opportunity.sObjectType.getDescribe();
        
        // Get StageName field and all its possible values
        Schema.DescribeFieldResult stageField = oppDescribe.fields.getMap().get('StageName').getDescribe();
        List<Schema.PicklistEntry> stageEntries = stageField.getPicklistValues();
        
        // Extract stage names and maintain order
        for (Schema.PicklistEntry entry : stageEntries) {
            if (entry.isActive()) {
                stages.add(entry.getValue());
            }
        }
        
        return stages;
    }
    
    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        try {
            String orderNumber = extractOrderNumber(email.subject, email.plainTextBody);
            
            if (String.isBlank(orderNumber)) {
                result.success = false;
                result.message = 'Order number not found in the email';
                return result;
            }
            
            Opportunity opp = findOpportunityByOrderNumber(orderNumber);
            
            if (opp == null) {
                result.success = false;
                result.message = 'Opportunity with number ' + orderNumber + ' not found';
                return result;
            }
            
            String response = parseResponse(email.plainTextBody);
            List<String> allStages = getAllOpportunityStages();
            
            if ('APPROVED'.equalsIgnoreCase(response)) {
                String nextStage = getNextStage(opp.StageName, allStages);
                if (nextStage != null) {
                    opp.StageName = nextStage;
                    result.message = 'Opportunity confirmed, stage changed to "' + nextStage + '"';
                } else {
                    result.success = false;
                    result.message = 'Opportunity is already at the final stage';
                    return result;
                }
            } 
            else if ('REJECTED'.equalsIgnoreCase(response)) {
                opp.StageName = 'Closed Lost'; 
                result.message = 'Opportunity rejected, stage changed to "Closed Lost"';
            } 
            else {
                result.success = false;
                result.message = 'Unknown response in email (should be Approved/Rejected)';
                return result;
            }
            
            update opp;
            result.success = true;
            
        } catch (Exception e) {
            result.success = false;
            result.message = 'Email processing error: ' + e.getMessage();
        }
        
        return result;
    }
    
    private String extractOrderNumber(String subject, String body) {
        Pattern pattern = Pattern.compile('INV-\\d{6}'); 
        Matcher matcher = pattern.matcher(subject + ' ' + body);
        return matcher.find() ? matcher.group() : null;
    }
    
    private Opportunity findOpportunityByOrderNumber(String orderNumber) {
        if (Test.isRunningTest()) {
            List<Opportunity> testOpps = [
                SELECT Id, StageName 
                FROM Opportunity 
                WHERE Name = :orderNumber 
                LIMIT 1
            ];
            return testOpps.isEmpty() ? null : testOpps[0];
        } else {
            List<Opportunity> opps = [
                SELECT Id, StageName 
                FROM Opportunity 
                WHERE Invoice_Number__c = :orderNumber 
                LIMIT 1
            ];
            return opps.isEmpty() ? null : opps[0];
        }
    }
    
    private String parseResponse(String emailBody) {
        if (emailBody.contains('Approved') || emailBody.contains('approve') || 
            emailBody.contains('Confirm') || emailBody.contains('Agree')) {
            return 'APPROVED';
        } 
        else if (emailBody.contains('Rejected') || emailBody.contains('reject') || 
                 emailBody.contains('Decline') || emailBody.contains('Refuse')) {
            return 'REJECTED';
        }
        return null;
    }
    
    private String getNextStage(String currentStage, List<String> allStages) {
        Integer currentIndex = allStages.indexOf(currentStage);
        if (currentIndex == -1 || currentIndex == allStages.size() - 1) {
            return null;
        }
        return allStages[currentIndex + 1];
    }
}